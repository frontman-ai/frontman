// Message types for agent-user conversations
//
// This module defines the structure of messages in a conversation between a user and an AI agent.
// Messages flow in a cycle: User asks questions (with text/images/files), Assistant responds
// (with text or tool calls), Tool results are returned, and System messages provide context.
//
// The four message types represent the different participants in the conversation:
// - System: Provides context, instructions, or system-level information to the agent
// - User: Questions, commands, or content from the human user (supports multimodal input)
// - Assistant: Responses from the AI agent (can include tool execution requests)
// - Tool: Results from tool executions that the assistant can use to continue the conversation

// Enable JSON support in Sury
S.enableJson()

module Part = Agent__Task__Message__Part
module TaskId = Agent__Task__Id
module Id = Agent__Id

module System = {
  @schema
  type t = {
    id: Id.t,
    taskId: option<TaskId.t>,
    content: string,
  }
}

module User = {
  @schema
  type contentParts =
    | Text(Part.TextPart.t)
    | Image(Part.ImagePart.t)
    | File(Part.FilePart.t)
  @schema
  type userContent = String(string) | List(array<contentParts>)

  @schema
  type t = {taskId?: TaskId.t, content: userContent}
}

module Assistant = {
  @schema
  type contentParts = Text(Part.TextPart.t) | ToolCall(Part.ToolCallPart.t)

  @schema
  type content = String(string) | List(array<contentParts>)

  @schema
  type t = {taskId: option<TaskId.t>, content: content}
}
module Tool = {
  @schema
  type content = array<Part.ToolResultPart.t>
  @schema
  type t = {taskId: option<TaskId.t>, content: content}
}

@schema
type t = System(System.t) | User(User.t) | Assistant(Assistant.t) | Tool(Tool.t)

let getTaskId = (message: t): option<Agent__Task__Id.t> => {
  switch message {
  | System({taskId}) => taskId
  | User({taskId, content: _, _}) => Some(taskId)
  | User({content: _}) => None
  | Assistant({taskId}) => taskId
  | Tool({taskId}) => taskId
  }
}
let isAssistantMessage = message => {
  switch message {
  | Assistant(_) => true
  | _ => false
  }
}

let isToolMessage = message => {
  switch message {
  | Tool(_) => true
  | _ => false
  }
}

let hasToolCalls = (message: t): bool => {
  switch message {
  | Assistant({content: List(parts), _}) =>
    parts->Array.some(part =>
      switch part {
      | ToolCall(_) => true
      | _ => false
      }
    )
  | _ => false
  }
}

let extractToolCalls = (message: t): array<Part.ToolCallPart.t> => {
  switch message {
  | Assistant({content: List(parts), _}) =>
    parts->Array.filterMap(part =>
      switch part {
      | ToolCall(toolCall) => Some(toolCall)
      | _ => None
      }
    )
  | _ => []
  }
}
