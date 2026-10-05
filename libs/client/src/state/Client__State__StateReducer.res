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
module Connection = Client__ConnectionReducer

type taskTarget = CurrentTask | ForTask(string)

type apiKeyProvider = OpenRouter | Anthropic | Fireworks | Nvidia

type pendingPlanHandoff = {taskId: string, executorAgentId: string}

type promptInput = {
  content: array<UserContentPart.t>,
  annotationId: option<string>,
  onComplete: result<unit, string> => unit,
}

type rec action =
  | InitializeConnection(Connection.config)
  | ConnectionAction(Connection.action)
  | ConnectionEvent({signal: WebAPI.EventTypes.abortSignal, action: action})
  | SessionEvent({requestId: Connection.sessionRequestId, action: action})
  | AddUserMessage(promptInput)
  | PromptFailed({
      requestId: Connection.sessionRequestId,
      taskId: string,
      id: Message.UserMessageId.t,
      error: Connection.ACP.requestError,
    })
  | AcpSessionUpdateReceived({taskId: string, update: ACP.sessionUpdate})
  | TaskAction({target: taskTarget, action: TaskReducer.action})
  | CancelTurn
  | ExecutePendingPlan({id: Message.UserMessageId.t})
  | TaskLoadFinished({taskId: string, result: result<Connection.sessionRequestId, string>})
  | SwitchTask({taskId: string})
  | DeleteTask({taskId: string})
  | ClearCurrentTask
  | UpdateTaskTitle({taskId: string, title: string})
  | SetSettingsModalTab({tab: option<Client__State__Types.settingsTab>})
  | BillingStatusReceived(Client__Billing.status)
  | BillingStatusError({error: string})
  | RequestBilling(Client__Billing.request)
  | BillingUrlReceived({tab: WebAPI.Window.t, url: string})
  | BillingLaunchFailed({tab: option<WebAPI.Window.t>, error: string})
  | BillingAuthRequired({tab: option<WebAPI.Window.t>})
  | BillingRequestCancelled({tab: option<WebAPI.Window.t>})
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
  | CheckForUpdate({
      apiBaseUrl: string,
      installedVersion: string,
      target: Client__State__Types.updateTarget,
    })
  | UpdateInfoChecked(option<Client__State__Types.updateInfo>)
  | WordPressUpdatesChecked(option<Client__WordPressUpdates.response>)
  | DismissUpdateBanner
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
  | ConnectionEffect(Connection.effect)
  | CreateSession({taskId: string, input: promptInput})
  | SendMessage({taskId: string, submission: Client__State__Types.submission})
  | SubmissionCompleted({onComplete: result<unit, string> => unit, result: result<unit, string>})
  | AbortBillingRequest(option<WebAPI.EventTypes.abortController>)
  | FetchBillingStatus({signal: WebAPI.EventTypes.abortSignal, apiBaseUrl: string})
  | OpenBillingTabAndFetchUrl({
      signal: WebAPI.EventTypes.abortSignal,
      request: Client__Billing.request,
      apiBaseUrl: string,
    })
  | NavigateBillingTab({tab: WebAPI.Window.t, url: string})
  | CloseBillingTab(option<WebAPI.Window.t>)
  | RequireBillingAuthentication
  | BufferAssistantText({taskId: string, messageId: string, text: string, agentId: string})
  | BufferUserBlock({
      taskId: string,
      messageId: string,
      block: FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.t,
      agentId: string,
    })
  | FlushSessionActions(array<action>)
  | TaskEffect({target: taskTarget, effect: TaskReducer.effect})
  | FetchApiKeySettingsEffect({apiBaseUrl: string})
  | SaveApiKeyEffect({apiBaseUrl: string, provider: apiKeyProvider, key: string})
  | FetchAnthropicOAuthStatusEffect({apiBaseUrl: string})
  | GetAnthropicOAuthUrlEffect({apiBaseUrl: string})
  | ExchangeAnthropicOAuthCodeEffect({apiBaseUrl: string, code: string, verifier: string})
  | DisconnectAnthropicOAuthEffect({apiBaseUrl: string})
  | FetchOpenAIOAuthStatusEffect({apiBaseUrl: string})
  | InitiateOpenAIDeviceAuthEffect({apiBaseUrl: string})
  | DisconnectOpenAIOAuthEffect({apiBaseUrl: string})
  | PollOpenAIDeviceAuthEffect({apiBaseUrl: string, deviceAuthId: string, userCode: string})
  | FetchUserProfileEffect({apiBaseUrl: string})
  | CheckForUpdateEffect({
      apiBaseUrl: string,
      installedVersion: string,
      target: Client__State__Types.updateTarget,
    })
  | FetchCustomProvidersEffect({apiBaseUrl: string})
  | CustomProviderMutationEffect({apiBaseUrl: string, request: customProviderMutationRequest})

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
  connection: None,
  userProfile: None,
  settingsModalTab: None,
  billingStatus: Client__Billing.NotLoaded,
  billingFlow: Client__Billing.Idle,
  billingAbortController: None,
  billingStatusAbortController: None,
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
  wordpressUpdates: NotChecked,
  updateBannerDismissed: false,
  highlightedAnnotation: None,
}

