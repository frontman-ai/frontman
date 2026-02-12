// Message types - extracted to break circular dependency with MessageStore

// Data for file/image attachments extracted from user content parts
type fileAttachmentData = {
  dataUrl: string,
  mediaType: string,
  filename: string,
}

// Content part types for messages (simplified from Vercel AI SDK)
module UserContentPart = {
  type t =
    | Text({text: string})
    | Image({image: string, mediaType: option<string>, name: option<string>})
    | File({file: string})

  let text = (text: string): t => Text({text: text})
}

module AssistantContentPart = {
  type t =
    | Text({text: string})
    | ToolCall({toolCallId: string, toolName: string, input: JSON.t})

  let text = (text: string): t => Text({text: text})
}

type toolCallState =
  | InputStreaming
  | InputAvailable
  | OutputAvailable
  | OutputError

type assistantMessage =
  | Streaming({id: string, textBuffer: string, createdAt: float})
  | Completed({id: string, content: array<AssistantContentPart.t>, createdAt: float})

type toolCall = {
  id: string,
  toolName: string,
  state: toolCallState,
  inputBuffer: string,
  input: option<JSON.t>,
  result: option<JSON.t>,
  errorText: option<string>,
  createdAt: float,
  parentAgentId: option<string>,
  spawningToolName: option<string>,
}

type t =
  | User({id: string, content: array<UserContentPart.t>, createdAt: float})
  | Assistant(assistantMessage)
  | ToolCall(toolCall)

let getId = (msg: t): string => {
  switch msg {
  | User({id, _}) => id
  | Assistant(Streaming({id, _})) => id
  | Assistant(Completed({id, _})) => id
  | ToolCall({id, _}) => id
  }
}
