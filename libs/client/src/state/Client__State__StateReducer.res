module Agent = AskTheLlmAgent.Agent
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel
let name = "Client::StateReducer"

// ============================================================================
// Message Content Types
// ============================================================================

module UserContentPart = Vercel.UserPart
module AssistantContentPart = Vercel.AssistantPart
module Nextjs__Types = AskTheLlmNextjs.Nextjs__Types

module Message = {
  type toolCallState =
    | InputStreaming // Parameters are streaming in
    | InputAvailable // Parameters complete, executing
    | OutputAvailable // Completed successfully
    | OutputError // Failed with error

  type assistantMessage =
    | Streaming({id: string, textBuffer: string, createdAt: float})
    | Completed({id: string, content: array<AssistantContentPart.t>, createdAt: float})

  type toolCall = {
    id: string,
    toolName: string,
    state: toolCallState,
    inputBuffer: string,
    input: option<JSON.t>,
    result: option<JSON.t>,
    errorText: option<string>,
    createdAt: float,
  }

  type t =
    | User({id: string, content: array<UserContentPart.t>, createdAt: float})
    | Assistant(assistantMessage)
    | ToolCall(toolCall)

  let getId = (msg: t): string => {
    switch msg {
    | User({id, _}) => id
    | Assistant(Streaming({id, _})) => id
    | Assistant(Completed({id, _})) => id
    | ToolCall({id, _}) => id
    }
  }
}

module SelectedElement = {
  type t = {
    element: WebAPI.DOMAPI.element,
    selector: option<string>,
    screenshot: option<string>,
    sourceLocation: option<Client__Types.SourceLocation.t>,
  }

  let make = (
    ~element: WebAPI.DOMAPI.element,
    ~selector: option<string>,
    ~screenshot: option<string>,
    ~sourceLocation: option<Client__Types.SourceLocation.t>,
  ) => {
    {
      element,
      selector,
      screenshot,
      sourceLocation,
    }
  }
}

module Task = {
  type previewFrame = {
    url: string,
    contentDocument: option<WebAPI.DOMAPI.document>,
    contentWindow: option<WebAPI.DOMAPI.window>,
  }
  type t = {
    id: string,
    title: string,
    messages: Dict.t<Message.t>,
    createdAt: float,
    lastMessageAt: option<float>,
    previewFrame: previewFrame,
    webPreviewIsSelecting: bool,
    selectedElement: option<SelectedElement.t>,
  }
  let make = (~title: string, ~previewUrl: string, ~messages=Dict.make()): t => {
    let newId = WebAPI.Global.crypto->WebAPI.Crypto.randomUUID
    let timestamp = Date.now()

    // Normalize title: trim, truncate, add ellipsis, or default
    let normalizedTitle = switch String.trim(title) {
    | "" => "New Chat"
    | text => {
        let sliced = text->String.slice(~start=0, ~end=50)
        String.length(sliced) < String.length(text) ? sliced ++ "..." : sliced
      }
    }
    {
      id: newId,
      title: normalizedTitle,
      messages,
      createdAt: timestamp,
      previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None},
      lastMessageAt: None,
      webPreviewIsSelecting: false,
      selectedElement: None,
    }
  }
}

type state = {
  tasks: Dict.t<Task.t>,
  currentTaskId: option<string>,
}

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
}

type action =
  // User actions
  | AddUserMessage({id: string, content: array<UserContentPart.t>})
  // Streaming actions (from SSE events)
  | StreamingStarted({taskId: string, id: string})
  | TextDeltaReceived({taskId: string, id: string, text: string})
  | ToolCallReceived({taskId: string, toolCall: Message.toolCall})
  | ToolInputStartReceived({taskId: string, id: string, toolName: string})
  | ToolInputDeltaReceived({taskId: string, id: string, delta: string})
  | ToolInputEndReceived({taskId: string, id: string})
  | ToolResultReceived({taskId: string, id: string, result: JSON.t})
  | ToolErrorReceived({taskId: string, id: string, error: string})
  // Completion action
  | MessageCompleted({taskId: string, id: string})
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

// Effects for side effects
type effect =
  | SendMessageToAPI({message: string, taskId: string})
  | FetchElementDetails({element: WebAPI.DOMAPI.element, document: option<WebAPI.DOMAPI.document>})
  | ExecuteClientTool({toolCallId: string, toolName: string, args: option<JSON.t>})

let getInitialUrl = () => {
  "http://localhost:3000" // Default for test environment
}

let defaultState: state = {
  tasks: Dict.make(),
  currentTaskId: None,
}

