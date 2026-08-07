module Message = Client__State__Types.Message

type thinkingState = {
  showThinking: bool,
  thinkingContext: option<string>,
}

let getThinkingContext = (lastMessage: option<Message.t>): option<string> => {
  switch lastMessage {
  | Some(Message.User(_)) => Some("Thinking...")
  | Some(Message.ToolCall({state: OutputAvailable, _})) => Some("Processing result...")
  | Some(Message.ToolCall({state: OutputError, _})) => Some("Handling error...")
  | Some(Message.ToolCall({state: InputAvailable, _})) => Some("Executing tool...")
  | Some(Message.ToolCall({state: InputStreaming, _})) => None
  | Some(Message.Assistant(Streaming(_))) => None
  | Some(Message.Assistant(Completed(_))) => None
  | Some(Message.Error(_)) => None
  | None => None
  }
}

let isTurnEnded = (lastMessage: option<Message.t>): bool => {
  switch lastMessage {
  | Some(Message.Assistant(Completed(_))) => true
  | _ => false
  }
}

let isLastMessageStreaming = (lastMessage: option<Message.t>): bool => {
  switch lastMessage {
  | Some(Message.Assistant(Streaming(_))) => true
  | Some(Message.ToolCall({state: InputStreaming, _})) => true
  | _ => false
  }
}

let isAwaitingResponse = (lastMessage: option<Message.t>): bool => {
  switch lastMessage {
  | Some(Message.User(_)) => true
  | Some(Message.ToolCall({state: OutputAvailable, _})) => true
  | Some(Message.ToolCall({state: OutputError, _})) => false
  | _ => false
  }
}

let use = (
  ~messages: array<Message.t>,
  ~isStreaming: bool,
  ~isAgentRunning: bool,
  ~hasActiveACPSession: bool,
  ~sessionInitialized: bool,
): thinkingState => {
  let lastMessage = messages->Array.get(Array.length(messages) - 1)

  let showThinking =
    hasActiveACPSession &&
    sessionInitialized &&
    isAgentRunning &&
    !isStreaming &&
    !isTurnEnded(lastMessage) &&
    !isLastMessageStreaming(lastMessage) &&
    isAwaitingResponse(lastMessage)

  let thinkingContext = if showThinking {
    getThinkingContext(lastMessage)
  } else {
    None
  }

  {showThinking, thinkingContext}
}

let useWithMessageId = (
  ~messages: array<Message.t>,
  ~isStreaming: bool,
  ~isAgentRunning: bool,
  ~hasActiveACPSession: bool,
  ~sessionInitialized: bool,
): (thinkingState, string) => {
  let state = use(
    ~messages,
    ~isStreaming,
    ~isAgentRunning,
    ~hasActiveACPSession,
    ~sessionInitialized,
  )

  let messageId = switch messages->Array.get(Array.length(messages) - 1) {
  | Some(msg) => Message.getId(msg) ++ "-thinking"
  | None => "initial-thinking"
  }

  (state, messageId)
}
