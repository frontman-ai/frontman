// Task reducer - self-contained domain logic for Task aggregate
// All actions operate on a single Task (no taskId needed)

module Types = Client__Task__Types
module Task = Types.Task
module Message = Types.Message
module UserContentPart = Types.UserContentPart
module AssistantContentPart = Types.AssistantContentPart
module SelectedElement = Types.SelectedElement
module FigmaNode = Types.FigmaNode
module ACPTypes = Types.ACPTypes

// ============================================================================
// Lens Module - Composable state update functions for Task
// ============================================================================

module Lens = {
  // Update messages within a task (crashes if New or Unloaded - they have no messages)
  let updateMessages = (task: Task.t, fn: array<Message.t> => array<Message.t>): Task.t => {
    switch task {
    | Task.New(_) | Task.Unloaded(_) => failwith("[Lens.updateMessages] Cannot update messages on New/Unloaded task")
    | Task.Loading(data) => Task.Loading({...data, messages: fn(data.messages)})
    | Task.Loaded(data) => Task.Loaded({...data, messages: fn(data.messages)})
    }
  }

  // Update a specific message by ID
  let updateMessage = (task: Task.t, msgId: string, fn: Message.t => Message.t): Task.t => {
    updateMessages(task, messages =>
      messages->Array.map(msg => Message.getId(msg) == msgId ? fn(msg) : msg)
    )
  }

  // Insert a message at the end
  let insertMessage = (task: Task.t, message: Message.t): Task.t => {
    updateMessages(task, messages => messages->Array.concat([message]))
  }

  // Get the streaming message (at most one per task)
  // INVARIANT: Only one streaming message can exist at a time.
  let getStreamingMessage = (task: Task.t): option<Message.assistantMessage> => {
    let messages = Task.getMessages(task)
    let streaming = messages->Array.filterMap(msg => {
      switch msg {
      | Message.Assistant(Streaming(_) as streaming) => Some(streaming)
      | _ => None
      }
    })

    assert(Array.length(streaming) <= 1)
    streaming->Array.get(0)
  }

  // Complete any streaming message (convert Streaming to Completed)
  // Per ACP spec: message boundaries are signaled by prompt response or next user message
  let completeStreamingMessage = (task: Task.t): Task.t => {
    updateMessages(task, messages =>
      messages->Array.map(msg =>
        switch msg {
        | Message.Assistant(Streaming({id, textBuffer, createdAt})) =>
          // Empty buffer = empty content array (not a Text part with empty string)
          let content = if String.length(textBuffer) > 0 {
            [AssistantContentPart.Text({text: textBuffer})]
          } else {
            []
          }
          Message.Assistant(Completed({id, content, createdAt}))
        | other => other
        }
      )
    )
  }

  // Update preview frame URL
  let setPreviewUrl = (task: Task.t, url: string): Task.t => {
    switch task {
    | Task.New(data) => Task.New({...data, previewFrame: {...data.previewFrame, url}})
    | Task.Loading(data) => Task.Loading({...data, previewFrame: {...data.previewFrame, url}})
    | Task.Loaded(data) => Task.Loaded({...data, previewFrame: {...data.previewFrame, url}})
    | Task.Unloaded(_) => failwith("[Lens.setPreviewUrl] Cannot set preview URL on Unloaded task")
    }
  }

  // Update preview frame content
  let setPreviewFrame = (
    task: Task.t,
    ~contentDocument: option<WebAPI.DOMAPI.document>,
    ~contentWindow: option<WebAPI.DOMAPI.window>,
  ): Task.t => {
    switch task {
    | Task.New(data) => Task.New({...data, previewFrame: {...data.previewFrame, contentDocument, contentWindow}})
    | Task.Loading(data) => Task.Loading({...data, previewFrame: {...data.previewFrame, contentDocument, contentWindow}})
    | Task.Loaded(data) => Task.Loaded({...data, previewFrame: {...data.previewFrame, contentDocument, contentWindow}})
    | Task.Unloaded(_) => failwith("[Lens.setPreviewFrame] Cannot set preview frame on Unloaded task")
    }
  }

