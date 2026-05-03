/**
 * ToolGroupUtils - Logic for grouping consecutive tool calls
 * 
 * Groups consecutive "exploration" tools (read, list, search, grep)
 * into collapsible "Explored" summaries while keeping "action" tools separate.
 * 
 * Uses substring-based pattern matching to handle various tool naming conventions
 * (MCP tools, backend tools, etc.)
 * 
 * Key rules:
 * - Read-only operations are grouped → Reduces noise
 * - Mutations break groups → Important changes are always visible
 * - Error states are NOT grouped → Failures should be visible
 * - Single items are NOT grouped → No grouping overhead for singles
 */
module Message = Client__State__Types.Message
module Types = Client__ToolGroupTypes
module ToolLabels = Client__ToolLabels
module TodoUtils = Client__TodoUtils

// ============================================================================
// Helper Functions
// ============================================================================

// ============================================================================
// Tool Classification (using substring matching like ToolLabels)
// ============================================================================

let includesAny = (name, needles) => needles->Array.some(needle => String.includes(name, needle))

module BrowserAction = {
  type t = [#click | #typeText | #hover | #select | #pressKey | #resize | #executeJs]

  let all: array<t> = [#click, #typeText, #hover, #select, #pressKey, #resize, #executeJs]

  let toolName = (action: t): string =>
    switch action {
    | #click => "click"
    | #typeText => "type"
    | #hover => "hover"
    | #select => "select"
    | #pressKey => "press_key"
    | #resize => "resize"
    | #executeJs => "execute_js"
    }

  let matchesLowercaseToolName = (name: string, action: t): bool => {
    switch action {
    | #executeJs => name == toolName(action)
    | #click | #typeText | #hover | #select | #pressKey | #resize =>
      String.includes(name, toolName(action))
    }
  }

  let fromLowercaseToolName = (name: string): option<t> =>
    all->Array.find(action => matchesLowercaseToolName(name, action))

  let fromToolName = (toolNameToMatch: string): option<t> =>
    toolNameToMatch->String.toLowerCase->fromLowercaseToolName
}

let browserExplorationNeedles = ["snapshot", "screenshot", "console", "network"]
let groupableToolNeedles = ["read", "get", "fetch", "list", "search", "grep", "find"]
let groupingBreakerNeedles = [
  "edit",
  "write",
  "create",
  "delete",
  "remove",
  "terminal",
  "command",
  "run",
  "shell",
  "task",
]
let searchToolNeedles = ["search", "grep", "find"]
let definitionToolNeedles = ["definition", "symbol"]
let directoryToolNeedles = ["list", "dir"]
let browserSnapshotNeedles = ["snapshot", "screenshot"]

/**
 * Check if tool is browser exploration (not action)
 * Snapshots, console logs, network requests are read-only
 */
let isBrowserExploration = (toolName: string): bool => {
  let name = String.toLowerCase(toolName)
  includesAny(name, browserExplorationNeedles)
}

/**
 * Groupable tools (Read-Only/Exploratory)
 * Uses substring matching to handle various naming conventions.
 */
let isGroupableTool = (toolName: string): bool => {
  let name = String.toLowerCase(toolName)

  includesAny(name, groupableToolNeedles) ||
  includesAny(name, definitionToolNeedles) ||
  isBrowserExploration(name)
}

/**
 * Non-Groupable tools (Mutations / Group Breakers)
 * When any of these are encountered, the current group closes.
 */
let breaksGrouping = (toolName: string): bool => {
  let name = String.toLowerCase(toolName)

  includesAny(name, groupingBreakerNeedles) ||
  BrowserAction.fromLowercaseToolName(name)->Option.isSome ||
  (String.includes(name, "fix") && !String.includes(name, "prefix"))
}

/**
 * Check if tool call is from a subagent
 */
let isSubagentToolCall = (tc: Message.toolCall): bool => {
  Option.isSome(tc.parentAgentId)
}

/**
 * Determine the group type for a tool
 */
let getGroupType = (toolName: string): Types.groupType => {
  let name = String.toLowerCase(toolName)
  if String.includes(name, "browser") || String.includes(name, "snapshot") {
    Types.Browser
  } else if String.includes(name, "plan") {
    Types.PrePlan
  } else {
    Types.Activity
  }
}

// ============================================================================
// Summary Calculation
// ============================================================================

/**
 * Extract file path from tool input
 */
let extractFilePath = (input: option<JSON.t>): option<string> => {
  ToolLabels.extractTargetFromInput(input)
}

let appendPath = (items, path) => path->Option.mapOr(items, p => Array.concat(items, [p]))

let incrementIf = (count, condition) =>
  switch condition {
  | true => count + 1
  | false => count
  }

/**
 * Extract todo statistics from a todo_write tool's input
 * The input contains the todos array with status changes
 */
let extractTodoStatsFromInput = (input: option<JSON.t>): (int, int, int, int, int) => {
  // Returns: (total, created, completed, started, cancelled)
  switch input {
  | Some(json) =>
    switch JSON.Decode.object(json) {
    | Some(obj) =>
      // Check for "todos" array in input
      let todosField = obj->Dict.get("todos")
      switch todosField {
      | Some(todosJson) =>
        switch JSON.Decode.array(todosJson) {
        | Some(arr) =>
          let (created, completed, started, cancelled) = arr->Array.reduce((0, 0, 0, 0), (
            (c, comp, s, can),
            item,
          ) => {
            switch JSON.Decode.object(item) {
            | Some(itemObj) =>
              let status =
                itemObj
                ->Dict.get("status")
                ->Option.flatMap(JSON.Decode.string)
                ->Option.getOr("")
                ->String.toLowerCase

              // Count by status
              switch status {
              | "completed" | "complete" | "done" => (c, comp + 1, s, can)
              | "in_progress" | "in-progress" | "started" | "running" => (c, comp, s + 1, can)
              | "cancelled" | "canceled" | "removed" => (c, comp, s, can + 1)
              | "pending" => (c + 1, comp, s, can) // New pending = created
              | _ => (c, comp, s, can)
              }
            | None => (c, comp, s, can)
            }
          })
          (Array.length(arr), created, completed, started, cancelled)
        | None => (0, 0, 0, 0, 0)
        }
      | None => (0, 0, 0, 0, 0)
      }
    | None => (0, 0, 0, 0, 0)
    }
  | None => (0, 0, 0, 0, 0)
  }
}

/**
 * Calculate summary statistics from grouped tool calls
 */
let calculateSummary = (tools: array<Message.toolCall>): Types.toolsSummary => {
  tools->Array.reduce(Types.emptySummary, (acc, tool) => {
    let name = String.toLowerCase(tool.toolName)
    let path = extractFilePath(tool.input)

    // File reads
    let files = if String.includes(name, "read") && !String.includes(name, "lint") {
      appendPath(acc.files, path)
    } else {
      acc.files
    }

    // Directory listings
    let directories = if includesAny(name, directoryToolNeedles) {
      appendPath(acc.directories, path)
    } else {
      acc.directories
    }

    // Searches (grep, search, find)
    let searches = incrementIf(acc.searches, includesAny(name, searchToolNeedles))

    // Definition/symbol lookups
    let definitions = incrementIf(acc.definitions, includesAny(name, definitionToolNeedles))

    // Browser snapshots/screenshots
    let browserSnapshots = incrementIf(
      acc.browserSnapshots,
      includesAny(name, browserSnapshotNeedles),
    )

    // Todo operations
    let (
      todos,
      todosNewlyCreated,
      todosNewlyCompleted,
      todosNewlyStarted,
      todosNewlyCancelled,
    ) = if TodoUtils.isTodoTool(tool.toolName) {
      let (total, created, completed, started, cancelled) = extractTodoStatsFromInput(tool.input)
      (
        acc.todos + total,
        acc.todosNewlyCreated + created,
        acc.todosNewlyCompleted + completed,
        acc.todosNewlyStarted + started,
        acc.todosNewlyCancelled + cancelled,
      )
    } else {
      (
        acc.todos,
        acc.todosNewlyCreated,
        acc.todosNewlyCompleted,
        acc.todosNewlyStarted,
        acc.todosNewlyCancelled,
      )
    }

    {
      files,
      directories,
      searches,
      definitions,
      browserSnapshots,
      tools: Array.concat(acc.tools, [tool.toolName]),
      todos,
      todosNewlyCreated,
      todosNewlyCompleted,
      todosNewlyStarted,
      todosNewlyCancelled,
    }
  })
}

// ============================================================================
// Label Generation
// ============================================================================

/**
 * Get unique items from an array
 */
let unique = (arr: array<string>): array<string> => {
  arr->Array.reduce([], (acc, item) => {
    if acc->Array.includes(item) {
      acc
    } else {
      Array.concat(acc, [item])
    }
  })
}

/**
 * Generate a nice label for todo changes
 * Returns labels like:
 * - "completed 2 to-dos"
 * - "started 1 to-do"
 * - "created 3 to-dos, completed 2"
 */
let generateTodoLabel = (summary: Types.toolsSummary): option<string> => {
  let parts = []

  // Created todos
  let parts = if summary.todosNewlyCreated > 0 {
    let label = `created ${Int.toString(
        summary.todosNewlyCreated,
      )} to-do${summary.todosNewlyCreated == 1 ? "" : "s"}`
    Array.concat(parts, [label])
  } else {
    parts
  }

  // Completed todos
  let parts = if summary.todosNewlyCompleted > 0 {
    let label = `completed ${Int.toString(summary.todosNewlyCompleted)}`
    Array.concat(parts, [label])
  } else {
    parts
  }

  // Started todos (in_progress)
  let parts = if summary.todosNewlyStarted > 0 {
    let label = `started ${Int.toString(summary.todosNewlyStarted)}`
    Array.concat(parts, [label])
  } else {
    parts
  }

  // Cancelled todos
  let parts = if summary.todosNewlyCancelled > 0 {
    let label = `cancelled ${Int.toString(summary.todosNewlyCancelled)}`
    Array.concat(parts, [label])
  } else {
    parts
  }

  // If we have any parts, join them
  if Array.length(parts) > 0 {
    Some(Array.join(parts, ", "))
  } else if summary.todos > 0 {
    // Fallback: just show total count if we have todos but no specific actions
    Some(`${Int.toString(summary.todos)} to-do${summary.todos == 1 ? "" : "s"}`)
  } else {
    None
  }
}

/**
 * Generate summary labels from statistics
 * Returns an array like ["1 directory", "2 files", "3 searches"]
 * 
 * Activity Order:
 * 1. list → "N director(y|ies)"
 * 2. file → "N file(s)"  
 * 3. search → "N search(es)"
 * 4. definition → "found N definition(s)"
 * 5. todo → "completed N to-dos, started N"
 * 6. snapshot → "N snapshot(s)"
 */
let generateSummaryLabels = (summary: Types.toolsSummary): array<string> => {
  let labels = []

  // 1. Directories (list)
  let uniqueDirs = unique(summary.directories)
  let labels = if Array.length(uniqueDirs) > 0 {
    let count = Array.length(uniqueDirs)
    let label = `${Int.toString(count)} director${count == 1 ? "y" : "ies"}`
    Array.concat(labels, [label])
  } else {
    labels
  }

  // 2. Files
  let uniqueFiles = unique(summary.files)
  let labels = if Array.length(uniqueFiles) > 0 {
    let count = Array.length(uniqueFiles)
    let label = `${Int.toString(count)} file${count == 1 ? "" : "s"}`
    Array.concat(labels, [label])
  } else {
    labels
  }

  // 3. Searches
  let labels = if summary.searches > 0 {
    let label = `${Int.toString(summary.searches)} search${summary.searches == 1 ? "" : "es"}`
    Array.concat(labels, [label])
  } else {
    labels
  }

  // 4. Definitions
  let labels = if summary.definitions > 0 {
    let label = if summary.definitions == 1 {
      "found definition"
    } else {
      `found ${Int.toString(summary.definitions)} definitions`
    }
    Array.concat(labels, [label])
  } else {
    labels
  }

  // 5. Todos
  let labels = switch generateTodoLabel(summary) {
  | Some(todoLabel) => Array.concat(labels, [todoLabel])
  | None => labels
  }

  // 6. Browser snapshots
  let labels = if summary.browserSnapshots > 0 {
    let label = `${Int.toString(summary.browserSnapshots)} snapshot${summary.browserSnapshots == 1
        ? ""
        : "s"}`
    Array.concat(labels, [label])
  } else {
    labels
  }

  // Fallback if no specific labels - show operation count
  if Array.length(labels) == 0 {
    let count = Array.length(summary.tools)
    [`${Int.toString(count)} operation${count == 1 ? "" : "s"}`]
  } else {
    labels
  }
}

// ============================================================================
// Grouping Logic
// ============================================================================

/**
 * Check if a tool call has an error state
 * Error states should NOT be grouped - failures should be visible
 */
let hasError = (tc: Message.toolCall): bool => {
  tc.state == Message.OutputError || Option.isSome(tc.errorText)
}

/**
 * Group consecutive tool calls into display items
 * 
 * Algorithm:
 * 1. For each message, check if it's groupable
 * 2. If groupable AND no error → add to current group
 * 3. If not groupable OR has error → close current group, render individually
 * 4. At end, close any remaining group
 * 5. Single-item groups are expanded to individuals (no grouping overhead)
 * 6. Subagent tool calls (identified by parentAgentId) are grouped separately with "Processed" prefix
 *
 * @param toolCalls Array of tool calls to group
 * @param groupSubagents Whether to group subagent tool calls (default: true)
 * @param minGroupSize Minimum tools needed to form a group (default: 2)
 */
let groupToolCalls = (
  toolCalls: array<Message.toolCall>,
  ~groupSubagents: bool=true,
  ~minGroupSize: int=1,
): array<Types.displayItem> => {
  let result: array<Types.displayItem> = []
  let currentGroup: ref<array<Message.toolCall>> = ref([])
  let currentGroupType: ref<option<Types.groupType>> = ref(None)
  let currentIsSubagent: ref<bool> = ref(false)
  let currentParentAgentId: ref<option<string>> = ref(None)

  // Flush current group to results
  let flushGroup = () => {
    let group = currentGroup.contents

    // Check if group is entirely todo tools - use minGroupSize=2 for those
    let isTodoOnlyGroup =
      Array.length(group) > 0 && group->Array.every(tc => TodoUtils.isTodoTool(tc.toolName))

    // For subagent and explored groups: minGroupSize=1
    // For todo-only groups: minGroupSize=2
    let effectiveMinSize = if isTodoOnlyGroup {
      2
    } else {
      minGroupSize
    }

    if Array.length(group) >= effectiveMinSize {
      // Create a proper group
      let summary = calculateSummary(group)
      let groupType = currentGroupType.contents->Option.getOr(Types.Activity)
      // Get spawningToolName from first tool in group (for subagent groups)
      let spawningToolName = group->Array.get(0)->Option.flatMap(tc => tc.spawningToolName)
      // Generate stable ID from first tool call's ID (stable across re-renders)
      let firstToolId = group->Array.get(0)->Option.mapOr("unknown", tc => tc.id)
      let toolGroup: Types.toolGroup = {
        id: `group-${firstToolId}`,
        groupType,
        toolCalls: group,
        summary,
        prefix: Types.getPrefixForGroupType(groupType),
        spawningToolName,
      }
      result->Array.push(Types.ToolGroup(toolGroup))
    } else {
      // Not enough to group - emit as singles
      group->Array.forEach(tc => {
        result->Array.push(Types.SingleTool(tc))
      })
    }
    currentGroup := []
    currentGroupType := None
    currentIsSubagent := false
    currentParentAgentId := None
  }

  // Check if this specific tool call should be grouped (for main agent)
  let shouldGroupToolCall = (tc: Message.toolCall): bool =>
    !hasError(tc) && !breaksGrouping(tc.toolName) && isGroupableTool(tc.toolName)

  toolCalls->Array.forEach(tc => {
    let isSubagent = isSubagentToolCall(tc)

    // Only check subagent switching when groupSubagents is true
    // When groupSubagents is false, we're treating all tools as normal tools
    if groupSubagents {
      // If switching between subagent and main agent, flush the current group
      if currentIsSubagent.contents != isSubagent && Array.length(currentGroup.contents) > 0 {
        flushGroup()
      }

      // If switching to a different subagent (different parentAgentId), flush the current group
      if isSubagent && currentIsSubagent.contents {
        let currentParent = currentParentAgentId.contents
        let newParent = tc.parentAgentId
        switch (currentParent, newParent) {
        | (Some(current), Some(new_)) if current != new_ =>
          // Different subagent - flush and start new group
          flushGroup()
        | _ => ()
        }
      }
    }

    if isSubagent && groupSubagents {
      // Subagent tool calls are grouped together regardless of tool type
      // INCLUDING error states - we want to keep the group together
      currentIsSubagent := true
      currentGroupType := Some(Types.Subagent)
      currentParentAgentId := tc.parentAgentId
      currentGroup.contents->Array.push(tc)
    } else if shouldGroupToolCall(tc) {
      let toolGroupType = getGroupType(tc.toolName)

      // If group type changes, flush current group first
      switch currentGroupType.contents {
      | Some(current) if current != toolGroupType => flushGroup()
      | _ => ()
      }

      currentIsSubagent := false
      currentGroupType := Some(toolGroupType)
      currentGroup.contents->Array.push(tc)
    } else {
      // Non-groupable tool - render individually
      flushGroup()
      result->Array.push(Types.SingleTool(tc))
    }
  })

  // Flush any remaining group at the end
  flushGroup()

  result
}

/**
 * Get prefix for current group based on loading state and open state
 * Returns "Exploring" if any tool is still loading OR if group is still open
 * A group is "open" when it's the last group and the agent is still running
 */
let getGroupPrefix = (group: Types.toolGroup, ~isOpen: bool=false): string => {
  let isLoading = group.toolCalls->Array.some(tc => {
    switch tc.state {
    | Message.InputStreaming | Message.InputAvailable => true
    | Message.OutputAvailable | Message.OutputError => false
    }
  })

  // Show loading prefix if any tool is loading OR if group is still open
  if isLoading || isOpen {
    switch group.groupType {
    | Types.Activity => "Exploring..."
    | Types.Browser => "Performing..."
    | Types.PrePlan => "Preparing plan..."
    | Types.Subagent => "Processing..."
    }
  } else {
    group.prefix
  }
}

/**
 * Generate a summary label for subagent grouped tools
 * Shows tool types executed by the subagent
 */
let generateSubagentSummaryLabel = (summary: Types.toolsSummary): string => {
  let count = Array.length(summary.tools)
  if count == 1 {
    "1 operation"
  } else {
    `${Int.toString(count)} operations`
  }
}
