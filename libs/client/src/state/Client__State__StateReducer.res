let name = "Client::StateReducer"

// ============================================================================
// Type Re-exports from Client__State__Types
// ============================================================================

module UserContentPart = Client__State__Types.UserContentPart
module Message = Client__State__Types.Message
module SelectedElement = Client__State__Types.SelectedElement
module FigmaNode = Client__State__Types.FigmaNode
module Task = Client__State__Types.Task
type state = Client__State__Types.state

// ============================================================================
// Actions and Effects
// ============================================================================

type action =
  // User actions
  | AddUserMessage({id: string, sessionId: string, content: array<UserContentPart.t>})
  // Streaming actions (from ACP session updates)
  | StreamingStarted({taskId: string})
  | TextDeltaReceived({taskId: string, text: string})
  | ToolCallReceived({taskId: string, toolCall: Message.toolCall})
  | ToolInputStartReceived({
      taskId: string,
      id: string,
      toolName: string,
      parentAgentId: option<string>,
      spawningToolName: option<string>,
    })
  | ToolInputDeltaReceived({taskId: string, id: string, delta: string})
  | ToolInputEndReceived({taskId: string, id: string})
  | ToolInputReceived({taskId: string, id: string, input: JSON.t})
  | ToolResultReceived({taskId: string, id: string, result: JSON.t})
  | ToolErrorReceived({taskId: string, id: string, error: string})
  // Preview frame actions
  | SetPreviewUrl({url: string})
  | SetPreviewFrame({
      contentDocument: option<WebAPI.DOMAPI.document>,
      contentWindow: option<WebAPI.DOMAPI.window>,
    })
  // WebPreview selection actions
  | ToggleWebPreviewSelection
  | SetSelectedElement({selectedElement: option<SelectedElement.t>})
  // Task management actions
  | CreateTask
  | SwitchTask({taskId: string})
  | DeleteTask({taskId: string})
  | ClearCurrentTask // Used when clicking "+" to start a new task - clears selection so next message creates new task
  | UpdateTaskTitle({taskId: string, title: string})
  // Figma node actions
  | SetFigmaNode({figmaNode: FigmaNode.selectedNodeData})
  | ClearFigmaNode
  | SetFigmaNodeWaiting
  | ClearFigmaNodeWaiting
  // Connection actions
  | Connect({
      sendPrompt: Client__State__Types.sendPromptFn,
      loadTask: Client__State__Types.loadTaskFn,
      deleteSession: Client__State__Types.deleteSessionFn,
      apiBaseUrl: string,
    })
  | Disconnect
  // Task loading actions (for persisted sessions)
  | TaskLoadStarted({taskId: string})
  | TaskLoadComplete({taskId: string})
  | TaskLoadError({taskId: string, error: string})
  // Initialization actions
  | ReceivedDiscoveredProjectRule({taskId: string})
  // Turn completion actions
  | TurnCompleted({taskId: string})
  // Plan actions (ACP compliant)
  | PlanReceived({taskId: string, entries: array<Client__State__Types.ACPTypes.planEntry>})
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
  // Hydration actions (for session/load)
  | UserMessageReceived({taskId: string, id: string, text: string, timestamp: string})
  | SessionsLoadStarted
  | SessionsLoadSuccess({
      sessions: array<FrontmanFrontmanClient.FrontmanClient__ACP__Types.sessionSummary>,
    })
  | SessionsLoadError({error: string})

type effect =
  | SendMessageToAPI({message: string, taskId: string})
  | FetchElementDetails({element: WebAPI.DOMAPI.element, document: option<WebAPI.DOMAPI.document>})
  | StartInitializationTimeout({taskId: string, timeoutMs: int})
  | FetchUsageInfo({apiBaseUrl: string})
  | FetchApiKeySettingsEffect({apiBaseUrl: string})
  | SaveOpenRouterKeyEffect({apiBaseUrl: string, key: string})
  | FetchModelsConfigEffect({apiBaseUrl: string})
  // Anthropic OAuth effects
  | FetchAnthropicOAuthStatusEffect({apiBaseUrl: string})
  | GetAnthropicOAuthUrlEffect({apiBaseUrl: string})
  | ExchangeAnthropicOAuthCodeEffect({apiBaseUrl: string, code: string, verifier: string})
  | DisconnectAnthropicOAuthEffect({apiBaseUrl: string})
  // Task loading effect
  | LoadTaskEffect({taskId: string})