  // Toggle web preview selection mode
  let toggleWebPreviewSelection = (task: Task.t): Task.t => {
    switch task {
    | Task.New(data) =>
      Task.New({
        ...data,
        webPreviewIsSelecting: !data.webPreviewIsSelecting,
        selectedElement: if !data.webPreviewIsSelecting { None } else { data.selectedElement },
      })
    | Task.Loading(data) =>
      Task.Loading({
        ...data,
        webPreviewIsSelecting: !data.webPreviewIsSelecting,
        selectedElement: if !data.webPreviewIsSelecting { None } else { data.selectedElement },
      })
    | Task.Loaded(data) =>
      Task.Loaded({
        ...data,
        webPreviewIsSelecting: !data.webPreviewIsSelecting,
        selectedElement: if !data.webPreviewIsSelecting { None } else { data.selectedElement },
      })
    | Task.Unloaded(_) => failwith("[Lens.toggleWebPreviewSelection] Cannot toggle on Unloaded task")
    }
  }

  // Set selected element
  let setSelectedElement = (task: Task.t, selectedElement: option<SelectedElement.t>): Task.t => {
    switch task {
    | Task.New(data) => Task.New({...data, webPreviewIsSelecting: false, selectedElement})
    | Task.Loading(data) => Task.Loading({...data, webPreviewIsSelecting: false, selectedElement})
    | Task.Loaded(data) => Task.Loaded({...data, webPreviewIsSelecting: false, selectedElement})
    | Task.Unloaded(_) => failwith("[Lens.setSelectedElement] Cannot set element on Unloaded task")
    }
  }

  // Set figma node
  let setFigmaNode = (task: Task.t, figmaNode: FigmaNode.selectedNodeData): Task.t => {
    switch task {
    | Task.New(data) => Task.New({...data, figmaNode: FigmaNode.SelectedNode(figmaNode)})
    | Task.Loading(data) => Task.Loading({...data, figmaNode: FigmaNode.SelectedNode(figmaNode)})
    | Task.Loaded(data) => Task.Loaded({...data, figmaNode: FigmaNode.SelectedNode(figmaNode)})
    | Task.Unloaded(_) => failwith("[Lens.setFigmaNode] Cannot set figma node on Unloaded task")
    }
  }

  // Clear figma node
  let clearFigmaNode = (task: Task.t): Task.t => {
    switch task {
    | Task.New(data) => Task.New({...data, figmaNode: FigmaNode.NoSelection})
    | Task.Loading(data) => Task.Loading({...data, figmaNode: FigmaNode.NoSelection})
    | Task.Loaded(data) => Task.Loaded({...data, figmaNode: FigmaNode.NoSelection})
    | Task.Unloaded(_) => failwith("[Lens.clearFigmaNode] Cannot clear figma node on Unloaded task")
    }
  }

  // Set figma node waiting
  let setFigmaNodeWaiting = (task: Task.t): Task.t => {
    switch task {
    | Task.New(data) => Task.New({...data, figmaNode: FigmaNode.WaitingForSelection})
    | Task.Loading(data) => Task.Loading({...data, figmaNode: FigmaNode.WaitingForSelection})
    | Task.Loaded(data) => Task.Loaded({...data, figmaNode: FigmaNode.WaitingForSelection})
    | Task.Unloaded(_) => failwith("[Lens.setFigmaNodeWaiting] Cannot set waiting on Unloaded task")
    }
  }
}

// ============================================================================
// Selectors Module - Query functions for Task state
// ============================================================================

module Selectors = {
  // Get messages from a task
  // None = Unloaded (we don't know), Some([]) = New/loaded but empty
  let messages = (task: Task.t): option<array<Message.t>> => {
    switch task {
    | Task.Unloaded(_) => None
    | Task.New(_) => Some([])
    | Task.Loading({messages}) | Task.Loaded({messages}) => Some(messages)
    }
  }

