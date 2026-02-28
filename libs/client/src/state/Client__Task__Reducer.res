// Task reducer - self-contained domain logic for Task aggregate
// All actions operate on a single Task (no taskId needed)

module Log = FrontmanLogs.Logs.Make({
  let component = #TaskReducer
})

module Types = Client__Task__Types
module Task = Types.Task
module Message = Types.Message
module UserContentPart = Types.UserContentPart
module AssistantContentPart = Types.AssistantContentPart
module SelectedElement = Types.SelectedElement
module ACPTypes = Types.ACPTypes

// ============================================================================
// Lens Module - Composable state update functions for Task
// ============================================================================

module MessageStore = Client__MessageStore

module Lens = {
  // Update messages within a task (crashes if New or Unloaded - they have no messages)
  let updateMessages = (task: Task.t, fn: MessageStore.t => MessageStore.t): Task.t => {
    switch task {
    | Task.New(_) | Task.Unloaded(_) =>
      failwith("[Lens.updateMessages] Cannot update messages on New/Unloaded task")
    | Task.Loading(data) => Task.Loading({...data, messages: fn(data.messages)})
    | Task.Loaded(data) => Task.Loaded({...data, messages: fn(data.messages)})
    }
  }

  // Update a specific message by ID - O(1) lookup via index
  let updateMessage = (task: Task.t, msgId: string, fn: Message.t => Message.t): Task.t => {
    updateMessages(task, store => MessageStore.update(store, msgId, fn))
  }