let actionToString = action => {
  switch action {
  | AddUserMessage({id}) => `AddUserMessage(${id})`
  | StreamingStarted({taskId, id}) => `StreamingStarted(${taskId}, ${id})`
  | TextDeltaReceived({taskId, id, text}) => `TextDeltaReceived(${taskId}, ${id}, "${text}")`
  | ToolCallReceived({taskId, toolCall}) => `ToolCallReceived(${taskId}, ${toolCall.toolName})`
  | ToolInputStartReceived({taskId, id, toolName}) =>
    `ToolInputStartReceived(${taskId}, ${id}, ${toolName})`
  | ToolInputDeltaReceived({taskId, id}) => `ToolInputDeltaReceived(${taskId}, ${id})`
  | ToolInputEndReceived({taskId, id}) => `ToolInputEndReceived(${taskId}, ${id})`
  | ToolResultReceived({taskId, id}) => `ToolResultReceived(${taskId}, ${id})`
  | ToolErrorReceived({taskId, id}) => `ToolErrorReceived(${taskId}, ${id})`
  | MessageCompleted({taskId, id}) => `MessageCompleted(${taskId}, ${id})`
  | SetPreviewUrl({url}) => `SetPreviewUrl(${url})`
  | SetPreviewFrame(_) => `SetPreviewFrame(contentDocument, contentWindow)`
  | ToggleWebPreviewSelection => `ToggleWebPreviewSelection`
  | SetSelectedElement(_) => `SetSelectedElement`
  | CreateTask({title}) => `CreateTask("${title}")`
  | SwitchTask({taskId}) => `SwitchTask(${taskId})`
  | DeleteTask({taskId}) => `DeleteTask(${taskId})`
  | ClearCurrentTask => `ClearCurrentTask`
  | UpdateTaskTitle({taskId, title}) => `UpdateTaskTitle(${taskId}, "${title}")`
  }
}

module Selectors = {
  let getMessageId = Message.getId
  let currentTask = (state: state): option<Task.t> => {
    state.currentTaskId->Option.flatMap(id => state.tasks->Dict.get(id))
  }
  let currentTask = (state: state): option<Task.t> => currentTask(state)

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
}
let handleEffect = (effect, state, dispatch) => {
  switch effect {
  | ExecuteClientTool({toolCallId, toolName, args}) => Client__ToolExecutor.handleToolCall(
      ~toolCallId,
      ~toolName,
      ~args,
    )->ignore
  | SendMessageToAPI({message, taskId}) => {
      Js.log3("trying...", message, taskId)
      let headers = WebAPI.Headers.make()
      headers->WebAPI.Headers.set(~name="Content-Type", ~value="application/json")

      let selectedElement =
        Selectors.currentTask(state)->Option.flatMap(task => task.selectedElement)

      let payload: AskTheLlmNextjs.Nextjs__Types.chat = {
        message,
        taskId,
        selectedElement: selectedElement->Option.map(sel => {
          let result: Nextjs__Types.selectedElement = {
            selector: sel.selector,
            screenshot: sel.screenshot,
            sourceLocation: sel.sourceLocation->Option.map(
              Client__Types.SourceLocation.toNextJsType,
            ),
          }
          result
        }),
      }

      let body =
        payload
        ->S.reverseConvertToJsonOrThrow(AskTheLlmNextjs.Nextjs__Types.chatSchema)
        ->JSON.stringify

      let _ =
        WebAPI.Global.fetch(
          //TODO(BlueHotDog) - we should centralize routes before it becomes a nightmare to chase down
          "/ask-the-llm/chat",
          ~init={
            method: "POST",
            headers: WebAPI.HeadersInit.fromHeaders(headers),
            body: WebAPI.BodyInit.fromString(body),
          },
        )
        ->Promise.then(response => {
          Console.log2("[Effect] Message sent to API:", response)
          Promise.resolve()
        })
        ->Promise.catch(error => {
          Console.error2("[Effect] Failed to send message to API:", error)
          Promise.resolve()
        })
    }
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

      // Fetch source location
      let sourceLocationPromise =
        Bindings__DOMElementToComponentSource.getElementSourceLocation(~element)
        ->Promise.then(sourceLocationOpt => {
          Promise.resolve(sourceLocationOpt)
        })
        ->Promise.catch(error => {
          Console.error2("Failed to get source location:", error)
          Promise.resolve(None)
        })

      // Wait for all promises and update state once
      let _ = Promise.all3((
        selectorPromise,
        screenshotPromise,
        sourceLocationPromise,
      ))->Promise.then(((selector, screenshot, sourceLocation)) => {
        let tagName = element.tagName
        dispatch(
          SetSelectedElement({
            selectedElement: Some({
              element,
              selector,
              screenshot,
              sourceLocation: sourceLocation->Option.map(sourceLoc => {
                {
                  ...sourceLoc,
                  file: sourceLoc.file
                  ->String.split("?")
                  ->Array.get(0)
                  ->Option.getOr(sourceLoc.file),
                  tagName,
                }
              }),
            }),
          }),
        )
        Promise.resolve()
      })
    }
  }
}