  // Check if task is streaming
  // None = Unloaded (we don't know)
  let isStreaming = (task: Task.t): option<bool> => {
    messages(task)->Option.map(msgs =>
      msgs->Array.some(msg => {
        switch msg {
        | Message.Assistant(Streaming(_)) => true
        | Message.ToolCall({state: InputStreaming | InputAvailable, _}) => true
        | _ => false
        }
      })
    )
  }

  // Get current figma node state
  // None = Unloaded (we don't know)
  let figmaNode = (task: Task.t): option<FigmaNode.t> => {
    switch task {
    | Task.Unloaded(_) => None
    | Task.New({figmaNode}) | Task.Loading({figmaNode}) | Task.Loaded({figmaNode}) => Some(figmaNode)
    }
  }

  // Get selected element
  // None = Unloaded (we don't know) - actual None selection is represented as Some(None)
  let selectedElement = (task: Task.t): option<option<SelectedElement.t>> => {
    switch task {
    | Task.Unloaded(_) => None
    | Task.New({selectedElement}) | Task.Loading({selectedElement}) | Task.Loaded({selectedElement}) =>
      Some(selectedElement)
    }
  }

  // Get web preview selection mode
  // None = Unloaded (we don't know)
  let webPreviewIsSelecting = (task: Task.t): option<bool> => {
    switch task {
    | Task.Unloaded(_) => None
    | Task.New({webPreviewIsSelecting})
    | Task.Loading({webPreviewIsSelecting})
    | Task.Loaded({webPreviewIsSelecting}) =>
      Some(webPreviewIsSelecting)
    }
  }

  // Check if agent is running
  // None = Unloaded, New, or Loading (not applicable)
  let isAgentRunning = (task: Task.t): option<bool> => {
    switch task {
    | Task.New(_) | Task.Unloaded(_) | Task.Loading(_) => None
    | Task.Loaded({isAgentRunning}) => Some(isAgentRunning)
    }
  }

  // Get plan entries
  // None = Unloaded, New, or Loading (not applicable)
  let planEntries = (task: Task.t): option<array<ACPTypes.planEntry>> => {
    switch task {
    | Task.New(_) | Task.Unloaded(_) | Task.Loading(_) => None
    | Task.Loaded({planEntries}) => Some(planEntries)
    }
  }

  // Get preview frame
  // None = Unloaded (we don't know)
  let previewFrame = (task: Task.t): option<Task.previewFrame> => {
    switch task {
    | Task.Unloaded(_) => None
    | Task.New({previewFrame}) | Task.Loading({previewFrame}) | Task.Loaded({previewFrame}) =>
      Some(previewFrame)
    }
  }

  // Get message created at timestamp
  let getMessageCreatedAt = (msg: Message.t): float => {
    switch msg {
    | Message.User({createdAt, _}) => createdAt
    | Message.Assistant(Streaming({createdAt, _})) => createdAt
    | Message.Assistant(Completed({createdAt, _})) => createdAt
    | Message.ToolCall({createdAt, _}) => createdAt
    }
  }

  // Get the streaming message from a task (at most one per task)
  let streamingMessage = (task: Task.t): option<Message.assistantMessage> => {
    Lens.getStreamingMessage(task)
  }
}

// ============================================================================
// Task Actions - operate on a single Task (no taskId needed)
// ============================================================================