module Selectors = {
  let getSession = (state: state) =>
    state.connection->Option.flatMap(Connection.Selectors.getSession)
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
    | Some({config, connection: Ok(Some({phase: Ready(_) | Reconnecting(_)}))}) =>
      Some(Connection.apiBaseUrlFromLoginUrl(config.acp.loginUrl))
    | _ => None
    }
  let hasActiveACPSession = (state: state) => apiBaseUrl(state)->Option.isSome
  let isSubmitting = (state: state) =>
    switch state.connection {
    | Some({
        connection: Ok(Some({phase: Ready({session: SessionCreating({sessionId: None})})})),
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
      apiBaseUrl(state),
      findAgent(plannerAgentName),
      findAgent(executorAgentName),
      TaskReducer.Selectors.completedIdleTurn(currentTask(state)),
    ) {
    | (Some(_), Some(planner), Some(executor), Some({taskId, agentId})) if agentId == planner.id =>
      Some({taskId, executorAgentId: executor.id})
    | _ => None
    }
  }

  let settingsModalTab = (state: state) => state.settingsModalTab
  let billingStatus = (state: state) => state.billingStatus
  let billingFlow = (state: state) => state.billingFlow
  let billingAccessAllowed = (state: state) => Client__Billing.accessAllowed(state.billingStatus)

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

let buildPrompt = (state: state, ~messageId, ~attachments, ~annotations, ~task, ~agentId) => {
  let runtimeConfig = Client__RuntimeConfig.read()
  let pageContextBlocks = Client__State__Types.taskToPageContextBlocks(
    task,
    ~isAstro=runtimeConfig.framework == Astro,
  )

  let annotationBlocks = Client__State__Types.messageAnnotationsToContentBlocks(annotations)

  let attachmentBlocks = buildAttachmentContentBlocks(attachments)
  let additionalBlocks =
    Array.concat(pageContextBlocks, annotationBlocks)->Array.concat(attachmentBlocks)

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
  (additionalBlocks, Some(JSON.Encode.object(metadata)))
}

let validatePrompt = FrontmanAiFrontmanClient.FrontmanClient__ACP__Protocol.validatePrompt

let validateSubmission = (state: state, submission: Client__State__Types.submission) => {
  let {id: messageId, content, annotations, agentId} = submission
  let text = TaskReducer.extractTextFromUserContent(content)
  let attachments = TaskReducer.extractAttachmentsFromUserContent(content)
  let (additionalBlocks, _meta) = buildPrompt(
    state,
    ~messageId,
    ~attachments,
    ~annotations,
    ~task=Selectors.currentTask(state),
    ~agentId,
  )
  switch state.selectedModelValue {
  | None => Error("Select a model before sending.")
  | Some(_) => validatePrompt(~text, ~additionalBlocks, ~_meta)
  }
}

let updateInfoForVersions = (~target, ~installedVersion, ~latestVersion): option<
  Client__State__Types.updateInfo,
> =>
  switch (Client__Semver.parse(installedVersion), Client__Semver.parse(latestVersion)) {
  | (Some(installed), Some(latest)) if Client__Semver.isBehind(installed, latest) =>
    Some({target, installedVersion, latestVersion})
  | _ => None
  }

let targetIsCurrent = (state: state, target: taskTarget): bool =>
  switch target {
  | CurrentTask => true
  | ForTask(taskId) => Selectors.currentTaskId(state) == Some(taskId)
  }

let addUserMessageToState = (
  state: state,
  ~sessionId,
  submission: Client__State__Types.submission,
) => {
  let {id, content, annotations, agentId} = submission
  let handoff = Selectors.pendingPlanHandoff(state)->Option.isSome
  let (state, taskId) = switch state.currentTask {
  | Task.New(task) =>
    let tasks = state.tasks->Dict.copy
    tasks->Dict.set(
      sessionId,
      Task.newToLoaded(task, ~id=sessionId, ~title=TaskReducer.extractTextFromUserContent(content)),
    )
    ({...state, tasks, currentTask: Task.Selected(sessionId)}, sessionId)
  | Task.Selected(taskId) => (state, taskId)
  }
  let (state, effects) =
    state->Lens.delegateToTask(
      ForTask(taskId),
      TaskReducer.AddUserMessage({id, content, annotations, agentId}),
    )
  let (state, runningEffects) = switch handoff {
  | true => state->Lens.delegateToTask(ForTask(taskId), TaskReducer.ExecutionStateRunning)
  | false => (state, [])
  }
  state->StateReducer.update(
    ~sideEffects=Array.concat(effects, runningEffects)->Array.concat([
      SendMessage({taskId, submission}),
    ]),
  )
}

let requireEmbeddedAuthentication = dispatch => {
  Client__EmbeddedAuth.clearToken()
  dispatch(ConnectionAction(RequireAuthentication))
}

let embeddedAuthRequiredError = "Frontman authorization is required"

type billingRequestError = Unauthorized | Cancelled | RequestFailed(string)

let fetchBilling = async (
  ~request,
  ~apiBaseUrl,
  ~signal: WebAPI.EventTypes.abortSignal,
  ~schema,
  ~onResult,
) => {
  let token = Client__EmbeddedAuth.loadToken()
  let isCurrent = () => !signal.aborted && token === Client__EmbeddedAuth.loadToken()
  switch Client__EmbeddedAuth.jsonHeaders() {
  | None => Unauthorized->Error->onResult
  | Some(headers) =>
    try {
      let body = switch request {
      | Client__Billing.Checkout(interval) =>
        {Client__Billing.interval: interval}
        ->S.decodeOrThrow(
          ~from=Client__Billing.checkoutRequestSchema,
          ~to=S.json->S.noValidation(true),
        )
        ->JSON.stringify
        ->WebAPI.BodyInit.fromString
        ->Some
      | Status | CustomerPortal => None
      }
      let response = await `${apiBaseUrl}${Client__Billing.requestPath(
          request,
        )}`->WebAPI.Fetch.fetch(
        ~init={
          method: switch request {
          | Status => "GET"
          | _ => "POST"
          },
          headers,
          credentials: Omit,
          cache: NoStore,
          ?body,
          signal: [signal, WebAPI.AbortSignal.timeout(30000)]->WebAPI.AbortSignal.any->Null.make,
        },
      )
      let json = await response->WebAPI.Response.json
      switch (isCurrent(), response.status, response.ok) {
      | (false, _, _) => Error(Cancelled)
      | (true, 401, _) => Error(Unauthorized)
      | (true, _, false) =>
        let error = json->S.parseOrThrow(~to=Client__Billing.errorResponseSchema)
        switch error.requestId {
        | Some(id) => `${error.error} Request reference: ${id}`
        | None => error.error
        }
        ->RequestFailed
        ->Error
      | (true, _, true) => json->S.parseOrThrow(~to=schema)->Ok
      }->onResult
    } catch {
    | exn =>
      switch isCurrent() {
      | false => Cancelled
      | true =>
        Log.error(~error=JsExn.fromException(exn), "Billing request failed")
        RequestFailed("Could not contact billing. Please try again.")
      }
      ->Error
      ->onResult
    }
  }
}

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

let fetchCustomProvidersImpl = (dispatch, ~apiBaseUrl) => {
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
          | 401 => dispatch(ConnectionAction(RequireAuthentication))
          | _ =>
            Log.error(
              `Custom Provider request failed: HTTP ${response.status->Int.toString}: ${response.statusText}`,
            )
          }
        }
      | None => dispatch(ConnectionAction(RequireAuthentication))
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

let dispatchCustomProviderAuthRequired = (dispatch, ~operation) => {
  dispatch(ConnectionAction(RequireAuthentication))
  dispatch(
    CustomProviderMutationFailed({
      operation,
      error: Client__State__Types.CustomProviderNetworkError(embeddedAuthRequiredError),
    }),
  )
}

let handleCustomProviderMutationError = async (dispatch, response, ~operation) =>
  switch response.WebAPI.Response.status {
  | 401 => dispatchCustomProviderAuthRequired(dispatch, ~operation)
  | _ =>
    let json = await response->WebAPI.Response.json
    dispatch(
      CustomProviderMutationFailed({
        operation,
        error: decodeCustomProviderMutationError(~status=response.status, ~json),
      }),
    )
  }

let customProviderMutationImpl = (dispatch, ~apiBaseUrl, ~request) => {
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
          | false => await handleCustomProviderMutationError(dispatch, response, ~operation)
          }
        | None => dispatchCustomProviderAuthRequired(dispatch, ~operation)
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
          | false => await handleCustomProviderMutationError(dispatch, response, ~operation)
          }
        | None => dispatchCustomProviderAuthRequired(dispatch, ~operation)
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

let getSessionTextBuffer = dispatch =>
  switch Client__TextDeltaBuffer.active.contents {
  | Some(buffer) => buffer
  | None =>
    let dispatchTask = (taskId, action) => dispatch(TaskAction({target: ForTask(taskId), action}))
    let buffer = Client__TextDeltaBuffer.make(
      ~onFlush=(~taskId, ~messageId, ~text, ~agentId) =>
        dispatchTask(taskId, TextDeltaReceived({messageId, text, agentId})),
      ~onUserFlush=(~taskId, ~messageId, ~blocks, ~agentId) => {
        let (content, annotations) = Client__ACP__MessageCodec.parseUserMessageBlocks(blocks)
        dispatchTask(taskId, UserMessageReceived({id: messageId, content, annotations, agentId}))
      },
    )
    Client__TextDeltaBuffer.active := Some(buffer)
    buffer
  }

