module Agent = AskTheLlmAgent.Agent
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel
let name = "Client::StateReducer"

// ============================================================================
// Message Content Types
// ============================================================================

module UserContentPart = Vercel.UserPart
module AssistantContentPart = Vercel.AssistantPart

type toolCallState =
  | InputStreaming // Parameters are streaming in
  | InputAvailable // Parameters complete, executing
  | OutputAvailable // Completed successfully
  | OutputError // Failed with error

module Message = {
  // ============================================================================
  // Message Types
  // ============================================================================
  type toolCall = {
    id: string,
    toolName: string,
    inputBuffer: string, // Raw streamed JSON (for ToolInputDelta)
    input: option<JSON.t>, // Parsed complete input
    result: option<JSON.t>, // Tool output
    errorText: option<string>, // Error message
    state: toolCallState,
    createdAt: float,
  }
  type assistantMessage =
    | Streaming({id: string, textBuffer: string, createdAt: float})
    | Completed({id: string, content: array<AssistantContentPart.t>, createdAt: float})

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
// Preview frame with URL and optional loaded document/window
type previewFrame = {
  url: string,
  contentDocument: option<WebAPI.DOMAPI.document>,
  contentWindow: option<WebAPI.DOMAPI.window>,
}

module SelectedElement = {
  type t = {
    element: WebAPI.DOMAPI.element,
    selector: option<string>,
    screenshot: option<string>,
    sourceLocation: option<Client__Types.sourceLocation>,
  }

  let make = (
    ~element: WebAPI.DOMAPI.element,
    ~selector: option<string>,
    ~screenshot: option<string>,
    ~sourceLocation: option<Client__Types.sourceLocation>,
  ) => {
    {
      element,
      selector,
      screenshot,
      sourceLocation,
    }
  }

  let withoutElement = (selectedElement: option<t>) => {
    switch selectedElement {
    | Some(selectedElement) =>
      {
        "selector": selectedElement.selector,
        "screenshot": selectedElement.screenshot,
        "sourceLocation": selectedElement.sourceLocation,
      }->Some
    | None => None
    }
  }
}

// Helper for initial URL
let getInitialUrl = win => {
  let currentUrl = win->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
  `${currentUrl.protocol}//${currentUrl.host}`
}

type task = {
  id: string,
  title: string,
  messages: Dict.t<Message.t>,
  createdAt: float,
  lastMessageAt: float,
  // WebPreview state per task
  previewFrame: previewFrame,
  webPreviewIsSelecting: bool,
  selectedElement: option<SelectedElement.t>,
}

type state = {
  tasks: Dict.t<task>,
  currentTaskId: option<string>,
}

// Helper to create default task
let createDefaultTask = (
  ~id: string,
  ~title: string,
  ~timestamp: float,
  ~previewUrl: string,
  ~messages=Dict.make(),
): task => {
  {
    id,
    title,
    messages,
    createdAt: timestamp,
    lastMessageAt: timestamp,
    webPreviewIsSelecting: false,
    selectedElement: None,
    previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None},
  }
}
let getCurrentTask = (state: state): option<task> => {
  state.currentTaskId->Option.flatMap(id => state.tasks->Dict.get(id))
}

let updateTask = (state: state, task: task, updateFn: task => task): state => {
  let updatedTask = updateFn(task)
  let updatedTasks = state.tasks->Dict.copy
  updatedTasks->Dict.set(task.id, updatedTask)
  {...state, tasks: updatedTasks}
}

let updateCurrentTask = (state: state, updateFn: task => task): state => {
  getCurrentTask(state)->Option.mapOr(state, updateTask(state, _, updateFn))
}

let updateCurrentTaskMessage = (
  state: state,
  messageId: string,
  updateFn: Message.t => Message.t,
): state => {
  updateCurrentTask(state, task => {
    let updatedMessages = task.messages->Dict.mapValues(msg => {
      if Message.getId(msg) == messageId {
        updateFn(msg)
      } else {
        msg
      }
    })
    {...task, messages: updatedMessages}
  })
}

