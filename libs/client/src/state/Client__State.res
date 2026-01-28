// Re-export types
type state = Client__State__Types.state

// Hook for selecting state
let useSelector = selection =>
  FrontmanReactStatestore.StateStore.useSelector(Client__State__Store.store, selection)

module Selectors = Client__State__StateReducer.Selectors
module UserContentPart = Client__State__Types.UserContentPart
module AssistantContentPart = Client__State__Types.AssistantContentPart

// Action creators
module Actions = {
  let addUserMessage = (~sessionId, ~content) => {
    let id = `user-${Date.now()->Float.toString}`
    Client__State__Store.dispatch(AddUserMessage({id, sessionId, content}))
  }

  let textDeltaReceived = (~taskId, ~text) =>
    Client__State__Store.dispatch(TextDeltaReceived({taskId, text}))

  let streamingStarted = (~taskId) =>
    Client__State__Store.dispatch(StreamingStarted({taskId: taskId}))

  // TOOLS
  let toolCallReceived = (~taskId, ~toolCall) =>
    Client__State__Store.dispatch(ToolCallReceived({taskId, toolCall}))

  let toolInputReceived = (~taskId, ~id, ~input) =>
    Client__State__Store.dispatch(ToolInputReceived({taskId, id, input}))

  let toolResultReceived = (~taskId, ~id, ~result) =>
    Client__State__Store.dispatch(ToolResultReceived({taskId, id, result}))

  let toolErrorReceived = (~taskId, ~id, ~error) =>
    Client__State__Store.dispatch(ToolErrorReceived({taskId, id, error}))

  let setPreviewUrl = (~url) => Client__State__Store.dispatch(SetPreviewUrl({url: url}))

  let setPreviewFrame = (~contentDocument, ~contentWindow) =>
    Client__State__Store.dispatch(SetPreviewFrame({contentDocument, contentWindow}))

  let toggleWebPreviewSelection = () => Client__State__Store.dispatch(ToggleWebPreviewSelection)

  let setSelectedElement = (~selectedElement) =>
    Client__State__Store.dispatch(SetSelectedElement({selectedElement: selectedElement}))

  // Task management action creators
  // Note: Tasks are created implicitly when user sends first message (lazy session creation)
  // Use clearCurrentTask() to prepare for a new task

  let switchTask = (~taskId) => Client__State__Store.dispatch(SwitchTask({taskId: taskId}))

  let deleteTask = (~taskId) => Client__State__Store.dispatch(DeleteTask({taskId: taskId}))

  let clearCurrentTask = () => Client__State__Store.dispatch(ClearCurrentTask)

  let updateTaskTitle = (~taskId, ~title) =>
    Client__State__Store.dispatch(UpdateTaskTitle({taskId, title}))

  // Figma node action creators
  let setFigmaNode = (~figmaNode) =>
    Client__State__Store.dispatch(SetFigmaNode({figmaNode: figmaNode}))

  let clearFigmaNode = () => Client__State__Store.dispatch(ClearFigmaNode)

  let setFigmaNodeWaiting = () => Client__State__Store.dispatch(SetFigmaNodeWaiting)

  let clearFigmaNodeWaiting = () => Client__State__Store.dispatch(ClearFigmaNodeWaiting)

  // Connection action creators
  let connect = (~sendPrompt, ~loadTask, ~deleteSession, ~apiBaseUrl) =>
    Client__State__Store.dispatch(
      Connect({sendPrompt, loadTask, deleteSession, apiBaseUrl}),
    )

  let disconnect = () => Client__State__Store.dispatch(Disconnect)

  // Task loading action creators
  let taskLoadError = (~taskId, ~error) =>
    Client__State__Store.dispatch(TaskLoadError({taskId, error}))

  // Initialization action creators
  let receivedDiscoveredProjectRule = (~taskId: string) =>
    Client__State__Store.dispatch(ReceivedDiscoveredProjectRule({taskId: taskId}))

  // Turn completion action creators
  let turnCompleted = (~taskId: string) =>
    Client__State__Store.dispatch(TurnCompleted({taskId: taskId}))

  // Plan action creators (ACP compliant)
  let planReceived = (~taskId: string, ~entries) =>
    Client__State__Store.dispatch(PlanReceived({taskId, entries}))

  // API key settings action creators
  let fetchApiKeySettings = () => Client__State__Store.dispatch(FetchApiKeySettings)

  let saveOpenRouterKey = (~key) => Client__State__Store.dispatch(SaveOpenRouterKey({key: key}))

  let resetOpenRouterKeySaveStatus = () =>
    Client__State__Store.dispatch(ResetOpenRouterKeySaveStatus)

  // Model selection action creators
  let setSelectedModel = (~provider, ~value) =>
    Client__State__Store.dispatch(SetSelectedModel({model: {provider, value}}))

  // Anthropic OAuth action creators
  let fetchAnthropicOAuthStatus = () => Client__State__Store.dispatch(FetchAnthropicOAuthStatus)

  let initiateAnthropicOAuth = () => Client__State__Store.dispatch(InitiateAnthropicOAuth)

  let exchangeAnthropicOAuthCode = (~code, ~verifier) =>
    Client__State__Store.dispatch(ExchangeAnthropicOAuthCode({code, verifier}))

  let disconnectAnthropicOAuth = () => Client__State__Store.dispatch(DisconnectAnthropicOAuth)

  let resetAnthropicOAuthError = () => Client__State__Store.dispatch(ResetAnthropicOAuthError)

  // Hydration action creators (for session/load)
  let userMessageReceived = (~taskId: string, ~id: string, ~text: string, ~timestamp: string) =>
    Client__State__Store.dispatch(UserMessageReceived({taskId, id, text, timestamp}))

  let sessionsLoadStarted = () => Client__State__Store.dispatch(SessionsLoadStarted)

  let sessionsLoadSuccess = (~sessions) =>
    Client__State__Store.dispatch(SessionsLoadSuccess({sessions: sessions}))

  let sessionsLoadError = (~error: string) =>
    Client__State__Store.dispatch(SessionsLoadError({error: error}))
}
