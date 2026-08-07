module Message = Client__State__Types.Message
module Types = Client__ToolGroupTypes
module ToolLabels = Client__ToolLabels
module TodoUtils = Client__TodoUtils

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

let isBrowserExploration = (toolName: string): bool => {
  let name = String.toLowerCase(toolName)
  includesAny(name, browserExplorationNeedles)
}

let isGroupableTool = (toolName: string): bool => {
  let name = String.toLowerCase(toolName)

  includesAny(name, groupableToolNeedles) ||
  includesAny(name, definitionToolNeedles) ||
  isBrowserExploration(name)
}

let breaksGrouping = (toolName: string): bool => {
  let name = String.toLowerCase(toolName)

  includesAny(name, groupingBreakerNeedles) ||
  BrowserAction.fromLowercaseToolName(name)->Option.isSome ||
  (String.includes(name, "fix") && !String.includes(name, "prefix"))
}

let isSubagentToolCall = (tc: Message.toolCall): bool => {
  Option.isSome(tc.parentAgentId)
}

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

let extractFilePath = (input: option<JSON.t>): option<string> => {
  ToolLabels.extractTargetFromInput(input)
}

let appendPath = (items, path) => path->Option.mapOr(items, p => Array.concat(items, [p]))

let incrementIf = (count, condition) =>
  switch condition {
  | true => count + 1
  | false => count
  }

let calculateSummary = (tools: array<Message.toolCall>): Types.toolsSummary => {
  tools->Array.reduce(Types.emptySummary, (acc, tool) => {
    let name = String.toLowerCase(tool.toolName)
    let path = extractFilePath(tool.input)

    let files = if String.includes(name, "read") && !String.includes(name, "lint") {
      appendPath(acc.files, path)
    } else {
      acc.files
    }

    let directories = if includesAny(name, directoryToolNeedles) {
      appendPath(acc.directories, path)
    } else {
      acc.directories
    }

    let searches = incrementIf(acc.searches, includesAny(name, searchToolNeedles))

    let definitions = incrementIf(acc.definitions, includesAny(name, definitionToolNeedles))

    let browserSnapshots = incrementIf(
      acc.browserSnapshots,
      includesAny(name, browserSnapshotNeedles),
    )

    {
      files,
      directories,
      searches,
      definitions,
      browserSnapshots,
      tools: Array.concat(acc.tools, [tool.toolName]),
    }
  })
}

let unique = (arr: array<string>): array<string> => {
  arr->Array.reduce([], (acc, item) => {
    if acc->Array.includes(item) {
      acc
    } else {
      Array.concat(acc, [item])
    }
  })
}

let generateSummaryLabels = (summary: Types.toolsSummary): array<string> => {
  let labels = []

  let uniqueDirs = unique(summary.directories)
  let labels = if Array.length(uniqueDirs) > 0 {
    let count = Array.length(uniqueDirs)
    let label = `${Int.toString(count)} director${count == 1 ? "y" : "ies"}`
    Array.concat(labels, [label])
  } else {
    labels
  }

  let uniqueFiles = unique(summary.files)
  let labels = if Array.length(uniqueFiles) > 0 {
    let count = Array.length(uniqueFiles)
    let label = `${Int.toString(count)} file${count == 1 ? "" : "s"}`
    Array.concat(labels, [label])
  } else {
    labels
  }

  let labels = if summary.searches > 0 {
    let label = `${Int.toString(summary.searches)} search${summary.searches == 1 ? "" : "es"}`
    Array.concat(labels, [label])
  } else {
    labels
  }

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

  let labels = if summary.browserSnapshots > 0 {
    let label = `${Int.toString(summary.browserSnapshots)} snapshot${summary.browserSnapshots == 1
        ? ""
        : "s"}`
    Array.concat(labels, [label])
  } else {
    labels
  }

  if Array.length(labels) == 0 {
    let count = Array.length(summary.tools)
    [`${Int.toString(count)} operation${count == 1 ? "" : "s"}`]
  } else {
    labels
  }
}

let hasError = (tc: Message.toolCall): bool => {
  tc.state == Message.OutputError || Option.isSome(tc.errorText)
}

let groupToolCalls = (toolCalls: array<Message.toolCall>, ~minGroupSize: int): array<
  Types.displayItem,
> => {
  let result: array<Types.displayItem> = []
  let currentGroup: ref<array<Message.toolCall>> = ref([])
  let currentGroupType: ref<option<Types.groupType>> = ref(None)
  let currentIsSubagent: ref<bool> = ref(false)
  let currentParentAgentId: ref<option<string>> = ref(None)

  let flushGroup = () => {
    let group = currentGroup.contents

    let isTodoOnlyGroup =
      Array.length(group) > 0 && group->Array.every(tc => TodoUtils.isTodoTool(tc.toolName))

    let effectiveMinSize = if isTodoOnlyGroup {
      2
    } else {
      minGroupSize
    }

    if Array.length(group) >= effectiveMinSize {
      let summary = calculateSummary(group)
      let groupType = currentGroupType.contents->Option.getOr(Types.Activity)
      let spawningToolName = group->Array.get(0)->Option.flatMap(tc => tc.spawningToolName)
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
      group->Array.forEach(tc => {
        result->Array.push(Types.SingleTool(tc))
      })
    }
    currentGroup := []
    currentGroupType := None
    currentIsSubagent := false
    currentParentAgentId := None
  }

  let shouldGroupToolCall = (tc: Message.toolCall): bool =>
    !hasError(tc) && !breaksGrouping(tc.toolName) && isGroupableTool(tc.toolName)

  toolCalls->Array.forEach(tc => {
    let isSubagent = isSubagentToolCall(tc)

    if currentIsSubagent.contents != isSubagent && Array.length(currentGroup.contents) > 0 {
      flushGroup()
    }

    if isSubagent && currentIsSubagent.contents {
      let currentParent = currentParentAgentId.contents
      let newParent = tc.parentAgentId
      switch (currentParent, newParent) {
      | (Some(current), Some(new_)) if current != new_ => flushGroup()
      | _ => ()
      }
    }

    if isSubagent {
      currentIsSubagent := true
      currentGroupType := Some(Types.Subagent)
      currentParentAgentId := tc.parentAgentId
      currentGroup.contents->Array.push(tc)
    } else if shouldGroupToolCall(tc) {
      let toolGroupType = getGroupType(tc.toolName)

      switch currentGroupType.contents {
      | Some(current) if current != toolGroupType => flushGroup()
      | _ => ()
      }

      currentIsSubagent := false
      currentGroupType := Some(toolGroupType)
      currentGroup.contents->Array.push(tc)
    } else {
      flushGroup()
      result->Array.push(Types.SingleTool(tc))
    }
  })

  flushGroup()

  result
}

let getGroupPrefix = (group: Types.toolGroup, ~isOpen: bool): string => {
  let isLoading = group.toolCalls->Array.some(tc => {
    switch tc.state {
    | Message.InputStreaming | Message.InputAvailable => true
    | Message.OutputAvailable | Message.OutputError => false
    }
  })

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

let generateSubagentSummaryLabel = (summary: Types.toolsSummary): string => {
  let count = Array.length(summary.tools)
  if count == 1 {
    "1 operation"
  } else {
    `${Int.toString(count)} operations`
  }
}
