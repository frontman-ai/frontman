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
    taskId: TaskId.t,
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
  type t = {
    taskId: TaskId.t,
    content: userContent,
    selectedElementSourceLocation: option<
      AskTheLlmBindings.DOMElementToComponentSource.sourceLocation,
    >,
  }

  let contentAsString = (content: userContent): string => {
    switch content {
    | String(content) => content
    | List(parts) =>
      parts
      ->Array.map(part => {
        switch part {
        | Text(textPart) => textPart.content
        | _ => ""
        }
      })
      ->Array.join("\n")
    }
  }
}

module Assistant = {
  @schema
  type contentParts = Text(Part.TextPart.t) | ToolCall(Part.ToolCallPart.t)

  @schema
  type content = String(string) | List(array<contentParts>)

  @schema
  type t = {taskId: TaskId.t, content: content}

  let contentAsString = (content: content): string => {
    switch content {
    | String(content) => content
    | List(parts) =>
      parts
      ->Array.map(part => {
        switch part {
        | Text(textPart) => textPart.content
        | _ => ""
        }
      })
      ->Array.join("\n")
    }
  }
}
module Tool = {
  @schema
  type content = array<Part.ToolResultPart.t>
  @schema
  type t = {taskId: TaskId.t, content: content}

  let contentAsString = (content: content): string => {
    content
    ->Array.map(part => {
      switch part.output {
      | Part.ToolResultPart.Output.Text(textPart) => textPart
      | _ => ""
      }
    })
    ->Array.join("\n")
  }
}

@schema
type t = System(System.t) | User(User.t) | Assistant(Assistant.t) | Tool(Tool.t)

let toString: t => string = (message: t) => {
  message->S.reverseConvertOrThrow(schema)->JSON.stringifyAny->Option.getOr("unable to serialize")
}

let getTaskId = (message: t): Agent__Task__Id.t => {
  switch message {
  | System({taskId}) => taskId
  | Assistant({taskId}) => taskId
  | User({taskId}) => taskId
  | Tool({taskId}) => taskId
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

let isUserMessage = (message: t): bool => {
  switch message {
  | User(_) => true
  | _ => false
  }
}

let isAssistantMessage = (message: t): bool => {
  switch message {
  | Assistant(_) => true
  | _ => false
  }
}

let isToolMessage = (message: t): bool => {
  switch message {
  | Tool(_) => true
  | _ => false
  }
}

let isSystemMessage = (message: t): bool => {
  switch message {
  | System(_) => true
  | _ => false
  }
}

let getContent = (t: t): string => {
  switch t {
  | System({content}) => content
  | User({content}) => User.contentAsString(content)
  | Assistant({content}) => Assistant.contentAsString(content)
  | Tool({content}) => Tool.contentAsString(content)
  }
}
