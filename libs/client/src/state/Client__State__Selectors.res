module Message = Client__State__Types.Message
module Task = Client__State__Types.Task
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module TaskReducer = Client__Task__Reducer
module Connection = Client__ConnectionReducer
type state = Client__State__Types.state
type pendingPlanHandoff = Client__State__Protocol.pendingPlanHandoff

let plannerAgentName = "planner"
let executorAgentName = "executor"
let getInitialUrl = Client__BrowserUrl.getInitialUrl

let wordPressLoginRecovery = (state: state) => state.wordPressLoginRecovery
let wordPressConnectionStatus = (state: state) => state.wordPressConnectionStatus
let wordPressCredentialWarning = (state: state) => state.wordPressCredentialWarning
let getSession = (state: state) => state.connection->Option.flatMap(Connection.Selectors.getSession)
let getRelay = (state: state) => state.connection->Option.flatMap(Connection.Selectors.getRelay)
let getSessionError = (state: state) =>
  state.connection->Option.flatMap(Connection.Selectors.getSessionError)
let getAuthRedirectUrl = (state: state) =>
  state.connection->Option.flatMap(Connection.Selectors.getAuthRedirectUrl)
let getConnectionStatus = (state: state) =>
  state.connection->Option.mapOr(
    Connection.Selectors.Disconnected,
    Connection.Selectors.getConnectionStatus,
  )
let apiBaseUrl = (state: state) =>
  switch state.connection {
  | Some({config, connection: Ok(Some({phase: Ready(_)}))}) =>
    Some(Connection.apiBaseUrlFromLoginUrl(config.acp.loginUrl))
  | _ => None
  }
let hasActiveACPSession = (state: state) => apiBaseUrl(state)->Option.isSome
let isSubmitting = (state: state) =>
  switch state.connection {
  | Some({
      connection: Ok(Some({phase: Ready({session: SessionCreating({onComplete: Some(_)})})})),
    }) => true
  | _ => false
  }

let getMessageId = Message.getId

let currentTask = (state: state): Task.t => {
  switch state.currentTask {
  | Task.New(task) => task
  | Task.Selected(id) =>
    state.tasks
    ->Dict.get(id)
    ->Option.getOrThrow(~message=`[Selectors.currentTask] Selected task ${id} not found in dict`)
  }
}

let currentTaskId = (state: state): option<string> => {
  switch state.currentTask {
  | Task.New(_) => None
  | Task.Selected(id) => Some(id)
  }
}

let currentTaskClientId = (state: state): string => {
  Task.getClientId(currentTask(state))
}

let isNewTask = (state: state): bool => Task.isNew(currentTask(state))

let messages = (state: state): array<Message.t> => {
  Task.getMessages(currentTask(state))
}

let isStreaming = (state: state): bool => {
  TaskReducer.Selectors.isStreaming(currentTask(state))->Option.getOr(false)
}

let previewFrame = (state: state): Task.previewFrame => {
  Task.getPreviewFrame(currentTask(state), ~defaultUrl=getInitialUrl())
}

let annotations = (state: state): array<Client__Annotation__Types.t> => {
  Task.getAnnotations(currentTask(state))
}

let webPreviewIsSelecting = (state: state): bool => {
  !isSubmitting(state) && Task.getWebPreviewIsSelecting(currentTask(state))
}

let hasEnrichingAnnotations = (state: state): bool => {
  TaskReducer.Selectors.hasEnrichingAnnotations(currentTask(state))->Option.getOr(false)
}

let activePopupAnnotationId = (state: state): option<string> => {
  Task.getActivePopupAnnotationId(currentTask(state))
}

let isAgentRunning = (state: state): bool => {
  TaskReducer.Selectors.isAgentRunning(currentTask(state))->Option.getOr(false)
}

let currentPlanEntries = (state: state): array<Client__State__Types.ACPTypes.planEntry> => {
  TaskReducer.Selectors.planEntries(currentTask(state))->Option.getOr([])
}

let completedFileChanges = (state: state): Client__FileChanges.snapshot =>
  TaskReducer.Selectors.completedFileChanges(currentTask(state))

let queuedUserMessages = (state: state): array<Message.t> => {
  TaskReducer.Selectors.queuedUserMessages(currentTask(state))->Option.getOr([])
}

let turnError = (state: state): option<Task.turnErrorInfo> => {
  TaskReducer.Selectors.turnError(currentTask(state))
}

let retryStatus = (state: state): option<Task.retryStatus> => {
  TaskReducer.Selectors.retryStatus(currentTask(state))
}

let resolveImageRef = (state: state, ~taskId: string, ~uri: string): option<
  Message.resolvedImageData,
> => {
  state.tasks
  ->Dict.get(taskId)
  ->Option.flatMap(task => Task.getImageAttachments(task)->Dict.get(uri))
  ->Option.map(Message.resolveAttachmentImage)
}

let previewUrl = (state: state): string => {
  Task.getPreviewFrame(currentTask(state), ~defaultUrl=getInitialUrl()).url
}

