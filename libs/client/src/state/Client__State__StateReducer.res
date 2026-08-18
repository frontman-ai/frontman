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

type taskTarget = CurrentTask | ForTask(string)

type apiKeyProvider = OpenRouter | Anthropic | Fireworks | Nvidia

type pendingPlanHandoff = {taskId: string, executorAgentId: string}

type action =
  | TaskAction({target: taskTarget, action: TaskReducer.action})
  | AddUserMessage({
      id: string,
      sessionId: string,
      content: array<UserContentPart.t>,
      annotations: array<Message.MessageAnnotation.t>,
      agentId: string,
    })
  | CancelTurn
  | ExecutePendingPlan({id: string})
  | SwitchTask({taskId: string})
  | DeleteTask({taskId: string})
  | ClearCurrentTask
  | UpdateTaskTitle({taskId: string, title: string})
  | SetAcpSession({
      sendPrompt: Client__State__Types.sendPromptFn,
      cancelPrompt: Client__State__Types.cancelPromptFn,
      retryTurn: Client__State__Types.retryTurnFn,
      loadTask: Client__State__Types.loadTaskFn,
      deleteSession: Client__State__Types.deleteSessionFn,
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
  | CheckForUpdate({installedVersion: string, npmPackage: string})
  | UpdateInfoReceived({updateInfo: Client__State__Types.updateInfo})
  | DismissUpdateBanner

type effect =
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
  | LoadTaskEffect({taskId: string})
  | CheckForUpdateEffect({apiBaseUrl: string, installedVersion: string, npmPackage: string})

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
    FrontmanBindings.LocalStorage.getItem(selectedModelStorageKey)
    ->Nullable.toOption
    ->Option.map(migrateOpenAIModelValue)
  } catch {
  | _ => None
  }
}

