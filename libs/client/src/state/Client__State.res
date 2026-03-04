// Re-export types
type state = Client__State__Types.state

// Hook for selecting state
let useSelector = selection =>
  StateStore.useSelector(Client__State__Store.store, selection)

module Selectors = Client__State__StateReducer.Selectors
module UserContentPart = Client__State__Types.UserContentPart
module AssistantContentPart = Client__State__Types.AssistantContentPart

// Action creators
module Actions = {
  let addUserMessage = (~sessionId, ~content, ~annotations=[]) => {
    let id = `user-${Date.now()->Float.toString}`
    Client__State__Store.dispatch(AddUserMessage({id, sessionId, content, annotations}))
  }

  // ForTask(taskId) actions - streaming/tool events from ACP
  let textDeltaReceived = (~taskId, ~text) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: TextDeltaReceived({text: text})}))

  let streamingStarted = (~taskId) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: StreamingStarted}))

  // TOOLS
  let toolCallReceived = (~taskId, ~toolCall) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: ToolCallReceived({toolCall: toolCall})}))

  let toolInputReceived = (~taskId, ~id, ~input) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: ToolInputReceived({id, input})}))

  let toolResultReceived = (~taskId, ~id, ~result) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: ToolResultReceived({id, result})}))

  let toolErrorReceived = (~taskId, ~id, ~error) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: ToolErrorReceived({id, error})}))

  // CurrentTask actions - UI interactions
  let setPreviewUrl = (~url) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: SetPreviewUrl({url: url})}))

  let setPreviewFrame = (~contentDocument, ~contentWindow) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: SetPreviewFrame({contentDocument, contentWindow})}))

  let setAnnotationMode = (~mode) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: SetAnnotationMode({mode: mode})}))

  // Device mode action creators
  let setDeviceMode = (~deviceMode) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: SetDeviceMode({deviceMode: deviceMode})}))

  let setOrientation = (~orientation) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: SetOrientation({orientation: orientation})}))

  let toggleDeviceMode = () =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: ToggleDeviceMode}))

  // Toggle between Off and Selecting mode
  let toggleWebPreviewSelection = () =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: ToggleAnnotationMode}))

  let toggleAnnotation = (~element, ~position, ~tagName) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: ToggleAnnotation({element, position, tagName})}))

  let addAnnotations = (~elements) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: AddAnnotations({elements: elements})}))

  let removeAnnotation = (~id) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: RemoveAnnotation({id: id})}))

  let clearAnnotations = () =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: ClearAnnotations}))

  let updateAnnotationComment = (~id, ~comment) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: UpdateAnnotationComment({id, comment})}))

  let setActivePopupAnnotationId = (~id) =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: SetActivePopupAnnotationId({id: id})}))

  let closeAnnotationPopup = () =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: SetActivePopupAnnotationId({id: None})}))

  let toggleAnimationFrozen = () =>
    Client__State__Store.dispatch(TaskAction({target: CurrentTask, action: ToggleAnimationFrozen}))


  // Task management action creators
  // Note: Tasks are created implicitly when user sends first message (lazy session creation)
  // Use clearCurrentTask() to prepare for a new task

  let switchTask = (~taskId) => Client__State__Store.dispatch(SwitchTask({taskId: taskId}))

  let deleteTask = (~taskId) => Client__State__Store.dispatch(DeleteTask({taskId: taskId}))

  let clearCurrentTask = () => Client__State__Store.dispatch(ClearCurrentTask)

  let updateTaskTitle = (~taskId, ~title) =>
    Client__State__Store.dispatch(UpdateTaskTitle({taskId, title}))

  // Cancel the current turn (discard partial response, kill server agent)
  let cancelTurn = () => Client__State__Store.dispatch(CancelTurn)

  // ACP session action creators
  let setAcpSession = (~sendPrompt, ~cancelPrompt, ~loadTask, ~deleteSession, ~apiBaseUrl) =>
    Client__State__Store.dispatch(
      SetAcpSession({sendPrompt, cancelPrompt, loadTask, deleteSession, apiBaseUrl}),
    )

  let clearAcpSession = () => Client__State__Store.dispatch(ClearAcpSession)

  // Task loading action creators (ForTask)
  let taskLoadError = (~taskId, ~error) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: LoadError({error: error})}))

  // Turn completion action creators (ForTask)
  let turnCompleted = (~taskId: string) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: TurnCompleted}))

  // Error action creators (ForTask)
  let agentErrorReceived = (~taskId: string, ~error: string) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: AgentError({error: error})}))

  let clearTurnError = (~taskId: string) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: ClearTurnError}))

  // Plan action creators (ForTask)
  let planReceived = (~taskId: string, ~entries) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: PlanReceived({entries: entries})}))

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

  // ChatGPT OAuth action creators
  let fetchChatGPTOAuthStatus = () => Client__State__Store.dispatch(FetchChatGPTOAuthStatus)

  let initiateChatGPTOAuth = () => Client__State__Store.dispatch(InitiateChatGPTOAuth)

  let disconnectChatGPTOAuth = () => Client__State__Store.dispatch(DisconnectChatGPTOAuth)

  let resetChatGPTOAuthError = () => Client__State__Store.dispatch(ResetChatGPTOAuthError)

  // Hydration action creators (ForTask)
  let userMessageReceived = (~taskId: string, ~id: string, ~text: string, ~timestamp: string) =>
    Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: UserMessageReceived({id, text, timestamp})}))

  let sessionsLoadStarted = () => Client__State__Store.dispatch(SessionsLoadStarted)

  let sessionsLoadSuccess = (~sessions) =>
    Client__State__Store.dispatch(SessionsLoadSuccess({sessions: sessions}))

  let sessionsLoadError = (~error: string) =>
    Client__State__Store.dispatch(SessionsLoadError({error: error}))

  // Update banner action creators
  let checkForUpdate = (~installedVersion, ~npmPackage) =>
    Client__State__Store.dispatch(CheckForUpdate({installedVersion, npmPackage}))

  let dismissUpdateBanner = () => Client__State__Store.dispatch(DismissUpdateBanner)
}