module ConnectionEffects = {
  type appAction = action
  open! Client__ConnectionReducer
  let relayFailureReason = message =>
    switch message {
    | message if message->String.startsWith("HTTP ") => Client__Analytics.HttpError
    | message if message->String.startsWith("Invalid tools response: ") =>
      Client__Analytics.InvalidResponse
    | _ => Client__Analytics.NetworkError
    }

  let revokeEmbeddedClientToken = async (
    ~apiBaseUrl: string,
    ~signal: WebAPI.EventTypes.abortSignal,
  ) => {
    switch Client__EmbeddedAuth.headers() {
    | Some(headers) =>
      try {
        let response = await WebAPI.Fetch.fetch(
          `${apiBaseUrl}/api/client-token`,
          ~init={method: "DELETE", headers, signal: Null.make(signal)},
        )
        switch response.status {
        | 204 | 401 => ()
        | status => Log.error(`Embedded token revocation failed: HTTP ${status->Int.toString}`)
        }
      } catch {
      | exn =>
        switch exn->JsExn.fromException->Option.map(FrontmanBindings.JsException.name) {
        | Some("AbortError") | Some("TypeError") => ()
        | _ => throw(exn)
        }
      }
    | None => ()
    }
    Client__EmbeddedAuth.clearToken()
    WebAPI.Window.current->WebAPI.Window.location->WebAPI.Location.reload
  }

  let connectRuntime = async (
    ~config: config,
    ~signal: WebAPI.EventTypes.abortSignal,
    ~onReconnecting,
    ~onReconnect,
  ): result<readyState, connectError> => {
    let attempt = WebAPI.AbortController.make()
    let attemptSignal = WebAPI.AbortSignal.any([signal, attempt.signal])
    let failure = ref(None)
    let connection = ref(None)
    let relay = ref(None)
    let fail = error => {
      switch failure.contents {
      | None => failure := Some(error)
      | Some(_) => ()
      }
      WebAPI.AbortController.abort(attempt)
    }
    let release = () => {
      connection.contents->Option.forEach(conn => ACP.disconnect(conn))
      connection := None
    }
    let acpError = error =>
      switch error {
      | ACP.AuthRequired({loginUrl}) =>
        let framework = config.acp.clientInfo._meta->Option.flatMap(frameworkFromClientInfoMeta)
        AuthenticationRequired({loginUrl: enrichLoginUrl(~loginUrl, ~framework)})
      | ACP.ConnectionFailed(message) => ConnectionFailed(ACPError(message))
      }
    let validateConnection = result =>
      result
      ->Result.mapError(acpError)
      ->Result.flatMap(conn =>
        switch (ACP.isInitialized(conn), ACP.getAgentAttributionConfiguration(conn)) {
        | (false, _) | (true, Some(_)) => Ok(conn)
        | (true, None) =>
          Error(ConnectionFailed(ACPError("Frontman requires agent attribution v1")))
        }
      )
    let connectACP = async () => {
      let result = await ACP.connect(
        config.acp,
        ~signal=attemptSignal,
        ~onConnectionCreated=conn => connection := Some(conn),
        ~onReconnecting,
        ~onReconnect=result => {
          let result = validateConnection(result)
          switch result {
          | Error(error) => fail(error)
          | Ok(_) => ()
          }
          onReconnect(result)
        },
      )
      switch validateConnection(result) {
      | Ok(conn) =>
        switch attemptSignal.aborted {
        | true =>
          ACP.disconnect(conn)
          connection := None
        | false => ()
        }
      | Error(error) => fail(error)
      }
    }
    let connectRelay = async () => {
      let result = await Relay.connect(config.relay, ~signal=attemptSignal)
      switch attemptSignal.aborted {
      | true => ()
      | false =>
        switch result {
        | Ok(connected) =>
          relay := Some(connected)
          Client__Analytics.track(RelayConnectionCompleted(Success))
        | Error(message) =>
          Client__Analytics.track(RelayConnectionCompleted(Failure(relayFailureReason(message))))
          fail(ConnectionFailed(RelayError(message)))
        }
      }
    }
    try {
      let _ = await Promise.all([connectACP(), connectRelay()])
      switch (signal.aborted, failure.contents) {
      | (true, _) =>
        release()
        Error(ConnectionFailed(ACPError("Connection aborted")))
      | (false, Some(error)) =>
        release()
        Error(error)
      | (false, None) =>
        let relay = relay.contents->Option.getOrThrow
        Ok({
          connection: connection.contents->Option.getOrThrow,
          relay,
          mcpServer: MCPServer.make(config.mcp, ~relay),
          session: NoSession,
        })
      }
    } catch {
    | exn =>
      WebAPI.AbortController.abort(attempt)
      release()
      throw(exn)
    }
  }

  let billingRequestErrorMessage = (error, dispatchApp: appAction => unit) => {
    switch ACP.requestErrorIsBillingInactive(error) {
    | true => dispatchApp(SetSettingsModalTab({tab: Some(Billing)}))
    | false => ()
    }
    ACP.requestErrorMessage(error)
  }

