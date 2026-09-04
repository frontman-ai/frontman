module Log = FrontmanLogs.Logs.Make({
  let component = #StateReducer
})
module Sentry = FrontmanAiFrontmanClient.FrontmanClient__Sentry

let name = "Client::StateReducer"

let plannerAgentName = "planner"
let executorAgentName = "executor"
let executePlanPrompt = "Execute the plan above."

module UserContentPart = Client__State__Types.UserContentPart
module Message = Client__State__Types.Message
module Task = Client__State__Types.Task
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
type state = Client__State__Types.state

module TaskReducer = Client__Task__Reducer
module FirstTaskFeedbackShare = Client__FirstTaskFeedbackShare

type taskTarget = CurrentTask | ForTask(string)

type apiKeyProvider = OpenRouter | Anthropic | Fireworks | Nvidia

type pendingPlanHandoff = {taskId: string, executorAgentId: string}

type action =
  | TaskAction({target: taskTarget, action: TaskReducer.action})
  | TaskExecutionStopped({taskId: string, stopReason: option<ACP.stopReason>})
  | AddUserMessage({
      id: Message.UserMessageId.t,
      sessionId: string,
      content: array<UserContentPart.t>,
      annotations: array<Message.MessageAnnotation.t>,
      agentId: string,
    })
  | ExecuteAnnotation({
      id: Message.UserMessageId.t,
      sessionId: string,
      annotationId: string,
      comment: string,
    })
  | CancelTurn
  | ExecutePendingPlan({id: Message.UserMessageId.t})
  | SwitchTask({taskId: string})
  | DeleteTask({taskId: string})
  | ClearCurrentTask
  | UpdateTaskTitle({taskId: string, title: string})
  | SetAcpSession({
      sendPrompt: Client__State__Types.sendPromptFn,
      sendSessionCommand: Client__State__Types.sendSessionCommandFn,
      loadTask: Client__State__Types.loadTaskFn,
      deleteSession: Client__State__Types.deleteSessionFn,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
      apiBaseUrl: string,
    })
  | ClearAcpSession
  | FetchUserProfile({apiBaseUrl: string})
  | FetchApiKeySettings
  | ApiKeySettingsReceived({provider: apiKeyProvider, source: Client__State__Types.apiKeySource})
  | SaveApiKey({provider: apiKeyProvider, key: string})
  | ApiKeySaveStarted({provider: apiKeyProvider})
  | ApiKeySaved({provider: apiKeyProvider})
  | ApiKeySaveError({provider: apiKeyProvider, error: string})
  | ResetApiKeySaveStatus({provider: apiKeyProvider})
  | ConfigOptionsReceived({
      configOptions: array<Client__State__Types.ACPConfig.sessionConfigOption>,
    })
  | SetSelectedModelValue({value: Client__State__Types.ACPConfig.sessionConfigValueId})
  | AgentAttributionConfigured({agentCatalog: array<ACP.agentCatalogEntry>, defaultAgentId: string})
  | SetSelectedAgentId(string)
  | FetchAnthropicOAuthStatus
  | AnthropicOAuthStatusReceived({connected: bool, expiresAt: option<string>})
  | InitiateAnthropicOAuth
  | AnthropicOAuthUrlReceived({authorizeUrl: string, verifier: string})
  | ExchangeAnthropicOAuthCode({code: string, verifier: string})
  | AnthropicOAuthConnected({expiresAt: string})
  | AnthropicOAuthError({error: string})
  | DisconnectAnthropicOAuth
  | AnthropicOAuthDisconnected
  | ResetAnthropicOAuthError
  | CancelAnthropicOAuth
  | FetchOpenAIOAuthStatus
  | OpenAIOAuthStatusReceived({connected: bool, expiresAt: option<string>})
  | InitiateOpenAIOAuth
  | OpenAIDeviceCodeReceived({deviceAuthId: string, userCode: string, verificationUrl: string})
  | OpenAIOAuthConnected({deviceAuthId: string, expiresAt: string})
  | OpenAIOAuthError({deviceAuthId: option<string>, error: string})
  | DisconnectOpenAIOAuth
  | OpenAIOAuthDisconnected
  | ResetOpenAIOAuthError
  | UserProfileReceived({userProfile: Client__State__Types.userProfile})
  | SessionsLoadStarted
  | SessionsLoadSuccess({
      sessions: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionSummary>,
    })
  | SessionsLoadError({error: string})
  | CheckForUpdate({installedVersion: string, target: Client__State__Types.updateTarget})
  | UpdateInfoReceived({updateInfo: Client__State__Types.updateInfo})
  | DismissUpdateBanner
  | CloseFirstTaskFeedbackDialog
  | DismissFirstTaskFeedbackDialog
  | ShareFrontman
  | ShareFrontmanLinkCopied
  | ShareFrontmanFailed
  | HighlightAnnotation({annotationId: string, selector: string})
  | FetchCustomProviders
  | CustomProvidersReceived({providers: array<Client__State__Types.customProvider>})
  | SaveCustomProvider(Client__State__Types.customProviderDraft)
  | DeleteCustomProvider(string, int)
  | AcknowledgeCustomProviderMutation
  | CustomProviderMutationSucceeded({
      operation: Client__State__Types.customProviderMutationOperation,
      provider: option<Client__State__Types.customProvider>,
    })
  | CustomProviderMutationFailed({
      operation: Client__State__Types.customProviderMutationOperation,
      error: Client__State__Types.customProviderMutationError,
    })

type customProviderMutationRequest =
  | SaveCustomProviderRequest(Client__State__Types.customProviderDraft)
  | DeleteCustomProviderRequest({id: string, lockVersion: int})

type effect =
  | TaskEffect({target: taskTarget, effect: TaskReducer.effect})
  | FetchApiKeySettingsEffect({apiBaseUrl: string})
  | SaveApiKeyEffect({apiBaseUrl: string, provider: apiKeyProvider, key: string})
  | FetchAnthropicOAuthStatusEffect({
      apiBaseUrl: string,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })
  | GetAnthropicOAuthUrlEffect({
      apiBaseUrl: string,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })
  | ExchangeAnthropicOAuthCodeEffect({
      apiBaseUrl: string,
      code: string,
      verifier: string,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })
  | DisconnectAnthropicOAuthEffect({
      apiBaseUrl: string,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })
  | FetchOpenAIOAuthStatusEffect({
      apiBaseUrl: string,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })
  | InitiateOpenAIDeviceAuthEffect({
      apiBaseUrl: string,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })
  | DisconnectOpenAIOAuthEffect({
      apiBaseUrl: string,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })
  | PollOpenAIDeviceAuthEffect({
      apiBaseUrl: string,
      deviceAuthId: string,
      userCode: string,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })
  | FetchUserProfileEffect({apiBaseUrl: string})
  | LoadTaskEffect({taskId: string})
  | DeleteSessionEffect({taskId: string})
  | CheckForUpdateEffect({
      apiBaseUrl: string,
      installedVersion: string,
      target: Client__State__Types.updateTarget,
    })
  | TrackAnalyticsEffect(Client__Analytics.event)
  | ShareFrontmanEffect
  | FetchCustomProvidersEffect({
      apiBaseUrl: string,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })
  | CustomProviderMutationEffect({
      apiBaseUrl: string,
      request: customProviderMutationRequest,
      requireAuthentication: Client__State__Types.requireAuthenticationFn,
    })

module Lens = {
  let updateTask = (state: state, taskId: string, fn: Task.t => Task.t): state => {
    let task = state.tasks->Dict.get(taskId)->Option.getOrThrow
    let updated = fn(task)
    let tasks = state.tasks->Dict.copy
    tasks->Dict.set(taskId, updated)
    {...state, tasks}
  }

  let delegateToNewTask = (state: state, task: Task.t, taskAction: TaskReducer.action) => {
    let (updated, taskEffects) = TaskReducer.next(task, taskAction)
    let wrappedEffects =
      taskEffects->Array.map(eff => TaskEffect({target: CurrentTask, effect: eff}))
    {...state, currentTask: Task.New(updated)}->StateReducer.update(~sideEffects=wrappedEffects)
  }

  let delegateToTaskId = (state: state, taskId: string, taskAction: TaskReducer.action) => {
    let task = state.tasks->Dict.get(taskId)->Option.getOrThrow
    let (updated, taskEffects) = TaskReducer.next(task, taskAction)
    let wrappedEffects =
      taskEffects->Array.map(eff => TaskEffect({target: ForTask(taskId), effect: eff}))
    let tasks = state.tasks->Dict.copy
    tasks->Dict.set(taskId, updated)
    {...state, tasks}->StateReducer.update(~sideEffects=wrappedEffects)
  }

  let delegateToTask = (state: state, target: taskTarget, taskAction: TaskReducer.action) => {
    switch (target, state.currentTask) {
    | (CurrentTask, Task.New(task)) => delegateToNewTask(state, task, taskAction)
    | (CurrentTask, Task.Selected(taskId)) | (ForTask(taskId), _) =>
      delegateToTaskId(state, taskId, taskAction)
    }
  }
}

