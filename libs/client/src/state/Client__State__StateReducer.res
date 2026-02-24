let name = "Client::StateReducer"

// ============================================================================
// Type Re-exports from Client__State__Types
// ============================================================================

module UserContentPart = Client__State__Types.UserContentPart
module Message = Client__State__Types.Message
module SelectedElement = Client__State__Types.SelectedElement
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
  | AddUserMessage({id: string, sessionId: string, content: array<UserContentPart.t>})
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
  // Model selection actions
  | FetchModelsConfig
  | ModelsConfigReceived({config: Client__State__Types.modelsConfig})
  | SetSelectedModel({model: Client__State__Types.selectedModel})
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
      sessions: array<FrontmanFrontmanProtocol.FrontmanProtocol__ACP.sessionSummary>,
    })
  | SessionsLoadError({error: string})

type effect =
  | TaskEffect({target: taskTarget, effect: TaskReducer.effect})
  | FetchUsageInfo({apiBaseUrl: string})
  | FetchApiKeySettingsEffect({apiBaseUrl: string})
  | SaveOpenRouterKeyEffect({apiBaseUrl: string, key: string})
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
      {...state, currentTask: Task.New(updated)}->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=wrappedEffects,
      )
    | Task.Selected(id) =>
      let task = state.tasks->Dict.get(id)->Option.getOrThrow
      let (updated, taskEffects) = TaskReducer.next(task, taskAction)
      let wrappedEffects =
        taskEffects->Array.map(eff => TaskEffect({target: ForTask(id), effect: eff}))
      let tasks = state.tasks->Dict.copy
      tasks->Dict.set(id, updated)
      {...state, tasks}->FrontmanReactStatestore.StateReducer.update(~sideEffects=wrappedEffects)
    }
  }
}

let getInitialUrl = Client__BrowserUrl.getInitialUrl
let selectedModelStorageKey = "frontman:selectedModel"

// Load selected model from localStorage
let loadSelectedModelFromStorage = (): option<Client__State__Types.selectedModel> => {
  try {
    FrontmanBindings.LocalStorage.getItem(selectedModelStorageKey)
    ->Nullable.toOption
    ->Option.flatMap(jsonString => {
      try {
        Some(S.parseJsonStringOrThrow(jsonString, Client__State__Types.selectedModelSchema))
      } catch {
      | _ => None
      }
    })
  } catch {
  | _ => None
  }
}

