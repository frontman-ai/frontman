module Log = FrontmanLogs.Logs.Make({
  let component = #StateReducer
})
module Sentry = FrontmanAiFrontmanClient.FrontmanClient__Sentry

let name = "Client::StateReducer"

// ============================================================================
// Type Re-exports from Client__State__Types
// ============================================================================

module UserContentPart = Client__State__Types.UserContentPart
module Message = Client__State__Types.Message
module Task = Client__State__Types.Task
type state = Client__State__Types.state

// ============================================================================
// Actions and Effects
// ============================================================================

module TaskReducer = Client__Task__Reducer

type taskTarget = CurrentTask | ForTask(string)

type action =
  // Task-scoped actions (routed to task sub-reducer)
  | TaskAction({target: taskTarget, action: TaskReducer.action})
  // User actions
  | AddUserMessage({id: string, sessionId: string, content: array<UserContentPart.t>, annotations: array<Message.MessageAnnotation.t>})
  // Cancel current turn
  | CancelTurn
  // Task management actions
  | CreateTask
  | SwitchTask({taskId: string})
  | DeleteTask({taskId: string})
  | ClearCurrentTask // Used when clicking "+" to start a new task - clears selection so next message creates new task
  | UpdateTaskTitle({taskId: string, title: string})
  // ACP session actions
  | SetAcpSession({
      sendPrompt: Client__State__Types.sendPromptFn,
      cancelPrompt: Client__State__Types.cancelPromptFn,
      loadTask: Client__State__Types.loadTaskFn,
      deleteSession: Client__State__Types.deleteSessionFn,
      apiBaseUrl: string,
    })
  | ClearAcpSession
  // Usage info actions
  | UsageInfoReceived({usageInfo: Client__State__Types.usageInfo})
  // API key settings actions
  | FetchApiKeySettings
  | ApiKeySettingsReceived({source: Client__State__Types.apiKeySource})
  | SaveOpenRouterKey({key: string})
  | OpenRouterKeySaveStarted
  | OpenRouterKeySaved
  | OpenRouterKeySaveError({error: string})
  | ResetOpenRouterKeySaveStatus
  // Anthropic API key settings actions
  | FetchAnthropicApiKeySettings
  | AnthropicApiKeySettingsReceived({source: Client__State__Types.apiKeySource})
  | SaveAnthropicKey({key: string})
  | AnthropicKeySaveStarted
  | AnthropicKeySaved
  | AnthropicKeySaveError({error: string})
  | ResetAnthropicKeySaveStatus
  // Model selection actions
  | FetchModelsConfig
  | ModelsConfigReceived({config: Client__State__Types.modelsConfig})
  | SetSelectedModel({model: Client__State__Types.modelSelection})
  // Anthropic OAuth actions
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
  // ChatGPT OAuth actions (device auth flow)
  | FetchChatGPTOAuthStatus
  | ChatGPTOAuthStatusReceived({connected: bool, expiresAt: option<string>})
  | InitiateChatGPTOAuth
  | ChatGPTDeviceCodeReceived({deviceAuthId: string, userCode: string, verificationUrl: string})
  | ChatGPTOAuthConnected({deviceAuthId: string, expiresAt: string})
  | ChatGPTOAuthError({deviceAuthId: option<string>, error: string})
  | DisconnectChatGPTOAuth
  | ChatGPTOAuthDisconnected
  | ResetChatGPTOAuthError
  // User profile actions
  | UserProfileReceived({userProfile: Client__State__Types.userProfile})
  // Session loading actions
  | SessionsLoadStarted
  | SessionsLoadSuccess({
      sessions: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionSummary>,
    })
  | SessionsLoadError({error: string})
  // Update banner actions
  | CheckForUpdate({installedVersion: string, npmPackage: string})
  | UpdateInfoReceived({updateInfo: Client__State__Types.updateInfo})
  | DismissUpdateBanner

type effect =
  | TaskEffect({target: taskTarget, effect: TaskReducer.effect})
  | FetchUsageInfo({apiBaseUrl: string})
  | FetchApiKeySettingsEffect({apiBaseUrl: string})
  | SaveOpenRouterKeyEffect({apiBaseUrl: string, key: string})
  | FetchAnthropicApiKeySettingsEffect({apiBaseUrl: string})
  | SaveAnthropicKeyEffect({apiBaseUrl: string, key: string})
  | FetchModelsConfigEffect({apiBaseUrl: string})
  // Anthropic OAuth effects
  | FetchAnthropicOAuthStatusEffect({apiBaseUrl: string})
  | GetAnthropicOAuthUrlEffect({apiBaseUrl: string})
  | ExchangeAnthropicOAuthCodeEffect({apiBaseUrl: string, code: string, verifier: string})
  | DisconnectAnthropicOAuthEffect({apiBaseUrl: string})
  // ChatGPT OAuth effects (device auth flow)
  | FetchChatGPTOAuthStatusEffect({apiBaseUrl: string})
  | InitiateChatGPTDeviceAuthEffect({apiBaseUrl: string})
  | DisconnectChatGPTOAuthEffect({apiBaseUrl: string})
  | PollChatGPTDeviceAuthEffect({apiBaseUrl: string, deviceAuthId: string, userCode: string})
  // User profile effect
  | FetchUserProfileEffect({apiBaseUrl: string})
  // Task loading effect
  | LoadTaskEffect({taskId: string})
  // Update check effect
  | CheckForUpdateEffect({apiBaseUrl: string, installedVersion: string, npmPackage: string})

// ============================================================================
// Lens helpers for state updates
// ============================================================================

module Lens = {
  let updateTask = (state: state, taskId: string, fn: Task.t => Task.t): state => {
    let task = state.tasks->Dict.get(taskId)->Option.getOrThrow
    let updated = fn(task)
    let tasks = state.tasks->Dict.copy
    tasks->Dict.set(taskId, updated)
    {...state, tasks}
  }

  // Delegate an action to the TaskReducer
  // - New(task): operate on task inline, write back to currentTask
  // - Selected(id): look up in dict, operate, write back to dict
  // Wraps task effects as TaskEffect with the appropriate target
  let delegateToTask = (state: state, target: Task.currentTask, taskAction: TaskReducer.action) => {
    switch target {
    | Task.New(task) =>
      let (updated, taskEffects) = TaskReducer.next(task, taskAction)
      let wrappedEffects =
        taskEffects->Array.map(eff => TaskEffect({target: CurrentTask, effect: eff}))
      {...state, currentTask: Task.New(updated)}->StateReducer.update(
        ~sideEffects=wrappedEffects,
      )
    | Task.Selected(id) =>
      let task = state.tasks->Dict.get(id)->Option.getOrThrow
      let (updated, taskEffects) = TaskReducer.next(task, taskAction)
      let wrappedEffects =
        taskEffects->Array.map(eff => TaskEffect({target: ForTask(id), effect: eff}))
      let tasks = state.tasks->Dict.copy
      tasks->Dict.set(id, updated)
      {...state, tasks}->StateReducer.update(~sideEffects=wrappedEffects)
    }
  }
}