  let rec handleEffect = (
    effect: effect,
    state: state,
    dispatch: action => unit,
    ~dispatchApp: appAction => unit,
  ) => {
    let activateSession = async (~requestId, ~sessionId, activate) => {
      switch isCurrentSessionRequest(state, requestId) {
      | false => ()
      | true =>
        let pending = ref(true)
        let creationError = ref(None)
        let result = await activate(
          (sessionId, update) =>
            dispatchApp(
              SessionEvent({
                requestId,
                action: AcpSessionUpdateReceived({taskId: sessionId, update}),
              }),
            ),
          (sessionId, title) =>
            dispatchApp(
              SessionEvent({requestId, action: UpdateTaskTitle({taskId: sessionId, title})}),
            ),
          error =>
            switch pending.contents {
            | true => creationError := Some(error)
            | false =>
              dispatch(
                SessionResultReceived({
                  requestId,
                  sessionId,
                  result: Error(ACP.requestErrorFromMessage(error)),
                }),
              )
            },
        )
        let result = result->Result.flatMap(((session, configOptions)) =>
          switch creationError.contents {
          | Some(error) =>
            ACP.cleanupSessionChannel(session)
            Error(ACP.requestErrorFromMessage(error))
          | None => Ok((session, configOptions))
          }
        )
        pending := false
        dispatch(SessionResultReceived({requestId, sessionId, result}))
      }
    }

    switch effect {
    | LogError(msg) => Log.error(msg)
    | LogInfo(msg) => Log.info(msg)
    | NotifyRequestRejected(notify) => notify()
    | SessionCompletionEffect({sessionId, ready, result, onComplete}) =>
      let complete = result =>
        switch (onComplete, result) {
        | (Some(onComplete), _) => onComplete(result)
        | (None, Ok(_)) =>
          Client__TextDeltaBuffer.flush()
          switch ready.session {
          | SessionActive({requestId}) =>
            dispatchApp(TaskLoadFinished({taskId: sessionId, result: Ok(requestId)}))
          | _ => failwith("Loaded session must be active")
          }
        | (None, Error(error)) =>
          dispatchApp(TaskLoadFinished({taskId: sessionId, result: Error(error)}))
        }
      switch state.connection {
      | Ok(Some({phase: Ready(current), lifetimeAbortController}))
        if current === ready &&
        !lifetimeAbortController.signal.aborted &&
        ACP.isInitialized(current.connection) =>
        switch result {
        | Ok(_) => complete(Ok(sessionId))
        | Error(error) =>
          Client__TextDeltaBuffer.discardTask(sessionId)
          complete(Error(billingRequestErrorMessage(error, dispatchApp)))
        }
      | Ok(Some({phase: Ready(current) | Reconnecting(current)}))
        if current.session === ready.session =>
        complete(Error("Connection changed before submission completed; send again when ready"))
      | Ok(_) | Error(_) => complete(Error("Conversation changed. Your message was not sent."))
      }
    | TaskLoadFailed({taskId, error}) =>
      dispatchApp(TaskLoadFinished({taskId, result: Error(error)}))
    | CleanupEffect(runtime) =>
      WebAPI.AbortController.abort(runtime.lifetimeAbortController)
      switch runtime.phase {
      | Ready({connection, session}) | Reconnecting({connection, session}) =>
        ACP.disconnect(connection)
        releaseSession(session)->Array.forEach(effect =>
          handleEffect(effect, state, dispatch, ~dispatchApp)
        )
      | _ => ()
      }
    | CleanupConnectionEffect(connection) => ACP.disconnect(connection)
    | ConnectRuntime({config, signal}) =>
      let connect = async () => {
        let result = await connectRuntime(
          ~config,
          ~signal,
          ~onReconnecting=() => dispatch(ACPReconnecting({signal: signal})),
          ~onReconnect=result => dispatch(ACPReconnected({signal, result})),
        )
        switch (signal.aborted, result) {
        | (true, Ok(ready)) => ACP.disconnect(ready.connection)
        | (true, Error(_)) => ()
        | (false, _) => dispatch(ConnectionResultReceived({signal, result}))
        }
      }
      connect()->ignore
    | ScheduleAuthRetry({signal}) =>
      let _ = WebAPI.Window.setTimeout(WebAPI.Window.current, ~timeout=2000, ~handler=() => {
        switch signal.aborted {
        | true => ()
        | false => dispatch(RetryAuthentication)
        }
      })
    | LogoutEffect({apiBaseUrl, signal}) => revokeEmbeddedClientToken(~apiBaseUrl, ~signal)->ignore
    | SessionCommandEffect({session, command}) => ACP.sendSessionCommand(session, command)
    | FetchSessionsEffect({connection, signal}) =>
      let fetch = async () => {
        let {agents, defaultAgentId} =
          ACP.getAgentAttributionConfiguration(connection)->Option.getOrThrow
        dispatchApp(AgentAttributionConfigured({agentCatalog: agents, defaultAgentId}))
        dispatchApp(SessionsLoadStarted)
        let result = await ACP.listSessions(connection)
        dispatchApp(
          ConnectionEvent({
            signal,
            action: switch result {
            | Ok(sessions) => SessionsLoadSuccess({sessions: sessions})
            | Error(error) => SessionsLoadError({error: error})
            },
          }),
        )
      }
      switch isCurrentConnection(state, signal) {
      | true => fetch()->ignore
      | false => ()
      }
    | ActivateSessionEffect({requestId, connection, mcpServer, operation}) =>
      let sessionId = switch operation {
      | #load(sessionId) | #join(sessionId) | #create(sessionId) => sessionId
      }
      activateSession(~requestId, ~sessionId, async (onUpdate, onTitleUpdated, onParseError) => {
        let mcpServerInterface = MCPServer.toInterface(mcpServer)
        switch operation {
        | #create(_) =>
          let result = await ACP.createSession(
            connection,
            ~sessionId,
            ~onUpdate,
            ~onTitleUpdated,
            ~onParseError,
            ~mcpServerInterface,
          )
          result->Result.map(((session, result)) => (session, result.configOptions))
        | #load(_) =>
          let result = await ACP.loadSession(
            connection,
            sessionId,
            ~onLoadResult=_ => (),
            ~onUpdate,
            ~onTitleUpdated,
            ~onParseError,
            ~mcpServerInterface,
          )
          result
          ->Result.map(((session, result)) => (session, result.configOptions))
          ->Result.mapError(ACP.requestErrorFromMessage)
        | #join(_) =>
          let result = await ACP.joinSession(
            connection,
            sessionId,
            ~onUpdate=ACP.validatedUpdateHandler(connection, sessionId, onUpdate),
            ~onTitleUpdated,
            ~onParseError,
            ~mcpServerInterface,
          )
          result
          ->Result.map(session => (session, None))
          ->Result.mapError(ACP.requestErrorFromMessage)
        }
      })->ignore
    | DeleteSessionEffect({signal, connection, taskId}) =>
      let delete = async () => {
        switch await ACP.deleteSession(connection, taskId) {
        | Ok() => Log.info(~ctx={"taskId": taskId}, "Session deleted")
        | Error(error) =>
          Log.error(~ctx={"taskId": taskId, "error": error}, "Failed to delete session")
        }
      }
      switch isCurrentConnection(state, signal) {
      | true => delete()->ignore
      | false => ()
      }
    | CleanupSessionEffect({session}) =>
      ACP.cleanupSessionChannel(session)
      Log.debug(~ctx={"sessionId": session.sessionId}, "Cleaned up session channel")
    }
  }
}