type action =
  // Streaming actions
  | StreamingStarted
  | TextDeltaReceived({text: string})
  // Tool call actions
  | ToolInputStartReceived({
      id: string,
      toolName: string,
      parentAgentId: option<string>,
      spawningToolName: option<string>,
    })
  | ToolInputDeltaReceived({id: string, delta: string})
  | ToolInputEndReceived({id: string})
  | ToolInputReceived({id: string, input: JSON.t})
  | ToolResultReceived({id: string, result: JSON.t})
  | ToolErrorReceived({id: string, error: string})
  | ToolCallReceived({toolCall: Message.toolCall})
  // Content actions
  | AddUserMessage({id: string, content: array<UserContentPart.t>})
  | SetSelectedElement({selectedElement: option<SelectedElement.t>})
  | ToggleWebPreviewSelection
  | SetPreviewUrl({url: string})
  | SetPreviewFrame({
      contentDocument: option<WebAPI.DOMAPI.document>,
      contentWindow: option<WebAPI.DOMAPI.window>,
    })
  // Figma actions
  | SetFigmaNode({figmaNode: FigmaNode.selectedNodeData})
  | ClearFigmaNode
  | SetFigmaNodeWaiting
  | ClearFigmaNodeWaiting
  // Plan/Turn actions
  | PlanReceived({entries: array<ACPTypes.planEntry>})
  | TurnCompleted
  // Load state actions
  | LoadStarted({previewUrl: string})
  | LoadComplete
  | LoadError({error: string})
  // Hydration actions
  | UserMessageReceived({id: string, text: string, timestamp: string})


let actionToString = (action: action): string =>
  switch action {
  | AddUserMessage(_) => "AddUserMessage"
  | StreamingStarted => "StreamingStarted"
  | TextDeltaReceived(_) => "TextDeltaReceived"
  | ToolCallReceived(_) => "ToolCallReceived"
  | ToolInputStartReceived(_) => "ToolInputStartReceived"
  | ToolInputDeltaReceived(_) => "ToolInputDeltaReceived"
  | ToolInputEndReceived(_) => "ToolInputEndReceived"
  | ToolInputReceived(_) => "ToolInputReceived"
  | ToolResultReceived(_) => "ToolResultReceived"
  | ToolErrorReceived(_) => "ToolErrorReceived"
  | SetSelectedElement(_) => "SetSelectedElement"
  | ToggleWebPreviewSelection => "ToggleWebPreviewSelection"
  | SetPreviewUrl(_) => "SetPreviewUrl"
  | SetPreviewFrame(_) => "SetPreviewFrame"
  | SetFigmaNode(_) => "SetFigmaNode"
  | ClearFigmaNode => "ClearFigmaNode"
  | SetFigmaNodeWaiting => "SetFigmaNodeWaiting"
  | ClearFigmaNodeWaiting => "ClearFigmaNodeWaiting"
  | PlanReceived(_) => "PlanReceived"
  | TurnCompleted => "TurnCompleted"
  | LoadStarted(_) => "LoadStarted"
  | LoadComplete => "LoadComplete"
  | LoadError(_) => "LoadError"
  | UserMessageReceived(_) => "UserMessageReceived"
  }

// Helper to get task ID for error messages
let getTaskIdForError = (task: Task.t): string =>
  Task.getId(task)->Option.getOr("(no id)")

