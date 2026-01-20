let name = "Client::StateReducer"

// ============================================================================
// Type Re-exports from Client__State__Types
// ============================================================================

module UserContentPart = Client__State__Types.UserContentPart
module AssistantContentPart = Client__State__Types.AssistantContentPart
module Message = Client__State__Types.Message
module SelectedElement = Client__State__Types.SelectedElement
module FigmaNode = Client__State__Types.FigmaNode
module Task = Client__State__Types.Task
type state = Client__State__Types.state

// ============================================================================
// Lens Module - Composable state update functions
// ============================================================================

module Lens = {
  let updateTask = (state: state, taskId: string, fn: Task.t => Task.t): state => {
    state.tasks
    ->Dict.get(taskId)
    ->Option.map(task => {
      let updated = fn(task)
      let tasks = state.tasks->Dict.copy
      tasks->Dict.set(taskId, updated)
      {...state, tasks}
    })
    ->Option.getOr(state)
  }

  let updateCurrentTask = (state: state, fn: Task.t => Task.t): state => {
    state.currentTaskId->Option.mapOr(state, taskId => updateTask(state, taskId, fn))
  }

  let updateTaskMessage = (task: Task.t, msgId: string, fn: Message.t => Message.t): Task.t => {
    let updatedMessages =
      task.messages->Dict.mapValues(msg => Message.getId(msg) == msgId ? fn(msg) : msg)
    {...task, messages: updatedMessages}
  }

  let insertTaskMessage = (task: Task.t, message: Message.t): Task.t => {
    let messages = task.messages->Dict.copy
    messages->Dict.set(Message.getId(message), message)
    {...task, messages}
  }

  let updateCurrentTaskMessage = (
    state: state,
    msgId: string,
    fn: Message.t => Message.t,
  ): state => {
    updateCurrentTask(state, task => updateTaskMessage(task, msgId, fn))
  }

  let insertCurrentTaskMessage = (state: state, message: Message.t): state => {
    updateCurrentTask(state, task => insertTaskMessage(task, message))
  }

  // Generic helper to get task by ID
  let getTaskById = (state: state, taskId: string): option<Task.t> => {
    state.tasks->Dict.get(taskId)
  }

  // Get the streaming message in a task (at most one per task).
  let getStreamingMessage = (task: Task.t): option<Message.assistantMessage> => {
    let streaming =
      task.messages
      ->Dict.valuesToArray
      ->Array.filterMap(msg => {
        switch msg {
        | Message.Assistant(Streaming(_) as streaming) => Some(streaming)
        | _ => None
        }
      })

    assert(Array.length(streaming) <= 1)
    streaming->Array.get(0)
  }
}

type action =
  // User actions
  | AddUserMessage({id: string, content: array<UserContentPart.t>})
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
  // Completion action
  | MessageCompleted({taskId: string})
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
  | CreateTask({title: string})
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
  | Connect({sendPrompt: Client__State__Types.sendPromptFn, apiBaseUrl: string})
  | Disconnect
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

// Effects for side effects
type effect =
  | SendMessageToAPI({message: string, taskId: string})
  | FetchElementDetails({element: WebAPI.DOMAPI.element, document: option<WebAPI.DOMAPI.document>})
  | StartInitializationTimeout({taskId: string, timeoutMs: int})
  | FetchUsageInfo({apiBaseUrl: string})
  | FetchApiKeySettingsEffect({apiBaseUrl: string})
  | SaveOpenRouterKeyEffect({apiBaseUrl: string, key: string})

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

let defaultState: state = {
  tasks: Dict.make(),
  currentTaskId: None,
  connectionState: Disconnected,
  sessionInitialized: false,
  usageInfo: None,
  apiBaseUrl: None,
  openrouterKeySettings: {
    source: Client__State__Types.None,
    saveStatus: Client__State__Types.Idle,
  },
}

let actionToString = action => {
  switch action {
  | AddUserMessage({id}) => `AddUserMessage(${id})`
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
  | MessageCompleted({taskId}) => `MessageCompleted(${taskId})`
  | SetPreviewUrl({url}) => `SetPreviewUrl(${url})`
  | SetPreviewFrame(_) => `SetPreviewFrame(contentDocument, contentWindow)`
  | ToggleWebPreviewSelection => `ToggleWebPreviewSelection`
  | SetSelectedElement(_) => `SetSelectedElement`
  | CreateTask({title}) => `CreateTask("${title}")`
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
  }
}