let handleEffect = (effect, state: state, dispatch: action => unit) => {
  switch effect {
  | BufferAssistantText({taskId, messageId, text, agentId}) =>
    getSessionTextBuffer(dispatch).add(~taskId, ~messageId, ~text, ~agentId)
  | BufferUserBlock({taskId, messageId, block, agentId}) =>
    getSessionTextBuffer(dispatch).addUserBlock(~taskId, ~messageId, ~block, ~agentId)
  | FlushSessionActions(actions) =>
    Client__TextDeltaBuffer.flush()
    actions->Array.forEach(action => dispatch(action))
  | AbortBillingRequest(controller) =>
    controller->Option.forEach(controller => WebAPI.AbortController.abort(controller))
  | FetchBillingStatus({apiBaseUrl, signal}) =>
    fetchBilling(
      ~request=Status,
      ~apiBaseUrl,
      ~signal,
      ~schema=Client__Billing.statusSchema,
      ~onResult=result => {
        switch result {
        | Ok(status) => dispatch(BillingStatusReceived(status))
        | Error(RequestFailed(error)) => dispatch(BillingStatusError({error: error}))
        | Error(Unauthorized) => dispatch(BillingAuthRequired({tab: None}))
        | Error(Cancelled) => ()
        }
      },
    )->ignore
  | OpenBillingTabAndFetchUrl({request, apiBaseUrl, signal}) =>
    switch Client__EmbeddedAuth.loadToken() {
    | None => dispatch(BillingAuthRequired({tab: None}))
    | Some(_) =>
      switch Client__HostNavigation.openManagedTab(~url="about:blank") {
      | None => dispatch(BillingLaunchFailed({tab: None, error: "Allow popups, then try again."}))
      | Some(tab) =>
        fetchBilling(
          ~request,
          ~apiBaseUrl,
          ~signal,
          ~schema=Client__Billing.urlResponseSchema,
          ~onResult=result => {
            switch result {
            | Ok({url}) =>
              switch WebAPI.URL.make(~url).protocol {
              | "https:" => dispatch(BillingUrlReceived({tab, url}))
              | _ => failwith("Invalid Stripe URL")
              }
            | Error(RequestFailed(error)) => dispatch(BillingLaunchFailed({tab: Some(tab), error}))
            | Error(Unauthorized) => dispatch(BillingAuthRequired({tab: Some(tab)}))
            | Error(Cancelled) => dispatch(BillingRequestCancelled({tab: Some(tab)}))
            }
          },
        )->ignore
      }
    }
  | CloseBillingTab(tab) => tab->Option.forEach(WebAPI.Window.close)
  | RequireBillingAuthentication => requireEmbeddedAuthentication(dispatch)
  | NavigateBillingTab({tab, url}) =>
    try {
      switch WebAPI.Window.closed(tab) {
      | true =>
        dispatch(
          BillingLaunchFailed({tab: Some(tab), error: "Stripe tab was closed. Please try again."}),
        )
      | false => tab->WebAPI.Window.location->WebAPI.Location.assign(url)
      }
    } catch {
    | exn =>
      Log.error(~error=JsExn.fromException(exn), "Billing navigation failed")
      dispatch(
        BillingLaunchFailed({tab: Some(tab), error: "Could not open Stripe. Please try again."}),
      )
    }
  | FetchUserProfileEffect({apiBaseUrl}) => fetchUserProfileImpl(dispatch, ~apiBaseUrl)
  | SubmissionCompleted({onComplete, result}) => onComplete(result)
  | ConnectionEffect(effect) =>
    ConnectionEffects.handleEffect(
      effect,
      state.connection->Option.getOrThrow,
      action => dispatch(ConnectionAction(action)),
      ~dispatchApp=dispatch,
    )
  | CreateSession({taskId, input}) =>
    dispatch(
      ConnectionAction(
        CreateSession({
          sessionId: taskId,
          onComplete: result =>
            switch result {
            | Ok(_) => dispatch(AddUserMessage(input))
            | Error(error) => input.onComplete(Error(error))
            },
        }),
      ),
    )
  | SendMessage({taskId, submission: {id, content, annotations, agentId, onComplete}}) =>
    let text = TaskReducer.extractTextFromUserContent(content)
    let attachments = TaskReducer.extractAttachmentsFromUserContent(content)
    let (additionalBlocks, _meta) = buildPrompt(
      state,
      ~messageId=id,
      ~attachments,
      ~annotations,
      ~task=state.tasks->Dict.get(taskId)->Option.getOrThrow,
      ~agentId,
    )
    let result = switch validatePrompt(~text, ~additionalBlocks, ~_meta) {
    | Error(error) => Error(error)
    | Ok() =>
      switch state.connection {
      | Some(
          {
            connection: Ok(Some({phase: Ready({session: SessionActive({session, requestId})})})),
          } as connection,
        )
        if session.sessionId == taskId &&
          Connection.isCurrentSessionRequest(connection, requestId) =>
        let fail = error => dispatch(PromptFailed({requestId, taskId, id, error}))
        let send = async () => {
          try {
            switch await Connection.ACP.sendPrompt(session, text, ~additionalBlocks, ~_meta) {
            | Ok(_) => ()
            | Error(error) => fail(error)
            }
          } catch {
          | exn =>
            fail(Connection.ACP.requestErrorFromMessage("sendPrompt exception"))
            throw(exn)
          }
        }
        send()->ignore
        Ok()
      | _ => Error("Cannot send message: no active ACP session")
      }
    }
    switch result {
    | Error(error) =>
      dispatch(TaskAction({target: ForTask(taskId), action: UserMessageSendFailed({id, error})}))
    | Ok() => ()
    }
    onComplete(result)
  | TaskEffect({target, effect: taskEffect}) => {
      let taskDispatch = (taskAction: TaskReducer.action) => {
        dispatch(TaskAction({target, action: taskAction}))
      }

      let delegate = (delegated: TaskReducer.delegated) => {
        switch delegated {
        | NeedSessionCommand(command) => dispatch(ConnectionAction(SessionCommand(command)))
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
  | FetchAnthropicOAuthStatusEffect({apiBaseUrl}) =>
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
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ => ()
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to fetch OAuth status"}))
      }
    }
    fetch()->ignore

  | GetAnthropicOAuthUrlEffect({apiBaseUrl}) =>
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
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ => dispatch(AnthropicOAuthError({error: "Failed to get authorization URL"}))
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to get authorization URL"}))
      }
    }
    fetch()->ignore

  | ExchangeAnthropicOAuthCodeEffect({apiBaseUrl, code, verifier}) =>
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
            | 401 => requireEmbeddedAuthentication(dispatch)
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
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to exchange authorization code"}))
      }
    }
    exchange()->ignore

  | DisconnectAnthropicOAuthEffect({apiBaseUrl}) =>
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
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ => dispatch(AnthropicOAuthError({error: "Failed to disconnect"}))
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ => dispatch(AnthropicOAuthError({error: "Failed to disconnect"}))
      }
    }
    disconnect()->ignore

  | FetchOpenAIOAuthStatusEffect({apiBaseUrl}) =>
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
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ => ()
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ =>
        dispatch(
          OpenAIOAuthError({deviceAuthId: None, error: "Failed to fetch OpenAI OAuth status"}),
        )
      }
    }
    fetch()->ignore

  | InitiateOpenAIDeviceAuthEffect({apiBaseUrl}) =>
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
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ =>
              dispatch(
                OpenAIOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}),
              )
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ =>
        dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}))
      }
    }
    fetch()->ignore

  | PollOpenAIDeviceAuthEffect({apiBaseUrl, deviceAuthId, userCode}) =>
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
              | (false, 401) => requireEmbeddedAuthentication(dispatch)
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
            | None => requireEmbeddedAuthentication(dispatch)
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

  | DisconnectOpenAIOAuthEffect({apiBaseUrl}) =>
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
            | 401 => requireEmbeddedAuthentication(dispatch)
            | _ => dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
            }
          }
        | None => requireEmbeddedAuthentication(dispatch)
        }
      } catch {
      | _ => dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
      }
    }
    disconnect()->ignore

  | CheckForUpdateEffect({apiBaseUrl, installedVersion, target}) =>
    let fetch = async () => {
      try {
        let url = switch target {
        | NpmPackage(_) => `${apiBaseUrl}/api/integrations/latest-versions`
        | WordPressPlugin => `${Client__RelayBaseUrl.current()}/frontman/plugin-update`
        }
        let response = await WebAPI.Fetch.fetch(url)
        switch (target, response.status, response.ok) {
        | (WordPressPlugin, 404, _) => dispatch(WordPressUpdatesChecked(None))
        | (_, _, false) =>
          Sentry.captureConnectionError(
            `CheckForUpdate: HTTP ${response.status->Int.toString} ${response.statusText}`,
            ~endpoint=url,
          )
        | (_, _, true) =>
          let json = await response->WebAPI.Response.json
          switch target {
          | WordPressPlugin =>
            let data =
              json->S.decodeOrThrow(~from=S.json, ~to=Client__WordPressUpdates.responseSchema)
            dispatch(WordPressUpdatesChecked(Some(data)))
          | NpmPackage(npmPackage) =>
            let {versions} =
              json->S.decodeOrThrow(
                ~from=S.json,
                ~to=Client__State__Types.latestVersionsResponseSchema,
              )
            switch versions->Dict.get(npmPackage)->Option.flatMap(version => version) {
            | Some(latestVersion) =>
              dispatch(
                UpdateInfoChecked(
                  updateInfoForVersions(~target, ~installedVersion, ~latestVersion),
                ),
              )
            | None =>
              Sentry.captureConnectionError(
                `CheckForUpdate: package "${npmPackage}" not found or null in registry response`,
                ~endpoint=url,
              )
            }
          }
        }
      } catch {
      | exn => Sentry.captureException(exn, ~operation="CheckForUpdate")
      }
    }
    fetch()->ignore
  | FetchCustomProvidersEffect({apiBaseUrl}) => fetchCustomProvidersImpl(dispatch, ~apiBaseUrl)
  | CustomProviderMutationEffect({apiBaseUrl, request}) =>
    customProviderMutationImpl(dispatch, ~apiBaseUrl, ~request)
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
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        customProviderMutation: CustomProviderMutationPending(operation),
      }->StateReducer.update(~sideEffects=[CustomProviderMutationEffect({apiBaseUrl, request})])
    | None =>
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

