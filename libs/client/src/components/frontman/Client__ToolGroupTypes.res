module Message = Client__State__Types.Message

type toolsSummary = {
  files: array<string>,
  directories: array<string>,
  searches: int,
  definitions: int,
  browserSnapshots: int,
  tools: array<string>,
}

let emptySummary: toolsSummary = {
  files: [],
  directories: [],
  searches: 0,
  definitions: 0,
  browserSnapshots: 0,
  tools: [],
}

type groupType =
  | Activity
  | Browser
  | PrePlan
  | Subagent

type toolGroup = {
  id: string,
  groupType: groupType,
  toolCalls: array<Message.toolCall>,
  summary: toolsSummary,
  prefix: string,
  spawningToolName: option<string>,
}

type displayItem =
  | SingleTool(Message.toolCall)
  | ToolGroup(toolGroup)

let getPrefixForGroupType = (gt: groupType): string => {
  switch gt {
  | Activity => "Explored"
  | Browser => "Performed"
  | PrePlan => "Prepared plan"
  | Subagent => "Processed"
  }
}