module Selectors = {
  let getMessageId = Message.getId
  let currentTask = (state: state): option<Task.t> => {
    state.currentTaskId->Option.flatMap(id => state.tasks->Dict.get(id))
  }

  let getMessageCreatedAt = (msg: Message.t): float => {
    switch msg {
    | User({createdAt, _}) => createdAt
    | Assistant(Streaming({createdAt, _})) => createdAt
    | Assistant(Completed({createdAt, _})) => createdAt
    | ToolCall({createdAt, _}) => createdAt
    }
  }

  let messages = (state: state) => {
    currentTask(state)->Option.mapOr([], task =>
      task.messages
      ->Dict.valuesToArray
      ->Array.toSorted((a, b) => {
        let aTime = getMessageCreatedAt(a)
        let bTime = getMessageCreatedAt(b)
        aTime -. bTime
      })
    )
  }

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

  let streamingMessages = (state: state) =>
    messages(state)->Array.filterMap(msg => {
      switch msg {
      | Assistant(Streaming(_) as streaming) => Some(streaming)
      | _ => None
      }
    })

  let isStreaming = (state: state) =>
    messages(state)->Array.some(msg => {
      switch msg {
      | Assistant(Streaming(_)) => true
      | ToolCall({state: InputStreaming | InputAvailable, _}) => true
      | _ => false
      }
    })

  let lastMessage = (state: state) => {
    let msgs = messages(state)
    msgs->Array.get(Array.length(msgs) - 1)
  }

  let previewFrame = (state: state) => {
    let previewFrame: Task.previewFrame = {
      url: getInitialUrl(),
      contentDocument: None,
      contentWindow: None,
    }
    currentTask(state)->Option.mapOr(previewFrame, task => task.previewFrame)
  }

  let webPreviewIsSelecting = (state: state) => {
    currentTask(state)->Option.mapOr(false, task => task.webPreviewIsSelecting)
  }

  // Get current task's selected element
  let selectedElement = (state: state) => {
    currentTask(state)->Option.flatMap(task => task.selectedElement)
  }

  // Get current task's preview URL
  let previewUrl = (state: state) => {
    currentTask(state)->Option.mapOr(getInitialUrl(), task => task.previewFrame.url)
  }

  let currentTaskId = (state: state) => state.currentTaskId

  // Get all tasks sorted by lastMessageAt (most recent first)
  let tasks = (state: state): array<Task.t> => {
    state.tasks
    ->Dict.valuesToArray
    ->Array.toSorted((a, b) =>
      b.lastMessageAt->Option.getOr(0.0) -. a.lastMessageAt->Option.getOr(0.0)
    )
  }

  // Get recent tasks (excluding current, max 2)
  let recentTasks = (state: state): array<Task.t> => {
    let currentId = state.currentTaskId
    tasks(state)
    ->Array.filter(task =>
      switch currentId {
      | Some(id) => task.id != id
      | None => true
      }
    )
    ->Array.slice(~start=0, ~end=2)
  }

  // Get current task's figma node state
  let figmaNode = (state: state): FigmaNode.t => {
    currentTask(state)->Option.mapOr(FigmaNode.NoSelection, task => task.figmaNode)
  }

  // Get connection state
  let connectionState = (state: state): Client__State__Types.connectionState => {
    state.connectionState
  }

  // Check if connected
  let isConnected = (state: state): bool => {
    switch state.connectionState {
    | Connected(_) => true
    | Disconnected => false
    }
  }

  // Get current task's plan entries (ACP compliant)
  let currentPlanEntries = (state: state): array<Client__State__Types.ACPTypes.planEntry> => {
    currentTask(state)->Option.mapOr([], task => task.planEntries)
  }

  // Check if session has been initialized (project rules loaded)
  let sessionInitialized = (state: state): bool => {
    state.sessionInitialized
  }

  // Check if the agent is currently running (waiting for response)
  let isAgentRunning = (state: state): bool => {
    currentTask(state)->Option.mapOr(false, task => task.isAgentRunning)
  }

  // Get usage info
  let usageInfo = (state: state): option<Client__State__Types.usageInfo> => {
    state.usageInfo
  }