let clearConnectionState = (state: state) => {
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
    billingStatus: Client__Billing.NotLoaded,
    billingFlow: Client__Billing.Idle,
    billingAbortController: None,
    billingStatusAbortController: None,
    settingsModalTab: None,
  }->StateReducer.update(
    ~sideEffects=[
      AbortBillingRequest(state.billingAbortController),
      AbortBillingRequest(state.billingStatusAbortController),
    ],
  )
}

let rec next = (state: state, action) => {
  switch action {
  | InitializeConnection(config) =>
    next(
      {...state, connection: Some(Connection.initialState(config))},
      ConnectionAction(Initialize),
    )
  | ConnectionEvent({signal, action}) =>
    switch state.connection {
    | Some(connection) if Connection.isCurrentConnection(connection, signal) => next(state, action)
    | _ => state->StateReducer.update
    }
  | SessionEvent({requestId, action}) =>
    switch state.connection {
    | Some(connection) if Connection.isCurrentSessionRequest(connection, requestId) =>
      next(state, action)
    | _ => state->StateReducer.update
    }
  | ConnectionAction(LoadTask({taskId})) if state.connection->Option.isNone =>
    next(state, TaskLoadFinished({taskId, result: Error("No active ACP session")}))
  | ConnectionAction(action) =>
    let (updated, effects) = switch state.connection {
    | None => (state, [])
    | Some(previous) =>
      let (connection, effects) = Connection.next(previous, action)
      let updated = {...state, connection: Some(connection)}
      let (updated, configEffects) = switch action {
      | SessionResultReceived({result: Ok((_, Some(configOptions)))}) if connection !== previous =>
        next(updated, ConfigOptionsReceived({configOptions: configOptions}))
      | _ => (updated, [])
      }
      (updated, Array.concat(configEffects, effects->Array.map(effect => ConnectionEffect(effect))))
    }
    switch (
      action,
      Selectors.hasActiveACPSession(state) && !Selectors.hasActiveACPSession(updated),
    ) {
    | (Dispose, _) | (_, true) =>
      let (updated, cleanupEffects) = clearConnectionState(updated)
      updated->StateReducer.update(~sideEffects=Array.concat(effects, cleanupEffects))
    | _ => updated->StateReducer.update(~sideEffects=effects)
    }
  | TaskAction({
    action:
      SetAnnotationMode(_)
      | ToggleAnnotationMode
      | ToggleAnnotation(_)
      | AddAnnotation(_)
      | AddAnnotations(_)
      | RemoveAnnotation(_)
      | ClearAnnotations
      | SetActivePopupAnnotationId(_)
      | UpdateAnnotationComment(_),
  })
  | SetSelectedAgentId(_)
  | SetSelectedModelValue(_)
  | ExecutePendingPlan(_) if Selectors.isSubmitting(state) =>
    state->StateReducer.update
  | AcpSessionUpdateReceived({taskId, update}) =>
    let task = action => TaskAction({target: ForTask(taskId), action})
    let flush = actions => state->StateReducer.update(~sideEffect=FlushSessionActions(actions))
    switch update {
    | AgentMessageChunk({messageId, content: TextContent({text}), _meta: {agentId}}) =>
      state->StateReducer.update(
        ~sideEffect=BufferAssistantText({taskId, messageId, text, agentId}),
      )
    | UserMessageChunk({messageId, content, _meta: {agentId}}) =>
      state->StateReducer.update(
        ~sideEffect=BufferUserBlock({taskId, messageId, block: content, agentId}),
      )
    | GenericAgentMessageChunk(_) | GenericUserMessageChunk(_) =>
      failwith("Frontman UI requires negotiated agent attribution")
    | AgentMessageChunk(_) | Unknown(_) => state->StateReducer.update
    | MessageUnqueued({messageId}) =>
      state->Lens.delegateToTask(
        ForTask(taskId),
        TaskReducer.MessageUnqueued({messageId: messageId}),
      )
    | ToolCall({
        toolCallId,
        title,
        status,
        content,
        rawInput,
        rawOutput,
        parentAgentId,
        spawningToolName,
      }) =>
      let toolCall = Client__ACP__MessageCodec.makeToolCall(
        ~id=toolCallId,
        ~title,
        ~status,
        ~content,
        ~rawInput,
        ~rawOutput,
        ~parentAgentId,
        ~spawningToolName,
      )
      flush([task(ToolCallReceived({toolCall: toolCall}))])
    | ToolCallUpdate({toolCallId, status, content, rawInput, rawOutput}) =>
      let input = rawInput->Option.map(input => task(ToolInputReceived({id: toolCallId, input})))
      let result = switch (rawOutput, content, status) {
      | (None, None, None | Some(Pending | InProgress | Failed)) => None
      | _ =>
        Some(
          task(
            ToolResultReceived({
              id: toolCallId,
              rawOutput,
              content,
              complete: status == Some(Completed),
            }),
          ),
        )
      }
      let error = switch status {
      | Some(Failed) =>
        let error =
          content
          ->Option.flatMap(items =>
            items->Array.findMap(item =>
              switch item {
              | Content({content: TextContent({text})}) => Some(text)
              | _ => None
              }
            )
          )
          ->Option.getOr("Unknown error")
        Some(task(ToolErrorReceived({id: toolCallId, error})))
      | Some(Pending | Completed | InProgress) | None => None
      }
      flush([input, result, error]->Array.filterMap(value => value))
    | Plan({entries}) => flush([task(PlanReceived({entries: entries}))])
    | StateUpdate({state: executionState}) =>
      let action = switch executionState {
      | Running => TaskReducer.ExecutionStateRunning
      | Idle => TaskReducer.ExecutionStateIdle
      | RequiresAction => TaskReducer.ExecutionStateRequiresAction
      }
      flush([task(action)])
    | ConfigOptionUpdate({configOptions}) =>
      flush([ConfigOptionsReceived({configOptions: configOptions})])
    | CurrentModeUpdate(_) => flush([])
    | Error({_meta, message, retryAt, attempt, maxAttempts, category}) =>
      let settings = switch category {
      | Some("billing") => [SetSettingsModalTab({tab: Some(Providers)})]
      | Some(_) | None => []
      }
      let action = switch retryAt {
      | Some(retryAt) =>
        TaskReducer.RetryingUpdate({
          retryStatus: {
            attempt: attempt->Option.getOr(1),
            maxAttempts: maxAttempts->Option.getOr(5),
            retryAt: Date.fromString(retryAt)->Date.getTime,
            error: message,
          },
        })
      | None =>
        TaskReducer.AgentError({
          id: Client__ACP__MessageCodec.agentErrorId(_meta),
          error: message,
          category: Client__ErrorCategory.fromAcpCategory(category),
        })
      }
      flush([...settings, task(action)])
    }
  | TaskAction({target, action: taskAction}) => state->Lens.delegateToTask(target, taskAction)

  | PromptFailed({requestId, taskId, id, error}) =>
    let failed = (state, error) =>
      state->Lens.delegateToTask(ForTask(taskId), UserMessageSendFailed({id, error}))
    switch state.connection {
    | Some(connection) if Connection.isCurrentSessionRequest(connection, requestId) =>
      let state = switch Connection.ACP.requestErrorIsBillingInactive(error) {
      | true => {...state, settingsModalTab: Some(Billing)}
      | false => state
      }
      failed(state, Connection.ACP.requestErrorMessage(error))
    | Some({
        connection: Ok(Some({
          phase: Reconnecting({session: SessionActive({requestId: expected})}),
        })),
      }) if requestId === expected =>
      failed(state, "Connection lost; request was not replayed")
    | _ => state->StateReducer.update
    }
  | AddUserMessage({content, annotationId, onComplete} as input) =>
    let reject = error =>
      state->StateReducer.update(
        ~sideEffect=SubmissionCompleted({onComplete, result: Error(error)}),
      )
    switch (Selectors.isSubmitting(state), state.selectedAgentId) {
    | (false, Some(agentId)) if !Selectors.hasEnrichingAnnotations(state) =>
      let annotations = Selectors.annotations(state)
      let annotations = switch annotationId {
      | None => annotations
      | Some(id) => [annotations->Array.find(annotation => annotation.id == id)->Option.getOrThrow]
      }
      let submission: Client__State__Types.submission = {
        id: Message.UserMessageId.make(),
        content,
        annotations: annotations->Array.map(Message.MessageAnnotation.fromAnnotation),
        agentId,
        onComplete,
      }
      switch validateSubmission(state, submission) {
      | Error(error) => reject(error)
      | Ok() =>
        let taskId =
          Selectors.currentTaskId(state)->Option.getOr(Selectors.currentTaskClientId(state))
        switch (Selectors.getSession(state), Selectors.currentTaskId(state)) {
        | (Some({sessionId}), _) if sessionId == taskId =>
          addUserMessageToState(state, ~sessionId, submission)
        | (_, None) if Selectors.hasActiveACPSession(state) =>
          state->StateReducer.update(~sideEffect=CreateSession({taskId, input}))
        | (_, Some(taskId)) =>
          let (state, effects) = next(state, SwitchTask({taskId: taskId}))
          state->StateReducer.update(
            ~sideEffects=Array.concat(
              effects,
              [
                SubmissionCompleted({
                  onComplete,
                  result: Error("Reconnecting this conversation. Send again when it is ready."),
                }),
              ],
            ),
          )
        | _ => reject("Cannot send message: no active connection")
        }
      }
    | _ => reject("The composer is not ready to send.")
    }

  | CancelTurn =>
    switch state.currentTask {
    | Task.Selected(taskId) => state->Lens.delegateToTask(ForTask(taskId), TaskReducer.CancelTurn)
    | Task.New(_) => state->StateReducer.update
    }

  | ExecutePendingPlan({id}) =>
    switch (state.selectedModelValue, Selectors.pendingPlanHandoff(state)) {
    | (Some(_), Some({taskId, executorAgentId})) =>
      addUserMessageToState(
        {...state, selectedAgentId: Some(executorAgentId)},
        ~sessionId=taskId,
        {
          id,
          content: [UserContentPart.Text({text: executePlanPrompt})],
          annotations: [],
          agentId: executorAgentId,
          onComplete: _ => (),
        },
      )
    | _ => state->StateReducer.update
    }

  | TaskLoadFinished({taskId, result: Ok(requestId)})
    if !(
      state.connection->Option.mapOr(false, connection =>
        Connection.isCurrentSessionRequest(connection, requestId)
      )
    ) =>
    next(
      state,
      TaskLoadFinished({taskId, result: Error("Conversation changed before loading completed")}),
    )
  | TaskLoadFinished({taskId, result: Error(_)})
    if state.connection->Option.mapOr(false, connection =>
      switch connection.connection {
      | Ok(Some({
        phase: Ready({session: SessionCreating({sessionId: Some(currentId), requestId})}),
      }))
      | Ok(Some({
        phase: Ready({session: SessionActive({session: {sessionId: currentId}, requestId})}),
      })) =>
        currentId == taskId && Connection.isCurrentSessionRequest(connection, requestId)
      | _ => false
      }
    ) =>
    state->StateReducer.update
  | TaskLoadFinished({taskId, result}) =>
    switch state.tasks->Dict.get(taskId) {
    | Some(Loading(_)) =>
      state->Lens.delegateToTask(
        ForTask(taskId),
        switch result {
        | Ok(_) => LoadComplete
        | Error(error) => LoadError({error: error})
        },
      )
    | _ => state->StateReducer.update
    }
  | SwitchTask({taskId}) => {
      let (state, connectionEffects) = switch Selectors.currentTaskId(state) == Some(taskId) {
      | true => (state, [])
      | false => next(state, ConnectionAction(ClearSession))
      }
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
      let (updatedState, loadEffects) = next(
        {
          ...updatedState,
          currentTask: Task.Selected(taskId),
          highlightedAnnotation: None,
        },
        ConnectionAction(LoadTask({taskId, needsHistory: !Task.isLoaded(task)})),
      )
      updatedState->StateReducer.update(
        ~sideEffects=Array.concat(connectionEffects, loadEffects)->Array.concat(taskEffects),
      )
    }

  | DeleteTask({taskId}) => {
      let (state, effects) = switch Selectors.currentTaskId(state) == Some(taskId) ||
        Selectors.isSubmitting(state) {
      | true => next(state, ConnectionAction(ClearSession))
      | false => (state, [])
      }
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

      let (state, deleteEffects) = next(
        {
          ...state,
          tasks: updatedTasks,
          currentTask: newCurrentTask,
          highlightedAnnotation: None,
        },
        ConnectionAction(DeleteSession({taskId: taskId})),
      )
      state->StateReducer.update(~sideEffects=Array.concat(effects, deleteEffects))
    }

  | ClearCurrentTask =>
    let (state, effects) = next(state, ConnectionAction(ClearSession))
    let previewUrl = Selectors.previewUrl(state)
    {
      ...state,
      currentTask: Task.New(Task.makeNew(~previewUrl)),
      highlightedAnnotation: None,
    }->StateReducer.update(~sideEffects=effects)

  | UpdateTaskTitle({taskId, title}) =>
    switch state.tasks->Dict.get(taskId) {
    | Some(_) =>
      state
      ->Lens.updateTask(taskId, task => Task.setTitle(task, title))
      ->StateReducer.update
    | None => state->StateReducer.update
    }

  | SetSettingsModalTab({tab}) => {...state, settingsModalTab: tab}->StateReducer.update
  | RequestBilling(request) =>
    switch (Selectors.apiBaseUrl(state), request, state.billingFlow) {
    | (None, _, _) | (_, Checkout(_) | CustomerPortal, Opening) => state->StateReducer.update
    | (Some(apiBaseUrl), _, _) =>
      let controller = switch state.billingAbortController {
      | Some(controller) => controller
      | None => WebAPI.AbortController.make()
      }
      let statusController = switch request {
      | Status => Some(WebAPI.AbortController.make())
      | _ => state.billingStatusAbortController
      }
      let signal = switch (request, statusController) {
      | (Status, Some(statusController)) =>
        WebAPI.AbortSignal.any([controller.signal, statusController.signal])
      | _ => controller.signal
      }
      let effects = switch request {
      | Status => [
          AbortBillingRequest(state.billingStatusAbortController),
          FetchBillingStatus({apiBaseUrl, signal}),
        ]
      | Checkout(_) | CustomerPortal => [OpenBillingTabAndFetchUrl({request, apiBaseUrl, signal})]
      }
      {
        ...state,
        billingAbortController: Some(controller),
        billingStatusAbortController: statusController,
        billingFlow: switch request {
        | Status => state.billingFlow
        | _ => Opening
        },
      }->StateReducer.update(~sideEffects=effects)
    }
  | BillingUrlReceived({tab, url}) =>
    {...state, billingFlow: Client__Billing.Idle}->StateReducer.update(
      ~sideEffects=[NavigateBillingTab({tab, url})],
    )
  | BillingLaunchFailed({tab, error}) =>
    {...state, billingFlow: Client__Billing.Failed(error)}->StateReducer.update(
      ~sideEffects=[CloseBillingTab(tab)],
    )
  | BillingRequestCancelled({tab}) =>
    state->StateReducer.update(~sideEffects=[CloseBillingTab(tab)])
  | BillingAuthRequired({tab}) =>
    {...state, billingFlow: Client__Billing.Idle}->StateReducer.update(
      ~sideEffects=switch Selectors.apiBaseUrl(state) {
      | None => [CloseBillingTab(tab)]
      | Some(_) => [CloseBillingTab(tab), RequireBillingAuthentication]
      },
    )
  | BillingStatusReceived(status) =>
    {
      ...state,
      billingStatus: Client__Billing.Loaded(status),
      billingStatusAbortController: None,
    }->StateReducer.update(
      ~sideEffects=switch state.billingStatusAbortController {
      | None => []
      | Some(_) => [AbortBillingRequest(state.billingStatusAbortController)]
      },
    )
  | BillingStatusError({error}) =>
    {
      ...state,
      billingStatus: Client__Billing.Error(error),
      billingStatusAbortController: None,
    }->StateReducer.update(
      ~sideEffects=switch state.billingStatusAbortController {
      | None => []
      | Some(_) => [AbortBillingRequest(state.billingStatusAbortController)]
      },
    )

  | FetchUserProfile({apiBaseUrl}) =>
    state->StateReducer.update(~sideEffects=[FetchUserProfileEffect({apiBaseUrl: apiBaseUrl})])

  | UserProfileReceived({userProfile: {id, email, name}}) =>
    let userProfile: Client__State__Types.userProfile = {id, email, name}
    {...state, userProfile: Some(userProfile)}->StateReducer.update
  | FetchApiKeySettings =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state
      ->setAllApiKeySources(Client__State__Types.Loading)
      ->StateReducer.update(~sideEffects=[FetchApiKeySettingsEffect({apiBaseUrl: apiBaseUrl})])
    | None => state->StateReducer.update
    }

  | ApiKeySettingsReceived({provider, source}) =>
    state->setApiKeySource(provider, source)->StateReducer.update

  | SaveApiKey({provider, key}) =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        pendingProviderAutoSelect: Some(apiKeyProviderId(provider)),
      }->StateReducer.update(~sideEffects=[SaveApiKeyEffect({apiBaseUrl, provider, key})])
    | None =>
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
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.FetchingStatus,
      }->StateReducer.update(
        ~sideEffects=[FetchAnthropicOAuthStatusEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
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
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state->StateReducer.update(
        ~sideEffects=[GetAnthropicOAuthUrlEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
    }

  | AnthropicOAuthUrlReceived({authorizeUrl, verifier}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Authorizing({authorizeUrl, verifier}),
    }->StateReducer.update

  | ExchangeAnthropicOAuthCode({code, verifier}) =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
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
          }),
        ],
      )
    | None => state->StateReducer.update
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
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state->StateReducer.update(
        ~sideEffects=[DisconnectAnthropicOAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
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
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIFetchingStatus,
      }->StateReducer.update(~sideEffects=[FetchOpenAIOAuthStatusEffect({apiBaseUrl: apiBaseUrl})])
    | None => state->StateReducer.update
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
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIWaitingForCode,
        pendingProviderAutoSelect: Some("openai_codex"),
      }->StateReducer.update(
        ~sideEffects=[InitiateOpenAIDeviceAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
    }

  | OpenAIDeviceCodeReceived({deviceAuthId, userCode, verificationUrl}) =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
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
          }),
        ],
      )
    | None =>
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
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state->StateReducer.update(
        ~sideEffects=[DisconnectOpenAIOAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
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

    {
      ...state,
      tasks: updatedTasks,
      sessionsLoadState: Client__State__Types.SessionsLoaded,
    }->StateReducer.update

  | SessionsLoadError({error}) =>
    {
      ...state,
      sessionsLoadState: Client__State__Types.SessionsLoadError(error),
    }->StateReducer.update(~sideEffect=ConnectionEffect(LogError(error)))

  | CheckForUpdate({apiBaseUrl, installedVersion, target}) =>
    switch (target, state.wordpressUpdates) {
    | (WordPressPlugin, Unsupported) => state->StateReducer.update
    | _ =>
      state->StateReducer.update(
        ~sideEffects=[CheckForUpdateEffect({apiBaseUrl, installedVersion, target})],
      )
    }

  | WordPressUpdatesChecked(None) =>
    {...state, wordpressUpdates: Unsupported, updateInfo: None}->StateReducer.update

  | WordPressUpdatesChecked(Some(response)) =>
    {
      ...state,
      wordpressUpdates: Client__WordPressUpdates.Available({
        autoUpdateEnabled: response.autoUpdateEnabled,
      }),
      updateInfo: updateInfoForVersions(
        ~target=WordPressPlugin,
        ~installedVersion=response.installedVersion,
        ~latestVersion=response.latestVersion,
      ),
    }->StateReducer.update

  | UpdateInfoChecked(updateInfo) => {...state, updateInfo}->StateReducer.update

  | DismissUpdateBanner => {...state, updateBannerDismissed: true}->StateReducer.update

  | HighlightAnnotation({annotationId, selector}) =>
    let taskId = Selectors.currentTaskClientId(state)
    let highlighted = switch state.highlightedAnnotation {
    | Some(current) if current.taskId == taskId && current.annotationId == annotationId => None
    | Some(_) | None => Some({Client__State__Types.taskId, annotationId, selector})
    }
    {...state, highlightedAnnotation: highlighted}->StateReducer.update

  | FetchCustomProviders =>
    switch Selectors.apiBaseUrl(state) {
    | Some(apiBaseUrl) =>
      state->StateReducer.update(
        ~sideEffects=[FetchCustomProvidersEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->StateReducer.update
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