let deviceMode = (state: state): Client__DeviceMode.deviceMode => {
  TaskReducer.Selectors.deviceMode(currentTask(state))
}

let deviceOrientation = (state: state): Client__DeviceMode.orientation => {
  TaskReducer.Selectors.orientation(currentTask(state))
}

let getTaskSortTime = (task: Task.t): float => Task.getUpdatedAt(task)->Option.getOr(0.0)

let tasks = (state: state): array<Task.t> => {
  state.tasks
  ->Dict.valuesToArray
  ->Array.toSorted((a, b) => {
    let aTime = getTaskSortTime(a)
    let bTime = getTaskSortTime(b)
    bTime -. aTime
  })
}

let userProfile = (state: state): option<Client__State__Types.userProfile> => {
  state.userProfile
}

let openrouterKeySettings = (state: state): Client__State__Types.apiKeySettings => {
  state.openrouterKeySettings
}

let anthropicKeySettings = (state: state): Client__State__Types.apiKeySettings => {
  state.anthropicKeySettings
}

let fireworksKeySettings = (state: state): Client__State__Types.apiKeySettings => {
  state.fireworksKeySettings
}

let nvidiaKeySettings = (state: state): Client__State__Types.apiKeySettings => {
  state.nvidiaKeySettings
}

let configOptions = (state: state): option<
  array<Client__State__Types.ACPConfig.sessionConfigOption>,
> => {
  state.configOptions
}

let agentCatalog = (state: state) => state.agentCatalog

let selectedAgentId = (state: state) => state.selectedAgentId

let selectedModelValue = (state: state): option<
  Client__State__Types.ACPConfig.sessionConfigValueId,
> => {
  state.selectedModelValue
}

let anthropicOAuthStatus = (state: state): Client__State__Types.anthropicOAuthStatus => {
  state.anthropicOAuthStatus
}

let openaiOAuthStatus = (state: state): Client__State__Types.openaiOAuthStatus => {
  state.openaiOAuthStatus
}

let updateInfo = (state: state): option<Client__State__Types.updateInfo> => {
  state.updateInfo
}

let wordpressUpdates = (state: state): Client__WordPressUpdates.t => state.wordpressUpdates

let updateBannerDismissed = (state: state): bool => {
  state.updateBannerDismissed
}

let highlightedAnnotation = (state: state): option<Client__State__Types.highlightedAnnotation> => {
  switch state.highlightedAnnotation {
  | Some(highlighted) if highlighted.taskId == currentTaskClientId(state) => Some(highlighted)
  | Some(_) | None => None
  }
}

let customProviders = (state: state): option<array<Client__State__Types.customProvider>> => {
  state.customProviders
}

let customProviderMutation = (state: state): Client__State__Types.customProviderMutation => {
  state.customProviderMutation
}

let pendingQuestion = (state: state): option<Client__Question__Types.pendingQuestion> => {
  switch state.currentTask {
  | Task.Selected(id) =>
    state.tasks->Dict.get(id)->Option.flatMap(TaskReducer.Selectors.pendingQuestion)
  | Task.New(_) => None
  }
}

let pendingPlanHandoff = (state: state): option<pendingPlanHandoff> => {
  let findAgent = name =>
    state.agentCatalog->Option.flatMap(catalog => catalog->Array.find(agent => agent.name == name))
  switch (
    getSession(state),
    findAgent(plannerAgentName),
    findAgent(executorAgentName),
    TaskReducer.Selectors.completedIdleTurn(currentTask(state)),
  ) {
  | (Some({sessionId}), Some(planner), Some(executor), Some({taskId, agentId}))
    if agentId == planner.id && sessionId == taskId =>
    Some({taskId, executorAgentId: executor.id})
  | _ => None
  }
}

let settingsModalTab = (state: state) => state.settingsModalTab
let billingStatus = (state: state) => state.billingStatus
let billingFlow = (state: state) => state.billingFlow
let billingCanStartTurn = (state: state) =>
  Client__Billing.canStartTurnFromState(state.billingStatus)

let providerSetupRequired = (state: state): bool => {
  switch (apiBaseUrl(state), state.configOptions) {
  | (Some(_), Some(configOptions)) =>
    switch configOptions->ACP.findConfigOptionByCategory(ACP.Model) {
    | Some(modelConfig) => ACP.sessionConfigOptionFirstOption(modelConfig)->Option.isNone
    | None => false
    }
  | _ => false
  }
}

let providerSetupPromptRequired = (state: state, framework: Client__RuntimeConfig.frameworkId) =>
  switch framework {
  | Wordpress =>
    switch (state.wordPressAssistantSetupSelected, state.wordPressConnectionStatus) {
    | (true, _)
    | (
      _,
      WordPressNotChecked | WordPressChecking | WordPressLinked(_) | WordPressUpdatingAccess(_),
    ) => false
    | (false, WordPressUnlinked | WordPressLinking | WordPressConnectionFailed(_)) =>
      providerSetupRequired(state)
    }
  | Nextjs | Vite | Astro => providerSetupRequired(state)
  }