// ============================================================================
// Lens helpers for state updates
// ============================================================================

module TaskReducer = Client__Task__Reducer

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
  let delegateToTask = (
    state: state,
    target: Task.currentTask,
    taskAction: TaskReducer.action,
    ~sideEffects: array<effect>=[],
  ) => {
    switch target {
    | Task.New(task) =>
      let updated = TaskReducer.next(task, taskAction)
      {...state, currentTask: Task.New(updated)}->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects,
      )
    | Task.Selected(id) =>
      state
      ->updateTask(id, task => TaskReducer.next(task, taskAction))
      ->FrontmanReactStatestore.StateReducer.update(~sideEffects)
    }
  }
}

let getInitialUrl = () => {
  let entrypointUrl =
    WebAPI.Global.document
    ->WebAPI.Document.querySelector("#frontman-entrypoint-url")
    ->Null.toOption
    ->Option.map(element => {
      element->WebAPI.Element.asNode->WebAPI.Node.textContent->Null.toOption->Option.getOr("")
    })
  let currentUrl =
    WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)

  let originUrl = switch entrypointUrl {
  | Some(entrypointUrl) => entrypointUrl
  | None => `${currentUrl.protocol}//${currentUrl.host}`
  }
  originUrl
}

// Normalize URL by removing trailing slash for comparison
let normalizeUrl = (url: string): string => {
  url->String.endsWith("/") && String.length(url) > 1
    ? url->String.slice(~start=0, ~end=String.length(url) - 1)
    : url
}

// localStorage key for persisting selected model
let selectedModelStorageKey = "frontman:selectedModel"

// localStorage bindings
@val @scope("localStorage")
external getStorageItem: string => Nullable.t<string> = "getItem"

@val @scope("localStorage")
external setStorageItem: (string, string) => unit = "setItem"

// Load selected model from localStorage
let loadSelectedModelFromStorage = (): option<Client__State__Types.selectedModel> => {
  try {
    getStorageItem(selectedModelStorageKey)
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
    setStorageItem(selectedModelStorageKey, jsonString)
  } catch {
  | exn => Console.error2("[saveSelectedModelToStorage] Failed:", exn)
  }
}

let defaultState: state = {
  tasks: Dict.make(),
  currentTask: Task.New(Task.makeNew(~previewUrl=getInitialUrl())),
  connectionState: Disconnected,
  sessionInitialized: false,
  usageInfo: None,
  openrouterKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
  anthropicOAuthStatus: Client__State__Types.NotConnected,
  modelsConfig: None,
  selectedModel: loadSelectedModelFromStorage(), // Load from localStorage on init
  sessionsLoadState: Client__State__Types.SessionsNotLoaded,
}