let getInitialUrl = Client__BrowserUrl.getInitialUrl
let selectedModelStorageKey = "frontman:selectedModelValue"

let migrateOpenAIModelValue = value =>
  switch value->String.startsWith("openai:") {
  | true => "openai_codex:" ++ value->String.slice(~start=7, ~end=String.length(value))
  | false => value
  }

let loadSelectedModelValueFromStorage = (): option<string> => {
  try {
    WebAPI.Window.current
    ->WebAPI.Window.localStorage
    ->WebAPI.Storage.getItem(selectedModelStorageKey)
    ->Null.toOption
    ->Option.map(migrateOpenAIModelValue)
  } catch {
  | _ => None
  }
}

let syncSelectedModelValueToStorage = (value: option<string>): unit => {
  try {
    let storage = WebAPI.Window.current->WebAPI.Window.localStorage
    switch value {
    | Some(value) => storage->WebAPI.Storage.setItem(~key=selectedModelStorageKey, ~value)
    | None => storage->WebAPI.Storage.removeItem(selectedModelStorageKey)
    }
  } catch {
  | exn => Log.error(~error=JsExn.fromException(exn), "syncSelectedModelValueToStorage failed")
  }
}

let apiKeyProviderId = provider =>
  switch provider {
  | OpenRouter => "openrouter"
  | Anthropic => "anthropic"
  | Fireworks => "fireworks_ai"
  | Nvidia => "nvidia"
  }

let apiKeyProviders: array<apiKeyProvider> = [OpenRouter, Anthropic, Fireworks, Nvidia]

let updateApiKeySettings = (state: state, provider, update) =>
  switch provider {
  | OpenRouter => {...state, openrouterKeySettings: update(state.openrouterKeySettings)}
  | Anthropic => {...state, anthropicKeySettings: update(state.anthropicKeySettings)}
  | Fireworks => {...state, fireworksKeySettings: update(state.fireworksKeySettings)}
  | Nvidia => {...state, nvidiaKeySettings: update(state.nvidiaKeySettings)}
  }

let setApiKeySource = (state, provider, source) =>
  updateApiKeySettings(state, provider, settings => {...settings, source})

let setApiKeySaveStatus = (state, provider, saveStatus) =>
  updateApiKeySettings(state, provider, settings => {...settings, saveStatus})

let markApiKeySaved = (state, provider) =>
  updateApiKeySettings(state, provider, _settings => {source: UserOverride, saveStatus: Saved})

let setAllApiKeySources = (state: state, source) => {
  ...state,
  openrouterKeySettings: {...state.openrouterKeySettings, source},
  anthropicKeySettings: {...state.anthropicKeySettings, source},
  fireworksKeySettings: {...state.fireworksKeySettings, source},
  nvidiaKeySettings: {...state.nvidiaKeySettings, source},
}

let defaultState: state = {
  tasks: Dict.make(),
  currentTask: Task.New(Task.makeNew(~previewUrl=getInitialUrl())),
  acpSession: NoAcpSession,
  userProfile: None,
  openrouterKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  anthropicKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  fireworksKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  nvidiaKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  anthropicOAuthStatus: Client__State__Types.NotConnected,
  openaiOAuthStatus: Client__State__Types.OpenAINotConnected,
  configOptions: None,
  selectedModelValue: loadSelectedModelValueFromStorage(),
  agentCatalog: None,
  selectedAgentId: None,
  pendingProviderAutoSelect: None,
  sessionsLoadState: Client__State__Types.SessionsNotLoaded,
  customProviders: None,
  customProviderMutation: Client__State__Types.CustomProviderMutationIdle,
  updateInfo: None,
  updateCheckStatus: UpdateNotChecked,
  updateBannerDismissed: false,
  firstTaskFeedbackDialogState: Waiting,
  highlightedAnnotation: None,
}

module Selectors = {
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
    Task.getWebPreviewIsSelecting(currentTask(state))
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

  let acpSession = (state: state): Client__State__Types.acpSession => {
    state.acpSession
  }