let next = (task: Task.t, action: action): Task.t => {
  switch (task, action) {
  // ============================================================================
  // UI State Actions - work on New, Loading, or Loaded (via Lens)
  // ============================================================================
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetPreviewUrl({url})) =>
    Lens.setPreviewUrl(task, url)

  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetPreviewFrame({contentDocument, contentWindow})) =>
    Lens.setPreviewFrame(task, ~contentDocument, ~contentWindow)

  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), ToggleWebPreviewSelection) =>
    Lens.toggleWebPreviewSelection(task)

  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetSelectedElement({selectedElement})) =>
    Lens.setSelectedElement(task, selectedElement)

  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetFigmaNode({figmaNode})) =>
    Lens.setFigmaNode(task, figmaNode)

  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), ClearFigmaNode) =>
    Lens.clearFigmaNode(task)

  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetFigmaNodeWaiting) =>
    Lens.setFigmaNodeWaiting(task)

  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), ClearFigmaNodeWaiting) =>
    Lens.clearFigmaNode(task) // Same as ClearFigmaNode

  // ============================================================================
  // Message Actions - work on Loading or Loaded (via Lens)
  // ============================================================================
  | (Task.Loading(_) | Task.Loaded(_), StreamingStarted) =>
    switch Lens.getStreamingMessage(task) {
    | Some(_) => failwith(`[TaskReducer] StreamingStarted but streaming message already exists in task ${getTaskIdForError(task)}`)
    | None =>
      let msgId = `msg_${getTaskIdForError(task)}_${Date.now()->Float.toString}`
      let newMessage = Message.Assistant(Streaming({id: msgId, textBuffer: "", createdAt: Date.now()}))
      Lens.insertMessage(task, newMessage)
    }

  | (Task.Loading(_) | Task.Loaded(_), TextDeltaReceived({text})) =>
    switch Lens.getStreamingMessage(task) {
    | Some(Message.Streaming({id: msgId, textBuffer, createdAt})) =>
      let updatedMsg = Message.Assistant(Streaming({id: msgId, textBuffer: textBuffer ++ text, createdAt}))
      Lens.updateMessage(task, msgId, _ => updatedMsg)
    | Some(Message.Completed(_)) => failwith(`[TaskReducer] TextDeltaReceived but message already Completed in task ${getTaskIdForError(task)}`)
    | None =>
      // Per ACP spec: first agent_message_chunk implicitly signals message start
      // Auto-create streaming message with the received text
      let msgId = `msg_${getTaskIdForError(task)}_${Date.now()->Float.toString}`
      let newMessage = Message.Assistant(Streaming({id: msgId, textBuffer: text, createdAt: Date.now()}))
      Lens.insertMessage(task, newMessage)
    }

  | (Task.Loading(_) | Task.Loaded(_), ToolCallReceived({toolCall})) =>
    let messages = Task.getMessages(task)
    switch messages->Array.find(msg => Message.getId(msg) == toolCall.id) {
    | Some(Message.ToolCall(existingToolCall)) =>
      Lens.updateMessage(task, toolCall.id, _ =>
        Message.ToolCall({
          ...existingToolCall,
          input: toolCall.input,
          state: Message.InputAvailable,
          parentAgentId: toolCall.parentAgentId,
          spawningToolName: toolCall.spawningToolName,
        })
      )
    | Some(msg) => failwith(`[TaskReducer] ToolCallReceived but message ${Message.getId(msg)} is not a ToolCall`)
    | None => Lens.insertMessage(task, Message.ToolCall(toolCall))
    }

  | (Task.Loading(_) | Task.Loaded(_), ToolInputStartReceived({id, toolName, parentAgentId, spawningToolName})) =>
    Lens.insertMessage(
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

  | (Task.Loading(_) | Task.Loaded(_), ToolInputDeltaReceived({id, delta})) =>
    Lens.updateMessage(task, id, msg =>
      switch msg {
      | Message.ToolCall(tool) => Message.ToolCall({...tool, inputBuffer: tool.inputBuffer ++ delta})
      | _ => failwith(`[TaskReducer] ToolInputDeltaReceived but message ${id} is not a ToolCall`)
      }
    )

  | (Task.Loading(_) | Task.Loaded(_), ToolInputEndReceived({id})) =>
    Lens.updateMessage(task, id, msg =>
      switch msg {
      | Message.ToolCall(tool) =>
        let parsedInput = try {
          Some(JSON.parseOrThrow(tool.inputBuffer))
        } catch {
        | exn =>
          let errorMsg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("unknown error")
          let errorObj = {"error": `Failed to parse tool input: ${errorMsg}`, "originalInput": tool.inputBuffer}
          JSON.stringifyAny(errorObj)->Option.flatMap(str => Some(JSON.parseOrThrow(str)))
        }
        Message.ToolCall({...tool, input: parsedInput, state: Message.InputAvailable})
      | _ => failwith(`[TaskReducer] ToolInputEndReceived but message ${id} is not a ToolCall`)
      }
    )

  | (Task.Loading(_) | Task.Loaded(_), ToolInputReceived({id, input})) =>
    Lens.updateMessage(task, id, msg =>
      switch msg {
      | Message.ToolCall(tool) => Message.ToolCall({...tool, input: Some(input)})
      | _ => failwith(`[TaskReducer] ToolInputReceived but message ${id} is not a ToolCall`)
      }
    )

  | (Task.Loading(_) | Task.Loaded(_), ToolResultReceived({id, result})) =>
    Lens.updateMessage(task, id, msg =>
      switch msg {
      | Message.ToolCall(tool) => Message.ToolCall({...tool, result: Some(result), state: Message.OutputAvailable})
      | _ => failwith(`[TaskReducer] ToolResultReceived but message ${id} is not a ToolCall`)
      }
    )

  | (Task.Loading(_) | Task.Loaded(_), ToolErrorReceived({id, error})) =>
    Lens.updateMessage(task, id, msg =>
      switch msg {
      | Message.ToolCall(tool) => Message.ToolCall({...tool, errorText: Some(error), state: Message.OutputError})
      | _ => failwith(`[TaskReducer] ToolErrorReceived but message ${id} is not a ToolCall`)
      }
    )

  // Hydration: user messages replayed from history
  // Per ACP spec: a new user message signals the end of the previous agent message
  | (Task.Loading(_), UserMessageReceived({id, text, timestamp})) =>
    let createdAt = Date.fromString(timestamp)->Date.getTime
    let userMessage = Message.User({id, content: [UserContentPart.text(text)], createdAt})
    task->Lens.completeStreamingMessage->Lens.insertMessage(userMessage)

  // ============================================================================
  // Loaded-only Actions - require isAgentRunning or planEntries
  // ============================================================================
  | (Task.Loaded(data), AddUserMessage({id, content})) =>
    let message = Message.User({id, content, createdAt: Date.now()})
    Task.Loaded({
      ...data,
      messages: data.messages->Array.concat([message]),
      isAgentRunning: true,
    })

  | (Task.Loaded(data), PlanReceived({entries})) =>
    Task.Loaded({...data, planEntries: entries})

  | (Task.Loaded(_), TurnCompleted) =>
    // Per ACP spec: session/prompt response signals message end
    let completed = task->Lens.completeStreamingMessage
    switch completed {
    | Task.Loaded(completedData) => Task.Loaded({...completedData, isAgentRunning: false})
    | _ => completed // Should never happen for Loaded task
    }

  // ============================================================================
  // Load State Transitions
  // ============================================================================
  | (Task.Unloaded({id, title, createdAt, updatedAt}), LoadStarted({previewUrl})) =>
    Task.Loading({
      id,
      title,
      createdAt,
      updatedAt,
      messages: [],
      previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None},
      webPreviewIsSelecting: false,
      selectedElement: None,
      figmaNode: FigmaNode.NoSelection,
    })

  | (Task.Loading(_), LoadComplete) =>
    // Per ACP spec: session/load response signals end of history replay
    // Complete any remaining streaming message, then transition to Loaded
    switch task->Lens.completeStreamingMessage {
    | Task.Loading({id, title, createdAt, updatedAt, messages, previewFrame, webPreviewIsSelecting, selectedElement, figmaNode}) =>
      let sortedMessages = messages->Array.toSorted((a, b) =>
        Selectors.getMessageCreatedAt(a) -. Selectors.getMessageCreatedAt(b)
      )
      Task.Loaded({
        id,
        title,
        createdAt,
        updatedAt,
        messages: sortedMessages,
        previewFrame,
        webPreviewIsSelecting,
        selectedElement,
        figmaNode,
        isAgentRunning: false,
        planEntries: [],
      })
    | _ => failwith("[TaskReducer] LoadComplete: unexpected task state after completeStreamingMessage")
    }

  | (Task.Loading({id, title, createdAt, updatedAt}), LoadError({error})) =>
    Console.error2("[TaskReducer] Task load failed:", error)
    Task.Unloaded({id, title, createdAt, updatedAt})

  // ============================================================================
  // Catch-all - invalid state/action combinations
  // ============================================================================
  | (_, action) =>
    failwith(`[TaskReducer] ${actionToString(action)} on ${Task.stateToString(task)} task ${getTaskIdForError(task)}`)
  }
}