let getInitialUrl = Client__BrowserUrl.getInitialUrl
let selectedModelStorageKey = "frontman:selectedModel"

// Load selected model from localStorage
let loadSelectedModelFromStorage = (): option<Client__State__Types.modelSelection> => {
  try {
    FrontmanBindings.LocalStorage.getItem(selectedModelStorageKey)
    ->Nullable.toOption
    ->Option.flatMap(jsonString => {
      try {
        Some(S.parseJsonStringOrThrow(jsonString, FrontmanAiFrontmanProtocol.FrontmanProtocol__Types.modelSelectionSchema))
      } catch {
      | _ => None
      }
    })
  } catch {
  | _ => None
  }
}

// Save selected model to localStorage
let saveSelectedModelToStorage = (model: Client__State__Types.modelSelection): unit => {
  try {
    let jsonString = S.reverseConvertToJsonStringOrThrow(
      model,
      FrontmanAiFrontmanProtocol.FrontmanProtocol__Types.modelSelectionSchema,
    )
    FrontmanBindings.LocalStorage.setItem(selectedModelStorageKey, jsonString)
  } catch {
  | exn => Log.error(~ctx={"error": exn}, "saveSelectedModelToStorage failed")
  }
}

let defaultState: state = {
  tasks: Dict.make(),
  currentTask: Task.New(Task.makeNew(~previewUrl=getInitialUrl())),
  acpSession: NoAcpSession,
  sessionInitialized: false,
  usageInfo: None,
  userProfile: None,
  openrouterKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  anthropicKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  anthropicOAuthStatus: Client__State__Types.NotConnected,
  chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
  modelsConfig: None,
  selectedModel: loadSelectedModelFromStorage(), // Load from localStorage on init
  pendingProviderAutoSelect: None,
  sessionsLoadState: Client__State__Types.SessionsNotLoaded,
  updateInfo: None,
  updateCheckStatus: UpdateNotChecked,
  updateBannerDismissed: false,
}

let actionToString = action => {
  switch action {
  | TaskAction({target, action}) =>
    let targetStr = switch target {
    | CurrentTask => "CurrentTask"
    | ForTask(id) => `ForTask(${id})`
    }
    `TaskAction(${targetStr}, ${TaskReducer.actionToString(action)})`
  | AddUserMessage({id, sessionId}) => `AddUserMessage(${id}, session=${sessionId})`
  | CancelTurn => `CancelTurn`
  | CreateTask => `CreateTask`
  | SwitchTask({taskId}) => `SwitchTask(${taskId})`
  | DeleteTask({taskId}) => `DeleteTask(${taskId})`
  | ClearCurrentTask => `ClearCurrentTask`
  | UpdateTaskTitle({taskId, title}) => `UpdateTaskTitle(${taskId}, "${title}")`
  | SetAcpSession(_) => `SetAcpSession`
  | ClearAcpSession => `ClearAcpSession`
  | UsageInfoReceived(_) => `UsageInfoReceived`
  | FetchApiKeySettings => `FetchApiKeySettings`
  | ApiKeySettingsReceived({source}) =>
    let sourceStr = switch source {
    | Client__State__Types.None => "None"
    | Client__State__Types.FromEnv => "FromEnv"
    | Client__State__Types.UserOverride => "UserOverride"
    }
    `ApiKeySettingsReceived(${sourceStr})`
  | SaveOpenRouterKey(_) => `SaveOpenRouterKey`
  | OpenRouterKeySaveStarted => `OpenRouterKeySaveStarted`
  | OpenRouterKeySaved => `OpenRouterKeySaved`
  | OpenRouterKeySaveError({error}) => `OpenRouterKeySaveError(${error})`
  | ResetOpenRouterKeySaveStatus => `ResetOpenRouterKeySaveStatus`
  | FetchAnthropicApiKeySettings => `FetchAnthropicApiKeySettings`
  | AnthropicApiKeySettingsReceived({source}) => {
      let sourceStr = switch source {
      | Client__State__Types.None => "None"
      | Client__State__Types.FromEnv => "FromEnv"
      | Client__State__Types.UserOverride => "UserOverride"
      }
      `AnthropicApiKeySettingsReceived(${sourceStr})`
    }
  | SaveAnthropicKey(_) => `SaveAnthropicKey`
  | AnthropicKeySaveStarted => `AnthropicKeySaveStarted`
  | AnthropicKeySaved => `AnthropicKeySaved`
  | AnthropicKeySaveError({error}) => `AnthropicKeySaveError(${error})`
  | ResetAnthropicKeySaveStatus => `ResetAnthropicKeySaveStatus`
  | FetchModelsConfig => `FetchModelsConfig`
  | ModelsConfigReceived(_) => `ModelsConfigReceived`
  | SetSelectedModel({model}) => `SetSelectedModel(${model.provider}:${model.value})`
  | FetchAnthropicOAuthStatus => `FetchAnthropicOAuthStatus`
  | AnthropicOAuthStatusReceived({connected}) =>
    `AnthropicOAuthStatusReceived(connected=${connected->string_of_bool})`
  | InitiateAnthropicOAuth => `InitiateAnthropicOAuth`
  | AnthropicOAuthUrlReceived(_) => `AnthropicOAuthUrlReceived`
  | ExchangeAnthropicOAuthCode(_) => `ExchangeAnthropicOAuthCode`
  | AnthropicOAuthConnected({expiresAt}) => `AnthropicOAuthConnected(${expiresAt})`
  | AnthropicOAuthError({error}) => `AnthropicOAuthError(${error})`
  | DisconnectAnthropicOAuth => `DisconnectAnthropicOAuth`
  | AnthropicOAuthDisconnected => `AnthropicOAuthDisconnected`
  | ResetAnthropicOAuthError => `ResetAnthropicOAuthError`
  | CancelAnthropicOAuth => `CancelAnthropicOAuth`
  | FetchChatGPTOAuthStatus => `FetchChatGPTOAuthStatus`
  | ChatGPTOAuthStatusReceived({connected}) =>
    `ChatGPTOAuthStatusReceived(connected=${connected->string_of_bool})`
  | InitiateChatGPTOAuth => `InitiateChatGPTOAuth`
  | ChatGPTDeviceCodeReceived({userCode}) => `ChatGPTDeviceCodeReceived(userCode=${userCode})`
  | ChatGPTOAuthConnected({expiresAt}) => `ChatGPTOAuthConnected(expiresAt=${expiresAt})`
  | ChatGPTOAuthError({error}) => `ChatGPTOAuthError(error=${error})`
  | DisconnectChatGPTOAuth => `DisconnectChatGPTOAuth`
  | ChatGPTOAuthDisconnected => `ChatGPTOAuthDisconnected`
  | ResetChatGPTOAuthError => `ResetChatGPTOAuthError`
  | UserProfileReceived(_) => `UserProfileReceived`
  | SessionsLoadStarted => `SessionsLoadStarted`
  | SessionsLoadSuccess({sessions}) =>
    `SessionsLoadSuccess(${sessions->Array.length->Int.toString} sessions)`
  | SessionsLoadError({error}) => `SessionsLoadError(${error})`
  | CheckForUpdate({npmPackage}) => `CheckForUpdate(${npmPackage})`
  | UpdateInfoReceived({updateInfo}) =>
    `UpdateInfoReceived(${updateInfo.npmPackage} ${updateInfo.installedVersion} -> ${updateInfo.latestVersion})`
  | DismissUpdateBanner => `DismissUpdateBanner`
  }
}