  let hasActiveACPSession = (state: state): bool => {
    switch state.acpSession {
    | AcpSessionActive(_) => true
    | NoAcpSession => false
    }
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

  let updateCheckStatus = (state: state): Client__State__Types.updateCheckStatus => {
    state.updateCheckStatus
  }

  let updateBannerDismissed = (state: state): bool => {
    state.updateBannerDismissed
  }

  let showFirstTaskFeedbackDialog = (state: state) =>
    switch state.firstTaskFeedbackDialogState {
    | Visible | LinkCopied | ShareFailed => true
    | Waiting | AwaitingHistory | Dismissed => false
    }

  let firstTaskFeedbackLinkCopied = (state: state) =>
    state.firstTaskFeedbackDialogState == LinkCopied

  let firstTaskFeedbackShareFailed = (state: state) =>
    state.firstTaskFeedbackDialogState == ShareFailed

  let highlightedAnnotation = (state: state): option<
    Client__State__Types.highlightedAnnotation,
  > => {
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
      state.agentCatalog->Option.flatMap(catalog =>
        catalog->Array.find(agent => agent.name == name)
      )
    switch (
      state.acpSession,
      findAgent(plannerAgentName),
      findAgent(executorAgentName),
      TaskReducer.Selectors.completedIdleTurn(currentTask(state)),
    ) {
    | (AcpSessionActive(_), Some(planner), Some(executor), Some({taskId, agentId}))
      if agentId == planner.id =>
      Some({taskId, executorAgentId: executor.id})
    | _ => None
    }
  }

  let providerSetupRequired = (state: state): bool => {
    switch (state.acpSession, state.configOptions) {
    | (AcpSessionActive(_), Some(configOptions)) =>
      switch configOptions->ACP.findConfigOptionByCategory(ACP.Model) {
      | Some(modelConfig) => ACP.sessionConfigOptionFirstOption(modelConfig)->Option.isNone
      | None => false
      }
    | _ => false
    }
  }
}

let buildAttachmentContentBlocks = (attachments: array<Client__Message.fileAttachmentData>): array<
  Client__State__Types.ContentBlock.t,
> => {
  attachments->Array.map(att => {
    let base64Data = switch att.dataUrl->String.indexOf(";base64,") {
    | -1 => att.dataUrl
    | idx => att.dataUrl->String.slice(~start=idx + 8, ~end=String.length(att.dataUrl))
    }

    let metaObj = Dict.make()
    metaObj->Dict.set("user_image", JSON.Encode.bool(true))
    metaObj->Dict.set("filename", JSON.Encode.string(att.filename))
    let meta = JSON.Encode.object(metaObj)

    Client__State__Types.ContentBlock.EmbeddedResource({
      resource: Client__State__Types.ContentBlock.BlobResourceContents({
        uri: `attachment://${att.id}/${att.filename}`,
        mimeType: Some(att.mediaType),
        blob: base64Data,
      }),
      _meta: Some(meta),
      annotations: None,
    })
  })
}

let sendMessageToAPIImpl = (
  state: state,
  dispatch,
  ~messageId,
  ~message,
  ~attachments: array<Client__Message.fileAttachmentData>,
  ~annotations: array<Client__Message.MessageAnnotation.t>,
  ~taskId,
  ~agentId,
) => {
  switch state.acpSession {
  | AcpSessionActive({sendPrompt}) =>
    let pageContextBlocks =
      state.tasks
      ->Dict.get(taskId)
      ->Option.mapOr([], Client__State__Types.taskToPageContextBlocks)

    let annotationBlocks = Client__State__Types.messageAnnotationsToContentBlocks(annotations)

    let attachmentBlocks = buildAttachmentContentBlocks(attachments)
    let additionalBlocks =
      Array.concat(pageContextBlocks, annotationBlocks)->Array.concat(attachmentBlocks)

    let runtimeConfig = Client__RuntimeConfig.read()
    let baseMeta = Client__RuntimeConfig.toMeta(runtimeConfig)
    let metadata = baseMeta->JSON.Decode.object->Option.getOrThrow->Dict.copy
    state.selectedModelValue->Option.forEach(modelValue =>
      metadata->Dict.set("model", JSON.Encode.string(modelValue))
    )
    metadata->Dict.set(
      "frontman.dev/messageId",
      JSON.Encode.string(Message.UserMessageId.toString(messageId)),
    )
    metadata->Dict.set("agent", JSON.Encode.string(agentId))
    let _meta = Some(JSON.Encode.object(metadata))

    sendPrompt(
      message,
      ~additionalBlocks,
      ~onComplete=result =>
        switch result {
        | Ok(_) => ()
        | Error(error) =>
          dispatch(
            TaskAction({
              target: ForTask(taskId),
              action: UserMessageSendFailed({id: messageId, error}),
            }),
          )
        },
      ~_meta,
    )
  | NoAcpSession =>
    let error = "Cannot send message: no active ACP session"
    Log.error(error)
    dispatch(
      TaskAction({
        target: ForTask(taskId),
        action: UserMessageSendFailed({id: messageId, error}),
      }),
    )
  }
}

let updateTargetKey = (target: Client__State__Types.updateTarget): string =>
  switch target {
  | NpmPackage(npmPackage) => npmPackage
  | WordPressPlugin(slug) => `wordpress:${slug}`
  }

let updateInfoFromVersions = (
  ~target: Client__State__Types.updateTarget,
  ~installedVersion: string,
  ~versions: Dict.t<option<string>>,
): option<Client__State__Types.updateInfo> => {
  let key = updateTargetKey(target)
  switch versions->Dict.get(key)->Option.flatMap(version => version) {
  | Some(latestVersion) =>
    switch (Client__Semver.parse(installedVersion), Client__Semver.parse(latestVersion)) {
    | (Some(installed), Some(latest)) if Client__Semver.isBehind(installed, latest) =>
      Some({target, installedVersion, latestVersion})
    | _ => None
    }
  | None => None
  }
}

let targetIsCurrent = (state: state, target: taskTarget): bool =>
  switch target {
  | CurrentTask => true
  | ForTask(taskId) => Selectors.currentTaskId(state) == Some(taskId)
  }

let canShowFirstTaskFeedback = (state: state, task) =>
  state.tasks->Dict.valuesToArray->Array.length == 1 &&
  TaskReducer.Selectors.completedIdleTurn(task)->Option.isSome &&
  TaskReducer.Selectors.queuedUserMessages(task)->Option.getOrThrow->Array.length == 0

let firstTaskFeedbackTransitionEffects = (
  previous: Client__State__Types.firstTaskFeedbackDialogState,
  next: Client__State__Types.firstTaskFeedbackDialogState,
) =>
  switch (previous, next) {
  | (Visible, Visible) => []
  | (_, Visible) => [TrackAnalyticsEffect(FirstTaskFeedbackDialogShown)]
  | _ => []
  }

let addUserMessageToState = (state: state, ~id, ~sessionId, ~content, ~annotations, ~agentId) =>
  switch state.selectedModelValue {
  | None => state->StateReducer.update
  | Some(_) => {
      let textContent = TaskReducer.extractTextFromUserContent(content)

      switch state.currentTask {
      | Task.New(newTask) =>
        let loadedTask = Task.newToLoaded(newTask, ~id=sessionId, ~title=textContent)
        let updatedTasks = state.tasks->Dict.copy
        updatedTasks->Dict.set(sessionId, loadedTask)
        let promotedState = {
          ...state,
          tasks: updatedTasks,
          currentTask: Task.Selected(sessionId),
        }
        promotedState->Lens.delegateToTask(
          ForTask(sessionId),
          TaskReducer.AddUserMessage({id, content, annotations, agentId}),
        )
      | Task.Selected(taskId) =>
        let pendingPlanHandoff = Selectors.pendingPlanHandoff(state)
        let (updatedState, sendEffects) =
          state->Lens.delegateToTask(
            ForTask(taskId),
            TaskReducer.AddUserMessage({id, content, annotations, agentId}),
          )
        switch pendingPlanHandoff {
        | Some(_) =>
          let (runningState, runningEffects) =
            updatedState->Lens.delegateToTask(ForTask(taskId), TaskReducer.ExecutionStateRunning)
          runningState->StateReducer.update(~sideEffects=Array.concat(sendEffects, runningEffects))
        | None => updatedState->StateReducer.update(~sideEffects=sendEffects)
        }
      }
    }
  }

let resolveFeedbackHistory = (state: state) =>
  switch state.firstTaskFeedbackDialogState {
  | AwaitingHistory
    if state.sessionsLoadState == Client__State__Types.SessionsLoaded &&
    Selectors.pendingPlanHandoff(state)->Option.isNone &&
    canShowFirstTaskFeedback(state, Selectors.currentTask(state)) => {
      ...state,
      firstTaskFeedbackDialogState: Visible,
    }
  | AwaitingHistory => {...state, firstTaskFeedbackDialogState: Dismissed}
  | Waiting | Visible | LinkCopied | ShareFailed | Dismissed => state
  }

let requireEmbeddedAuthentication = requireAuthentication => {
  Client__EmbeddedAuth.clearToken()
  requireAuthentication()
}

let embeddedAuthRequiredError = "Frontman authorization is required"

let fetchUserProfileImpl = (dispatch, ~apiBaseUrl) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/me`

    try {
      switch Client__EmbeddedAuth.headers() {
      | Some(headers) =>
        let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
        Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
        switch response.ok {
        | true =>
          let json = await response->WebAPI.Response.json
          let userProfile =
            json->S.decodeOrThrow(~from=S.json, ~to=Client__State__Types.userProfileSchema)
          dispatch(UserProfileReceived({userProfile: userProfile}))
          Client__Heap.identify(userProfile.id)
        | false => ()
        }
      | None => ()
      }
    } catch {
    | exn => Log.error(~error=JsExn.fromException(exn), "FetchUserProfile failed")
    }
  }
  fetch()->ignore
}

let encodeUserApiKeySaveRequest = (~provider, ~key) => {
  let payload: Client__State__Types.userApiKeySaveRequest = {provider, key}
  payload
  ->S.decodeOrThrow(
    ~from=Client__State__Types.userApiKeySaveRequestSchema,
    ~to=S.json->S.noValidation(true),
  )
  ->JSON.stringify
}

let fetchApiKeySettingsImpl = (dispatch, ~apiBaseUrl) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/api-keys`

    try {
      switch Client__EmbeddedAuth.headers() {
      | Some(headers) =>
        let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
        Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
        switch response.ok {
        | true =>
          let json = await response->WebAPI.Response.json
          let apiKeysResponse =
            json->S.decodeOrThrow(~from=S.json, ~to=Client__State__Types.userApiKeysResponseSchema)
          apiKeyProviders->Array.forEach(provider => {
            let providerId = apiKeyProviderId(provider)
            let hasUserKey = apiKeysResponse.providers->Array.includes(providerId)
            let source = switch hasUserKey {
            | true => Client__State__Types.UserOverride
            | false => Client__State__Types.None
            }

            dispatch(ApiKeySettingsReceived({provider, source}))
          })
        | false => ()
        }
      | None => ()
      }
    } catch {
    | exn => Log.error(~error=JsExn.fromException(exn), "FetchApiKeySettings failed")
    }
  }
  fetch()->ignore
}