  // Insert a message at the end
  let insertMessage = (task: Task.t, message: Message.t): Task.t => {
    updateMessages(task, store => MessageStore.insert(store, message))
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
    updateMessages(task, store =>
      MessageStore.map(store, msg =>
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
    | Task.New(data) =>
      Task.New({...data, previewFrame: {...data.previewFrame, contentDocument, contentWindow}})
    | Task.Loading(data) =>
      Task.Loading({...data, previewFrame: {...data.previewFrame, contentDocument, contentWindow}})
    | Task.Loaded(data) =>
      Task.Loaded({...data, previewFrame: {...data.previewFrame, contentDocument, contentWindow}})
    | Task.Unloaded(_) =>
      failwith("[Lens.setPreviewFrame] Cannot set preview frame on Unloaded task")
    }
  }

  // Update device mode
  let setDeviceMode = (task: Task.t, deviceMode: Client__DeviceMode.deviceMode): Task.t => {
    switch task {
    | Task.New(data) =>
      Task.New({...data, previewFrame: {...data.previewFrame, deviceMode}})
    | Task.Loading(data) =>
      Task.Loading({...data, previewFrame: {...data.previewFrame, deviceMode}})
    | Task.Loaded(data) =>
      Task.Loaded({...data, previewFrame: {...data.previewFrame, deviceMode}})
    | Task.Unloaded(_) =>
      failwith("[Lens.setDeviceMode] Cannot set device mode on Unloaded task")
    }
  }

  // Update orientation
  let setOrientation = (task: Task.t, orientation: Client__DeviceMode.orientation): Task.t => {
    switch task {
    | Task.New(data) =>
      Task.New({...data, previewFrame: {...data.previewFrame, orientation}})
    | Task.Loading(data) =>
      Task.Loading({...data, previewFrame: {...data.previewFrame, orientation}})
    | Task.Loaded(data) =>
      Task.Loaded({...data, previewFrame: {...data.previewFrame, orientation}})
    | Task.Unloaded(_) =>
      failwith("[Lens.setOrientation] Cannot set orientation on Unloaded task")
    }
  }

  // Toggle web preview selection mode
  let toggleWebPreviewSelection = (task: Task.t): Task.t => {
    switch task {
    | Task.New(data) =>
      Task.New({
        ...data,
        webPreviewIsSelecting: !data.webPreviewIsSelecting,
        selectedElement: if !data.webPreviewIsSelecting {
          None
        } else {
          data.selectedElement
        },
      })
    | Task.Loading(data) =>
      Task.Loading({
        ...data,
        webPreviewIsSelecting: !data.webPreviewIsSelecting,
        selectedElement: if !data.webPreviewIsSelecting {
          None
        } else {
          data.selectedElement
        },
      })
    | Task.Loaded(data) =>
      Task.Loaded({
        ...data,
        webPreviewIsSelecting: !data.webPreviewIsSelecting,
        selectedElement: if !data.webPreviewIsSelecting {
          None
        } else {
          data.selectedElement
        },
      })
    | Task.Unloaded(_) =>
      failwith("[Lens.toggleWebPreviewSelection] Cannot toggle on Unloaded task")
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
    | Task.Loading({messages}) | Task.Loaded({messages}) => Some(MessageStore.toArray(messages))
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

  // Get selected element
  // None = Unloaded (we don't know) - actual None selection is represented as Some(None)
  let selectedElement = (task: Task.t): option<option<SelectedElement.t>> => {
    switch task {
    | Task.Unloaded(_) => None
    | Task.New({selectedElement})
    | Task.Loading({selectedElement})
    | Task.Loaded({selectedElement}) =>
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

  // Get device mode
  let deviceMode = (task: Task.t): Client__DeviceMode.deviceMode => {
    switch task {
    | Task.Unloaded(_) => Client__DeviceMode.defaultDeviceMode
    | Task.New({previewFrame}) | Task.Loading({previewFrame}) | Task.Loaded({previewFrame}) =>
      previewFrame.deviceMode
    }
  }

  // Get orientation
  let orientation = (task: Task.t): Client__DeviceMode.orientation => {
    switch task {
    | Task.Unloaded(_) => Client__DeviceMode.defaultOrientation
    | Task.New({previewFrame}) | Task.Loading({previewFrame}) | Task.Loaded({previewFrame}) =>
      previewFrame.orientation
    }
  }

  // Get turn error
  // None = Unloaded, New, or Loading (not applicable), or no error
  let turnError = (task: Task.t): option<string> => {
    switch task {
    | Task.New(_) | Task.Unloaded(_) | Task.Loading(_) => None
    | Task.Loaded({turnError}) => turnError
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
  // Device mode actions
  | SetDeviceMode({deviceMode: Client__DeviceMode.deviceMode})
  | SetOrientation({orientation: Client__DeviceMode.orientation})
  | ToggleDeviceMode
  // Plan/Turn actions
  | PlanReceived({entries: array<ACPTypes.planEntry>})
  | TurnCompleted
  | CancelTurn
  // Error actions
  | AgentError({error: string})
  | ClearTurnError
  // Load state actions
  | LoadStarted({previewUrl: string})
  | LoadComplete
  | LoadError({error: string})
  // Hydration actions
  | UserMessageReceived({id: string, text: string, timestamp: string})

// ============================================================================
// Effects - side effects that the task reducer requests
// ============================================================================

type effect =
  | FetchElementDetails({
      element: WebAPI.DOMAPI.element,
      document: option<WebAPI.DOMAPI.document>,
      contentWindow: option<WebAPI.DOMAPI.window>,
    })
  | SendMessage({
      text: string,
      attachments: array<Message.fileAttachmentData>,
    })
  | NotifyTurnCompleted
  | CancelPrompt

// Delegated effects - things the task needs from its parent
type delegated =
  | NeedSendMessage({
      text: string,
      attachments: array<Message.fileAttachmentData>,
    })
  | NeedUsageRefresh
  | NeedCancelPrompt

let actionToString = (action: action): string =>
  switch action {
  | AddUserMessage(_) => "AddUserMessage"
  | StreamingStarted => "StreamingStarted"
  | TextDeltaReceived(_) => "TextDeltaReceived"
  | ToolCallReceived(_) => "ToolCallReceived"
  | ToolInputReceived(_) => "ToolInputReceived"
  | ToolResultReceived(_) => "ToolResultReceived"
  | ToolErrorReceived(_) => "ToolErrorReceived"
  | SetSelectedElement(_) => "SetSelectedElement"
  | ToggleWebPreviewSelection => "ToggleWebPreviewSelection"
  | SetPreviewUrl(_) => "SetPreviewUrl"
  | SetPreviewFrame(_) => "SetPreviewFrame"
  | SetDeviceMode(_) => "SetDeviceMode"
  | SetOrientation(_) => "SetOrientation"
  | ToggleDeviceMode => "ToggleDeviceMode"
  | PlanReceived(_) => "PlanReceived"
  | TurnCompleted => "TurnCompleted"
  | CancelTurn => "CancelTurn"
  | AgentError(_) => "AgentError"
  | ClearTurnError => "ClearTurnError"
  | LoadStarted(_) => "LoadStarted"
  | LoadComplete => "LoadComplete"
  | LoadError(_) => "LoadError"
  | UserMessageReceived(_) => "UserMessageReceived"
  }

// Normalize URL by removing trailing slash for comparison
let normalizeUrl = (url: string): string => {
  url->String.endsWith("/") && String.length(url) > 1
    ? url->String.slice(~start=0, ~end=String.length(url) - 1)
    : url
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

// Helper to extract image/file attachments from user message parts
let extractAttachmentsFromUserContent = (
  content: array<UserContentPart.t>,
): array<Message.fileAttachmentData> => {
  content->Array.filterMap(part => {
    switch part {
    | Image({id, image, mediaType, name}) =>
      Some({
        Message.id: id->Option.getOrThrow,
        dataUrl: image,
        mediaType: mediaType->Option.getOrThrow,
        filename: name->Option.getOrThrow,
      })
    | File({file}) =>
      Some({
        Message.id: WebAPI.Global.crypto->WebAPI.Crypto.randomUUID,
        dataUrl: file,
        mediaType: "application/octet-stream",
        filename: "file",
      })
    | Text(_) => None
    }
  })
}

// Helper to get task ID for error messages
let getTaskIdForError = (task: Task.t): string => Task.getId(task)->Option.getOr("(no id)")

let next = (task: Task.t, action: action): (Task.t, array<effect>) => {
  switch (task, action) {
  // ============================================================================
  // UI State Actions - work on New, Loading, or Loaded (via Lens)
  // ============================================================================
  | (Task.Unloaded(_), SetPreviewUrl(_)) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetPreviewUrl({url})) =>
    let currentUrl = Task.getPreviewFrame(task, ~defaultUrl="").url
    let urlChanged = normalizeUrl(currentUrl) != normalizeUrl(url)
    let updated = Lens.setPreviewUrl(task, url)

    // Clear selected element only on actual navigation, not initial iframe mount
    if urlChanged {
      (Lens.setSelectedElement(updated, None), [])
    } else {
      (updated, [])
    }

  | (Task.Unloaded(_), SetPreviewFrame(_)) => (task, [])
  | (
      Task.New(_) | Task.Loading(_) | Task.Loaded(_),
      SetPreviewFrame({contentDocument, contentWindow}),
    ) => (Lens.setPreviewFrame(task, ~contentDocument, ~contentWindow), [])

  // Device mode actions
  | (Task.Unloaded(_), SetDeviceMode(_) | SetOrientation(_) | ToggleDeviceMode) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetDeviceMode({deviceMode})) =>
    let updated = Lens.setDeviceMode(task, deviceMode)
    (updated, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetOrientation({orientation})) =>
    let updated = Lens.setOrientation(task, orientation)
    (updated, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), ToggleDeviceMode) =>
    let currentDeviceMode = Selectors.deviceMode(task)
    let newDeviceMode = switch currentDeviceMode {
    | Client__DeviceMode.Responsive =>
      // When toggling on, default to iPhone 15 Pro (index 1 in presets)
      Client__DeviceMode.DevicePreset(
        Client__DeviceMode.presets->Array.get(1)->Option.getOrThrow
      )
    | _ => Client__DeviceMode.Responsive
    }
    (Lens.setDeviceMode(task, newDeviceMode), [])

  | (Task.Unloaded(_), ToggleWebPreviewSelection) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), ToggleWebPreviewSelection) => (
      Lens.toggleWebPreviewSelection(task),
      [],
    )

  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetSelectedElement({selectedElement})) =>
    // Decide if we need to fetch element details
    let effects = switch selectedElement {
    | Some({element, selector: None, screenshot: None, sourceLocation: None}) =>
      let previewFrame = Task.getPreviewFrame(task, ~defaultUrl="")
      [
        FetchElementDetails({
          element,
          document: previewFrame.contentDocument,
          contentWindow: previewFrame.contentWindow,
        }),
      ]
    | _ => []
    }
    (Lens.setSelectedElement(task, selectedElement), effects)

  // ============================================================================
  // Message Actions - work on Loading or Loaded (via Lens)
  // ============================================================================

  // Guard: drop stale streaming events that arrive after cancel
  // When a turn is cancelled, isAgentRunning is set to false. Any streaming
  // events that arrive after that are late echoes from the killed agent process.
  | (Task.Loaded({isAgentRunning: false}),
    StreamingStarted
    | TextDeltaReceived(_)
    | ToolCallReceived(_)
    | ToolInputReceived(_)
    | ToolResultReceived(_)
    | ToolErrorReceived(_)) =>
    (task, [])

  | (Task.Loading(_) | Task.Loaded(_), StreamingStarted) =>
    switch Lens.getStreamingMessage(task) {
    | Some(_) =>
      failwith(
        `[TaskReducer] StreamingStarted but streaming message already exists in task ${getTaskIdForError(
            task,
          )}`,
      )
    | None =>
      let msgId = `msg_${getTaskIdForError(task)}_${Date.now()->Float.toString}`
      let newMessage = Message.Assistant(
        Streaming({id: msgId, textBuffer: "", createdAt: Date.now()}),
      )
      (Lens.insertMessage(task, newMessage), [])
    }

  | (Task.Loading(_) | Task.Loaded(_), TextDeltaReceived({text})) =>
    switch Lens.getStreamingMessage(task) {
    | Some(Message.Streaming({id: msgId, textBuffer, createdAt})) =>
      let updatedMsg = Message.Assistant(
        Streaming({id: msgId, textBuffer: textBuffer ++ text, createdAt}),
      )
      (Lens.updateMessage(task, msgId, _ => updatedMsg), [])
    | Some(Message.Completed(_)) =>
      failwith(
        `[TaskReducer] TextDeltaReceived but message already Completed in task ${getTaskIdForError(
            task,
          )}`,
      )
    | None =>
      // Per ACP spec: first agent_message_chunk implicitly signals message start
      // Check if last message is a Completed assistant message - if so, reopen it for streaming
      let messages = Task.getMessages(task)
      let lastMsg = messages->Array.get(Array.length(messages) - 1)
      switch lastMsg {
      | Some(Message.Assistant(Completed({id: msgId, content, createdAt}))) =>
        // Extract existing text from all Text content parts
        let existingText =
          content
          ->Array.filterMap(part =>
            switch part {
            | AssistantContentPart.Text({text: t}) => Some(t)
            | AssistantContentPart.ToolCall(_) => None
            }
          )
          ->Array.join("")
        // Convert back to Streaming with appended text
        let updatedMsg = Message.Assistant(
          Streaming({id: msgId, textBuffer: existingText ++ text, createdAt}),
        )
        (Lens.updateMessage(task, msgId, _ => updatedMsg), [])
      | _ =>
        // Last message is User/ToolCall/None - create new streaming message
        let msgId = `msg_${getTaskIdForError(task)}_${Date.now()->Float.toString}`
        let newMessage = Message.Assistant(
          Streaming({id: msgId, textBuffer: text, createdAt: Date.now()}),
        )
        (Lens.insertMessage(task, newMessage), [])
      }
    }

  | (Task.Loading(_) | Task.Loaded(_), ToolCallReceived({toolCall})) =>
    // Complete any streaming message before inserting tool call
    // This ensures text after tool calls creates a new message
    let taskWithCompletedMsg = Lens.completeStreamingMessage(task)
    let messages = Task.getMessages(taskWithCompletedMsg)
    switch messages->Array.find(msg => Message.getId(msg) == toolCall.id) {
    | Some(Message.ToolCall(existingToolCall)) => (
        Lens.updateMessage(taskWithCompletedMsg, toolCall.id, _ => Message.ToolCall({
          ...existingToolCall,
          input: toolCall.input,
          state: Message.InputAvailable,
          parentAgentId: toolCall.parentAgentId,
          spawningToolName: toolCall.spawningToolName,
        })),
        [],
      )
    | Some(msg) =>
      failwith(`[TaskReducer] ToolCallReceived but message ${Message.getId(msg)} is not a ToolCall`)
    | None => (Lens.insertMessage(taskWithCompletedMsg, Message.ToolCall(toolCall)), [])
    }

  | (Task.Loading(_) | Task.Loaded(_), ToolInputReceived({id, input})) => (
      Lens.updateMessage(task, id, msg =>
        switch msg {
        | Message.ToolCall(tool) => Message.ToolCall({...tool, input: Some(input)})
        | _ => failwith(`[TaskReducer] ToolInputReceived but message ${id} is not a ToolCall`)
        }
      ),
      [],
    )

  | (Task.Loading(_) | Task.Loaded(_), ToolResultReceived({id, result})) => (
      Lens.updateMessage(task, id, msg =>
        switch msg {
        | Message.ToolCall(tool) =>
          Message.ToolCall({...tool, result: Some(result), state: Message.OutputAvailable})
        | _ => failwith(`[TaskReducer] ToolResultReceived but message ${id} is not a ToolCall`)
        }
      ),
      [],
    )

  | (Task.Loading(_) | Task.Loaded(_), ToolErrorReceived({id, error})) => (
      Lens.updateMessage(task, id, msg =>
        switch msg {
        | Message.ToolCall(tool) =>
          Message.ToolCall({...tool, errorText: Some(error), state: Message.OutputError})
        | _ => failwith(`[TaskReducer] ToolErrorReceived but message ${id} is not a ToolCall`)
        }
      ),
      [],
    )

  // Hydration: user messages replayed from history
  // Per ACP spec: a new user message signals the end of the previous agent message
  | (Task.Loading(_), UserMessageReceived({id, text, timestamp})) =>
    let createdAt = Date.fromString(timestamp)->Date.getTime
    let userMessage = Message.User({id, content: [UserContentPart.text(text)], createdAt})
    (task->Lens.completeStreamingMessage->Lens.insertMessage(userMessage), [])

  // ============================================================================
  // Loaded-only Actions - require isAgentRunning or planEntries
  // ============================================================================
  | (Task.Loaded(data), AddUserMessage({id, content})) =>
    let text = extractTextFromUserContent(content)
    let attachments = extractAttachmentsFromUserContent(content)
    let message = Message.User({id, content, createdAt: Date.now()})

    // Accumulate image attachments keyed by URI for write_file image_ref resolution
    let updatedImageAttachments = data.imageAttachments->Dict.copy
    attachments->Array.forEach(att => {
      let uri = `attachment://${att.id}/${att.filename}`
      updatedImageAttachments->Dict.set(uri, att)
    })

    (
      Task.Loaded({
        ...data,
        messages: MessageStore.insert(data.messages, message),
        isAgentRunning: true,
        turnError: None, // Clear any previous error when sending a new message
        imageAttachments: updatedImageAttachments,
      }),
      [SendMessage({text, attachments})],
    )

  | (Task.Loaded(data), PlanReceived({entries})) => (
      Task.Loaded({...data, planEntries: entries}),
      [],
    )

  | (Task.Loaded(_), TurnCompleted) =>
    // Per ACP spec: session/prompt response signals message end
    let completed = task->Lens.completeStreamingMessage
    let updatedTask = completed->Task.updateLoadedData(data => {...data, isAgentRunning: false})
    (updatedTask, [NotifyTurnCompleted])

  // Cancel the current turn: complete any partial response, stop agent
  | (Task.Loaded(data), CancelTurn) =>
    if !data.isAgentRunning {
      (task, [])
    } else {
      // Complete any streaming message (keeps partial text as a truncated response)
      // and mark in-progress tool calls as cancelled
      let completed = Lens.completeStreamingMessage(task)
      // Cancel any in-progress tool calls (InputStreaming or InputAvailable)
      let withCancelledTools = Lens.updateMessages(completed, store =>
        MessageStore.map(store, msg =>
          switch msg {
          | Message.ToolCall(tool) if tool.state == Message.InputStreaming || tool.state == Message.InputAvailable =>
            Message.ToolCall({...tool, state: Message.OutputError, errorText: Some("Cancelled")})
          | other => other
          }
        )
      )
      let final = withCancelledTools->Task.updateLoadedData(d => {...d, isAgentRunning: false, turnError: None})
      (final, [CancelPrompt])
    }

  | (Task.Loaded(data), AgentError({error})) =>
    // Set turn error and stop agent running - user can still send messages
    let completed = task->Lens.completeStreamingMessage
    switch completed {
    | Task.Loaded(completedData) => (
        Task.Loaded({...completedData, turnError: Some(error), isAgentRunning: false}),
        [NotifyTurnCompleted],
      )
    | _ => (
        Task.Loaded({...data, turnError: Some(error), isAgentRunning: false}),
        [NotifyTurnCompleted],
      )
    }

  | (Task.Loaded(data), ClearTurnError) => (Task.Loaded({...data, turnError: None}), [])

  // ============================================================================
  // Load State Transitions
  // ============================================================================
  | (Task.Unloaded({id, title, createdAt, updatedAt}), LoadStarted({previewUrl})) => (
      Task.Loading({
        id,
        title,
        createdAt,
        updatedAt,
        messages: MessageStore.make(),
        previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None, deviceMode: Client__DeviceMode.defaultDeviceMode, orientation: Client__DeviceMode.defaultOrientation},
        webPreviewIsSelecting: false,
        selectedElement: None,
      }),
      [],
    )

  | (Task.Loading(_), LoadComplete) =>
    // Per ACP spec: session/load response signals end of history replay
    // Complete any remaining streaming message, then transition to Loaded
    switch task->Lens.completeStreamingMessage {
    | Task.Loading({
        id,
        title,
        createdAt,
        updatedAt,
        messages,
        previewFrame,
        webPreviewIsSelecting,
        selectedElement,
      }) =>
      let sortedMessages = MessageStore.toSorted(messages, (a, b) =>
        Selectors.getMessageCreatedAt(a) -. Selectors.getMessageCreatedAt(b)
      )
      (
        Task.Loaded({
          id,
          clientId: None,
          title,
          createdAt,
          updatedAt,
          messages: sortedMessages,
          previewFrame,
          webPreviewIsSelecting,
          selectedElement,
          isAgentRunning: false,
          planEntries: [],
          turnError: None,
          imageAttachments: Dict.make(),
        }),
        [],
      )
    | _ =>
      failwith("[TaskReducer] LoadComplete: unexpected task state after completeStreamingMessage")
    }

  | (Task.Loading({id, title, createdAt, updatedAt}), LoadError({error})) =>
    Log.error(~ctx={"error": error}, "Task load failed")
    (Task.Unloaded({id, title, createdAt, updatedAt}), [])

  // ============================================================================
  // Catch-all - invalid state/action combinations
  // ============================================================================
  | (_, action) =>
    failwith(
      `[TaskReducer] ${actionToString(action)} on ${Task.stateToString(
          task,
        )} task ${getTaskIdForError(task)}`,
    )
  }
}

// ============================================================================
// Effect Handler - processes task effects, delegates to parent when needed
// ============================================================================

let handleEffect = (effect: effect, ~dispatch: action => unit, ~delegate: delegated => unit) => {
  switch effect {
  | FetchElementDetails({element, document, contentWindow}) => {
      // Fetch selector
      let selectorPromise =
        Promise.resolve()
        ->Promise.then(_ => {
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
        ->Promise.catch(error => {
          Log.error(~ctx={"error": error}, "Failed to get selector")
          Promise.resolve(None)
        })

      // Fetch screenshot (with conservative dimension limits to stay within all provider caps).
      // Uses conservative limits (7680px) — safe for every provider. The server-side gate
      // in agents.ex strips anything that still exceeds the limit.
      let screenshotPromise = {
        let limits = Client__ImageLimits.conservative
        let scale = Client__ImageLimits.computeScale(element, limits.maxDimension)

        Bindings__Snapdom.snapdom(element)
        ->Promise.then(captureResult => {
          captureResult.toJpg({scale, quality: limits.quality})->Promise.then(img => {
            Promise.resolve(Some(img))
          })
        })
        ->Promise.catch(error => {
          Log.error(~ctx={"error": error}, "Failed to capture screenshot")
          Promise.resolve(None)
        })
      }

      // Fetch source location (cascading: React fiber first, then Astro annotations)
      // Race against a timeout to prevent hanging when source map resolution stalls (e.g., CORS on RSC URLs)
      let sourceLocationPromise = {
        let detectionPromise = switch contentWindow {
        | Some(window) =>
          Bindings__SourceDetection.getElementSourceLocation(~element, ~window)
          ->Promise.catch(error => {
            Log.error(~ctx={"error": error}, "Failed to get source location")
            Promise.resolve(None)
          })
        | None => Promise.resolve(None)
        }
        let timeoutPromise = Promise.make((resolve, _) => {
          let _ = Js.Global.setTimeout(() => resolve(None), 5000)
        })
        Promise.race([detectionPromise, timeoutPromise])
      }

      // Wait for all promises and update state once
      let _ =
        Promise.all3((selectorPromise, screenshotPromise, sourceLocationPromise))
        ->Promise.then(((selector, screenshot, sourceLocation)) => {
          let sourceLocationWithTagName = sourceLocation->Option.map(sourceLoc => {
            {
              ...sourceLoc,
              file: sourceLoc.file
              ->String.split("?")
              ->Array.get(0)
              ->Option.getOr(sourceLoc.file),
            }
          })

          // Resolve source location via server to get relative file paths
          let resolvedSourceLocationPromise = switch sourceLocationWithTagName {
          | Some(sourceLoc) =>
            Client__SourceLocationResolver.resolve(sourceLoc)->Promise.then(result => {
              switch result {
              | Ok(resolved) => Promise.resolve(Some(resolved))
              | Error(err) =>
                Log.warning(~ctx={"error": err}, "Source location resolution failed, using original")
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
                  screenshot: screenshot->Option.map(s => s.src),
                  sourceLocation: finalSourceLocation,
                }),
              }),
            )
            Promise.resolve()
          })
        })
        ->Promise.catch(_ => {
          Promise.resolve()
        })
    }
  | SendMessage({text, attachments}) => delegate(NeedSendMessage({text, attachments}))
  | NotifyTurnCompleted => delegate(NeedUsageRefresh)
  | CancelPrompt => delegate(NeedCancelPrompt)
  }
}