let upsertToolCall = (
  state: state,
  ~id: string,
  ~toolName: string,
  ~updates: Message.toolCall => Message.toolCall,
): state => {
  updateCurrentTask(state, task => {
    let existingMessage = task.messages->Dict.get(id)
    let toolCall = switch existingMessage {
    | Some(Message.ToolCall(existingToolCall)) => updates(existingToolCall)
    | None =>
      updates({
        id,
        toolName,
        inputBuffer: "",
        input: None,
        result: None,
        errorText: None,
        state: InputStreaming,
        createdAt: Date.now(),
      })
    | Some(User(_) | Assistant(_)) => failwith("Expected ToolCall message")
    }
    let newMessages = task.messages->Dict.copy
    newMessages->Dict.set(id, Message.ToolCall(toolCall))
    {...task, messages: newMessages}
  })
}

type action =
  // User actions
  | AddUserMessage({id: string, content: array<UserContentPart.t>})
  // Streaming actions (from SSE events)
  | StreamingStarted({id: string})
  | TextDeltaReceived({id: string, text: string})
  | ToolCallReceived({toolCall: Message.toolCall})
  | ToolInputStartReceived({id: string, toolName: string})
  | ToolInputDeltaReceived({id: string, delta: string})
  | ToolInputEndReceived({id: string})
  | ToolResultReceived({id: string, result: JSON.t})
  | ToolErrorReceived({id: string, error: string})
  // Completion action
  | MessageCompleted({id: string})
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
  | CreateTask({id: string, title: string, timestamp: float})
  | SwitchTask({taskId: string})
  | DeleteTask({taskId: string})
  | ClearCurrentTask // Used when clicking "+" to start a new task - clears selection so next message creates new task
  | UpdateTaskTitle({taskId: string, title: string})

// Effects for side effects
type effect =
  | SendMessageToAPI({message: string, taskId: string})
  | FetchElementDetails({element: WebAPI.DOMAPI.element, document: option<WebAPI.DOMAPI.document>})

let defaultState: state = {
  tasks: Dict.make(),
  currentTaskId: None,
}

let actionToString = action => {
  switch action {
  | AddUserMessage({id, _}) => `AddUserMessage(${id})`
  | StreamingStarted({id}) => `StreamingStarted(${id})`
  | TextDeltaReceived({id, text}) => `TextDeltaReceived(${id}, "${text}")`
  | ToolCallReceived({toolCall}) => `ToolCallReceived(${toolCall.toolName})`
  | ToolInputStartReceived({id, toolName, _}) => `ToolInputStartReceived(${id}, ${toolName})`
  | ToolInputDeltaReceived({id, _}) => `ToolInputDeltaReceived(${id})`
  | ToolInputEndReceived({id, _}) => `ToolInputEndReceived(${id})`
  | ToolResultReceived({id, _}) => `ToolResultReceived(${id})`
  | ToolErrorReceived({id, _}) => `ToolErrorReceived(${id})`
  | MessageCompleted({id}) => `MessageCompleted(${id})`
  | SetPreviewUrl({url}) => `SetPreviewUrl(${url})`
  | SetPreviewFrame(_) => `SetPreviewFrame(contentDocument, contentWindow)`
  | ToggleWebPreviewSelection => `ToggleWebPreviewSelection`
  | SetSelectedElement(_) => `SetSelectedElement`
  | CreateTask({id, title: _, timestamp: _}) => `CreateTask(${id})`
  | SwitchTask({taskId}) => `SwitchTask(${taskId})`
  | DeleteTask({taskId}) => `DeleteTask(${taskId})`
  | ClearCurrentTask => `ClearCurrentTask`
  | UpdateTaskTitle({taskId, title}) => `UpdateTaskTitle(${taskId}, "${title}")`
  }
}