module Selectors = {
  let getMessageId = Message.getId

  // Get the current task - always returns a Task.t (never None)
  let currentTask = (state: state): Task.t => {
    switch state.currentTask {
    | Task.New(task) => task
    | Task.Selected(id) =>
      state.tasks
      ->Dict.get(id)
      ->Option.getOrThrow(~message=`[Selectors.currentTask] Selected task ${id} not found in dict`)
    }
  }

  // Get current task ID (None for New tasks)
  let currentTaskId = (state: state): option<string> => {
    switch state.currentTask {
    | Task.New(_) => None
    | Task.Selected(id) => Some(id)
    }
  }

  // Get the stable client-side identifier for React keys (prevents iframe remounts)
  let currentTaskClientId = (state: state): string => {
    Task.getClientId(currentTask(state))
  }

  // State predicates
  let isNewTask = (state: state): bool => Task.isNew(currentTask(state))
  let isCurrentTaskUnloaded = (state: state): bool => Task.isUnloaded(currentTask(state))
  let isCurrentTaskLoading = (state: state): bool => Task.isLoading(currentTask(state))
  let isCurrentTaskLoaded = (state: state): bool => Task.isLoaded(currentTask(state))

  // Delegate to Task helpers
  let getMessageCreatedAt = TaskReducer.Selectors.getMessageCreatedAt

  let messages = (state: state): array<Message.t> => {
    Task.getMessages(currentTask(state))
  }

  let isStreaming = (state: state): bool => {
    TaskReducer.Selectors.isStreaming(currentTask(state))->Option.getOr(false)
  }

  let previewFrame = (state: state): Task.previewFrame => {
    Task.getPreviewFrame(currentTask(state), ~defaultUrl=getInitialUrl())
  }