  // Get OpenRouter API key settings
  let openrouterKeySettings = (state: state): Client__State__Types.apiKeySettings => {
    state.openrouterKeySettings
  }
}

let handleEffect = (effect, state: state, dispatch) => {
  switch effect {
  | SendMessageToAPI({message, taskId}) =>
    switch state.connectionState {
    | Connected(sendPrompt) =>
      let additionalBlocks =
        state.tasks
        ->Dict.get(taskId)
        ->Option.mapOr([], Client__State__Types.taskToContentBlocks)

      let streamingMessages = Selectors.streamingMessages(state)
      switch streamingMessages[Array.length(streamingMessages) - 1] {
      | Some(Message.Streaming(_)) => dispatch(MessageCompleted({taskId: taskId}))
      | Some(Message.Completed(_)) | None => ()
      }

      // Include runtime config metadata (e.g., openrouterKeyValue) with each prompt
      let runtimeConfig = Client__RuntimeConfig.read()
      let metadata = Client__RuntimeConfig.toMetadata(runtimeConfig)

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

          // Parse the JSON to extract usage info
          let getInt = (dict, key) =>
            dict->Dict.get(key)->Option.flatMap(JSON.Decode.float)->Option.map(Float.toInt)
          let getBool = (dict, key) => dict->Dict.get(key)->Option.flatMap(JSON.Decode.bool)

          switch json->JSON.Decode.object {
          | Some(dict) =>
            let usageInfo: Client__State__Types.usageInfo = {
              limit: getInt(dict, "limit"),
              remaining: getInt(dict, "remaining"),
              hasUserKey: getBool(dict, "hasUserKey"),
              hasServerKey: getBool(dict, "hasServerKey"),
            }
            dispatch(UsageInfoReceived({usageInfo: usageInfo}))
          | None => ()
          }
        }
      } catch {
      | _ => ()
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

          let getBool = (dict, key) => dict->Dict.get(key)->Option.flatMap(JSON.Decode.bool)

          switch json->JSON.Decode.object {
          | Some(dict) =>
            let hasUserKey = getBool(dict, "hasUserKey")->Option.getOr(false)

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
          | None => ()
          }
        }
      } catch {
      | _ => ()
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

let next = (state, action) => {
  switch action {
  | AddUserMessage({id, content}) => {
      let message = Message.User({
        id,
        content,
        createdAt: Date.now(),
      })
      let textContent = extractTextFromUserContent(content)
      let timestamp = Date.now()

      // Ensure we have a task, creating one if needed
      let stateWithTask: state = switch Selectors.currentTask(state) {
      | Some(_task) => state
      | None => {
          let previewUrl = getInitialUrl()
          let task = Task.make(~title=textContent, ~previewUrl)
          let updatedTasks = state.tasks->Dict.copy
          updatedTasks->Dict.set(task.id, task)
          {...state, tasks: updatedTasks, currentTaskId: Some(task.id)}
        }
      }

      // Get the task ID - we know it exists now
      let taskId = stateWithTask.currentTaskId->Option.getOr("")

      stateWithTask
      ->Lens.updateCurrentTask(task => {
        let updatedMessages = task.messages->Dict.copy
        updatedMessages->Dict.set(Message.getId(message), message)
        {...task, messages: updatedMessages, lastMessageAt: Some(timestamp), isAgentRunning: true}
      })
      ->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[SendMessageToAPI({message: textContent, taskId})],
      )
    }

  | StreamingStarted({taskId}) =>
    state
    ->Lens.updateTask(taskId, task => {
      switch Lens.getStreamingMessage(task) {
      | Some(_) => // Already have a streaming message, don't create another
        task
      | None =>
        let id = `msg_${taskId}_${Date.now()->Float.toString}`
        let newMessage = Message.Assistant(
          Streaming({
            id,
            textBuffer: "",
            createdAt: Date.now(),
          }),
        )
        Lens.insertTaskMessage(task, newMessage)
      }
    })
    ->FrontmanReactStatestore.StateReducer.update

  | TextDeltaReceived({taskId, text}) =>
    state
    ->Lens.updateTask(taskId, task => {
      switch Lens.getStreamingMessage(task) {
      | Some(Message.Streaming({id, textBuffer, createdAt})) =>
        let updatedMsg = Message.Assistant(
          Streaming({id, textBuffer: textBuffer ++ text, createdAt}),
        )
        let updatedMessages = task.messages->Dict.copy
        updatedMessages->Dict.set(id, updatedMsg)
        {...task, messages: updatedMessages}
      | Some(Message.Completed(_)) => task
      | None =>
        let id = `msg_${taskId}_${Date.now()->Float.toString}`
        Lens.insertTaskMessage(
          task,
          Message.Assistant(Streaming({id, textBuffer: text, createdAt: Date.now()})),
        )
      }
    })
    ->FrontmanReactStatestore.StateReducer.update

  | ToolCallReceived({taskId, toolCall}) =>
    state
    ->Lens.updateTask(taskId, task => {
      let existingMessage = task.messages->Dict.get(toolCall.id)
      switch existingMessage {
      | Some(Message.ToolCall(existingToolCall)) =>
        Lens.updateTaskMessage(task, toolCall.id, msg =>
          switch msg {
          | Message.ToolCall(_) =>
            Message.ToolCall({
              ...existingToolCall,
              input: toolCall.input,
              state: Message.InputAvailable,
              parentAgentId: toolCall.parentAgentId,
              spawningToolName: toolCall.spawningToolName,
            })
          | Assistant(_) => failwith("expected toolcall got assistant message")
          | User(_) => failwith("expected toolcall got user message")
          }
        )
      | _ =>
        Lens.insertTaskMessage(
          task,
          Message.ToolCall({
            id: toolCall.id,
            toolName: toolCall.toolName,
            state: toolCall.state,
            inputBuffer: toolCall.inputBuffer,
            input: toolCall.input,
            result: toolCall.result,
            errorText: toolCall.errorText,
            createdAt: toolCall.createdAt,
            parentAgentId: toolCall.parentAgentId,
            spawningToolName: toolCall.spawningToolName,
          }),
        )
      }
    })
    ->FrontmanReactStatestore.StateReducer.update

  | ToolInputStartReceived({taskId, id, toolName, parentAgentId, spawningToolName}) =>
    state
    ->Lens.updateTask(taskId, task =>
      Lens.insertTaskMessage(
        task,
        Message.ToolCall({
          id,
          toolName,
          state: Message.InputStreaming,
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          createdAt: Date.now(),
          parentAgentId,
          spawningToolName,
        }),
      )
    )
    ->FrontmanReactStatestore.StateReducer.update

  | ToolInputDeltaReceived({taskId, id, delta}) =>
    state
    ->Lens.updateTask(taskId, task =>
      Lens.updateTaskMessage(task, id, msg =>
        switch msg {
        | Message.ToolCall(tool) =>
          Message.ToolCall({...tool, inputBuffer: tool.inputBuffer ++ delta})
        | other => other
        }
      )
    )
    ->FrontmanReactStatestore.StateReducer.update

  | ToolInputEndReceived({taskId, id}) =>
    state
    ->Lens.updateTask(taskId, task =>
      Lens.updateTaskMessage(task, id, msg =>
        switch msg {
        | Message.ToolCall(tool) => {
            let parsedInput = try {
              Some(JSON.parseOrThrow(tool.inputBuffer))
            } catch {
            | exn => {
                let errorMsg =
                  exn
                  ->JsExn.fromException
                  ->Option.flatMap(JsExn.message)
                  ->Option.getOr("unknown error")

                let errorObj = {
                  "error": `Failed to parse tool input: ${errorMsg}`,
                  "originalInput": tool.inputBuffer,
                }
                JSON.stringifyAny(errorObj)->Option.flatMap(str => Some(JSON.parseOrThrow(str)))
              }
            }
            Message.ToolCall({...tool, input: parsedInput, state: Message.InputAvailable})
          }
        | other => other
        }
      )
    )
    ->FrontmanReactStatestore.StateReducer.update

  | ToolInputReceived({taskId, id, input}) =>
    // Directly set the parsed input on the tool call
    state
    ->Lens.updateTask(taskId, task =>
      Lens.updateTaskMessage(task, id, msg =>
        switch msg {
        | Message.ToolCall(tool) => Message.ToolCall({...tool, input: Some(input)})
        | other => other
        }
      )
    )
    ->FrontmanReactStatestore.StateReducer.update

  | ToolResultReceived({taskId, id, result}) =>
    // Update the tool call message with its result
    // Note: Todo tools don't send tool_call_update (they use plan updates instead)
    state
    ->Lens.updateTask(taskId, task =>
      Lens.updateTaskMessage(task, id, msg =>
        switch msg {
        | Message.ToolCall(tool) =>
          Message.ToolCall({...tool, result: Some(result), state: Message.OutputAvailable})
        | other => other
        }
      )
    )
    ->FrontmanReactStatestore.StateReducer.update

  | ToolErrorReceived({taskId, id, error}) =>
    state
    ->Lens.updateTask(taskId, task =>
      Lens.updateTaskMessage(task, id, msg =>
        switch msg {
        | Message.ToolCall(tool) =>
          Message.ToolCall({...tool, errorText: Some(error), state: Message.OutputError})
        | other => other
        }
      )
    )
    ->FrontmanReactStatestore.StateReducer.update

  | MessageCompleted({taskId}) =>
    state
    ->Lens.updateTask(taskId, task => {
      switch Lens.getStreamingMessage(task) {
      | Some(Message.Streaming({id, textBuffer, createdAt})) =>
        let content = if String.length(textBuffer) > 0 {
          [AssistantContentPart.Text({text: textBuffer})]
        } else {
          []
        }
        let completedMsg = Message.Assistant(Completed({id, content, createdAt}))
        let updatedMessages = task.messages->Dict.copy
        updatedMessages->Dict.set(id, completedMsg)
        {...task, messages: updatedMessages}
      | Some(Message.Completed(_)) | None => task
      }
    })
    ->FrontmanReactStatestore.StateReducer.update

  | SetPreviewUrl({url}) =>
    state
    ->Lens.updateCurrentTask(task => {
      {...task, previewFrame: {...task.previewFrame, url}}
    })
    ->FrontmanReactStatestore.StateReducer.update

  // Set preview frame (keep existing URL and errors, just update references)
  | SetPreviewFrame({contentDocument, contentWindow}) =>
    state
    ->Lens.updateCurrentTask(task => {
      {...task, previewFrame: {...task.previewFrame, contentDocument, contentWindow}}
    })
    ->FrontmanReactStatestore.StateReducer.update

  // Toggle WebPreview selection mode
  | ToggleWebPreviewSelection => {
      // Create task if none exists
      let stateWithTask = switch state.currentTaskId {
      | Some(_) => state
      | None => {
          let previewUrl = getInitialUrl()
          let task = Task.make(~title="New Chat", ~previewUrl)
          let updatedTasks = state.tasks->Dict.copy
          updatedTasks->Dict.set(task.id, task)
          {...state, tasks: updatedTasks, currentTaskId: Some(task.id)}
        }
      }

      // Now toggle selection on the current task
      stateWithTask
      ->Lens.updateCurrentTask(task => {
        ...task,
        webPreviewIsSelecting: !task.webPreviewIsSelecting,
        selectedElement: if !task.webPreviewIsSelecting {
          None
        } else {
          task.selectedElement
        },
      })
      ->FrontmanReactStatestore.StateReducer.update
    }

  // Set selected element and reset selection mode
  | SetSelectedElement({selectedElement}) => {
      let currentTask = state.currentTaskId->Option.flatMap(id => state.tasks->Dict.get(id))
      let shouldFetchDetails = switch (selectedElement, currentTask) {
      | (Some({element, selector: None, screenshot: None, sourceLocation: None}), Some(task)) =>
        // New element with no details - trigger fetch
        Some(
          FetchElementDetails({
            element,
            document: task.previewFrame.contentDocument,
          }),
        )
      | _ => None // Element with details or clearing selection - no fetch needed
      }

      state
      ->Lens.updateCurrentTask(task => {...task, webPreviewIsSelecting: false, selectedElement})
      ->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=shouldFetchDetails->Option.mapOr([], effect => [effect]),
      )
    }

  // Create new task
  | CreateTask({title}) => {
      let previewUrl = getInitialUrl()
      let newTask = Task.make(~title, ~previewUrl)
      let updatedTasks = state.tasks->Dict.copy
      updatedTasks->Dict.set(newTask.id, newTask)

      {
        ...state,
        tasks: updatedTasks,
        currentTaskId: Some(newTask.id),
      }->FrontmanReactStatestore.StateReducer.update
    }

  // Switch to different task
  | SwitchTask({taskId}) =>
    {...state, currentTaskId: Some(taskId)}->FrontmanReactStatestore.StateReducer.update

  // Delete task
  | DeleteTask({taskId}) => {
      let updatedTasks = state.tasks->Dict.copy
      updatedTasks->Dict.delete(taskId)

      // If deleting current task, switch to most recent
      let newCurrentTaskId = switch state.currentTaskId {
      | Some(currentId) if currentId == taskId =>
        updatedTasks
        ->Dict.valuesToArray
        ->Array.toSorted((a, b) =>
          b.lastMessageAt->Option.getOr(0.0) -. a.lastMessageAt->Option.getOr(0.0)
        )
        ->Array.get(0)
        ->Option.map(task => task.id)
      | other => other
      }

      {
        ...state,
        tasks: updatedTasks,
        currentTaskId: newCurrentTaskId,
      }->FrontmanReactStatestore.StateReducer.update
    }

  | ClearCurrentTask => {...state, currentTaskId: None}->FrontmanReactStatestore.StateReducer.update

  | UpdateTaskTitle({taskId, title}) =>
    state
    ->Lens.updateTask(taskId, task => {...task, title})
    ->FrontmanReactStatestore.StateReducer.update

  | SetFigmaNode({figmaNode}) =>
    state
    ->Lens.updateCurrentTask(task => {...task, figmaNode: FigmaNode.SelectedNode(figmaNode)})
    ->FrontmanReactStatestore.StateReducer.update

  | ClearFigmaNode =>
    state
    ->Lens.updateCurrentTask(task => {...task, figmaNode: FigmaNode.NoSelection})
    ->FrontmanReactStatestore.StateReducer.update

  | SetFigmaNodeWaiting =>
    state
    ->Lens.updateCurrentTask(task => {...task, figmaNode: FigmaNode.WaitingForSelection})
    ->FrontmanReactStatestore.StateReducer.update

  | ClearFigmaNodeWaiting =>
    state
    ->Lens.updateCurrentTask(task => {...task, figmaNode: FigmaNode.NoSelection})
    ->FrontmanReactStatestore.StateReducer.update

  | Connect({sendPrompt, apiBaseUrl}) =>
    {
      ...state,
      connectionState: Connected(sendPrompt),
      apiBaseUrl: Some(apiBaseUrl),
    }->FrontmanReactStatestore.StateReducer.update(
      ~sideEffects=Array.concat(
        state.currentTaskId
        ->Option.map(taskId => [StartInitializationTimeout({taskId, timeoutMs: 3000})])
        ->Option.getOr([]),
        [FetchUsageInfo({apiBaseUrl: apiBaseUrl})],
      ),
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
    // Mark agent turn as complete and fetch updated usage
    let sideEffects = switch state.apiBaseUrl {
    | Some(apiBaseUrl) => [FetchUsageInfo({apiBaseUrl: apiBaseUrl})]
    | None => []
    }
    state
    ->Lens.updateTask(taskId, task => {...task, isAgentRunning: false})
    ->FrontmanReactStatestore.StateReducer.update(~sideEffects)

  | PlanReceived({taskId, entries}) =>
    // Replace plan entries completely (per ACP spec)
    state
    ->Lens.updateTask(taskId, task => {...task, planEntries: entries})
    ->FrontmanReactStatestore.StateReducer.update

  | UsageInfoReceived({usageInfo}) =>
    // Update usage info in state
    {...state, usageInfo: Some(usageInfo)}->FrontmanReactStatestore.StateReducer.update

  // API key settings actions
  | FetchApiKeySettings =>
    switch state.apiBaseUrl {
    | Some(apiBaseUrl) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[FetchApiKeySettingsEffect({apiBaseUrl: apiBaseUrl})],
      )
    | None => state->FrontmanReactStatestore.StateReducer.update
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
    switch state.apiBaseUrl {
    | Some(apiBaseUrl) =>
      state->FrontmanReactStatestore.StateReducer.update(
        ~sideEffects=[SaveOpenRouterKeyEffect({apiBaseUrl, key})],
      )
    | None =>
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
    let effects = switch state.apiBaseUrl {
    | Some(apiBaseUrl) => [FetchUsageInfo({apiBaseUrl: apiBaseUrl})]
    | None => []
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
  }
}