let saveApiKeyImpl = (dispatch, ~apiBaseUrl, ~provider: apiKeyProvider, ~key) => {
  let save = async () => {
    dispatch(ApiKeySaveStarted({provider: provider}))
    let url = `${apiBaseUrl}/api/user/api-keys`

    try {
      switch Client__EmbeddedAuth.jsonHeaders() {
      | Some(headers) =>
        let response = await WebAPI.Fetch.fetch(
          url,
          ~init={
            method: "POST",
            headers,
            body: WebAPI.BodyInit.fromString(
              encodeUserApiKeySaveRequest(~provider=apiKeyProviderId(provider), ~key),
            ),
          },
        )
        Client__EmbeddedAuth.clearTokenOnUnauthorized(response)

        switch response.ok {
        | false =>
          dispatch(
            ApiKeySaveError({
              provider,
              error: `HTTP ${response.status->Int.toString}: ${response.statusText}`,
            }),
          )
        | true => dispatch(ApiKeySaved({provider: provider}))
        }
      | None => dispatch(ApiKeySaveError({provider, error: embeddedAuthRequiredError}))
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      dispatch(ApiKeySaveError({provider, error: `Failed to save API key: ${msg}`}))
    }
  }
  save()->ignore
}

let fetchCustomProvidersImpl = (dispatch, ~apiBaseUrl, ~requireAuthentication) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/custom-providers`

    try {
      switch Client__EmbeddedAuth.headers() {
      | Some(headers) =>
        let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
        Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
        switch response.ok {
        | true =>
          let json = await response->WebAPI.Response.json
          let providersResponse =
            json->S.decodeOrThrow(
              ~from=S.json,
              ~to=Client__State__Types.customProvidersResponseSchema,
            )
          dispatch(CustomProvidersReceived({providers: providersResponse.providers}))
        | false =>
          switch response.status {
          | 401 => requireAuthentication()
          | _ =>
            Log.error(
              `Custom Provider request failed: HTTP ${response.status->Int.toString}: ${response.statusText}`,
            )
          }
        }
      | None => requireAuthentication()
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Log.error(`Failed to fetch custom providers: ${msg}`)
    }
  }
  fetch()->ignore
}

let customProviderCreateRequestSchema = S.object(s => (
  s.field("name", S.string),
  s.field("base_url", S.string),
  s.field("models", S.array(S.string)),
  s.field("api_key", S.option(S.string)),
))
let customProviderApiKeyChangeRequestSchema = S.object(s => (
  s.field("action", S.string),
  s.field("value", S.option(S.string)),
))
let customProviderUpdateRequestSchema = S.object(s => (
  s.field("name", S.string),
  s.field("base_url", S.string),
  s.field("models", S.array(S.string)),
  s.field("lock_version", S.int),
  s.field("api_key_change", customProviderApiKeyChangeRequestSchema),
))

let jsonString = (value, schema) =>
  value
  ->S.decodeOrThrow(~from=schema, ~to=S.json)
  ->JSON.stringifyAny
  ->Option.getOrThrow(~message="Expected schema output to be JSON")

let encodeCustomProviderSaveRequest = (draft: Client__State__Types.customProviderDraft) =>
  switch draft.id {
  | None =>
    let apiKey = switch draft.apiKeyChange {
    | ReplaceCustomProviderApiKey(value) => Some(value)
    | KeepCustomProviderApiKey | ClearCustomProviderApiKey => None
    }
    jsonString((draft.name, draft.baseUrl, draft.models, apiKey), customProviderCreateRequestSchema)
  | Some(_) =>
    let apiKeyChange = switch draft.apiKeyChange {
    | KeepCustomProviderApiKey => ("keep", None)
    | ClearCustomProviderApiKey => ("clear", None)
    | ReplaceCustomProviderApiKey(value) => ("replace", Some(value))
    }
    jsonString(
      (draft.name, draft.baseUrl, draft.models, draft.lockVersion->Option.getOrThrow, apiKeyChange),
      customProviderUpdateRequestSchema,
    )
  }

let customProviderValidationErrorsSchema = S.object(s =>
  s.field("errors", S.dict(S.array(S.string)))
)
let customProviderConflictSchema = S.object(s =>
  s.field("current_provider", Client__State__Types.customProviderSchema)
)

let decodeCustomProviderMutationError = (~status, ~json) =>
  switch status {
  | 404 => Client__State__Types.CustomProviderNotFound
  | 409 =>
    let provider = json->S.decodeOrThrow(~from=S.json, ~to=customProviderConflictSchema)
    Client__State__Types.CustomProviderConflict(provider)
  | 422 =>
    let errors = json->S.decodeOrThrow(~from=S.json, ~to=customProviderValidationErrorsSchema)
    Client__State__Types.CustomProviderValidationError(errors)
  | _ =>
    Client__State__Types.CustomProviderNetworkError(
      json->JSON.stringifyAny->Option.getOr(`HTTP ${status->Int.toString}`),
    )
  }

let customProviderSaveTarget = (~apiBaseUrl, draft: Client__State__Types.customProviderDraft) =>
  switch draft.id {
  | Some(providerId) => (`${apiBaseUrl}/api/user/custom-providers/${providerId}`, "PUT")
  | None => (`${apiBaseUrl}/api/user/custom-providers`, "POST")
  }

let customProviderDeleteUrl = (~apiBaseUrl, ~id, ~lockVersion) =>
  `${apiBaseUrl}/api/user/custom-providers/${id}?lock_version=${lockVersion->Int.toString}`

let customProviderMutationOperation = request =>
  switch request {
  | SaveCustomProviderRequest(draft) => Client__State__Types.SavingCustomProvider(draft.id)
  | DeleteCustomProviderRequest({id}) => Client__State__Types.DeletingCustomProvider(id)
  }

let dispatchCustomProviderAuthRequired = (dispatch, ~operation, ~requireAuthentication) => {
  requireAuthentication()
  dispatch(
    CustomProviderMutationFailed({
      operation,
      error: Client__State__Types.CustomProviderNetworkError(embeddedAuthRequiredError),
    }),
  )
}

let handleCustomProviderMutationError = async (
  dispatch,
  response,
  ~operation,
  ~requireAuthentication,
) =>
  switch response.WebAPI.Response.status {
  | 401 => dispatchCustomProviderAuthRequired(dispatch, ~operation, ~requireAuthentication)
  | _ =>
    let json = await response->WebAPI.Response.json
    dispatch(
      CustomProviderMutationFailed({
        operation,
        error: decodeCustomProviderMutationError(~status=response.status, ~json),
      }),
    )
  }

let customProviderMutationImpl = (dispatch, ~apiBaseUrl, ~request, ~requireAuthentication) => {
  let run = async () => {
    let operation = customProviderMutationOperation(request)
    try {
      switch request {
      | SaveCustomProviderRequest(draft) =>
        switch Client__EmbeddedAuth.jsonHeaders() {
        | Some(headers) =>
          let (url, method) = customProviderSaveTarget(~apiBaseUrl, draft)
          let response = await WebAPI.Fetch.fetch(
            url,
            ~init={
              method,
              headers,
              body: WebAPI.BodyInit.fromString(encodeCustomProviderSaveRequest(draft)),
            },
          )
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {provider} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.customProviderResponseSchema,
              )
            dispatch(CustomProviderMutationSucceeded({operation, provider: Some(provider)}))
          | false =>
            await handleCustomProviderMutationError(
              dispatch,
              response,
              ~operation,
              ~requireAuthentication,
            )
          }
        | None => dispatchCustomProviderAuthRequired(dispatch, ~operation, ~requireAuthentication)
        }
      | DeleteCustomProviderRequest({id, lockVersion}) =>
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(
            customProviderDeleteUrl(~apiBaseUrl, ~id, ~lockVersion),
            ~init={headers, method: "DELETE"},
          )
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true => dispatch(CustomProviderMutationSucceeded({operation, provider: None}))
          | false =>
            await handleCustomProviderMutationError(
              dispatch,
              response,
              ~operation,
              ~requireAuthentication,
            )
          }
        | None => dispatchCustomProviderAuthRequired(dispatch, ~operation, ~requireAuthentication)
        }
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      let action = switch request {
      | SaveCustomProviderRequest(_) => "save"
      | DeleteCustomProviderRequest(_) => "delete"
      }
      dispatch(
        CustomProviderMutationFailed({
          operation,
          error: Client__State__Types.CustomProviderNetworkError(
            `Failed to ${action} custom provider: ${msg}`,
          ),
        }),
      )
    }
  }
  run()->ignore
}

let handleEffect = (effect, state: state, dispatch) => {
  switch effect {
  | FetchUserProfileEffect({apiBaseUrl}) => fetchUserProfileImpl(dispatch, ~apiBaseUrl)
  | TaskEffect({target, effect: taskEffect}) => {
      let taskDispatch = (taskAction: TaskReducer.action) => {
        dispatch(TaskAction({target, action: taskAction}))
      }

      let delegate = (delegated: TaskReducer.delegated) => {
        switch delegated {
        | NeedSendMessage({id, text, attachments, annotations, agentId}) =>
          let taskId = switch target {
          | ForTask(id) => id
          | CurrentTask =>
            switch state.currentTask {
            | Task.Selected(id) => id
            | Task.New(_) =>
              failwith("[TaskEffect] NeedSendMessage from CurrentTask but currentTask is New")
            }
          }
          sendMessageToAPIImpl(
            state,
            dispatch,
            ~messageId=id,
            ~message=text,
            ~attachments,
            ~annotations,
            ~taskId,
            ~agentId,
          )
        | NeedSessionCommand(command) =>
          switch state.acpSession {
          | AcpSessionActive({sendSessionCommand}) => sendSessionCommand(command)
          | NoAcpSession => Log.error("Cannot send session command: no active ACP session")
          }
        | NeedSyncBrowserUrl(url) =>
          switch targetIsCurrent(state, target) {
          | true => Client__BrowserUrl.syncBrowserUrl(~previewUrl=url)
          | false => ()
          }
        }
      }

      TaskReducer.handleEffect(taskEffect, ~dispatch=taskDispatch, ~delegate)
    }
  | FetchApiKeySettingsEffect({apiBaseUrl}) => fetchApiKeySettingsImpl(dispatch, ~apiBaseUrl)
  | SaveApiKeyEffect({apiBaseUrl, provider, key}) =>
    saveApiKeyImpl(dispatch, ~apiBaseUrl, ~provider, ~key)
  | FetchAnthropicOAuthStatusEffect({apiBaseUrl, requireAuthentication}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/oauth/anthropic/status`

      try {
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {connected, expiresAt} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.oauthStatusResponseSchema,
              )
            dispatch(AnthropicOAuthStatusReceived({connected, expiresAt}))
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(requireAuthentication)
            | _ => ()
            }
          }
        | None => requireEmbeddedAuthentication(requireAuthentication)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to fetch OAuth status"}))
      }
    }
    fetch()->ignore

  | GetAnthropicOAuthUrlEffect({apiBaseUrl, requireAuthentication}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/oauth/anthropic/authorize-url`

      try {
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {authorizeUrl, verifier} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.anthropicOAuthAuthorizeUrlResponseSchema,
              )
            dispatch(AnthropicOAuthUrlReceived({authorizeUrl, verifier}))
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(requireAuthentication)
            | _ => dispatch(AnthropicOAuthError({error: "Failed to get authorization URL"}))
            }
          }
        | None => requireEmbeddedAuthentication(requireAuthentication)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to get authorization URL"}))
      }
    }
    fetch()->ignore

  | ExchangeAnthropicOAuthCodeEffect({apiBaseUrl, code, verifier, requireAuthentication}) =>
    let exchange = async () => {
      let url = `${apiBaseUrl}/api/oauth/anthropic/exchange`

      try {
        let body = JSON.Encode.object(
          Dict.fromArray([
            ("code", JSON.Encode.string(code)),
            ("verifier", JSON.Encode.string(verifier)),
          ]),
        )
        switch Client__EmbeddedAuth.jsonHeaders() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(
            url,
            ~init={
              method: "POST",
              headers,
              body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
            },
          )
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {expiresAt} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.anthropicOAuthExchangeResponseSchema,
              )
            dispatch(AnthropicOAuthConnected({expiresAt: expiresAt}))
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(requireAuthentication)
            | _ =>
              let json = await response->WebAPI.Response.json
              let {error} =
                json->S.decodeOrThrow(
                  ~from=S.json,
                  ~to=Client__State__Types.anthropicOAuthErrorResponseSchema,
                )
              dispatch(AnthropicOAuthError({error: error}))
            }
          }
        | None => requireEmbeddedAuthentication(requireAuthentication)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to exchange authorization code"}))
      }
    }
    exchange()->ignore

  | DisconnectAnthropicOAuthEffect({apiBaseUrl, requireAuthentication}) =>
    let disconnect = async () => {
      let url = `${apiBaseUrl}/api/oauth/anthropic/disconnect`

      try {
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={method: "DELETE", headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true => dispatch(AnthropicOAuthDisconnected)
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(requireAuthentication)
            | _ => dispatch(AnthropicOAuthError({error: "Failed to disconnect"}))
            }
          }
        | None => requireEmbeddedAuthentication(requireAuthentication)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to disconnect"}))
      }
    }
    disconnect()->ignore

  | FetchOpenAIOAuthStatusEffect({apiBaseUrl, requireAuthentication}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/oauth/openai/status`

      try {
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={headers: headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {connected, expiresAt} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.oauthStatusResponseSchema,
              )
            dispatch(OpenAIOAuthStatusReceived({connected, expiresAt}))
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(requireAuthentication)
            | _ => ()
            }
          }
        | None => requireEmbeddedAuthentication(requireAuthentication)
        }
      } catch {
      | _ =>
        dispatch(
          OpenAIOAuthError({deviceAuthId: None, error: "Failed to fetch OpenAI OAuth status"}),
        )
      }
    }
    fetch()->ignore

  | InitiateOpenAIDeviceAuthEffect({apiBaseUrl, requireAuthentication}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/oauth/openai/initiate`

      try {
        switch Client__EmbeddedAuth.jsonHeaders() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={method: "POST", headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true =>
            let json = await response->WebAPI.Response.json
            let {deviceAuthId, userCode, verificationUrl} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.openAIDeviceAuthResponseSchema,
              )
            dispatch(OpenAIDeviceCodeReceived({deviceAuthId, userCode, verificationUrl}))
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(requireAuthentication)
            | _ =>
              dispatch(
                OpenAIOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}),
              )
            }
          }
        | None => requireEmbeddedAuthentication(requireAuthentication)
        }
      } catch {
      | _ =>
        dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}))
      }
    }
    fetch()->ignore

  | PollOpenAIDeviceAuthEffect({apiBaseUrl, deviceAuthId, userCode, requireAuthentication}) =>
    let poll = async () => {
      let maxAttempts = 180
      let intervalMs = 5000
      let body = JSON.stringifyAny(
        dict{
          "device_auth_id": deviceAuthId,
          "user_code": userCode,
        },
      )->Option.getOr("{}")
      let waitForNextPoll = () =>
        Promise.make((resolve, _) => {
          let _ = setTimeout(() => resolve(), intervalMs)
        })
      let rec pollLoop = async attempt => {
        switch attempt < maxAttempts {
        | false =>
          dispatch(
            OpenAIOAuthError({
              deviceAuthId: Some(deviceAuthId),
              error: "Authorization timed out. Please try again.",
            }),
          )
        | true =>
          try {
            let url = `${apiBaseUrl}/api/oauth/openai/poll`
            switch Client__EmbeddedAuth.jsonHeaders() {
            | Some(headers) =>
              let response = await WebAPI.Fetch.fetch(
                url,
                ~init={
                  method: "POST",
                  headers,
                  body: WebAPI.BodyInit.fromString(body),
                },
              )
              Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
              switch (response.ok, response.status) {
              | (true, _) =>
                let json = await response->WebAPI.Response.json
                let {status, expiresAt} =
                  json->S.decodeOrThrow(
                    ~from=S.json,
                    ~to=Client__State__Types.openAIDeviceAuthPollResponseSchema,
                  )
                switch status {
                | Client__State__Types.DeviceAuthConnected =>
                  let expiresAt = expiresAt->Option.getOrThrow
                  dispatch(OpenAIOAuthConnected({deviceAuthId, expiresAt}))
                | Client__State__Types.DeviceAuthPending =>
                  await waitForNextPoll()
                  await pollLoop(attempt + 1)
                }
              | (false, 401) => requireEmbeddedAuthentication(requireAuthentication)
              | (false, 403) =>
                dispatch(
                  OpenAIOAuthError({
                    deviceAuthId: Some(deviceAuthId),
                    error: "Authorization was declined.",
                  }),
                )
              | (false, _) =>
                await waitForNextPoll()
                await pollLoop(attempt + 1)
              }
            | None => requireEmbeddedAuthentication(requireAuthentication)
            }
          } catch {
          | _ =>
            await waitForNextPoll()
            await pollLoop(attempt + 1)
          }
        }
      }
      await pollLoop(0)
    }
    poll()->ignore

  | DisconnectOpenAIOAuthEffect({apiBaseUrl, requireAuthentication}) =>
    let disconnect = async () => {
      let url = `${apiBaseUrl}/api/oauth/openai/disconnect`

      try {
        switch Client__EmbeddedAuth.headers() {
        | Some(headers) =>
          let response = await WebAPI.Fetch.fetch(url, ~init={method: "DELETE", headers})
          Client__EmbeddedAuth.clearTokenOnUnauthorized(response)
          switch response.ok {
          | true => dispatch(OpenAIOAuthDisconnected)
          | false =>
            switch response.status {
            | 401 => requireEmbeddedAuthentication(requireAuthentication)
            | _ => dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
            }
          }
        | None => requireEmbeddedAuthentication(requireAuthentication)
        }
      } catch {
      | _ => dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
      }
    }
    disconnect()->ignore

  | DeleteSessionEffect({taskId}) =>
    switch state.acpSession {
    | AcpSessionActive({deleteSession}) => deleteSession(taskId, ~onComplete=_ => ())
    | NoAcpSession => ()
    }

  | LoadTaskEffect({taskId}) =>
    switch state.acpSession {
    | AcpSessionActive({loadTask}) =>
      let taskIdToLoad = taskId
      let needsHistory = switch state.tasks->Dict.get(taskId) {
      | Some(task) => !Task.isLoaded(task)
      | None => true
      }
      loadTask(taskId, ~needsHistory, ~onComplete=result => {
        switch result {
        | Ok() =>
          if needsHistory {
            Client__TextDeltaBuffer.flush()
            dispatch(TaskAction({target: ForTask(taskIdToLoad), action: LoadComplete}))
          }
        | Error(err) =>
          dispatch(TaskAction({target: ForTask(taskIdToLoad), action: LoadError({error: err})}))
        }
      })
    | NoAcpSession =>
      dispatch(
        TaskAction({target: ForTask(taskId), action: LoadError({error: "No active ACP session"})}),
      )
    }
  | CheckForUpdateEffect({apiBaseUrl, installedVersion, target}) =>
    let fetch = async () => {
      try {
        let url = `${apiBaseUrl}/api/integrations/latest-versions`
        let response = await WebAPI.Fetch.fetch(url)
        switch response.ok {
        | false =>
          Sentry.captureConnectionError(
            `CheckForUpdate: HTTP ${response.status->Int.toString} ${response.statusText}`,
            ~endpoint=url,
          )
        | true =>
          let json = await response->WebAPI.Response.json
          let {versions} =
            json->S.decodeOrThrow(
              ~from=S.json,
              ~to=Client__State__Types.latestVersionsResponseSchema,
            )
          switch updateInfoFromVersions(~target, ~installedVersion, ~versions) {
          | Some({target, installedVersion, latestVersion}) =>
            dispatch(UpdateInfoReceived({updateInfo: {target, installedVersion, latestVersion}}))
          | None =>
            switch target {
            | NpmPackage(npmPackage) =>
              Sentry.captureConnectionError(
                `CheckForUpdate: package "${npmPackage}" not found or null in registry response`,
                ~endpoint=url,
              )
            | WordPressPlugin(_) => ()
            }
          }
        }
      } catch {
      | exn => Sentry.captureException(exn, ~operation="CheckForUpdate")
      }
    }
    fetch()->ignore
  | TrackAnalyticsEffect(event) => Client__Analytics.track(event)

  | ShareFrontmanEffect =>
    FirstTaskFeedbackShare.run(
      ~onShared=() => dispatch(DismissFirstTaskFeedbackDialog),
      ~onCopied=() => dispatch(ShareFrontmanLinkCopied),
      ~onFailed=() => dispatch(ShareFrontmanFailed),
    )

  | FetchCustomProvidersEffect({apiBaseUrl, requireAuthentication}) =>
    fetchCustomProvidersImpl(dispatch, ~apiBaseUrl, ~requireAuthentication)
  | CustomProviderMutationEffect({apiBaseUrl, request, requireAuthentication}) =>
    customProviderMutationImpl(dispatch, ~apiBaseUrl, ~request, ~requireAuthentication)
  }
}

let upsertCustomProvider = (
  existing: option<array<Client__State__Types.customProvider>>,
  provider: Client__State__Types.customProvider,
): array<Client__State__Types.customProvider> => {
  let providers = existing->Option.getOr([])
  switch providers->Array.findIndexOpt(existing => existing.id == provider.id) {
  | Some(idx) =>
    let merged = providers->Array.copy
    merged[idx] = provider
    merged
  | None => Array.concat(providers, [provider])
  }
}

let clearSelectedModelValue = (state: state): state => {
  syncSelectedModelValueToStorage(None)
  {...state, selectedModelValue: None}
}

let applyCustomProvider = (state: state, provider: Client__State__Types.customProvider): state => {
  let state = {
    ...state,
    customProviders: Some(upsertCustomProvider(state.customProviders, provider)),
  }
  switch state.selectedModelValue {
  | Some(value) if value->String.startsWith(`custom:${provider.id}:`) =>
    switch provider.models->Array.some(model => value == `custom:${provider.id}:${model}`) {
    | true => state
    | false => clearSelectedModelValue(state)
    }
  | _ => state
  }
}

let startCustomProviderMutation = (state: state, request) => {
  let operation = customProviderMutationOperation(request)
  switch state.customProviderMutation {
  | CustomProviderMutationIdle =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      {
        ...state,
        customProviderMutation: CustomProviderMutationPending(operation),
      }->StateReducer.update(
        ~sideEffects=[CustomProviderMutationEffect({apiBaseUrl, request, requireAuthentication})],
      )
    | NoAcpSession =>
      {
        ...state,
        customProviderMutation: CustomProviderMutationFailed({
          operation,
          error: CustomProviderNetworkError(embeddedAuthRequiredError),
        }),
      }->StateReducer.update
    }
  | _ => state->StateReducer.update
  }
}

let next = (state: state, action) => {
  switch action {
  | TaskExecutionStopped({taskId, stopReason}) => {
      let (state, effects) = state->Lens.delegateToTask(ForTask(taskId), ExecutionStateIdle)
      let task = state.tasks->Dict.get(taskId)->Option.getOrThrow
      let feedbackState: Client__State__Types.firstTaskFeedbackDialogState = switch (
        state.firstTaskFeedbackDialogState,
        stopReason,
      ) {
      | (Waiting, Some(EndTurn)) =>
        switch (canShowFirstTaskFeedback(state, task), Selectors.pendingPlanHandoff(state)) {
        | (true, None) =>
          switch state.sessionsLoadState {
          | Client__State__Types.SessionsLoaded => Visible
          | Client__State__Types.SessionsNotLoaded | Client__State__Types.SessionsLoading =>
            AwaitingHistory
          | Client__State__Types.SessionsLoadError(_) => Dismissed
          }
        | (false, _) => Dismissed
        | (true, Some(_)) => Waiting
        }
      | _ => state.firstTaskFeedbackDialogState
      }
      let feedbackEffects = firstTaskFeedbackTransitionEffects(
        state.firstTaskFeedbackDialogState,
        feedbackState,
      )
      {...state, firstTaskFeedbackDialogState: feedbackState}->StateReducer.update(
        ~sideEffects=Array.concat(effects, feedbackEffects),
      )
    }
  | TaskAction({target, action: taskAction}) => state->Lens.delegateToTask(target, taskAction)

  | ExecuteAnnotation({id, sessionId, annotationId, comment}) =>
    let agentId = state.selectedAgentId->Option.getOrThrow(~message="Selected agent is required")
    let annotation =
      Selectors.currentTask(state)
      ->Task.getAnnotations
      ->Array.find(annotation => annotation.id == annotationId)
      ->Option.getOrThrow(~message=`Annotation ${annotationId} not found`)
    let trimmedComment = comment->String.trim
    let annotation = {
      ...annotation,
      comment: switch trimmedComment {
      | "" => None
      | value => Some(value)
      },
    }
    let content = switch trimmedComment {
    | "" => []
    | value => [UserContentPart.Text({text: value})]
    }
    let messageAnnotation = Client__Message.MessageAnnotation.fromAnnotation(annotation)
    addUserMessageToState(
      state,
      ~id,
      ~sessionId,
      ~content,
      ~annotations=[messageAnnotation],
      ~agentId,
    )

  | AddUserMessage({id, sessionId, content, annotations, agentId}) =>
    addUserMessageToState(state, ~id, ~sessionId, ~content, ~annotations, ~agentId)

  | CancelTurn =>
    switch state.currentTask {
    | Task.Selected(taskId) => state->Lens.delegateToTask(ForTask(taskId), TaskReducer.CancelTurn)
    | Task.New(_) => state->StateReducer.update
    }

  | ExecutePendingPlan({id}) =>
    switch (state.selectedModelValue, Selectors.pendingPlanHandoff(state)) {
    | (Some(_), Some({taskId, executorAgentId})) =>
      let (messageState, sendEffects) = state->Lens.delegateToTask(
        ForTask(taskId),
        TaskReducer.AddUserMessage({
          id,
          content: [UserContentPart.Text({text: executePlanPrompt})],
          annotations: [],
          agentId: executorAgentId,
        }),
      )
      let (runningState, runningEffects) =
        messageState->Lens.delegateToTask(ForTask(taskId), TaskReducer.ExecutionStateRunning)
      {
        ...runningState,
        selectedAgentId: Some(executorAgentId),
      }->StateReducer.update(~sideEffects=Array.concat(sendEffects, runningEffects))
    | _ => state->StateReducer.update
    }

  | SwitchTask({taskId}) => {
      let task = state.tasks->Dict.get(taskId)->Option.getOrThrow
      let needsLoad = Task.isUnloaded(task)
      let (updatedState, taskEffects) = if needsLoad {
        state->Lens.delegateToTask(
          ForTask(taskId),
          TaskReducer.LoadStarted({previewUrl: getInitialUrl()}),
        )
      } else {
        (state, [])
      }
      {
        ...updatedState,
        currentTask: Task.Selected(taskId),
        highlightedAnnotation: None,
      }->StateReducer.update(
        ~sideEffects=Array.concat([LoadTaskEffect({taskId: taskId})], taskEffects),
      )
    }

  | DeleteTask({taskId}) => {
      let updatedTasks = state.tasks->Dict.copy
      updatedTasks->Dict.delete(taskId)

      let newCurrentTask = switch state.currentTask {
      | Task.Selected(currentId) if currentId == taskId =>
        let mostRecent =
          updatedTasks
          ->Dict.valuesToArray
          ->Array.toSorted((a, b) => {
            let aTime = Selectors.getTaskSortTime(a)
            let bTime = Selectors.getTaskSortTime(b)
            bTime -. aTime
          })
          ->Array.get(0)
        switch mostRecent {
        | Some(task) => Task.Selected(Task.getId(task)->Option.getOrThrow)
        | None => Task.New(Task.makeNew(~previewUrl=getInitialUrl()))
        }
      | other => other
      }

      {
        ...state,
        tasks: updatedTasks,
        currentTask: newCurrentTask,
        highlightedAnnotation: None,
      }->StateReducer.update(~sideEffects=[DeleteSessionEffect({taskId: taskId})])
    }

  | ClearCurrentTask =>
    let previewUrl = Selectors.previewUrl(state)
    {
      ...state,
      currentTask: Task.New(Task.makeNew(~previewUrl)),
      highlightedAnnotation: None,
    }->StateReducer.update

  | UpdateTaskTitle({taskId, title}) =>
    switch state.tasks->Dict.get(taskId) {
    | Some(_) =>
      state
      ->Lens.updateTask(taskId, task => Task.setTitle(task, title))
      ->StateReducer.update
    | None => state->StateReducer.update
    }

  | SetAcpSession({
      sendPrompt,
      sendSessionCommand,
      loadTask,
      deleteSession,
      requireAuthentication,
      apiBaseUrl,
    }) =>
    {
      ...state,
      acpSession: AcpSessionActive({
        sendPrompt,
        sendSessionCommand,
        loadTask,
        deleteSession,
        requireAuthentication,
        apiBaseUrl,
      }),
    }->StateReducer.update

  | ClearAcpSession =>
    let updatedTasks = state.tasks->Dict.copy
    updatedTasks->Dict.forEachWithKey((task, taskId) => {
      switch TaskReducer.Selectors.pendingQuestion(task) {
      | Some(_) =>
        switch task {
        | Task.Loaded(data) =>
          updatedTasks->Dict.set(taskId, Task.Loaded({...data, pendingQuestion: None}))
        | _ => ()
        }
      | None => ()
      }
    })
    {
      ...state,
      tasks: updatedTasks,
      acpSession: NoAcpSession,
    }->StateReducer.update

  | FetchUserProfile({apiBaseUrl}) =>
    state->StateReducer.update(~sideEffects=[FetchUserProfileEffect({apiBaseUrl: apiBaseUrl})])

  | UserProfileReceived({userProfile: {id, email, name}}) =>
    let userProfile: Client__State__Types.userProfile = {id, email, name}
    {...state, userProfile: Some(userProfile)}->StateReducer.update
  | FetchApiKeySettings =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state
      ->setAllApiKeySources(Client__State__Types.Loading)
      ->StateReducer.update(~sideEffects=[FetchApiKeySettingsEffect({apiBaseUrl: apiBaseUrl})])
    | NoAcpSession => state->StateReducer.update
    }

  | ApiKeySettingsReceived({provider, source}) =>
    state->setApiKeySource(provider, source)->StateReducer.update

  | SaveApiKey({provider, key}) =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        pendingProviderAutoSelect: Some(apiKeyProviderId(provider)),
      }->StateReducer.update(~sideEffects=[SaveApiKeyEffect({apiBaseUrl, provider, key})])
    | NoAcpSession =>
      state->setApiKeySaveStatus(provider, SaveError("No active ACP session"))->StateReducer.update
    }

  | ApiKeySaveStarted({provider}) =>
    state->setApiKeySaveStatus(provider, Saving)->StateReducer.update

  | ApiKeySaved({provider}) => state->markApiKeySaved(provider)->StateReducer.update

  | ApiKeySaveError({provider, error}) =>
    let state = state->setApiKeySaveStatus(provider, SaveError(error))
    {...state, pendingProviderAutoSelect: None}->StateReducer.update

  | ResetApiKeySaveStatus({provider}) =>
    state->setApiKeySaveStatus(provider, Idle)->StateReducer.update

  | ConfigOptionsReceived({configOptions}) =>
    let modelConfigOption =
      ACP.findConfigOptionByCategory(configOptions, ACP.Model)->Option.getOrThrow(
        ~message="ConfigOptionsReceived missing model config option",
      )

    let firstModelValue =
      modelConfigOption->ACP.sessionConfigOptionFirstOption->Option.map(option => option.value)

    let modelValueExists = value =>
      switch modelConfigOption {
      | ACP.SelectConfigOption({options: ACP.Grouped(groups)}) =>
        groups->Array.some(group => group.options->Array.some(option => option.value == value))
      | ACP.SelectConfigOption({options: ACP.Ungrouped(options)}) =>
        options->Array.some(option => option.value == value)
      }

    let currentOrFirstModelValue = switch state.selectedModelValue {
    | Some(value) if modelValueExists(value) => Some(value)
    | _ => firstModelValue
    }

    let selectedModelValue = switch state.pendingProviderAutoSelect {
    | Some(providerId) =>
      let providerModelValue = switch modelConfigOption {
      | ACP.SelectConfigOption({options: ACP.Grouped(groups)}) =>
        groups
        ->Array.find(g => g.group == providerId)
        ->Option.flatMap(g => g.options->Array.get(0))
        ->Option.map(opt => opt.value)
      | ACP.SelectConfigOption({options: ACP.Ungrouped(_)}) => None
      }
      switch providerModelValue {
      | Some(value) => Some(value)
      | None => currentOrFirstModelValue
      }
    | None => currentOrFirstModelValue
    }
    switch (state.selectedModelValue, selectedModelValue) {
    | (Some(current), Some(next)) if current == next => ()
    | (None, None) => ()
    | _ => syncSelectedModelValueToStorage(selectedModelValue)
    }
    {
      ...state,
      configOptions: Some(configOptions),
      selectedModelValue,
      pendingProviderAutoSelect: None,
    }->StateReducer.update

  | SetSelectedModelValue({value}) =>
    syncSelectedModelValueToStorage(Some(value))
    {...state, selectedModelValue: Some(value)}->StateReducer.update

  | AgentAttributionConfigured({agentCatalog, defaultAgentId}) =>
    Client__Agent.findOrThrow(Some(agentCatalog), defaultAgentId)->ignore
    let selectedAgentId = switch state.selectedAgentId {
    | Some(agentId) if agentCatalog->Array.some(agent => agent.id == agentId) => Some(agentId)
    | _ => Some(defaultAgentId)
    }
    {...state, agentCatalog: Some(agentCatalog), selectedAgentId}->StateReducer.update

  | SetSelectedAgentId(agentId) =>
    Client__Agent.findOrThrow(state.agentCatalog, agentId)->ignore
    {...state, selectedAgentId: Some(agentId)}->StateReducer.update

  | FetchAnthropicOAuthStatus =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.FetchingStatus,
      }->StateReducer.update(
        ~sideEffects=[FetchAnthropicOAuthStatusEffect({apiBaseUrl, requireAuthentication})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | AnthropicOAuthStatusReceived({connected, expiresAt}) =>
    let status = switch (connected, expiresAt) {
    | (true, Some(expiresAtStr)) =>
      let expiresAtMs = Date.fromString(expiresAtStr)->Date.getTime
      Client__State__Types.Connected({expiresAt: expiresAtMs})
    | (true, None) => failwith("Connected Anthropic OAuth status missing expires_at")
    | (false, _) => Client__State__Types.NotConnected
    }
    {...state, anthropicOAuthStatus: status}->StateReducer.update

  | InitiateAnthropicOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      state->StateReducer.update(
        ~sideEffects=[GetAnthropicOAuthUrlEffect({apiBaseUrl, requireAuthentication})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | AnthropicOAuthUrlReceived({authorizeUrl, verifier}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Authorizing({authorizeUrl, verifier}),
    }->StateReducer.update

  | ExchangeAnthropicOAuthCode({code, verifier}) =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.Exchanging,
        pendingProviderAutoSelect: Some("anthropic"),
      }->StateReducer.update(
        ~sideEffects=[
          ExchangeAnthropicOAuthCodeEffect({
            apiBaseUrl,
            code,
            verifier,
            requireAuthentication,
          }),
        ],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | AnthropicOAuthConnected({expiresAt}) =>
    let expiresAtMs = Date.fromString(expiresAt)->Date.getTime
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Connected({expiresAt: expiresAtMs}),
    }->StateReducer.update

  | AnthropicOAuthError({error}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Error(error),
      pendingProviderAutoSelect: None,
    }->StateReducer.update

  | DisconnectAnthropicOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      state->StateReducer.update(
        ~sideEffects=[DisconnectAnthropicOAuthEffect({apiBaseUrl, requireAuthentication})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | AnthropicOAuthDisconnected =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.NotConnected,
    }->StateReducer.update

  | ResetAnthropicOAuthError =>
    switch state.anthropicOAuthStatus {
    | Client__State__Types.Error(_) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.NotConnected,
      }->StateReducer.update
    | _ => state->StateReducer.update
    }

  | CancelAnthropicOAuth =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.NotConnected,
    }->StateReducer.update

  | FetchOpenAIOAuthStatus =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIFetchingStatus,
      }->StateReducer.update(
        ~sideEffects=[FetchOpenAIOAuthStatusEffect({apiBaseUrl, requireAuthentication})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | OpenAIOAuthStatusReceived({connected, expiresAt}) =>
    let status = switch (connected, expiresAt) {
    | (true, Some(expiresAtStr)) =>
      let expiresAtMs = Date.fromString(expiresAtStr)->Date.getTime
      Client__State__Types.OpenAIConnected({expiresAt: expiresAtMs})
    | (true, None) => failwith("Connected OpenAI OAuth status missing expires_at")
    | (false, _) => Client__State__Types.OpenAINotConnected
    }
    {...state, openaiOAuthStatus: status}->StateReducer.update

  | InitiateOpenAIOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIWaitingForCode,
        pendingProviderAutoSelect: Some("openai_codex"),
      }->StateReducer.update(
        ~sideEffects=[InitiateOpenAIDeviceAuthEffect({apiBaseUrl, requireAuthentication})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | OpenAIDeviceCodeReceived({deviceAuthId, userCode, verificationUrl}) =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIShowingCode({
          deviceAuthId,
          userCode,
          verificationUrl,
        }),
      }->StateReducer.update(
        ~sideEffects=[
          PollOpenAIDeviceAuthEffect({
            apiBaseUrl,
            deviceAuthId,
            userCode,
            requireAuthentication,
          }),
        ],
      )
    | NoAcpSession =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIShowingCode({
          deviceAuthId,
          userCode,
          verificationUrl,
        }),
      }->StateReducer.update
    }

  | OpenAIOAuthConnected({deviceAuthId, expiresAt}) =>
    switch state.openaiOAuthStatus {
    | Client__State__Types.OpenAIShowingCode({deviceAuthId: currentId})
      if currentId == deviceAuthId =>
      let expiresAtMs = Date.fromString(expiresAt)->Date.getTime
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIConnected({expiresAt: expiresAtMs}),
      }->StateReducer.update
    | _ => state->StateReducer.update
    }

  | OpenAIOAuthError({deviceAuthId, error}) =>
    let isStale = switch deviceAuthId {
    | Some(id) =>
      switch state.openaiOAuthStatus {
      | Client__State__Types.OpenAIShowingCode({deviceAuthId: currentId}) => currentId != id
      | _ => true
      }
    | None => false
    }
    if isStale {
      state->StateReducer.update
    } else {
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIError(error),
        pendingProviderAutoSelect: None,
      }->StateReducer.update
    }

  | DisconnectOpenAIOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      state->StateReducer.update(
        ~sideEffects=[DisconnectOpenAIOAuthEffect({apiBaseUrl, requireAuthentication})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | OpenAIOAuthDisconnected =>
    {
      ...state,
      openaiOAuthStatus: Client__State__Types.OpenAINotConnected,
    }->StateReducer.update

  | ResetOpenAIOAuthError =>
    switch state.openaiOAuthStatus {
    | Client__State__Types.OpenAIError(_) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAINotConnected,
      }->StateReducer.update
    | _ => state->StateReducer.update
    }

  | SessionsLoadStarted =>
    {
      ...state,
      sessionsLoadState: Client__State__Types.SessionsLoading,
    }->StateReducer.update

  | SessionsLoadSuccess({sessions}) =>
    let previewUrl = getInitialUrl()
    let updatedTasks = state.tasks->Dict.copy

    sessions->Array.forEach(session => {
      if !(updatedTasks->Dict.has(session.sessionId)) {
        let createdAt = Date.fromString(session.createdAt)->Date.getTime
        let updatedAt = Date.fromString(session.updatedAt)->Date.getTime

        let task = Task.makeWithId(
          ~id=session.sessionId,
          ~title=session.title,
          ~previewUrl,
          ~createdAt,
          ~updatedAt,
        )
        updatedTasks->Dict.set(session.sessionId, task)
      }
    })

    let loadedState = {
      ...state,
      tasks: updatedTasks,
      sessionsLoadState: Client__State__Types.SessionsLoaded,
    }
    let resolvedState = loadedState->resolveFeedbackHistory
    resolvedState->StateReducer.update(
      ~sideEffects=firstTaskFeedbackTransitionEffects(
        loadedState.firstTaskFeedbackDialogState,
        resolvedState.firstTaskFeedbackDialogState,
      ),
    )

  | SessionsLoadError({error}) =>
    {
      ...state,
      sessionsLoadState: Client__State__Types.SessionsLoadError(error),
    }
    ->resolveFeedbackHistory
    ->StateReducer.update

  | CheckForUpdate({installedVersion, target}) =>
    switch (state.updateCheckStatus, state.acpSession) {
    | (UpdateNotChecked, AcpSessionActive({apiBaseUrl})) =>
      {
        ...state,
        updateCheckStatus: Client__State__Types.UpdateChecked,
      }->StateReducer.update(
        ~sideEffects=[CheckForUpdateEffect({apiBaseUrl, installedVersion, target})],
      )
    | _ => state->StateReducer.update
    }

  | UpdateInfoReceived({updateInfo}) =>
    {...state, updateInfo: Some(updateInfo)}->StateReducer.update

  | DismissUpdateBanner => {...state, updateBannerDismissed: true}->StateReducer.update

  | CloseFirstTaskFeedbackDialog =>
    switch state.firstTaskFeedbackDialogState {
    | Visible | LinkCopied | ShareFailed =>
      {...state, firstTaskFeedbackDialogState: Dismissed}->StateReducer.update(
        ~sideEffects=[TrackAnalyticsEffect(FirstTaskFeedbackDialogClosed)],
      )
    | Waiting | AwaitingHistory | Dismissed => state->StateReducer.update
    }

  | DismissFirstTaskFeedbackDialog =>
    {...state, firstTaskFeedbackDialogState: Dismissed}->StateReducer.update

  | ShareFrontman =>
    switch state.firstTaskFeedbackDialogState {
    | Visible | ShareFailed =>
      state->StateReducer.update(
        ~sideEffects=[TrackAnalyticsEffect(FirstTaskFeedbackShareClicked), ShareFrontmanEffect],
      )
    | Waiting | AwaitingHistory | LinkCopied | Dismissed => state->StateReducer.update
    }

  | ShareFrontmanLinkCopied =>
    switch state.firstTaskFeedbackDialogState {
    | Visible | ShareFailed =>
      {...state, firstTaskFeedbackDialogState: LinkCopied}->StateReducer.update
    | Waiting | AwaitingHistory | LinkCopied | Dismissed => state->StateReducer.update
    }

  | ShareFrontmanFailed =>
    switch state.firstTaskFeedbackDialogState {
    | Visible | ShareFailed =>
      {...state, firstTaskFeedbackDialogState: ShareFailed}->StateReducer.update
    | Waiting | AwaitingHistory | LinkCopied | Dismissed => state->StateReducer.update
    }

  | HighlightAnnotation({annotationId, selector}) =>
    let taskId = Selectors.currentTaskClientId(state)
    let highlighted = switch state.highlightedAnnotation {
    | Some(current) if current.taskId == taskId && current.annotationId == annotationId => None
    | Some(_) | None => Some({Client__State__Types.taskId, annotationId, selector})
    }
    {...state, highlightedAnnotation: highlighted}->StateReducer.update

  | FetchCustomProviders =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl, requireAuthentication}) =>
      state->StateReducer.update(
        ~sideEffects=[FetchCustomProvidersEffect({apiBaseUrl, requireAuthentication})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | CustomProvidersReceived({providers}) =>
    {...state, customProviders: Some(providers)}->StateReducer.update

  | SaveCustomProvider(draft) =>
    startCustomProviderMutation(state, SaveCustomProviderRequest(draft))

  | DeleteCustomProvider(id, lockVersion) =>
    startCustomProviderMutation(state, DeleteCustomProviderRequest({id, lockVersion}))

  | AcknowledgeCustomProviderMutation =>
    switch state.customProviderMutation {
    | CustomProviderMutationFailed({error: CustomProviderConflict(provider), _}) =>
      {
        ...applyCustomProvider(state, provider),
        customProviderMutation: CustomProviderMutationIdle,
      }->StateReducer.update
    | CustomProviderMutationSucceeded(_) | CustomProviderMutationFailed(_) =>
      {...state, customProviderMutation: CustomProviderMutationIdle}->StateReducer.update
    | CustomProviderMutationIdle | CustomProviderMutationPending(_) => state->StateReducer.update
    }

  | CustomProviderMutationSucceeded({operation, provider}) =>
    switch state.customProviderMutation {
    | CustomProviderMutationPending(pending) if pending == operation =>
      let state = switch operation {
      | SavingCustomProvider(_) =>
        let provider = provider->Option.getOrThrow
        applyCustomProvider(state, provider)
      | DeletingCustomProvider(id) =>
        let state = {
          ...state,
          customProviders: state.customProviders->Option.map(providers =>
            providers->Array.filter(provider => provider.id != id)
          ),
        }
        switch state.selectedModelValue {
        | Some(value) if value->String.startsWith(`custom:${id}:`) => clearSelectedModelValue(state)
        | _ => state
        }
      }
      {
        ...state,
        customProviderMutation: CustomProviderMutationSucceeded(operation),
      }->StateReducer.update
    | _ => state->StateReducer.update
    }

  | CustomProviderMutationFailed({operation, error}) =>
    switch state.customProviderMutation {
    | CustomProviderMutationPending(pending) if pending == operation =>
      {
        ...state,
        customProviderMutation: CustomProviderMutationFailed({operation, error}),
      }->StateReducer.update
    | _ => state->StateReducer.update
    }
  }
}