let actionToString = action => {
  switch action {
  | AddUserMessage({id, sessionId}) => `AddUserMessage(${id}, session=${sessionId})`
  | StreamingStarted({taskId}) => `StreamingStarted(${taskId})`
  | TextDeltaReceived({taskId, text}) => `TextDeltaReceived(${taskId}, "${text}")`
  | ToolCallReceived({taskId, toolCall}) => `ToolCallReceived(${taskId}, ${toolCall.toolName})`
  | ToolInputStartReceived({taskId, id, toolName, parentAgentId: _}) =>
    `ToolInputStartReceived(${taskId}, ${id}, ${toolName})`
  | ToolInputDeltaReceived({taskId, id}) => `ToolInputDeltaReceived(${taskId}, ${id})`
  | ToolInputEndReceived({taskId, id}) => `ToolInputEndReceived(${taskId}, ${id})`
  | ToolInputReceived({taskId, id, _}) => `ToolInputReceived(${taskId}, ${id})`
  | ToolResultReceived({taskId, id}) => `ToolResultReceived(${taskId}, ${id})`
  | ToolErrorReceived({taskId, id}) => `ToolErrorReceived(${taskId}, ${id})`
  | SetPreviewUrl({url}) => `SetPreviewUrl(${url})`
  | SetPreviewFrame(_) => `SetPreviewFrame(contentDocument, contentWindow)`
  | ToggleWebPreviewSelection => `ToggleWebPreviewSelection`
  | SetSelectedElement(_) => `SetSelectedElement`
  | CreateTask => `CreateTask`
  | SwitchTask({taskId}) => `SwitchTask(${taskId})`
  | DeleteTask({taskId}) => `DeleteTask(${taskId})`
  | ClearCurrentTask => `ClearCurrentTask`
  | UpdateTaskTitle({taskId, title}) => `UpdateTaskTitle(${taskId}, "${title}")`
  | SetFigmaNode(_) => `SetFigmaNode`
  | ClearFigmaNode => `ClearFigmaNode`
  | SetFigmaNodeWaiting => `SetFigmaNodeWaiting`
  | ClearFigmaNodeWaiting => `ClearFigmaNodeWaiting`
  | Connect(_) => `Connect`
  | Disconnect => `Disconnect`
  | TaskLoadStarted({taskId}) => `TaskLoadStarted(${taskId})`
  | TaskLoadComplete({taskId}) => `TaskLoadComplete(${taskId})`
  | TaskLoadError({taskId, error}) => `TaskLoadError(${taskId}, ${error})`
  | ReceivedDiscoveredProjectRule({taskId}) => `ReceivedDiscoveredProjectRule(${taskId})`
  | TurnCompleted({taskId}) => `TurnCompleted(${taskId})`
  | PlanReceived({taskId, entries}) =>
    `PlanReceived(${taskId}, ${entries->Array.length->Int.toString} entries)`
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
  | UserMessageReceived({taskId, id, _}) => `UserMessageReceived(${taskId}, ${id})`
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

  let figmaNode = (state: state): FigmaNode.t => {
    Task.getFigmaNode(currentTask(state))
  }

  let isAgentRunning = (state: state): bool => {
    TaskReducer.Selectors.isAgentRunning(currentTask(state))->Option.getOr(false)
  }

  let currentPlanEntries = (state: state): array<Client__State__Types.ACPTypes.planEntry> => {
    TaskReducer.Selectors.planEntries(currentTask(state))->Option.getOr([])
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
  let connectionState = (state: state): Client__State__Types.connectionState => {
    state.connectionState
  }

  let isConnected = (state: state): bool => {
    switch state.connectionState {
    | Connected(_) => true
    | Disconnected => false
    }
  }

  let sessionInitialized = (state: state): bool => {
    state.sessionInitialized
  }

  // Get usage info
  let usageInfo = (state: state): option<Client__State__Types.usageInfo> => {
    state.usageInfo
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
}

let handleEffect = (effect, state: state, dispatch) => {
  switch effect {
  | SendMessageToAPI({message, taskId}) =>
    switch state.connectionState {
    | Connected({sendPrompt}) =>
      let additionalBlocks =
        state.tasks
        ->Dict.get(taskId)
        ->Option.mapOr([], Client__State__Types.taskToContentBlocks)

      // Include runtime config metadata (e.g., openrouterKeyValue) with each prompt
      let runtimeConfig = Client__RuntimeConfig.read()
      let baseMetadata = Client__RuntimeConfig.toMetadata(runtimeConfig)

      // Add selected model to metadata if present
      let metadata = switch state.selectedModel {
      | Some(model) =>
        let modelJson: JSON.t = %raw(`(function(provider, value) {
          return { provider: provider, value: value };
        })`)(model.provider, model.value)
        switch baseMetadata {
        | Some(meta) =>
          switch meta->JSON.Decode.object {
          | Some(dict) =>
            let newDict = dict->Dict.copy
            newDict->Dict.set("model", modelJson)
            Some(newDict->Obj.magic)
          | None => baseMetadata
          }
        | None =>
          let dict = Dict.make()
          dict->Dict.set("model", modelJson)
          Some(dict->Obj.magic)
        }
      | None => baseMetadata
      }

      sendPrompt(
        message,
        ~additionalBlocks,
        ~onComplete=result => {
          switch result {
          | Ok(_) => dispatch(TurnCompleted({taskId: taskId}))
          | Error(error) =>
            Console.error2("[Effect] Failed to send message:", error)
            dispatch(TurnCompleted({taskId: taskId}))
          }
        },
        ~metadata,
      )
    | Disconnected => Console.error("[Effect] Cannot send message: not connected")
    }
  | FetchUsageInfo({apiBaseUrl}) =>
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
  | FetchElementDetails({element, document}) => {
      // Fetch selector
      let selectorPromise = Promise.resolve()->Promise.then(_ => {
        let selector = Bindings__Finder.finder(
          ~element,
          ~options={
            root: document
            ->Option.map(doc => doc.documentElement->Obj.magic)
            ->Option.getOr(element),
            idName: (~name as _) => true,
            className: (~name as _) => true,
            tagName: (~name as _) => true,
            attr: (~name as _, ~value as _) => false,
          },
        )
        Promise.resolve(Some(selector))
      })

      // Fetch screenshot
      let screenshotPromise =
        Bindings__Snapdom.snapdom(~element)
        ->Promise.then(captureResult => {
          Promise.resolve(Some(captureResult.url))
        })
        ->Promise.catch(error => {
          Console.error2("Failed to capture screenshot:", error)
          Promise.resolve(None)
        })

      // Fetch source location (cascading: React fiber first, then Astro annotations)
      let sourceLocationPromise = switch Selectors.previewFrame(state).contentWindow {
      | Some(window) =>
        Bindings__SourceDetection.getElementSourceLocation(~element, ~window)
        ->Promise.then(sourceLocationOpt => Promise.resolve(sourceLocationOpt))
        ->Promise.catch(error => {
          Console.error2("Failed to get source location:", error)
          Promise.resolve(None)
        })
      | None => Promise.resolve(None)
      }

      // Wait for all promises and update state once
      let _ = Promise.all3((
        selectorPromise,
        screenshotPromise,
        sourceLocationPromise,
      ))->Promise.then(((selector, screenshot, sourceLocation)) => {
        let tagName = element.tagName
        let sourceLocationWithTagName = sourceLocation->Option.map(sourceLoc => {
          {
            ...sourceLoc,
            file: sourceLoc.file
            ->String.split("?")
            ->Array.get(0)
            ->Option.getOr(sourceLoc.file),
            tagName,
          }
        })

        // Resolve source location via server to get relative file paths
        // We wait for resolution before dispatching to avoid race conditions
        // where messages are sent with unresolved absolute paths
        let resolvedSourceLocationPromise = switch sourceLocationWithTagName {
        | Some(sourceLoc) =>
          Client__SourceLocationResolver.resolve(sourceLoc)->Promise.then(result => {
            switch result {
            | Ok(resolved) => Promise.resolve(Some(resolved))
            | Error(err) =>
              Console.warn2("[Effect] Source location resolution failed, using original:", err)
              // Fall back to original source location if resolution fails
              Promise.resolve(sourceLocationWithTagName)
            }
          })
        | None => Promise.resolve(None)
        }

        // Dispatch only after resolution completes (or fails with fallback)
        resolvedSourceLocationPromise->Promise.then(finalSourceLocation => {
          dispatch(
            SetSelectedElement({
              selectedElement: Some({
                element,
                selector,
                screenshot,
                sourceLocation: finalSourceLocation,
              }),
            }),
          )
          Promise.resolve()
        })
      })
    }
  | StartInitializationTimeout({taskId, timeoutMs}) =>
    let taskId = taskId
    let _ = Js.Global.setTimeout(() => {
      if !state.sessionInitialized {
        dispatch(ReceivedDiscoveredProjectRule({taskId: taskId}))
      }
    }, timeoutMs)
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
      let url = `${apiBaseUrl}/api/models`

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

  | LoadTaskEffect({taskId}) =>
    switch state.connectionState {
    | Connected({loadTask}) =>
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
            dispatch(TaskLoadComplete({taskId: taskIdToLoad}))
          }
        | Error(err) => dispatch(TaskLoadError({taskId: taskIdToLoad, error: err}))
        }
      })
    | Disconnected => dispatch(TaskLoadError({taskId, error: "Not connected"}))
    }
  }
}