// Helper to extract text content from user message parts
let extractTextFromUserContent = (content: array<UserContentPart.t>): string => {
  content
  ->Array.filterMap(part => {
    switch part {
    | Text({text}) => Some(text)
    | Image({image: _, mediaType: _}) => %todo("add this")
    | Image({image: _}) => %todo("add this")
    | File(_) => %todo("add this")
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
          {tasks: updatedTasks, currentTaskId: Some(task.id)}
        }
      }

      // Get the task ID - we know it exists now
      let taskId = stateWithTask.currentTaskId->Option.getOr("")

      stateWithTask
      ->Lens.updateCurrentTask(task => {
        let updatedMessages = task.messages->Dict.copy
        updatedMessages->Dict.set(Message.getId(message), message)
        {...task, messages: updatedMessages, lastMessageAt: Some(timestamp)}
      })
      ->AskTheLlmReactStatestore.StateReducer.update(
        ~sideEffects=[SendMessageToAPI({message: textContent, taskId})],
      )
    }

  | StreamingStarted({taskId, id}) =>
    state
    ->Lens.updateTask(taskId, task =>
      Lens.insertTaskMessage(
        task,
        Message.Assistant(
          Streaming({
            id,
            textBuffer: "",
            createdAt: Date.now(),
          }),
        ),
      )
    )
    ->AskTheLlmReactStatestore.StateReducer.update

  | TextDeltaReceived({taskId, id, text}) =>
    state
    ->Lens.updateTask(taskId, task =>
      Lens.updateTaskMessage(task, id, msg =>
        switch msg {
        | Message.Assistant(Streaming({id: msgId, textBuffer, createdAt})) =>
          Message.Assistant(
            Streaming({
              id: msgId,
              textBuffer: textBuffer ++ text,
              createdAt,
            }),
          )
        | other => other
        }
      )
    )
    ->AskTheLlmReactStatestore.StateReducer.update

  | ToolCallReceived({taskId, toolCall}) => {
      // Check if this is a client-side tool and prepare effect
      let executeEffect = if Client__ToolRegistry.isClientTool(toolCall.toolName) {
        [
          ExecuteClientTool({
            toolCallId: toolCall.id,
            toolName: toolCall.toolName,
            args: toolCall.input,
          }),
        ]
      } else {
        []
      }

      state
      ->Lens.updateTask(taskId, task =>
        Lens.updateTaskMessage(task, toolCall.id, msg =>
          switch msg {
          | Message.ToolCall(existingToolCall) =>
            Message.ToolCall({
              ...existingToolCall,
              input: toolCall.input,
              state: Message.InputAvailable,
            })
          | Assistant(_) => failwith("expected toolcall got assistant message")
          | User(_) => failwith("expected toolcall got user message")
          }
        )
      )
      ->AskTheLlmReactStatestore.StateReducer.update(~sideEffects=executeEffect)
    }

  | ToolInputStartReceived({taskId, id, toolName}) =>
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
        }),
      )
    )
    ->AskTheLlmReactStatestore.StateReducer.update

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
    ->AskTheLlmReactStatestore.StateReducer.update

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
    ->AskTheLlmReactStatestore.StateReducer.update

  | ToolResultReceived({taskId, id, result}) =>
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
    ->AskTheLlmReactStatestore.StateReducer.update

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
    ->AskTheLlmReactStatestore.StateReducer.update

  | MessageCompleted({taskId, id}) =>
    state
    ->Lens.updateTask(taskId, task =>
      Lens.updateTaskMessage(task, id, msg =>
        switch msg {
        | Message.Assistant(Streaming({id, textBuffer, createdAt})) => {
            let content = if String.length(textBuffer) > 0 {
              [AssistantContentPart.Text({text: textBuffer})]
            } else {
              []
            }
            Message.Assistant(Completed({id, content, createdAt}))
          }
        | other => other
        }
      )
    )
    ->AskTheLlmReactStatestore.StateReducer.update

  // Set preview URL (clears document and window)
  | SetPreviewUrl({url}) =>
    state
    ->Lens.updateCurrentTask(task => {...task, previewFrame: {...task.previewFrame, url}})
    ->AskTheLlmReactStatestore.StateReducer.update

  // Set preview frame (keep existing URL)
  | SetPreviewFrame({contentDocument, contentWindow}) =>
    state
    ->Lens.updateCurrentTask(task => {
      {...task, previewFrame: {...task.previewFrame, contentDocument, contentWindow}}
    })
    ->AskTheLlmReactStatestore.StateReducer.update

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
          {tasks: updatedTasks, currentTaskId: Some(task.id)}
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
      ->AskTheLlmReactStatestore.StateReducer.update
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
      ->AskTheLlmReactStatestore.StateReducer.update(
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
        tasks: updatedTasks,
        currentTaskId: Some(newTask.id),
      }->AskTheLlmReactStatestore.StateReducer.update
    }

  // Switch to different task
  | SwitchTask({taskId}) =>
    {...state, currentTaskId: Some(taskId)}->AskTheLlmReactStatestore.StateReducer.update

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
        tasks: updatedTasks,
        currentTaskId: newCurrentTaskId,
      }->AskTheLlmReactStatestore.StateReducer.update
    }

  | ClearCurrentTask =>
    {...state, currentTaskId: None}->AskTheLlmReactStatestore.StateReducer.update

  | UpdateTaskTitle({taskId, title}) =>
    state
    ->Lens.updateTask(taskId, task => {...task, title})
    ->AskTheLlmReactStatestore.StateReducer.update
  }
}