let saveSelectedModelValueToStorage = (value: string): unit => {
  try {
    FrontmanBindings.LocalStorage.setItem(selectedModelStorageKey, value)
  } catch {
  | exn => Log.error(~error=JsExn.fromException(exn), "saveSelectedModelValueToStorage failed")
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

let hasApiKeySource = (source: Client__State__Types.apiKeySource) =>
  switch source {
  | UserOverride => true
  | Loading | Client__State__Types.None => false
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
  updateInfo: None,
  updateCheckStatus: UpdateNotChecked,
  updateBannerDismissed: false,
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

  let hasAnyProviderConfigured = (state: state): bool => {
    switch state.anthropicOAuthStatus {
    | Connected(_) => true
    | _ =>
      switch state.openaiOAuthStatus {
      | OpenAIConnected(_) => true
      | _ =>
        hasApiKeySource(state.openrouterKeySettings.source) ||
        hasApiKeySource(state.nvidiaKeySettings.source) ||
        hasApiKeySource(state.fireworksKeySettings.source) ||
        hasApiKeySource(state.anthropicKeySettings.source)
      }
    }
  }

  let providerSettingsLoaded = (state: state): bool => {
    let apiKeySettingsLoaded = switch (
      state.openrouterKeySettings.source,
      state.nvidiaKeySettings.source,
      state.fireworksKeySettings.source,
      state.anthropicKeySettings.source,
    ) {
    | (Loading, _, _, _) | (_, Loading, _, _) | (_, _, Loading, _) | (_, _, _, Loading) => false
    | _ => true
    }
    let oauthSettingsLoaded = switch (state.anthropicOAuthStatus, state.openaiOAuthStatus) {
    | (FetchingStatus, _) | (_, OpenAIFetchingStatus) => false
    | _ => true
    }

    apiKeySettingsLoaded && oauthSettingsLoaded
  }

  let providerSetupRequired = (state: state): bool => {
    hasActiveACPSession(state) && providerSettingsLoaded(state) && !hasAnyProviderConfigured(state)
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
  _dispatch,
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
    metadata->Dict.set("agent", JSON.Encode.string(agentId))
    let _meta = Some(JSON.Encode.object(metadata))

    sendPrompt(message, ~additionalBlocks, ~onComplete=_result => (), ~_meta)
  | NoAcpSession => Log.error("Cannot send message: no active ACP session")
  }
}

let fetchUserProfileImpl = (dispatch, ~apiBaseUrl) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/me`

    try {
      let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
      if response.ok {
        let json = await response->WebAPI.Response.json
        let userProfile =
          json->S.decodeOrThrow(~from=S.json, ~to=Client__State__Types.userProfileSchema)
        dispatch(UserProfileReceived({userProfile: userProfile}))
        Client__Heap.heap.identify(userProfile.id)
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

let jsonContentHeaders = () =>
  WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "application/json")]))

let fetchApiKeySettingsImpl = (dispatch, ~apiBaseUrl) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/api-keys`

    try {
      let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
      if response.ok {
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
      let response = await WebAPI.Global.fetch(
        url,
        ~init={
          credentials: Include,
          method: "POST",
          headers: jsonContentHeaders(),
          body: WebAPI.BodyInit.fromString(
            encodeUserApiKeySaveRequest(~provider=apiKeyProviderId(provider), ~key),
          ),
        },
      )

      if !response.ok {
        dispatch(
          ApiKeySaveError({
            provider,
            error: `HTTP ${response.status->Int.toString}: ${response.statusText}`,
          }),
        )
      } else {
        dispatch(ApiKeySaved({provider: provider}))
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

let handleEffect = (effect, state: state, dispatch) => {
  switch effect {
  | FetchUserProfileEffect({apiBaseUrl}) => fetchUserProfileImpl(dispatch, ~apiBaseUrl)
  | TaskEffect({target, effect: taskEffect}) => {
      let taskDispatch = (taskAction: TaskReducer.action) => {
        dispatch(TaskAction({target, action: taskAction}))
      }

      let delegate = (delegated: TaskReducer.delegated) => {
        switch delegated {
        | NeedSendMessage({text, attachments, annotations, agentId}) =>
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
            ~message=text,
            ~attachments,
            ~annotations,
            ~taskId,
            ~agentId,
          )
        | NeedCancelPrompt =>
          switch state.acpSession {
          | AcpSessionActive({cancelPrompt}) => cancelPrompt()
          | NoAcpSession => Log.error("Cannot cancel prompt: no active ACP session")
          }
        | NeedRetryTurn({retriedErrorId}) =>
          switch state.acpSession {
          | AcpSessionActive({retryTurn}) => retryTurn(retriedErrorId)
          | NoAcpSession => Log.error("Cannot retry turn: no active ACP session")
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
        let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
        if response.ok {
          let json = await response->WebAPI.Response.json
          let connected =
            json
            ->JSON.Decode.object
            ->Option.flatMap(obj => obj->Dict.get("connected")->Option.flatMap(JSON.Decode.bool))
            ->Option.getOr(false)
          let expiresAt =
            json
            ->JSON.Decode.object
            ->Option.flatMap(obj => obj->Dict.get("expires_at")->Option.flatMap(JSON.Decode.string))
          dispatch(AnthropicOAuthStatusReceived({connected, expiresAt}))
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
        let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
        if response.ok {
          let json = await response->WebAPI.Response.json
          let authorizeUrl =
            json
            ->JSON.Decode.object
            ->Option.flatMap(obj =>
              obj->Dict.get("authorize_url")->Option.flatMap(JSON.Decode.string)
            )
          let verifier =
            json
            ->JSON.Decode.object
            ->Option.flatMap(obj => obj->Dict.get("verifier")->Option.flatMap(JSON.Decode.string))
          switch (authorizeUrl, verifier) {
          | (Some(authorizeUrl), Some(verifier)) =>
            dispatch(AnthropicOAuthUrlReceived({authorizeUrl, verifier}))
          | _ => dispatch(AnthropicOAuthError({error: "Invalid response from server"}))
          }
        } else {
          dispatch(AnthropicOAuthError({error: "Failed to get authorization URL"}))
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
        let response = await WebAPI.Global.fetch(
          url,
          ~init={
            method: "POST",
            credentials: Include,
            headers: jsonContentHeaders(),
            body: WebAPI.BodyInit.fromString(JSON.stringify(body)),
          },
        )
        if response.ok {
          let json = await response->WebAPI.Response.json
          let expiresAt =
            json
            ->JSON.Decode.object
            ->Option.flatMap(obj => obj->Dict.get("expires_at")->Option.flatMap(JSON.Decode.string))
          switch expiresAt {
          | Some(expiresAt) => dispatch(AnthropicOAuthConnected({expiresAt: expiresAt}))
          | None => dispatch(AnthropicOAuthError({error: "Invalid response from server"}))
          }
        } else {
          let json = await response->WebAPI.Response.json
          let error =
            json
            ->JSON.Decode.object
            ->Option.flatMap(obj => obj->Dict.get("error")->Option.flatMap(JSON.Decode.string))
            ->Option.getOr("Failed to exchange code")
          dispatch(AnthropicOAuthError({error: error}))
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
        let response = await WebAPI.Global.fetch(
          url,
          ~init={
            method: "DELETE",
            credentials: Include,
          },
        )
        if response.ok {
          dispatch(AnthropicOAuthDisconnected)
        } else {
          dispatch(AnthropicOAuthError({error: "Failed to disconnect"}))
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
        let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
        if response.ok {
          let json = await response->WebAPI.Response.json
          let connected =
            json
            ->JSON.Decode.object
            ->Option.flatMap(obj => obj->Dict.get("connected")->Option.flatMap(JSON.Decode.bool))
            ->Option.getOr(false)
          let expiresAt =
            json
            ->JSON.Decode.object
            ->Option.flatMap(obj => obj->Dict.get("expires_at")->Option.flatMap(JSON.Decode.string))
          dispatch(OpenAIOAuthStatusReceived({connected, expiresAt}))
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
        let response = await WebAPI.Global.fetch(
          url,
          ~init={
            method: "POST",
            credentials: Include,
            headers: jsonContentHeaders(),
          },
        )
        if response.ok {
          let json = await response->WebAPI.Response.json
          let obj = json->JSON.Decode.object
          let deviceAuthId =
            obj->Option.flatMap(o =>
              o->Dict.get("device_auth_id")->Option.flatMap(JSON.Decode.string)
            )
          let userCode =
            obj->Option.flatMap(o => o->Dict.get("user_code")->Option.flatMap(JSON.Decode.string))
          let verificationUrl =
            obj->Option.flatMap(o =>
              o->Dict.get("verification_url")->Option.flatMap(JSON.Decode.string)
            )
          switch (deviceAuthId, userCode, verificationUrl) {
          | (Some(deviceAuthId), Some(userCode), Some(verificationUrl)) =>
            dispatch(OpenAIDeviceCodeReceived({deviceAuthId, userCode, verificationUrl}))
          | _ =>
            dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Invalid response from server"}))
          }
        } else {
          dispatch(
            OpenAIOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}),
          )
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
      let rec pollLoop = async attempt => {
        if attempt >= maxAttempts {
          dispatch(
            OpenAIOAuthError({
              deviceAuthId: Some(deviceAuthId),
              error: "Authorization timed out. Please try again.",
            }),
          )
        } else {
          try {
            let url = `${apiBaseUrl}/api/oauth/openai/poll`
            let response = await WebAPI.Global.fetch(
              url,
              ~init={
                method: "POST",
                credentials: Include,
                headers: jsonContentHeaders(),
                body: WebAPI.BodyInit.fromString(body),
              },
            )
            if response.ok {
              let json = await response->WebAPI.Response.json
              let status =
                json
                ->JSON.Decode.object
                ->Option.flatMap(obj => obj->Dict.get("status")->Option.flatMap(JSON.Decode.string))
                ->Option.getOr("")
              switch status {
              | "connected" =>
                let expiresAt =
                  json
                  ->JSON.Decode.object
                  ->Option.flatMap(obj =>
                    obj->Dict.get("expires_at")->Option.flatMap(JSON.Decode.string)
                  )
                  ->Option.getOr("")
                dispatch(OpenAIOAuthConnected({deviceAuthId, expiresAt}))
              | _ =>
                await Promise.make((resolve, _) => {
                  let _ = setTimeout(() => resolve(), intervalMs)
                })
                await pollLoop(attempt + 1)
              }
            } else if response.status == 403 {
              dispatch(
                OpenAIOAuthError({
                  deviceAuthId: Some(deviceAuthId),
                  error: "Authorization was declined.",
                }),
              )
            } else {
              await Promise.make((resolve, _) => {
                let _ = setTimeout(() => resolve(), intervalMs)
              })
              await pollLoop(attempt + 1)
            }
          } catch {
          | _ =>
            await Promise.make((resolve, _) => {
              let _ = setTimeout(() => resolve(), intervalMs)
            })
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
        let response = await WebAPI.Global.fetch(
          url,
          ~init={
            method: "DELETE",
            credentials: Include,
          },
        )
        if response.ok {
          dispatch(OpenAIOAuthDisconnected)
        } else {
          dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
        }
      } catch {
      | _ => dispatch(OpenAIOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
      }
    }
    disconnect()->ignore

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
  | CheckForUpdateEffect({apiBaseUrl, installedVersion, npmPackage}) =>
    let fetch = async () => {
      try {
        let url = `${apiBaseUrl}/api/integrations/latest-versions`
        let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
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
          switch versions->Dict.get(npmPackage)->Option.flatMap(v => v) {
          | Some(latest) =>
            switch (Client__Semver.parse(installedVersion), Client__Semver.parse(latest)) {
            | (Some(installed), Some(latestV)) if Client__Semver.isBehind(installed, latestV) =>
              dispatch(
                UpdateInfoReceived({
                  updateInfo: {npmPackage, installedVersion, latestVersion: latest},
                }),
              )
            | _ => ()
            }
          | None =>
            Sentry.captureConnectionError(
              `CheckForUpdate: package "${npmPackage}" not found or null in registry response`,
              ~endpoint=url,
            )
          }
        }
      } catch {
      | exn => Sentry.captureException(exn, ~operation="CheckForUpdate")
      }
    }
    fetch()->ignore
  }
}

let next = (state: state, action) => {
  switch action {
  | TaskAction({target, action: taskAction}) => state->Lens.delegateToTask(target, taskAction)

  | AddUserMessage({id, sessionId, content, annotations, agentId}) => {
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

  | CancelTurn =>
    switch state.currentTask {
    | Task.Selected(taskId) => state->Lens.delegateToTask(ForTask(taskId), TaskReducer.CancelTurn)
    | Task.New(_) => state->StateReducer.update
    }

  | ExecutePendingPlan({id}) =>
    switch Selectors.pendingPlanHandoff(state) {
    | Some({taskId, executorAgentId}) =>
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

      switch state.acpSession {
      | AcpSessionActive({deleteSession}) => deleteSession(taskId, ~onComplete=_ => ())
      | NoAcpSession => ()
      }

      {
        ...state,
        tasks: updatedTasks,
        currentTask: newCurrentTask,
      }->StateReducer.update
    }

  | ClearCurrentTask =>
    let previewUrl = Selectors.previewUrl(state)
    {
      ...state,
      currentTask: Task.New(Task.makeNew(~previewUrl)),
    }->StateReducer.update

  | UpdateTaskTitle({taskId, title}) =>
    switch state.tasks->Dict.get(taskId) {
    | Some(_) =>
      state
      ->Lens.updateTask(taskId, task => Task.setTitle(task, title))
      ->StateReducer.update
    | None => state->StateReducer.update
    }

  | SetAcpSession({sendPrompt, cancelPrompt, retryTurn, loadTask, deleteSession, apiBaseUrl}) =>
    let stateWithSession = {
      ...state,
      acpSession: AcpSessionActive({
        sendPrompt,
        cancelPrompt,
        retryTurn,
        loadTask,
        deleteSession,
        apiBaseUrl,
      }),
    }
    switch state.acpSession {
    | AcpSessionActive(_) => stateWithSession->StateReducer.update
    | NoAcpSession =>
      {
        ...stateWithSession,
        anthropicOAuthStatus: Client__State__Types.FetchingStatus,
        openaiOAuthStatus: Client__State__Types.OpenAIFetchingStatus,
      }
      ->setAllApiKeySources(Client__State__Types.Loading)
      ->StateReducer.update(
        ~sideEffects=[
          FetchApiKeySettingsEffect({apiBaseUrl: apiBaseUrl}),
          FetchAnthropicOAuthStatusEffect({apiBaseUrl: apiBaseUrl}),
          FetchOpenAIOAuthStatusEffect({apiBaseUrl: apiBaseUrl}),
        ],
      )
    }

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

    let firstModelValue = switch modelConfigOption {
    | ACP.SelectConfigOption({options: ACP.Grouped(groups)}) =>
      groups
      ->Array.get(0)
      ->Option.flatMap(g => g.options->Array.get(0))
      ->Option.map(opt => opt.value)
    | ACP.SelectConfigOption({options: ACP.Ungrouped(_)}) =>
      failwith("Model config option must use grouped options")
    }

    let (selectedModelValue, didAutoSelect) = switch state.pendingProviderAutoSelect {
    | Some(providerId) =>
      let providerModelValue = switch modelConfigOption {
      | ACP.SelectConfigOption({options: ACP.Grouped(groups)}) =>
        groups
        ->Array.find(g => g.group == providerId)
        ->Option.flatMap(g => g.options->Array.get(0))
        ->Option.map(opt => opt.value)
      | ACP.SelectConfigOption({options: ACP.Ungrouped(_)}) =>
        failwith("Model config option must use grouped options")
      }
      switch providerModelValue {
      | Some(value) => (Some(value), true)
      | None => (state.selectedModelValue, false)
      }
    | None =>
      switch state.selectedModelValue {
      | Some(value) => (Some(value), false)
      | None => (firstModelValue, firstModelValue->Option.isSome)
      }
    }
    switch (didAutoSelect, selectedModelValue) {
    | (true, Some(value)) => saveSelectedModelValueToStorage(value)
    | _ => ()
    }
    {
      ...state,
      configOptions: Some(configOptions),
      selectedModelValue,
      pendingProviderAutoSelect: None,
    }->StateReducer.update

  | SetSelectedModelValue({value}) =>
    saveSelectedModelValueToStorage(value)
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
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.FetchingStatus,
      }->StateReducer.update(
        ~sideEffects=[FetchAnthropicOAuthStatusEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | AnthropicOAuthStatusReceived({connected, expiresAt}) =>
    let status = if connected {
      switch expiresAt {
      | Some(expiresAtStr) =>
        let expiresAtMs = Date.fromString(expiresAtStr)->Date.getTime
        Client__State__Types.Connected({expiresAt: expiresAtMs})
      | None => Client__State__Types.Connected({expiresAt: 0.0})
      }
    } else {
      Client__State__Types.NotConnected
    }
    {...state, anthropicOAuthStatus: status}->StateReducer.update

  | InitiateAnthropicOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->StateReducer.update(
        ~sideEffects=[GetAnthropicOAuthUrlEffect({apiBaseUrl: apiBaseUrl})],
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
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.Exchanging,
        pendingProviderAutoSelect: Some("anthropic"),
      }->StateReducer.update(
        ~sideEffects=[ExchangeAnthropicOAuthCodeEffect({apiBaseUrl, code, verifier})],
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
    | AcpSessionActive({apiBaseUrl}) =>
      state->StateReducer.update(
        ~sideEffects=[DisconnectAnthropicOAuthEffect({apiBaseUrl: apiBaseUrl})],
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
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIFetchingStatus,
      }->StateReducer.update(~sideEffects=[FetchOpenAIOAuthStatusEffect({apiBaseUrl: apiBaseUrl})])
    | NoAcpSession => state->StateReducer.update
    }

  | OpenAIOAuthStatusReceived({connected, expiresAt}) =>
    let status = if connected {
      switch expiresAt {
      | Some(expiresAtStr) =>
        let expiresAtMs = Date.fromString(expiresAtStr)->Date.getTime
        Client__State__Types.OpenAIConnected({expiresAt: expiresAtMs})
      | None => Client__State__Types.OpenAIConnected({expiresAt: 0.0})
      }
    } else {
      Client__State__Types.OpenAINotConnected
    }
    {...state, openaiOAuthStatus: status}->StateReducer.update

  | InitiateOpenAIOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIWaitingForCode,
        pendingProviderAutoSelect: Some("openai_codex"),
      }->StateReducer.update(
        ~sideEffects=[InitiateOpenAIDeviceAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | OpenAIDeviceCodeReceived({deviceAuthId, userCode, verificationUrl}) =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        openaiOAuthStatus: Client__State__Types.OpenAIShowingCode({
          deviceAuthId,
          userCode,
          verificationUrl,
        }),
      }->StateReducer.update(
        ~sideEffects=[PollOpenAIDeviceAuthEffect({apiBaseUrl, deviceAuthId, userCode})],
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
    | AcpSessionActive({apiBaseUrl}) =>
      state->StateReducer.update(
        ~sideEffects=[DisconnectOpenAIOAuthEffect({apiBaseUrl: apiBaseUrl})],
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

    {
      ...state,
      tasks: updatedTasks,
      sessionsLoadState: Client__State__Types.SessionsLoaded,
    }->StateReducer.update

  | SessionsLoadError({error}) =>
    {
      ...state,
      sessionsLoadState: Client__State__Types.SessionsLoadError(error),
    }->StateReducer.update

  | CheckForUpdate({installedVersion, npmPackage}) =>
    switch (state.updateCheckStatus, state.acpSession) {
    | (UpdateNotChecked, AcpSessionActive({apiBaseUrl})) =>
      {
        ...state,
        updateCheckStatus: Client__State__Types.UpdateChecked,
      }->StateReducer.update(
        ~sideEffects=[CheckForUpdateEffect({apiBaseUrl, installedVersion, npmPackage})],
      )
    | _ => state->StateReducer.update
    }

  | UpdateInfoReceived({updateInfo}) =>
    {...state, updateInfo: Some(updateInfo)}->StateReducer.update

  | DismissUpdateBanner => {...state, updateBannerDismissed: true}->StateReducer.update
  }
}