  let annotationMode = (state: state): Client__Annotation__Types.annotationMode => {
    Task.getAnnotationMode(currentTask(state))
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

  let isAnimationFrozen = (state: state): bool => {
    Task.getIsAnimationFrozen(currentTask(state))
  }

  let isAgentRunning = (state: state): bool => {
    TaskReducer.Selectors.isAgentRunning(currentTask(state))->Option.getOr(false)
  }

  let currentPlanEntries = (state: state): array<Client__State__Types.ACPTypes.planEntry> => {
    TaskReducer.Selectors.planEntries(currentTask(state))->Option.getOr([])
  }

  let turnError = (state: state): option<string> => {
    TaskReducer.Selectors.turnError(currentTask(state))
  }

  // Resolve an image attachment URI from a specific task's accumulated attachments.
  // Used by the MCP server to resolve write_file image_ref before forwarding to relay.
  // Takes taskId (not currentTask) because the agent's task may differ from the viewed tab.
  let resolveImageRef = (state: state, ~taskId: string, ~uri: string): option<
    Message.resolvedImageData,
  > => {
    state.tasks
    ->Dict.get(taskId)
    ->Option.flatMap(task => Task.getImageAttachments(task)->Dict.get(uri))
    ->Option.map(Message.resolveAttachmentImage)
  }

  // Derived selectors (use messages from above)
  let completedMessages = (state: state) =>
    messages(state)->Array.filter(msg => {
      switch msg {
      | User(_) => true
      | Assistant(Completed(_)) => true
      | Assistant(Streaming(_)) => false
      | ToolCall({state: OutputAvailable | OutputError, _}) => true
      | ToolCall(_) => false
      }
    })

  let lastMessage = (state: state) => {
    let msgs = messages(state)
    msgs->Array.get(Array.length(msgs) - 1)
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

  // Task collection selectors
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

  // Global state selectors
  let acpSession = (state: state): Client__State__Types.acpSession => {
    state.acpSession
  }

  let hasActiveACPSession = (state: state): bool => {
    switch state.acpSession {
    | AcpSessionActive(_) => true
    | NoAcpSession => false
    }
  }

  let sessionInitialized = (state: state): bool => {
    state.sessionInitialized
  }

  // Get usage info
  let usageInfo = (state: state): option<Client__State__Types.usageInfo> => {
    state.usageInfo
  }

  // Get user profile
  let userProfile = (state: state): option<Client__State__Types.userProfile> => {
    state.userProfile
  }

  // Get OpenRouter API key settings
  let openrouterKeySettings = (state: state): Client__State__Types.apiKeySettings => {
    state.openrouterKeySettings
  }

  // Get Anthropic API key settings
  let anthropicKeySettings = (state: state): Client__State__Types.apiKeySettings => {
    state.anthropicKeySettings
  }

  // Get models config
  let modelsConfig = (state: state): option<Client__State__Types.modelsConfig> => {
    state.modelsConfig
  }

  // Get selected model
  let selectedModel = (state: state): option<Client__State__Types.modelSelection> => {
    state.selectedModel
  }

  // Get Anthropic OAuth status
  let anthropicOAuthStatus = (state: state): Client__State__Types.anthropicOAuthStatus => {
    state.anthropicOAuthStatus
  }

  // Get ChatGPT OAuth status
  let chatgptOAuthStatus = (state: state): Client__State__Types.chatgptOAuthStatus => {
    state.chatgptOAuthStatus
  }

  // Get update info for the banner
  let updateInfo = (state: state): option<Client__State__Types.updateInfo> => {
    state.updateInfo
  }

  let updateCheckStatus = (state: state): Client__State__Types.updateCheckStatus => {
    state.updateCheckStatus
  }

  let updateBannerDismissed = (state: state): bool => {
    state.updateBannerDismissed
  }

  // Pending question for the current task (shown in the drawer)
  let pendingQuestion = (state: state): option<Client__Question__Types.pendingQuestion> => {
    switch state.currentTask {
    | Task.Selected(id) =>
      state.tasks->Dict.get(id)->Option.flatMap(TaskReducer.Selectors.pendingQuestion)
    | Task.New(_) => None
    }
  }

  // Whether the user has any API provider configured via state-tracked sources
  // (DB-stored OpenRouter key, Anthropic API key, or OAuth).
  // Env-injected keys (window.__frontmanRuntime) live outside state — check RuntimeConfig separately.
  let hasAnyProviderConfigured = (state: state): bool => {
    switch state.usageInfo {
    | Some({hasUserKey: Some(true)}) => true
    | _ =>
      switch state.anthropicOAuthStatus {
      | Connected(_) => true
      | _ =>
        switch state.chatgptOAuthStatus {
        | ChatGPTConnected(_) => true
        | _ =>
          switch state.anthropicKeySettings.source {
          | Client__State__Types.UserOverride | Client__State__Types.FromEnv => true
          | _ => false
          }
        }
      }
    }
  }
}

// ============================================================================
// Effect handler helpers (extracted for reuse)
// ============================================================================

// Build ACP content blocks for image/file attachments
// Strips the data:mime;base64, prefix and creates resource blocks with BlobResourceContents
let buildAttachmentContentBlocks = (attachments: array<Client__Message.fileAttachmentData>): array<
  Client__State__Types.ACPTypes.contentBlock,
> => {
  attachments->Array.map(att => {
    // Strip "data:mime;base64," prefix to get raw base64
    let base64Data = switch att.dataUrl->String.indexOf(";base64,") {
    | -1 => att.dataUrl
    | idx => att.dataUrl->String.slice(~start=idx + 8, ~end=String.length(att.dataUrl))
    }

    // Build _meta JSON
    let meta: JSON.t = %raw(`(function(filename) {
      return { "user_image": true, "filename": filename };
    })`)(att.filename)

    Client__State__Types.ACPTypes.EmbeddedResource({
      resource: {
        _meta: Some(meta),
        annotations: None,
        resource: Client__State__Types.ACPTypes.BlobResourceContents({
          uri: `attachment://${att.id}/${att.filename}`,
          mimeType: Some(att.mediaType),
          blob: base64Data,
        }),
      },
      _meta: None,
      annotations: None,
    })
  })
}

let sendMessageToAPIImpl = (
  state: state,
  dispatch,
  ~message,
  ~attachments: array<Client__Message.fileAttachmentData>=[],
  ~annotations: array<Client__Message.MessageAnnotation.t>=[],
  ~taskId,
) => {
  switch state.acpSession {
  | AcpSessionActive({sendPrompt}) =>
    // Page context from task (always included)
    let pageContextBlocks =
      state.tasks
      ->Dict.get(taskId)
      ->Option.mapOr([], Client__State__Types.taskToPageContextBlocks)

    // Annotation content blocks from the message (not task state)
    let annotationBlocks = Client__State__Types.messageAnnotationsToContentBlocks(annotations)

    // Build attachment content blocks
    let attachmentBlocks = buildAttachmentContentBlocks(attachments)
    let additionalBlocks = Array.concat(pageContextBlocks, annotationBlocks)->Array.concat(attachmentBlocks)

    // Include runtime config _meta (e.g., framework, openrouterKeyValue) with each prompt
    let runtimeConfig = Client__RuntimeConfig.read()
    let baseMeta = Client__RuntimeConfig.toMeta(runtimeConfig)

    // Add selected model to _meta if present
    let _meta = switch state.selectedModel {
    | Some(model) =>
      let modelJson: JSON.t = %raw(`(function(provider, value) {
        return { provider: provider, value: value };
      })`)(model.provider, model.value)
      switch baseMeta->JSON.Decode.object {
      | Some(dict) =>
        let newDict = dict->Dict.copy
        newDict->Dict.set("model", modelJson)
        Some(newDict->Obj.magic)
      | None => Some(baseMeta)
      }
    | None => Some(baseMeta)
    }

    sendPrompt(
      message,
      ~additionalBlocks,
      ~onComplete=_result => {
        // Flush any buffered text deltas before completing the turn.
        // Without this, a rAF-buffered delta could fire after TurnCompleted,
        // reopening a Completed message as Streaming permanently.
        Client__TextDeltaBuffer.flush()
        // Always dispatch — the reducer gates TurnCompleted on isAgentRunning,
        // so duplicates (from notification + RPC) and post-cancel arrivals
        // are no-ops.
        dispatch(TaskAction({target: ForTask(taskId), action: TurnCompleted}))
      },
      ~_meta,
    )
  | NoAcpSession => Log.error("Cannot send message: no active ACP session")
  }
}

let fetchUsageInfoImpl = (dispatch, ~apiBaseUrl) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/api-key-usage`

    try {
      let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
      if response.ok {
        let json = await response->WebAPI.Response.json
        let usageInfo = S.parseJsonOrThrow(json, Client__State__Types.usageInfoSchema)
        dispatch(UsageInfoReceived({usageInfo: usageInfo}))
      }
    } catch {
    | exn => Log.error(~ctx={"error": exn}, "FetchUsageInfo failed")
    }
  }
  fetch()->ignore
}

let fetchUserProfileImpl = (dispatch, ~apiBaseUrl) => {
  let fetch = async () => {
    let url = `${apiBaseUrl}/api/user/me`

    try {
      let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
      if response.ok {
        let json = await response->WebAPI.Response.json
        let userProfile = S.parseJsonOrThrow(json, Client__State__Types.userProfileSchema)
        dispatch(UserProfileReceived({userProfile: userProfile}))
      }
    } catch {
    | exn => Log.error(~ctx={"error": exn}, "FetchUserProfile failed")
    }
  }
  fetch()->ignore
}

let handleEffect = (effect, state: state, dispatch) => {
  switch effect {
  | FetchUsageInfo({apiBaseUrl}) => fetchUsageInfoImpl(dispatch, ~apiBaseUrl)
  | FetchUserProfileEffect({apiBaseUrl}) => fetchUserProfileImpl(dispatch, ~apiBaseUrl)
  | TaskEffect({target, effect: taskEffect}) => {
      // Resolve taskId for dispatching task actions back
      let taskDispatch = (taskAction: TaskReducer.action) => {
        dispatch(TaskAction({target, action: taskAction}))
      }

      // Handle delegation from task effects
      let delegate = (delegated: TaskReducer.delegated) => {
        switch delegated {
        | NeedSendMessage({text, attachments, annotations}) =>
          // Resolve the taskId from target
          let taskId = switch target {
          | ForTask(id) => id
          | CurrentTask =>
            switch state.currentTask {
            | Task.Selected(id) => id
            | Task.New(_) =>
              failwith("[TaskEffect] NeedSendMessage from CurrentTask but currentTask is New")
            }
          }
          sendMessageToAPIImpl(state, dispatch, ~message=text, ~attachments, ~annotations, ~taskId)
        | NeedUsageRefresh =>
          switch state.acpSession {
          | AcpSessionActive({apiBaseUrl}) => fetchUsageInfoImpl(dispatch, ~apiBaseUrl)
          | NoAcpSession => ()
          }
        | NeedCancelPrompt =>
          switch state.acpSession {
          | AcpSessionActive({cancelPrompt}) => cancelPrompt()
          | NoAcpSession => Log.error("Cannot cancel prompt: no active ACP session")
          }
        }
      }

      TaskReducer.handleEffect(taskEffect, ~dispatch=taskDispatch, ~delegate)
    }
  | FetchApiKeySettingsEffect({apiBaseUrl}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/user/api-key-usage`

      try {
        let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
        if response.ok {
          let json = await response->WebAPI.Response.json
          let usageInfo = S.parseJsonOrThrow(json, Client__State__Types.usageInfoSchema)
          let hasUserKey = usageInfo.hasUserKey->Option.getOr(false)

          // Check if the Next.js project has OPENROUTER_API_KEY from runtime config
          // This is set by the framework middleware (e.g., FrontmanNextjs__Middleware)
          let runtimeConfig = Client__RuntimeConfig.read()
          let hasEnvKey = Client__RuntimeConfig.hasOpenrouterKey(runtimeConfig)

          // Determine the source: user key takes precedence, then env key, else none
          let source: Client__State__Types.apiKeySource = if hasUserKey {
            UserOverride
          } else if hasEnvKey {
            FromEnv
          } else {
            None
          }
          dispatch(ApiKeySettingsReceived({source: source}))
        }
      } catch {
      | exn => Log.error(~ctx={"error": exn}, "FetchApiKeySettings failed")
      }
    }
    fetch()->ignore
  | SaveOpenRouterKeyEffect({apiBaseUrl, key}) =>
    let save = async () => {
      dispatch(OpenRouterKeySaveStarted)
      let url = `${apiBaseUrl}/api/user/api-keys`
      let body = {
        "provider": "openrouter",
        "key": key,
      }

      try {
        let response = await WebAPI.Global.fetch(
          url,
          ~init={
            credentials: Include,
            method: "POST",
            headers: WebAPI.HeadersInit.fromDict(
              Dict.fromArray([("Content-Type", "application/json")]),
            ),
            body: WebAPI.BodyInit.fromString(JSON.stringifyAny(body)->Option.getOr("{}")),
          },
        )

        if !response.ok {
          dispatch(
            OpenRouterKeySaveError({
              error: `HTTP ${response.status->Int.toString}: ${response.statusText}`,
            }),
          )
        } else {
          dispatch(OpenRouterKeySaved)
        }
      } catch {
      | exn =>
        let msg =
          exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        dispatch(OpenRouterKeySaveError({error: `Failed to save API key: ${msg}`}))
      }
    }
    save()->ignore
  | FetchAnthropicApiKeySettingsEffect({apiBaseUrl}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/user/api-key-usage?provider=anthropic`

      try {
        let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
        if response.ok {
          let json = await response->WebAPI.Response.json
          let usageInfo = S.parseJsonOrThrow(json, Client__State__Types.usageInfoSchema)
          let hasUserKey = usageInfo.hasUserKey->Option.getOr(false)

          let runtimeConfig = Client__RuntimeConfig.read()
          let hasEnvKey = Client__RuntimeConfig.hasAnthropicKey(runtimeConfig)

          let source: Client__State__Types.apiKeySource = if hasUserKey {
            UserOverride
          } else if hasEnvKey {
            FromEnv
          } else {
            None
          }
          dispatch(AnthropicApiKeySettingsReceived({source: source}))
        }
      } catch {
      | exn => Log.error(~ctx={"error": exn}, "FetchAnthropicApiKeySettings failed")
      }
    }
    fetch()->ignore
  | SaveAnthropicKeyEffect({apiBaseUrl, key}) =>
    let save = async () => {
      dispatch(AnthropicKeySaveStarted)
      let url = `${apiBaseUrl}/api/user/api-keys`
      let body = {
        "provider": "anthropic",
        "key": key,
      }

      try {
        let response = await WebAPI.Global.fetch(
          url,
          ~init={
            credentials: Include,
            method: "POST",
            headers: WebAPI.HeadersInit.fromDict(
              Dict.fromArray([("Content-Type", "application/json")]),
            ),
            body: WebAPI.BodyInit.fromString(JSON.stringifyAny(body)->Option.getOr("{}")),
          },
        )

        if !response.ok {
          dispatch(
            AnthropicKeySaveError({
              error: `HTTP ${response.status->Int.toString}: ${response.statusText}`,
            }),
          )
        } else {
          dispatch(AnthropicKeySaved)
        }
      } catch {
      | exn =>
        let msg =
          exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        dispatch(AnthropicKeySaveError({error: `Failed to save API key: ${msg}`}))
      }
    }
    save()->ignore
  | FetchModelsConfigEffect({apiBaseUrl}) =>
    let fetch = async () => {
      // Pass env key presence so server can return full or free-tier model list
      let runtimeConfig = Client__RuntimeConfig.read()
      let hasEnvKey = Client__RuntimeConfig.hasOpenrouterKey(runtimeConfig)
      let hasAnthropicEnvKey = Client__RuntimeConfig.hasAnthropicKey(runtimeConfig)
      let envKeyParam = if hasEnvKey { "true" } else { "false" }
      let anthropicEnvKeyParam = if hasAnthropicEnvKey { "true" } else { "false" }
      let url = `${apiBaseUrl}/api/models?hasEnvKey=${envKeyParam}&hasAnthropicEnvKey=${anthropicEnvKeyParam}`

      try {
        let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
        if response.ok {
          let json = await response->WebAPI.Response.json
          let config = S.parseJsonOrThrow(json, Client__State__Types.modelsConfigSchema)
          dispatch(ModelsConfigReceived({config: config}))
        }
      } catch {
      | exn => Log.error(~ctx={"error": exn}, "FetchModelsConfig failed")
      }
    }
    fetch()->ignore

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
            headers: WebAPI.HeadersInit.fromDict(
              Dict.fromArray([("Content-Type", "application/json")]),
            ),
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

  | FetchChatGPTOAuthStatusEffect({apiBaseUrl}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/oauth/chatgpt/status`

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
          dispatch(ChatGPTOAuthStatusReceived({connected, expiresAt}))
        }
      } catch {
      | _ =>
        dispatch(
          ChatGPTOAuthError({deviceAuthId: None, error: "Failed to fetch ChatGPT OAuth status"}),
        )
      }
    }
    fetch()->ignore

  | InitiateChatGPTDeviceAuthEffect({apiBaseUrl}) =>
    let fetch = async () => {
      let url = `${apiBaseUrl}/api/oauth/chatgpt/initiate`

      try {
        let response = await WebAPI.Global.fetch(
          url,
          ~init={
            method: "POST",
            credentials: Include,
            headers: WebAPI.HeadersInit.fromDict(
              Dict.fromArray([("Content-Type", "application/json")]),
            ),
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
            dispatch(ChatGPTDeviceCodeReceived({deviceAuthId, userCode, verificationUrl}))
          | _ =>
            dispatch(ChatGPTOAuthError({deviceAuthId: None, error: "Invalid response from server"}))
          }
        } else {
          dispatch(
            ChatGPTOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}),
          )
        }
      } catch {
      | _ =>
        dispatch(
          ChatGPTOAuthError({deviceAuthId: None, error: "Failed to initiate authentication"}),
        )
      }
    }
    fetch()->ignore

  | PollChatGPTDeviceAuthEffect({apiBaseUrl, deviceAuthId, userCode}) =>
    // Poll our server every 5 seconds for up to 15 minutes (180 attempts)
    // Server is stateless — we send device_auth_id + user_code on each poll
    // Each dispatch carries deviceAuthId so the reducer can reject stale results
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
            ChatGPTOAuthError({
              deviceAuthId: Some(deviceAuthId),
              error: "Authorization timed out. Please try again.",
            }),
          )
        } else {
          try {
            let url = `${apiBaseUrl}/api/oauth/chatgpt/poll`
            let response = await WebAPI.Global.fetch(
              url,
              ~init={
                method: "POST",
                credentials: Include,
                headers: WebAPI.HeadersInit.fromDict(
                  Dict.fromArray([("Content-Type", "application/json")]),
                ),
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
                dispatch(ChatGPTOAuthConnected({deviceAuthId, expiresAt}))
              | _ =>
                // "pending" — wait and try again
                await Promise.make((resolve, _) => {
                  let _ = Js.Global.setTimeout(() => resolve(), intervalMs)
                })
                await pollLoop(attempt + 1)
              }
            } else if response.status == 403 {
              dispatch(
                ChatGPTOAuthError({
                  deviceAuthId: Some(deviceAuthId),
                  error: "Authorization was declined.",
                }),
              )
            } else {
              await Promise.make((resolve, _) => {
                let _ = Js.Global.setTimeout(() => resolve(), intervalMs)
              })
              await pollLoop(attempt + 1)
            }
          } catch {
          | _ =>
            await Promise.make((resolve, _) => {
              let _ = Js.Global.setTimeout(() => resolve(), intervalMs)
            })
            await pollLoop(attempt + 1)
          }
        }
      }
      await pollLoop(0)
    }
    poll()->ignore

  | DisconnectChatGPTOAuthEffect({apiBaseUrl}) =>
    let disconnect = async () => {
      let url = `${apiBaseUrl}/api/oauth/chatgpt/disconnect`

      try {
        let response = await WebAPI.Global.fetch(
          url,
          ~init={
            method: "DELETE",
            credentials: Include,
          },
        )
        if response.ok {
          dispatch(ChatGPTOAuthDisconnected)
        } else {
          dispatch(ChatGPTOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
        }
      } catch {
      | _ => dispatch(ChatGPTOAuthError({deviceAuthId: None, error: "Failed to disconnect"}))
      }
    }
    disconnect()->ignore

  | LoadTaskEffect({taskId}) =>
    switch state.acpSession {
    | AcpSessionActive({loadTask}) =>
      let taskIdToLoad = taskId
      // Check if task needs history loading or just channel activation
      let needsHistory = switch state.tasks->Dict.get(taskId) {
      | Some(task) => !Task.isLoaded(task)
      | None => true
      }
      loadTask(taskId, ~needsHistory, ~onComplete=result => {
        switch result {
        | Ok() =>
          // Only dispatch LoadComplete if we actually loaded history
          // (task was in Loading state). If task was already Loaded,
          // we just re-activated the channel - no state transition needed.
          if needsHistory {
            // Flush buffered text deltas before completing the load.
            // Agent messages go through the rAF-based TextDeltaBuffer,
            // so they may still be pending when the session/load RPC
            // response arrives. Without this flush, LoadComplete
            // transitions the task to Loaded({isAgentRunning: false}),
            // and the guard in TaskReducer drops any late TextDeltaReceived
            // actions — causing agent messages to silently vanish.
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
          let {versions} = S.parseJsonOrThrow(
            json,
            Client__State__Types.latestVersionsResponseSchema,
          )
          switch versions->Dict.get(npmPackage)->Option.flatMap(v => v) {
          | Some(latest) =>
            // Only show banner when installed is strictly behind latest
            // (pre-release < release per semver). Unparseable → no banner.
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
      | exn =>
        Sentry.captureException(exn, ~operation="CheckForUpdate")
      }
    }
    fetch()->ignore
  }
}

let next = (state: state, action) => {
  switch action {
  // ============================================================================
  // Task-scoped action routing
  // ============================================================================
  | TaskAction({target, action: taskAction}) =>
    switch target {
    | CurrentTask => state->Lens.delegateToTask(state.currentTask, taskAction)
    | ForTask(taskId) => state->Lens.delegateToTask(Task.Selected(taskId), taskAction)
    }

  // ============================================================================
  // AddUserMessage - cross-cutting (creates tasks, manages dict)
  // ============================================================================
  | AddUserMessage({id, sessionId, content, annotations}) => {
      let textContent = TaskReducer.extractTextFromUserContent(content)

      switch state.currentTask {
      | Task.New(newTask) =>
        // New -> Loaded: promote to persisted task, then delegate message creation
        let loadedTask = Task.newToLoaded(newTask, ~id=sessionId, ~title=textContent)
        let updatedTasks = state.tasks->Dict.copy
        updatedTasks->Dict.set(sessionId, loadedTask)
        let promotedState = {
          ...state,
          tasks: updatedTasks,
          currentTask: Task.Selected(sessionId),
        }
        // Delegate AddUserMessage to the (now Loaded) task reducer
        promotedState->Lens.delegateToTask(
          Task.Selected(sessionId),
          TaskReducer.AddUserMessage({id, content, annotations}),
        )
      | Task.Selected(taskId) =>
        state->Lens.delegateToTask(Task.Selected(taskId), TaskReducer.AddUserMessage({id, content, annotations}))
      }
    }

  // ============================================================================
  // Cancel current turn - delegates to task reducer and sends cancel notification
  // ============================================================================
  | CancelTurn =>
    switch state.currentTask {
    | Task.Selected(taskId) =>
      state->Lens.delegateToTask(Task.Selected(taskId), TaskReducer.CancelTurn)
    | Task.New(_) =>
      // No task to cancel
      state->StateReducer.update
    }

  // ============================================================================
  // Task management actions
  // ============================================================================
  | CreateTask =>
    {
      ...state,
      currentTask: Task.New(Task.makeNew(~previewUrl=getInitialUrl())),
    }->StateReducer.update
  | SwitchTask({taskId}) => {
      let task = state.tasks->Dict.get(taskId)->Option.getOrThrow
      let needsLoad = Task.isUnloaded(task)
      let (updatedState, taskEffects) = if needsLoad {
        state->Lens.delegateToTask(
          Task.Selected(taskId),
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

  // Delete task
  | DeleteTask({taskId}) => {
      let updatedTasks = state.tasks->Dict.copy
      updatedTasks->Dict.delete(taskId)

      // If deleting current task, switch to most recent or New
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

      // Persist deletion to server (fire and forget - optimistic UI)
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
    {
      ...state,
      currentTask: Task.New(Task.makeNew(~previewUrl=getInitialUrl())),
    }->StateReducer.update

  | UpdateTaskTitle({taskId, title}) =>
    switch state.tasks->Dict.get(taskId) {
    | Some(_) =>
      state
      ->Lens.updateTask(taskId, task => Task.setTitle(task, title))
      ->StateReducer.update
    | None =>
      // Task was deleted before the async title update arrived — ignore silently
      state->StateReducer.update
    }

  // ============================================================================
  // ACP session actions
  // ============================================================================

  | SetAcpSession({sendPrompt, cancelPrompt, loadTask, deleteSession, apiBaseUrl}) =>
    // Just set up session callbacks - task creation happens in AddUserMessage
    // when user sends their first message (lazy session creation)
    // apiBaseUrl is co-located in AcpSessionActive to make illegal state unrepresentable
    {
      ...state,
      acpSession: AcpSessionActive({sendPrompt, cancelPrompt, loadTask, deleteSession, apiBaseUrl}),
      sessionInitialized: true,
    }->StateReducer.update(
      ~sideEffects=[
        FetchUsageInfo({apiBaseUrl: apiBaseUrl}),
        FetchUserProfileEffect({apiBaseUrl: apiBaseUrl}),
        FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl}),
        FetchAnthropicOAuthStatusEffect({apiBaseUrl: apiBaseUrl}),
        FetchChatGPTOAuthStatusEffect({apiBaseUrl: apiBaseUrl}),
      ],
    )

  | ClearAcpSession =>
    // Clear pending questions across all tasks — the connection is gone,
    // so we can't resolve tool promises via the channel. The resolver
    // callbacks are now stale. When the user reconnects and loads the task,
    // the server-side executor's safety-net timeout (24h) will eventually expire.
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
    {...state, tasks: updatedTasks, acpSession: NoAcpSession}->StateReducer.update

  // ============================================================================
  // Global state actions
  // ============================================================================

  | UsageInfoReceived({usageInfo}) =>
    // Update usage info in state
    {...state, usageInfo: Some(usageInfo)}->StateReducer.update

  | UserProfileReceived({userProfile}) =>
    // Identify user in Heap Analytics
    Client__Heap.identify(userProfile.id)
    Client__Heap.addUserProperties({
      "Email": userProfile.email,
      "Name": userProfile.name->Option.getOr(""),
    })
    {...state, userProfile: Some(userProfile)}->StateReducer.update

  // API key settings actions
  | FetchApiKeySettings =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->StateReducer.update(
        ~sideEffects=[FetchApiKeySettingsEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | ApiKeySettingsReceived({source}) =>
    {
      ...state,
      openrouterKeySettings: {
        ...state.openrouterKeySettings,
        source,
      },
    }->StateReducer.update

  | SaveOpenRouterKey({key}) =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->StateReducer.update(
        ~sideEffects=[SaveOpenRouterKeyEffect({apiBaseUrl, key})],
      )
    | NoAcpSession =>
      {
        ...state,
        openrouterKeySettings: {
          ...state.openrouterKeySettings,
          saveStatus: SaveError("No active ACP session"),
        },
      }->StateReducer.update
    }

  | OpenRouterKeySaveStarted =>
    {
      ...state,
      openrouterKeySettings: {
        ...state.openrouterKeySettings,
        saveStatus: Saving,
      },
    }->StateReducer.update

  | OpenRouterKeySaved =>
    // After saving the API key, refresh usage info and models list
    // so the chatbox reflects the new state and unlocked models appear
    let effects = switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) => [
        FetchUsageInfo({apiBaseUrl: apiBaseUrl}),
        FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl}),
      ]
    | NoAcpSession => []
    }
    {
      ...state,
      openrouterKeySettings: {
        source: UserOverride,
        saveStatus: Saved,
      },
      pendingProviderAutoSelect: Some("openrouter"),
    }->StateReducer.update(~sideEffects=effects)

  | OpenRouterKeySaveError({error}) =>
    {
      ...state,
      openrouterKeySettings: {
        ...state.openrouterKeySettings,
        saveStatus: SaveError(error),
      },
    }->StateReducer.update

  | ResetOpenRouterKeySaveStatus =>
    {
      ...state,
      openrouterKeySettings: {
        ...state.openrouterKeySettings,
        saveStatus: Idle,
      },
    }->StateReducer.update

  // Anthropic API key settings actions
  | FetchAnthropicApiKeySettings =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->StateReducer.update(
        ~sideEffects=[FetchAnthropicApiKeySettingsEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | AnthropicApiKeySettingsReceived({source}) =>
    {
      ...state,
      anthropicKeySettings: {
        ...state.anthropicKeySettings,
        source,
      },
    }->StateReducer.update

  | SaveAnthropicKey({key}) =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->StateReducer.update(
        ~sideEffects=[SaveAnthropicKeyEffect({apiBaseUrl, key})],
      )
    | NoAcpSession =>
      {
        ...state,
        anthropicKeySettings: {
          ...state.anthropicKeySettings,
          saveStatus: SaveError("No active ACP session"),
        },
      }->StateReducer.update
    }

  | AnthropicKeySaveStarted =>
    {
      ...state,
      anthropicKeySettings: {
        ...state.anthropicKeySettings,
        saveStatus: Saving,
      },
    }->StateReducer.update

  | AnthropicKeySaved =>
    // After saving the API key, refresh models list so Anthropic models appear
    let effects = switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) => [
        FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl}),
      ]
    | NoAcpSession => []
    }
    {
      ...state,
      anthropicKeySettings: {
        source: UserOverride,
        saveStatus: Saved,
      },
      pendingProviderAutoSelect: Some("anthropic"),
    }->StateReducer.update(~sideEffects=effects)

  | AnthropicKeySaveError({error}) =>
    {
      ...state,
      anthropicKeySettings: {
        ...state.anthropicKeySettings,
        saveStatus: SaveError(error),
      },
    }->StateReducer.update

  | ResetAnthropicKeySaveStatus =>
    {
      ...state,
      anthropicKeySettings: {
        ...state.anthropicKeySettings,
        saveStatus: Idle,
      },
    }->StateReducer.update

  // Model selection actions
  | FetchModelsConfig =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->StateReducer.update(
        ~sideEffects=[FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | ModelsConfigReceived({config}) =>
    // When a provider was just connected, auto-select its first model.
    // Otherwise keep the current selection (or fall back to server default).
    let (selectedModel, didAutoSelect) = switch state.pendingProviderAutoSelect {
    | Some(providerId) =>
      // Find the first model from the newly connected provider
      let providerModel =
        config.providers
        ->Array.find(p => p.id == providerId)
        ->Option.flatMap(p => p.models->Array.get(0))
        ->Option.map((m): Client__State__Types.modelSelection => {
          provider: providerId,
          value: m.value,
        })
      switch providerModel {
      | Some(model) => (Some(model), true)
      | None => (state.selectedModel, false)
      }
    | None =>
      switch state.selectedModel {
      | Some(model) => (Some(model), false)
      | None => // Use default model from config
        (
          Some(
            (
              {
                provider: config.defaultModel.provider,
                value: config.defaultModel.value,
              }: Client__State__Types.modelSelection
            ),
          ),
          true,
        )
      }
    }
    // Persist whenever we picked a new model
    switch (didAutoSelect, selectedModel) {
    | (true, Some(model)) => saveSelectedModelToStorage(model)
    | _ => ()
    }
    {
      ...state,
      modelsConfig: Some(config),
      selectedModel,
      pendingProviderAutoSelect: None,
    }->StateReducer.update

  | SetSelectedModel({model}) =>
    // Save to localStorage for persistence
    saveSelectedModelToStorage(model)
    {...state, selectedModel: Some(model)}->StateReducer.update

  // Anthropic OAuth actions
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
        // Parse ISO8601 date string to timestamp
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
      }->StateReducer.update(
        ~sideEffects=[ExchangeAnthropicOAuthCodeEffect({apiBaseUrl, code, verifier})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | AnthropicOAuthConnected({expiresAt}) =>
    let expiresAtMs = Date.fromString(expiresAt)->Date.getTime
    // Refresh models when connected (adds Anthropic provider)
    let effects = switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) => [FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl})]
    | NoAcpSession => []
    }
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Connected({expiresAt: expiresAtMs}),
      pendingProviderAutoSelect: Some("anthropic"),
    }->StateReducer.update(~sideEffects=effects)

  | AnthropicOAuthError({error}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Error(error),
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
    // Refresh models when disconnected (removes Anthropic provider)
    let effects = switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) => [FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl})]
    | NoAcpSession => []
    }
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.NotConnected,
    }->StateReducer.update(~sideEffects=effects)

  | ResetAnthropicOAuthError =>
    // Reset error state back to NotConnected
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

  // ChatGPT OAuth actions
  | FetchChatGPTOAuthStatus =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTFetchingStatus,
      }->StateReducer.update(
        ~sideEffects=[FetchChatGPTOAuthStatusEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | ChatGPTOAuthStatusReceived({connected, expiresAt}) =>
    let status = if connected {
      switch expiresAt {
      | Some(expiresAtStr) =>
        let expiresAtMs = Date.fromString(expiresAtStr)->Date.getTime
        Client__State__Types.ChatGPTConnected({expiresAt: expiresAtMs})
      | None => Client__State__Types.ChatGPTConnected({expiresAt: 0.0})
      }
    } else {
      Client__State__Types.ChatGPTNotConnected
    }
    // Refresh models when ChatGPT status changes (may add/remove provider)
    let effects = switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) => [FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl})]
    | NoAcpSession => []
    }
    {...state, chatgptOAuthStatus: status}->StateReducer.update(
      ~sideEffects=effects,
    )

  | InitiateChatGPTOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTWaitingForCode,
      }->StateReducer.update(
        ~sideEffects=[InitiateChatGPTDeviceAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | ChatGPTDeviceCodeReceived({deviceAuthId, userCode, verificationUrl}) =>
    // Show the code to the user and start polling our server
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTShowingCode({
          deviceAuthId,
          userCode,
          verificationUrl,
        }),
      }->StateReducer.update(
        ~sideEffects=[PollChatGPTDeviceAuthEffect({apiBaseUrl, deviceAuthId, userCode})],
      )
    | NoAcpSession =>
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTShowingCode({
          deviceAuthId,
          userCode,
          verificationUrl,
        }),
      }->StateReducer.update
    }

  | ChatGPTOAuthConnected({deviceAuthId, expiresAt}) =>
    // Only accept if the current state is showing the same deviceAuthId
    // (ignores stale results from old polling loops after retry)
    switch state.chatgptOAuthStatus {
    | Client__State__Types.ChatGPTShowingCode({deviceAuthId: currentId})
      if currentId == deviceAuthId =>
      let expiresAtMs = Date.fromString(expiresAt)->Date.getTime
      // Refresh models when connected (adds ChatGPT provider)
      let effects = switch state.acpSession {
      | AcpSessionActive({apiBaseUrl}) => [FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl})]
      | NoAcpSession => []
      }
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTConnected({expiresAt: expiresAtMs}),
        pendingProviderAutoSelect: Some("openai"),
      }->StateReducer.update(~sideEffects=effects)
    | _ => state->StateReducer.update
    }

  | ChatGPTOAuthError({deviceAuthId, error}) =>
    // If deviceAuthId is provided (from poll loop), only accept if current
    // state is showing the same deviceAuthId — rejects stale poll results.
    // If no deviceAuthId (from status/initiate/disconnect), apply unconditionally.
    let isStale = switch deviceAuthId {
    | Some(id) =>
      switch state.chatgptOAuthStatus {
      | Client__State__Types.ChatGPTShowingCode({deviceAuthId: currentId}) => currentId != id
      | _ => true // state already moved past ShowingCode
      }
    | None => false
    }
    if isStale {
      state->StateReducer.update
    } else {
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTError(error),
      }->StateReducer.update
    }

  | DisconnectChatGPTOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->StateReducer.update(
        ~sideEffects=[DisconnectChatGPTOAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->StateReducer.update
    }

  | ChatGPTOAuthDisconnected =>
    // Refresh models when disconnected (removes ChatGPT provider)
    let effects = switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) => [FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl})]
    | NoAcpSession => []
    }
    {
      ...state,
      chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
    }->StateReducer.update(~sideEffects=effects)

  | ResetChatGPTOAuthError =>
    switch state.chatgptOAuthStatus {
    | Client__State__Types.ChatGPTError(_) =>
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
      }->StateReducer.update
    | _ => state->StateReducer.update
    }

  // ============================================================================
  // Session loading actions
  // ============================================================================

  | SessionsLoadStarted =>
    {
      ...state,
      sessionsLoadState: Client__State__Types.SessionsLoading,
    }->StateReducer.update

  | SessionsLoadSuccess({sessions}) =>
    // Add persisted sessions to tasks dict (only if not already present)
    let previewUrl = getInitialUrl()
    let updatedTasks = state.tasks->Dict.copy

    sessions->Array.forEach(session => {
      // Skip if task already exists
      if !(updatedTasks->Dict.has(session.sessionId)) {
        // Parse ISO timestamps to float
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

  // ============================================================================
  // Update banner actions
  // ============================================================================

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

  | DismissUpdateBanner =>
    {...state, updateBannerDismissed: true}->StateReducer.update
  }
}
