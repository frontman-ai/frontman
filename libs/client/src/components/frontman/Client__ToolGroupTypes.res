/**
 * ToolGroupTypes - Types for tool grouping and collapse behavior
 * 
 * Defines the data structures used to group consecutive tool calls
 * into collapsible "Explored" summaries.
 */
module Message = Client__State__Types.Message

// Tool categories for grouping purposes
type toolCategory =
  | Exploration // read, list, search, grep, go-to-definition
  | Action // edit, write, terminal, browser actions
  | Todo // todo operations
  | Task // subagent/nested tasks
  | Other

// Summary statistics for grouped tools
type toolsSummary = {
  files: array<string>, // Files read
  directories: array<string>, // Directories listed
  searches: int, // Search count
  definitions: int, // Definitions found
  browserSnapshots: int, // Browser snapshots taken
  tools: array<string>, // All tool names in group
  // Todo tracking
  todos: int, // Total todos in result
  todosNewlyCreated: int, // Todos created in this group
  todosNewlyCompleted: int, // Todos marked complete in this group
  todosNewlyStarted: int, // Todos started (in_progress) in this group
  todosNewlyCancelled: int, // Todos cancelled in this group
}

// Empty summary for initialization
let emptySummary: toolsSummary = {
  files: [],
  directories: [],
  searches: 0,
  definitions: 0,
  browserSnapshots: 0,
  tools: [],
  todos: 0,
  todosNewlyCreated: 0,
  todosNewlyCompleted: 0,
  todosNewlyStarted: 0,
  todosNewlyCancelled: 0,
}

// Group visual state
type toolGroupState =
  | Collapsed
  | Expanded

// Group type determines the prefix label
type groupType =
  | Activity // "Explored" - read, list, search
  | Browser // "Performed" - browser actions
  | PrePlan // "Prepared plan" - planning operations
  | Subagent // "Processed" - subagent tool calls

// A group of related tool calls
type toolGroup = {
  id: string,
  groupType: groupType,
  toolCalls: array<Message.toolCall>,
  summary: toolsSummary,
  prefix: string, // "Explored", "Performed", etc.
  spawningToolName: option<string>, // For subagent groups: the tool that spawned this agent
}

// Display item - either a single tool or a group
type displayItem =
  | SingleTool(Message.toolCall)
  | ToolGroup(toolGroup)

// Get prefix for a group type
let getPrefixForGroupType = (gt: groupType): string => {
  switch gt {
  | Activity => "Explored"
  | Browser => "Performed"
  | PrePlan => "Prepared plan"
  | Subagent => "Processed"
  }
}