// Save selected model to localStorage
let saveSelectedModelToStorage = (model: Client__State__Types.selectedModel): unit => {
  try {
    let jsonString = S.reverseConvertToJsonStringOrThrow(
      model,
      Client__State__Types.selectedModelSchema,
    )
    FrontmanBindings.LocalStorage.setItem(selectedModelStorageKey, jsonString)
  } catch {
  | exn => Console.error2("[saveSelectedModelToStorage] Failed:", exn)
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
  anthropicOAuthStatus: Client__State__Types.NotConnected,
  chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
  modelsConfig: None,
  selectedModel: loadSelectedModelFromStorage(), // Load from localStorage on init
  pendingProviderAutoSelect: None,
  sessionsLoadState: Client__State__Types.SessionsNotLoaded,
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

  let webPreviewIsSelecting = (state: state): bool => {
    Task.getWebPreviewIsSelecting(currentTask(state))
  }

  let selectedElement = (state: state): option<SelectedElement.t> => {
    Task.getSelectedElement(currentTask(state))
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

  // Get models config
  let modelsConfig = (state: state): option<Client__State__Types.modelsConfig> => {
    state.modelsConfig
  }

  // Get selected model
  let selectedModel = (state: state): option<Client__State__Types.selectedModel> => {
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

  // Whether the user has any API provider configured via state-tracked sources
  // (DB-stored OpenRouter key or Anthropic OAuth).
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
        | _ => false
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

    {
      Client__State__Types.ACPTypes.type_: "resource",
      text: None,
      uri: None,
      resource: Some({
        _meta: Some(meta),
        annotations: None,
        resource: Client__State__Types.ACPTypes.BlobResourceContents({
          uri: `attachment://${att.id}/${att.filename}`,
          mimeType: Some(att.mediaType),
          blob: base64Data,
        }),
      }),
      content: None,
    }
  })
}

let sendMessageToAPIImpl = (
  state: state,
  dispatch,
  ~message,
  ~attachments: array<Client__Message.fileAttachmentData>=[],
  ~taskId,
) => {
  switch state.acpSession {
  | AcpSessionActive({sendPrompt}) =>
    let contextBlocks =
      state.tasks
      ->Dict.get(taskId)
      ->Option.mapOr([], Client__State__Types.taskToContentBlocks)

    // Build attachment content blocks
    let attachmentBlocks = buildAttachmentContentBlocks(attachments)
    let additionalBlocks = Array.concat(contextBlocks, attachmentBlocks)

    // Include runtime config metadata (e.g., framework, openrouterKeyValue) with each prompt
    let runtimeConfig = Client__RuntimeConfig.read()
    let baseMetadata = Client__RuntimeConfig.toMetadata(runtimeConfig)

    // Add selected model to metadata if present
    let metadata = switch state.selectedModel {
    | Some(model) =>
      let modelJson: JSON.t = %raw(`(function(provider, value) {
        return { provider: provider, value: value };
      })`)(model.provider, model.value)
      switch baseMetadata->JSON.Decode.object {
      | Some(dict) =>
        let newDict = dict->Dict.copy
        newDict->Dict.set("model", modelJson)
        Some(newDict->Obj.magic)
      | None => Some(baseMetadata)
      }
    | None => Some(baseMetadata)
    }

    sendPrompt(
      message,
      ~additionalBlocks,
      ~onComplete=result => {
        switch result {
        | Ok({stopReason})
          if stopReason == "cancelled" => // CancelTurn already cleaned up state - don't dispatch TurnCompleted
          ()
        | Ok(_) => dispatch(TaskAction({target: ForTask(taskId), action: TurnCompleted}))
        | Error(_) => dispatch(TaskAction({target: ForTask(taskId), action: TurnCompleted}))
        }
      },
      ~metadata,
    )
  | NoAcpSession => Console.error("[Effect] Cannot send message: no active ACP session")
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
    | exn => Console.error2("[FetchUsageInfo] Failed:", exn)
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
    | exn => Console.error2("[FetchUserProfile] Failed:", exn)
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
        | NeedSendMessage({text, attachments}) =>
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
          sendMessageToAPIImpl(state, dispatch, ~message=text, ~attachments, ~taskId)
        | NeedUsageRefresh =>
          switch state.acpSession {
          | AcpSessionActive({apiBaseUrl}) => fetchUsageInfoImpl(dispatch, ~apiBaseUrl)
          | NoAcpSession => ()
          }
        | NeedCancelPrompt =>
          switch state.acpSession {
          | AcpSessionActive({cancelPrompt}) => cancelPrompt()
          | NoAcpSession => Console.error("[Effect] Cannot cancel prompt: no active ACP session")
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
      | exn => Console.error2("[FetchApiKeySettings] Failed:", exn)
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
  | FetchModelsConfigEffect({apiBaseUrl}) =>
    let fetch = async () => {
      // Pass env key presence so server can return full or free-tier model list
      let runtimeConfig = Client__RuntimeConfig.read()
      let hasEnvKey = Client__RuntimeConfig.hasOpenrouterKey(runtimeConfig)
      let envKeyParam = if hasEnvKey {
        "true"
      } else {
        "false"
      }
      let url = `${apiBaseUrl}/api/models?hasEnvKey=${envKeyParam}`

      try {
        let response = await WebAPI.Global.fetch(url, ~init={credentials: Include})
        if response.ok {
          let json = await response->WebAPI.Response.json
          let config = S.parseJsonOrThrow(json, Client__State__Types.modelsConfigSchema)
          dispatch(ModelsConfigReceived({config: config}))
        }
      } catch {
      | exn => Console.error2("[FetchModelsConfig] Failed:", exn)
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
  | AddUserMessage({id, sessionId, content}) => {
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
          TaskReducer.AddUserMessage({id, content}),
        )
      | Task.Selected(taskId) =>
        state->Lens.delegateToTask(Task.Selected(taskId), TaskReducer.AddUserMessage({id, content}))
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
      state->FrontmanReactStatestore.StateReducer.update
    }

  // ============================================================================
  // Task management actions
  // ============================================================================
  | CreateTask =>
    {
      ...state,
      currentTask: Task.New(Task.makeNew(~previewUrl=getInitialUrl())),
    }->FrontmanReactStatestore.StateReducer.update
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
      }->FrontmanReactStatestore.StateReducer.update(
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
      }->FrontmanReactStatestore.StateReducer.update
    }

  | ClearCurrentTask =>
    {
      ...state,
      currentTask: Task.New(Task.makeNew(~previewUrl=getInitialUrl())),
    }->FrontmanReactStatestore.StateReducer.update

  | UpdateTaskTitle({taskId, title}) =>
    switch state.tasks->Dict.get(taskId) {
    | Some(_) =>
      state
      ->Lens.updateTask(taskId, task => Task.setTitle(task, title))
      ->FrontmanReactStatestore.StateReducer.update
    | None =>
      // Task was deleted before the async title update arrived — ignore silently
      state->FrontmanReactStatestore.StateReducer.update
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
    }->FrontmanReactStatestore.StateReducer.update(
      ~sideEffects=[
        FetchUsageInfo({apiBaseUrl: apiBaseUrl}),
        FetchUserProfileEffect({apiBaseUrl: apiBaseUrl}),
        FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl}),
        FetchAnthropicOAuthStatusEffect({apiBaseUrl: apiBaseUrl}),
        FetchChatGPTOAuthStatusEffect({apiBaseUrl: apiBaseUrl}),
      ],
    )

  | ClearAcpSession =>
    {...state, acpSession: NoAcpSession}->FrontmanReactStatestore.StateReducer.update

  // ============================================================================
  // Global state actions
  // ============================================================================

  | UsageInfoReceived({usageInfo}) =>
    // Update usage info in state
    {...state, usageInfo: Some(usageInfo)}->FrontmanReactStatestore.StateReducer.update

  | UserProfileReceived({userProfile}) =>
    // Identify user in Heap Analytics
    Client__Heap.identify(userProfile.id)
    Client__Heap.addUserProperties({
      "Email": userProfile.email,
      "Name": userProfile.name->Option.getOr(""),
    })
    {...state, userProfile: Some(userProfile)}->FrontmanReactStatestore.StateReducer.update

  // API key settings actions
  | FetchApiKeySettings =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[FetchApiKeySettingsEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->FrontmanReactStatestore.StateReducer.update
    }

  | ApiKeySettingsReceived({source}) =>
    {
      ...state,
      openrouterKeySettings: {
        ...state.openrouterKeySettings,
        source,
      },
    }->FrontmanReactStatestore.StateReducer.update

  | SaveOpenRouterKey({key}) =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[SaveOpenRouterKeyEffect({apiBaseUrl, key})],
      )
    | NoAcpSession =>
      {
        ...state,
        openrouterKeySettings: {
          ...state.openrouterKeySettings,
          saveStatus: SaveError("No active ACP session"),
        },
      }->FrontmanReactStatestore.StateReducer.update
    }

  | OpenRouterKeySaveStarted =>
    {
      ...state,
      openrouterKeySettings: {
        ...state.openrouterKeySettings,
        saveStatus: Saving,
      },
    }->FrontmanReactStatestore.StateReducer.update

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
    }->FrontmanReactStatestore.StateReducer.update(~sideEffects=effects)

  | OpenRouterKeySaveError({error}) =>
    {
      ...state,
      openrouterKeySettings: {
        ...state.openrouterKeySettings,
        saveStatus: SaveError(error),
      },
    }->FrontmanReactStatestore.StateReducer.update

  | ResetOpenRouterKeySaveStatus =>
    {
      ...state,
      openrouterKeySettings: {
        ...state.openrouterKeySettings,
        saveStatus: Idle,
      },
    }->FrontmanReactStatestore.StateReducer.update

  // Model selection actions
  | FetchModelsConfig =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->FrontmanReactStatestore.StateReducer.update
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
        ->Option.map((m): Client__State__Types.selectedModel => {
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
              }: Client__State__Types.selectedModel
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
    }->FrontmanReactStatestore.StateReducer.update

  | SetSelectedModel({model}) =>
    // Save to localStorage for persistence
    saveSelectedModelToStorage(model)
    {...state, selectedModel: Some(model)}->FrontmanReactStatestore.StateReducer.update

  // Anthropic OAuth actions
  | FetchAnthropicOAuthStatus =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.FetchingStatus,
      }->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[FetchAnthropicOAuthStatusEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->FrontmanReactStatestore.StateReducer.update
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
    {...state, anthropicOAuthStatus: status}->FrontmanReactStatestore.StateReducer.update

  | InitiateAnthropicOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[GetAnthropicOAuthUrlEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->FrontmanReactStatestore.StateReducer.update
    }

  | AnthropicOAuthUrlReceived({authorizeUrl, verifier}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Authorizing({authorizeUrl, verifier}),
    }->FrontmanReactStatestore.StateReducer.update

  | ExchangeAnthropicOAuthCode({code, verifier}) =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.Exchanging,
      }->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[ExchangeAnthropicOAuthCodeEffect({apiBaseUrl, code, verifier})],
      )
    | NoAcpSession => state->FrontmanReactStatestore.StateReducer.update
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
    }->FrontmanReactStatestore.StateReducer.update(~sideEffects=effects)

  | AnthropicOAuthError({error}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Error(error),
    }->FrontmanReactStatestore.StateReducer.update

  | DisconnectAnthropicOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[DisconnectAnthropicOAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->FrontmanReactStatestore.StateReducer.update
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
    }->FrontmanReactStatestore.StateReducer.update(~sideEffects=effects)

  | ResetAnthropicOAuthError =>
    // Reset error state back to NotConnected
    switch state.anthropicOAuthStatus {
    | Client__State__Types.Error(_) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.NotConnected,
      }->FrontmanReactStatestore.StateReducer.update
    | _ => state->FrontmanReactStatestore.StateReducer.update
    }

  // ChatGPT OAuth actions
  | FetchChatGPTOAuthStatus =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTFetchingStatus,
      }->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[FetchChatGPTOAuthStatusEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->FrontmanReactStatestore.StateReducer.update
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
    {...state, chatgptOAuthStatus: status}->FrontmanReactStatestore.StateReducer.update(
      ~sideEffects=effects,
    )

  | InitiateChatGPTOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTWaitingForCode,
      }->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[InitiateChatGPTDeviceAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->FrontmanReactStatestore.StateReducer.update
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
      }->FrontmanReactStatestore.StateReducer.update(
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
      }->FrontmanReactStatestore.StateReducer.update
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
      }->FrontmanReactStatestore.StateReducer.update(~sideEffects=effects)
    | _ => state->FrontmanReactStatestore.StateReducer.update
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
      state->FrontmanReactStatestore.StateReducer.update
    } else {
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTError(error),
      }->FrontmanReactStatestore.StateReducer.update
    }

  | DisconnectChatGPTOAuth =>
    switch state.acpSession {
    | AcpSessionActive({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[DisconnectChatGPTOAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | NoAcpSession => state->FrontmanReactStatestore.StateReducer.update
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
    }->FrontmanReactStatestore.StateReducer.update(~sideEffects=effects)

  | ResetChatGPTOAuthError =>
    switch state.chatgptOAuthStatus {
    | Client__State__Types.ChatGPTError(_) =>
      {
        ...state,
        chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
      }->FrontmanReactStatestore.StateReducer.update
    | _ => state->FrontmanReactStatestore.StateReducer.update
    }

  // ============================================================================
  // Session loading actions
  // ============================================================================

  | SessionsLoadStarted =>
    {
      ...state,
      sessionsLoadState: Client__State__Types.SessionsLoading,
    }->FrontmanReactStatestore.StateReducer.update

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
    }->FrontmanReactStatestore.StateReducer.update

  | SessionsLoadError({error}) =>
    {
      ...state,
      sessionsLoadState: Client__State__Types.SessionsLoadError(error),
    }->FrontmanReactStatestore.StateReducer.update
  }
}