// Helper to extract text content from user message parts
let extractTextFromUserContent = (content: array<UserContentPart.t>): string => {
  content
  ->Array.filterMap(part => {
    switch part {
    | Text({text}) => Some(text)
    | Image(_) => None
    | File(_) => None
    }
  })
  ->Array.join(" ")
}

let next = (state: state, action) => {
  switch action {
  | AddUserMessage({id, sessionId, content}) => {
      let textContent = extractTextFromUserContent(content)

      // Handle based on current task state
      switch state.currentTask {
      | Task.New(newTask) =>
        // New → Loaded: promote to persisted task
        let userMessage = Message.User({
          id,
          content,
          createdAt: Date.now(),
        })
        let loadedTask = Task.newToLoaded(
          newTask,
          ~id=sessionId,
          ~title=textContent,
          ~firstMessage=userMessage,
        )
        // Add to dict and select it
        let updatedTasks = state.tasks->Dict.copy
        updatedTasks->Dict.set(sessionId, loadedTask)
        {
          ...state,
          tasks: updatedTasks,
          currentTask: Task.Selected(sessionId),
        }->FrontmanReactStatestore.StateReducer.update(
          ~sideEffects=[SendMessageToAPI({message: textContent, taskId: sessionId})],
        )
      | Task.Selected(taskId) =>
        // Selected: delegate to existing task
        state->Lens.delegateToTask(
          Task.Selected(taskId),
          AddUserMessage({id, content}),
          ~sideEffects=[SendMessageToAPI({message: textContent, taskId})],
        )
      }
    }

  | StreamingStarted({taskId}) => state->Lens.delegateToTask(Task.Selected(taskId), StreamingStarted)
  | TextDeltaReceived({taskId, text}) => state->Lens.delegateToTask(Task.Selected(taskId), TextDeltaReceived({text: text}))
  | ToolCallReceived({taskId, toolCall}) => state->Lens.delegateToTask(Task.Selected(taskId), ToolCallReceived({toolCall: toolCall}))
  | ToolInputStartReceived({taskId, id, toolName, parentAgentId, spawningToolName}) =>
    state->Lens.delegateToTask(Task.Selected(taskId), ToolInputStartReceived({id, toolName, parentAgentId, spawningToolName}))
  | ToolInputDeltaReceived({taskId, id, delta}) => state->Lens.delegateToTask(Task.Selected(taskId), ToolInputDeltaReceived({id, delta}))
  | ToolInputEndReceived({taskId, id}) => state->Lens.delegateToTask(Task.Selected(taskId), ToolInputEndReceived({id: id}))
  | ToolInputReceived({taskId, id, input}) => state->Lens.delegateToTask(Task.Selected(taskId), ToolInputReceived({id, input}))
  | ToolResultReceived({taskId, id, result}) => state->Lens.delegateToTask(Task.Selected(taskId), ToolResultReceived({id, result}))
  | ToolErrorReceived({taskId, id, error}) => state->Lens.delegateToTask(Task.Selected(taskId), ToolErrorReceived({id, error}))

  | SetPreviewUrl({url}) =>
    state->Lens.delegateToTask(state.currentTask, SetPreviewUrl({url: url}))

  | SetPreviewFrame({contentDocument, contentWindow}) =>
    state->Lens.delegateToTask(state.currentTask, SetPreviewFrame({contentDocument, contentWindow}))

  | ToggleWebPreviewSelection =>
    state->Lens.delegateToTask(state.currentTask, ToggleWebPreviewSelection)

  | SetSelectedElement({selectedElement}) =>
    let currentTask = Selectors.currentTask(state)
    // Parent decides if we need to fetch element details
    let sideEffects = switch selectedElement {
    | Some({element, selector: None, screenshot: None, sourceLocation: None}) =>
      [FetchElementDetails({element, document: Task.getPreviewFrame(currentTask, ~defaultUrl=getInitialUrl()).contentDocument})]
    | _ => []
    }
    state->Lens.delegateToTask(state.currentTask, SetSelectedElement({selectedElement: selectedElement}), ~sideEffects)

  // Create new task (starts as New, becomes Loaded when first message is sent)
  | CreateTask =>
    {
      ...state,
      currentTask: Task.New(Task.makeNew(~previewUrl=getInitialUrl())),
    }->FrontmanReactStatestore.StateReducer.update

  // Switch to different task - always re-activate session to ensure correct routing
  | SwitchTask({taskId}) => {
      let task = state.tasks->Dict.get(taskId)
      let needsLoad = switch task {
      | Some(t) => Task.isUnloaded(t)
      | None => true
      }

      // If task needs loading, transition to Loading state
      let updatedState = if needsLoad {
        Lens.updateTask(state, taskId, t => Task.startLoading(t, ~previewUrl=getInitialUrl()))
      } else {
        state
      }

      // Always emit LoadTaskEffect to re-activate the session
      {...updatedState, currentTask: Task.Selected(taskId)}->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[LoadTaskEffect({taskId: taskId})],
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
      switch state.connectionState {
      | Connected({deleteSession}) => deleteSession(taskId, ~onComplete=_ => ())
      | Disconnected => ()
      }

      {
        ...state,
        tasks: updatedTasks,
        currentTask: newCurrentTask,
      }->FrontmanReactStatestore.StateReducer.update
    }

  | ClearCurrentTask =>
    {...state, currentTask: Task.New(Task.makeNew(~previewUrl=getInitialUrl()))}->FrontmanReactStatestore.StateReducer.update

  | UpdateTaskTitle({taskId, title}) =>
    state
    ->Lens.updateTask(taskId, task => Task.setTitle(task, title))
    ->FrontmanReactStatestore.StateReducer.update

  | SetFigmaNode({figmaNode}) =>
    state->Lens.delegateToTask(state.currentTask, SetFigmaNode({figmaNode: figmaNode}))

  | ClearFigmaNode =>
    state->Lens.delegateToTask(state.currentTask, ClearFigmaNode)

  | SetFigmaNodeWaiting =>
    state->Lens.delegateToTask(state.currentTask, SetFigmaNodeWaiting)

  | ClearFigmaNodeWaiting =>
    state->Lens.delegateToTask(state.currentTask, ClearFigmaNodeWaiting)

  | Connect({sendPrompt, loadTask, deleteSession, apiBaseUrl}) =>
    // Just set up connection functions - task creation happens in AddUserMessage
    // when user sends their first message (lazy session creation)
    // apiBaseUrl is now co-located in Connected to make illegal state unrepresentable
    {
      ...state,
      connectionState: Connected({sendPrompt, loadTask, deleteSession, apiBaseUrl}),
      sessionInitialized: true,
    }->FrontmanReactStatestore.StateReducer.update(
      ~sideEffects=[
        FetchUsageInfo({apiBaseUrl: apiBaseUrl}),
        FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl}),
      ],
    )

  | Disconnect =>
    {...state, connectionState: Disconnected}->FrontmanReactStatestore.StateReducer.update

  | ReceivedDiscoveredProjectRule({taskId: _}) =>
    // Mark initialization complete
    {
      ...state,
      sessionInitialized: true,
    }->FrontmanReactStatestore.StateReducer.update

  | TurnCompleted({taskId}) =>
    let sideEffects = switch state.connectionState {
    | Connected({apiBaseUrl}) => [FetchUsageInfo({apiBaseUrl: apiBaseUrl})]
    | Disconnected => []
    }
    state->Lens.delegateToTask(Task.Selected(taskId), TurnCompleted, ~sideEffects)

  | PlanReceived({taskId, entries}) =>
    state->Lens.delegateToTask(Task.Selected(taskId), PlanReceived({entries: entries}))

  | UsageInfoReceived({usageInfo}) =>
    // Update usage info in state
    {...state, usageInfo: Some(usageInfo)}->FrontmanReactStatestore.StateReducer.update

  // API key settings actions
  | FetchApiKeySettings =>
    switch state.connectionState {
    | Connected({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[FetchApiKeySettingsEffect({apiBaseUrl: apiBaseUrl})],
      )
    | Disconnected => state->FrontmanReactStatestore.StateReducer.update
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
    switch state.connectionState {
    | Connected({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[SaveOpenRouterKeyEffect({apiBaseUrl, key})],
      )
    | Disconnected =>
      {
        ...state,
        openrouterKeySettings: {
          ...state.openrouterKeySettings,
          saveStatus: SaveError("Not connected to server"),
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
    // After saving the API key, refresh usage info so the chatbox reflects the new state
    let effects = switch state.connectionState {
    | Connected({apiBaseUrl}) => [FetchUsageInfo({apiBaseUrl: apiBaseUrl})]
    | Disconnected => []
    }
    {
      ...state,
      openrouterKeySettings: {
        source: UserOverride,
        saveStatus: Saved,
      },
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
    switch state.connectionState {
    | Connected({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[FetchModelsConfigEffect({apiBaseUrl: apiBaseUrl})],
      )
    | Disconnected => state->FrontmanReactStatestore.StateReducer.update
    }

  | ModelsConfigReceived({config}) =>
    // Set models config and initialize selected model if not already set
    let selectedModel = switch state.selectedModel {
    | Some(model) => Some(model)
    | None =>
      // Use default model from config
      Some(
        (
          {
            provider: config.defaultModel.provider,
            value: config.defaultModel.value,
          }: Client__State__Types.selectedModel
        ),
      )
    }
    {
      ...state,
      modelsConfig: Some(config),
      selectedModel,
    }->FrontmanReactStatestore.StateReducer.update

  | SetSelectedModel({model}) =>
    // Save to localStorage for persistence
    saveSelectedModelToStorage(model)
    {...state, selectedModel: Some(model)}->FrontmanReactStatestore.StateReducer.update

  // Anthropic OAuth actions
  | FetchAnthropicOAuthStatus =>
    switch state.connectionState {
    | Connected({apiBaseUrl}) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.FetchingStatus,
      }->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[FetchAnthropicOAuthStatusEffect({apiBaseUrl: apiBaseUrl})],
      )
    | Disconnected => state->FrontmanReactStatestore.StateReducer.update
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
    switch state.connectionState {
    | Connected({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[GetAnthropicOAuthUrlEffect({apiBaseUrl: apiBaseUrl})],
      )
    | Disconnected => state->FrontmanReactStatestore.StateReducer.update
    }

  | AnthropicOAuthUrlReceived({authorizeUrl, verifier}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Authorizing({authorizeUrl, verifier}),
    }->FrontmanReactStatestore.StateReducer.update

  | ExchangeAnthropicOAuthCode({code, verifier}) =>
    switch state.connectionState {
    | Connected({apiBaseUrl}) =>
      {
        ...state,
        anthropicOAuthStatus: Client__State__Types.Exchanging,
      }->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[ExchangeAnthropicOAuthCodeEffect({apiBaseUrl, code, verifier})],
      )
    | Disconnected => state->FrontmanReactStatestore.StateReducer.update
    }

  | AnthropicOAuthConnected({expiresAt}) =>
    let expiresAtMs = Date.fromString(expiresAt)->Date.getTime
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Connected({expiresAt: expiresAtMs}),
    }->FrontmanReactStatestore.StateReducer.update

  | AnthropicOAuthError({error}) =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.Error(error),
    }->FrontmanReactStatestore.StateReducer.update

  | DisconnectAnthropicOAuth =>
    switch state.connectionState {
    | Connected({apiBaseUrl}) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[DisconnectAnthropicOAuthEffect({apiBaseUrl: apiBaseUrl})],
      )
    | Disconnected => state->FrontmanReactStatestore.StateReducer.update
    }

  | AnthropicOAuthDisconnected =>
    {
      ...state,
      anthropicOAuthStatus: Client__State__Types.NotConnected,
    }->FrontmanReactStatestore.StateReducer.update

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

  | TaskLoadStarted({taskId}) => state->Lens.delegateToTask(Task.Selected(taskId), LoadStarted({previewUrl: getInitialUrl()}))
  | TaskLoadComplete({taskId}) => state->Lens.delegateToTask(Task.Selected(taskId), LoadComplete)
  | TaskLoadError({taskId, error}) => state->Lens.delegateToTask(Task.Selected(taskId), LoadError({error: error}))
  | UserMessageReceived({taskId, id, text, timestamp}) =>
    state->Lens.delegateToTask(Task.Selected(taskId), UserMessageReceived({id, text, timestamp}))

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