let handleEffect = (effect, state, dispatch) => {
  switch effect {
  | SendMessageToAPI({message, taskId}) => {
      let headers = WebAPI.Headers.make()
      headers->WebAPI.Headers.set(~name="Content-Type", ~value="application/json")

      let selectedElement = getCurrentTask(state)->Option.flatMap(task => task.selectedElement)

      let body = JSON.stringifyAny({
        "message": message,
        "taskId": taskId,
        "selectedElement": SelectedElement.withoutElement(selectedElement),
      })->Option.getOr("{}")

      let _ =
        WebAPI.Global.fetch(
          "/api/ask-the-llm/chat",
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

      let (taskId, newTask) = switch state.currentTaskId {
      | Some(id) => (id, None)
      | None => {
          let newId = WebAPI.Global.crypto->WebAPI.Crypto.randomUUID
          let title = textContent->String.slice(~start=0, ~end=50) // First 50 chars
          let previewUrl = getInitialUrl(WebAPI.Global.window)
          let task = createDefaultTask(~id=newId, ~title, ~timestamp, ~previewUrl)
          (newId, Some(task))
        }
      }

      let stateWithTask = switch newTask {
      | Some(task) => {
          let updatedTasks = state.tasks->Dict.copy
          updatedTasks->Dict.set(taskId, task)
          {
            tasks: updatedTasks,
            currentTaskId: Some(taskId),
          }
        }
      | None => state
      }

      let finalState = updateCurrentTask(stateWithTask, task => {
        let updatedMessages = task.messages->Dict.copy
        updatedMessages->Dict.set(Message.getId(message), message)
        {
          ...task,
          messages: updatedMessages,
          lastMessageAt: timestamp,
        }
      })

      AskTheLlmReactStatestore.StateReducer.update(
        finalState,
        ~sideEffects=[SendMessageToAPI({message: textContent, taskId})],
      )
    }

  | StreamingStarted({id}) => {
      let message = Message.Assistant(
        Streaming({
          id,
          textBuffer: "",
          createdAt: Date.now(),
        }),
      )

      let newState = updateCurrentTask(state, task => {
        let newMessages = task.messages->Dict.copy
        newMessages->Dict.set(id, message)
        {...task, messages: newMessages}
      })

      AskTheLlmReactStatestore.StateReducer.update(newState)
    }

  | TextDeltaReceived({id, text}) =>
    updateCurrentTaskMessage(state, id, msg =>
      switch msg {
      | Message.Assistant(Streaming({id, textBuffer, createdAt})) =>
        Message.Assistant(Streaming({id, textBuffer: textBuffer ++ text, createdAt}))
      | other => other
      }
    )->AskTheLlmReactStatestore.StateReducer.update

  | ToolCallReceived({toolCall}) =>
    upsertToolCall(state, ~id=toolCall.id, ~toolName=toolCall.toolName, ~updates=existing => {
      ...existing,
      toolName: toolCall.toolName,
      input: toolCall.input,
      state: InputAvailable,
    })->AskTheLlmReactStatestore.StateReducer.update

  | ToolInputStartReceived({id, toolName}) =>
    upsertToolCall(state, ~id, ~toolName, ~updates=existing => {
      ...existing,
      toolName,
      state: InputStreaming,
    })->AskTheLlmReactStatestore.StateReducer.update

  // Tool input delta received (streaming parameters)
  | ToolInputDeltaReceived({id, delta}) =>
    updateCurrentTaskMessage(state, id, msg =>
      switch msg {
      | Message.ToolCall(tool) =>
        Message.ToolCall({...tool, inputBuffer: tool.inputBuffer ++ delta})
      | other => other
      }
    )->AskTheLlmReactStatestore.StateReducer.update

  // Tool input complete (parse buffered JSON)
  | ToolInputEndReceived({id}) =>
    updateCurrentTaskMessage(state, id, msg =>
      switch msg {
      | Message.ToolCall(tool) => {
          let parsedInput = try {
            Some(JSON.parseOrThrow(tool.inputBuffer))
          } catch {
          | _ => None
          }
          Message.ToolCall({...tool, input: parsedInput, state: InputAvailable})
        }
      | other => other
      }
    )->AskTheLlmReactStatestore.StateReducer.update

  // Tool execution completed with result
  | ToolResultReceived({id, result}) =>
    updateCurrentTaskMessage(state, id, msg =>
      switch msg {
      | Message.ToolCall(tool) =>
        Message.ToolCall({...tool, result: Some(result), state: OutputAvailable})
      | other => other
      }
    )->AskTheLlmReactStatestore.StateReducer.update

  // Tool execution failed with error
  | ToolErrorReceived({id, error}) =>
    updateCurrentTaskMessage(state, id, msg =>
      switch msg {
      | Message.ToolCall(tool) =>
        Message.ToolCall({...tool, errorText: Some(error), state: OutputError})
      | other => other
      }
    )->AskTheLlmReactStatestore.StateReducer.update

  // Transition streaming message to completed
  | MessageCompleted({id}) =>
    updateCurrentTaskMessage(state, id, msg =>
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
    )->AskTheLlmReactStatestore.StateReducer.update

  // Set preview URL (clears document and window)
  | SetPreviewUrl({url}) =>
    updateCurrentTask(state, task => {
      {...task, previewFrame: {...task.previewFrame, url}}
    })->AskTheLlmReactStatestore.StateReducer.update

  // Set preview frame (keep existing URL)
  | SetPreviewFrame({contentDocument, contentWindow}) =>
    updateCurrentTask(state, task => {
      {...task, previewFrame: {...task.previewFrame, contentDocument, contentWindow}}
    })->AskTheLlmReactStatestore.StateReducer.update

  // Toggle WebPreview selection mode
  | ToggleWebPreviewSelection =>
    updateCurrentTask(state, task => {
      {
        ...task,
        webPreviewIsSelecting: !task.webPreviewIsSelecting,
        selectedElement: if !task.webPreviewIsSelecting {
          None
        } else {
          task.selectedElement
        },
      }
    })->AskTheLlmReactStatestore.StateReducer.update

  // Set selected element and reset selection mode
  | SetSelectedElement({selectedElement}) => {
      let shouldFetchDetails = switch selectedElement {
      | Some({element, selector: None, screenshot: None, sourceLocation: None}) =>
        getCurrentTask(state)->Option.map(task => FetchElementDetails({
          element,
          document: task.previewFrame.contentDocument,
        }))
      | _ => None
      }

      AskTheLlmReactStatestore.StateReducer.update(
        updateCurrentTask(state, task => {
          {...task, webPreviewIsSelecting: false, selectedElement}
        }),
        ~sideEffects=shouldFetchDetails->Option.mapOr([], effect => [effect]),
      )
    }

  // Create new task
  | CreateTask({id, title, timestamp}) => {
      let previewUrl = getInitialUrl(WebAPI.Global.window)
      let newTask = createDefaultTask(~id, ~title, ~timestamp, ~previewUrl)

      let updatedTasks = state.tasks->Dict.copy
      updatedTasks->Dict.set(id, newTask)

      AskTheLlmReactStatestore.StateReducer.update({
        tasks: updatedTasks,
        currentTaskId: Some(id),
      })
    }

  // Switch to different task
  | SwitchTask({taskId}) =>
    AskTheLlmReactStatestore.StateReducer.update({
      ...state,
      currentTaskId: Some(taskId),
    })

  // Delete task
  | DeleteTask({taskId}) => {
      let updatedTasks = state.tasks->Dict.copy
      updatedTasks->Dict.delete(taskId)

      // If deleting current task, switch to most recent
      let newCurrentTaskId = switch state.currentTaskId {
      | Some(currentId) if currentId == taskId =>
        updatedTasks
        ->Dict.valuesToArray
        ->Array.toSorted((a, b) => b.lastMessageAt -. a.lastMessageAt)
        ->Array.get(0)
        ->Option.map(task => task.id)
      | other => other
      }

      AskTheLlmReactStatestore.StateReducer.update({
        tasks: updatedTasks,
        currentTaskId: newCurrentTaskId,
      })
    }

  | ClearCurrentTask =>
    AskTheLlmReactStatestore.StateReducer.update({
      ...state,
      currentTaskId: None,
    })

  | UpdateTaskTitle({taskId, title}) =>
    state.tasks
    ->Dict.get(taskId)
    ->Option.mapOr((state, []), task => {
      updateTask(state, task, task => {
        ...task,
        title,
      })->AskTheLlmReactStatestore.StateReducer.update
    })
  }
}

module Selectors = {
  // Get message ID
  let getMessageId = Message.getId

  // Get current task
  let currentTask = (state: state): option<task> => getCurrentTask(state)

  // Helper to extract createdAt from any message type
  let getMessageCreatedAt = (msg: Message.t): float => {
    switch msg {
    | User({createdAt, _}) => createdAt
    | Assistant(Streaming({createdAt, _})) => createdAt
    | Assistant(Completed({createdAt, _})) => createdAt
    | ToolCall({createdAt, _}) => createdAt
    }
  }

  // Get current task's messages sorted by creation time
  let messages = (state: state) => {
    getCurrentTask(state)->Option.mapOr([], task =>
      task.messages
      ->Dict.valuesToArray
      ->Array.toSorted((a, b) => {
        let aTime = getMessageCreatedAt(a)
        let bTime = getMessageCreatedAt(b)
        aTime -. bTime
      })
    )
  }

  // Get only completed messages from current task
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

  // Get streaming messages from current task
  let streamingMessages = (state: state) =>
    messages(state)->Array.filterMap(msg => {
      switch msg {
      | Assistant(Streaming(_) as streaming) => Some(streaming)
      | _ => None
      }
    })

  // Check if any message is currently streaming in current task
  let isStreaming = (state: state) =>
    messages(state)->Array.some(msg => {
      switch msg {
      | Assistant(Streaming(_)) => true
      | ToolCall({state: InputStreaming | InputAvailable, _}) => true
      | _ => false
      }
    })

  // Get last message from current task
  let lastMessage = (state: state) => {
    let msgs = messages(state)
    msgs->Array.get(Array.length(msgs) - 1)
  }

  // Extract stable ID for React keys

  // Get current task's preview frame state
  let previewFrame = (state: state) => {
    getCurrentTask(state)->Option.mapOr(
      {url: getInitialUrl(WebAPI.Global.window), contentDocument: None, contentWindow: None},
      task => task.previewFrame,
    )
  }

  // Get current task's webPreview selection mode
  let webPreviewIsSelecting = (state: state) => {
    getCurrentTask(state)->Option.mapOr(false, task => task.webPreviewIsSelecting)
  }

  // Get current task's selected element
  let selectedElement = (state: state) => {
    getCurrentTask(state)->Option.flatMap(task => task.selectedElement)
  }

  // Get current task's preview URL
  let previewUrl = (state: state) => {
    getCurrentTask(state)->Option.mapOr(getInitialUrl(WebAPI.Global.window), task =>
      task.previewFrame.url
    )
  }

  // Get current task ID
  let currentTaskId = (state: state) => state.currentTaskId

  // Get all tasks sorted by lastMessageAt (most recent first)
  let tasks = (state: state): array<task> => {
    state.tasks
    ->Dict.valuesToArray
    ->Array.toSorted((a, b) => b.lastMessageAt -. a.lastMessageAt)
  }

  // Get recent tasks (excluding current, max 2)
  let recentTasks = (state: state): array<task> => {
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
