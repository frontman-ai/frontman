/**
 * useThinkingState - Hook for determining when to show thinking indicator
 *
 * Encapsulates the logic for showing/hiding the thinking indicator
 * based on message state, streaming state, and connection status.
 */
module Message = Client__State__Types.Message

type thinkingState = {
  showThinking: bool,
  thinkingContext: option<string>,
}

/**
 * Determine the thinking context based on the last message
 */
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

/**
 * Check if the last message indicates the turn has ended
 */
let isTurnEnded = (lastMessage: option<Message.t>): bool => {
  switch lastMessage {
  | Some(Message.Assistant(Completed(_))) => true
  | _ => false
  }
}

/**
 * Check if the last message is currently streaming
 */
let isLastMessageStreaming = (lastMessage: option<Message.t>): bool => {
  switch lastMessage {
  | Some(Message.Assistant(Streaming(_))) => true
  | Some(Message.ToolCall({state: InputStreaming, _})) => true
  | _ => false
  }
}

/**
 * Check if the last message is a completed tool call that might need a response
 */
let isAwaitingResponse = (lastMessage: option<Message.t>): bool => {
  switch lastMessage {
  | Some(Message.User(_)) => true
  | Some(Message.ToolCall({state: OutputAvailable, _})) => true
  | Some(Message.ToolCall({state: OutputError, _})) => false
  | _ => false
  }
}

/**
 * Main hook - determines thinking state based on all relevant factors
 */
let use = (
  ~messages: array<Message.t>,
  ~isStreaming as _: bool,
  ~isAgentRunning: bool,
  ~hasActiveACPSession: bool,
  ~sessionInitialized: bool,
): thinkingState => {
  let lastMessage = messages->Array.get(Array.length(messages) - 1)

  let showThinking =
    hasActiveACPSession &&
    sessionInitialized &&
    isAgentRunning &&
    !isTurnEnded(lastMessage)

  let thinkingContext = if showThinking {
    getThinkingContext(lastMessage)
  } else {
    None
  }

  {showThinking, thinkingContext}
}

/**
 * Hook variant that also provides stable messageId for animations
 */
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
