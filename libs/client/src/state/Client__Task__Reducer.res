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
module Annotation = Types.Annotation
module ACPTypes = Types.ACPTypes

// ============================================================================
// Lens Module - Composable state update functions for Task
// ============================================================================

module MessageStore = Client__MessageStore

module Lens = {
  // ---- Generic helpers to eliminate repetitive 4-way switches ----

  // Update the previewFrame on New/Loading/Loaded (crashes on Unloaded)
  let updatePreviewFrame = (task: Task.t, fn: Task.previewFrame => Task.previewFrame): Task.t =>
    switch task {
    | Task.New(data) => Task.New({...data, previewFrame: fn(data.previewFrame)})
    | Task.Loading(data) => Task.Loading({...data, previewFrame: fn(data.previewFrame)})
    | Task.Loaded(data) => Task.Loaded({...data, previewFrame: fn(data.previewFrame)})
    | Task.Unloaded(_) =>
      failwith("[Lens.updatePreviewFrame] Cannot update preview frame on Unloaded task")
    }

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

  // ---- PreviewFrame lenses (delegate to updatePreviewFrame) ----

  let setPreviewUrl = (task: Task.t, url: string): Task.t =>
    updatePreviewFrame(task, pf => {...pf, url})

  let setPreviewFrame = (
    task: Task.t,
    ~contentDocument: option<WebAPI.DOMAPI.document>,
    ~contentWindow: option<WebAPI.DOMAPI.window>,
  ): Task.t =>
    updatePreviewFrame(task, pf => {...pf, contentDocument, contentWindow})

  let setDeviceMode = (task: Task.t, deviceMode: Client__DeviceMode.deviceMode): Task.t =>
    updatePreviewFrame(task, pf => {...pf, deviceMode})

  let setOrientation = (task: Task.t, orientation: Client__DeviceMode.orientation): Task.t =>
    updatePreviewFrame(task, pf => {...pf, orientation})

  // ---- Annotation / UI lenses ----

  // Like Task.updateLoadedData but crashes on Unloaded (crash-early contract)
  let updateTaskData = (task: Task.t, fn: Task.loadedData => Task.loadedData): Task.t =>
    switch task {
    | Task.Unloaded(_) => failwith("[Lens.updateTaskData] Cannot update Unloaded task")
    | _ => Task.updateLoadedData(task, fn)
    }

  let setAnnotationMode = (task: Task.t, mode: Annotation.annotationMode): Task.t =>
    updateTaskData(task, d => {...d, annotationMode: mode})

  let setAnnotations = (task: Task.t, annotations: array<Annotation.t>): Task.t =>
    updateTaskData(task, d => {...d, annotations})

  let updateAnnotation = (task: Task.t, id: string, fn: Annotation.t => Annotation.t): Task.t => {
    let annotations = Task.getAnnotations(task)
    let updated = annotations->Array.map(a => a.id == id ? fn(a) : a)
    setAnnotations(task, updated)
  }

  let setAnimationFrozen = (task: Task.t, frozen: bool): Task.t =>
    updateTaskData(task, d => {...d, isAnimationFrozen: frozen})

  let setActivePopupAnnotationId = (task: Task.t, id: option<string>): Task.t =>
    updateTaskData(task, d => {...d, activePopupAnnotationId: id})

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

  // Get annotations
  // None = Unloaded (we don't know)
  let annotations = (task: Task.t): option<array<Annotation.t>> => {
    switch task {
    | Task.Unloaded(_) => None
    | Task.New({annotations})
    | Task.Loading({annotations})
    | Task.Loaded({annotations}) =>
      Some(annotations)
    }
  }

  // Get annotation mode
  // None = Unloaded (we don't know)
  let annotationMode = (task: Task.t): option<Annotation.annotationMode> => {
    switch task {
    | Task.Unloaded(_) => None
    | Task.New({annotationMode})
    | Task.Loading({annotationMode})
    | Task.Loaded({annotationMode}) =>
      Some(annotationMode)
    }
  }

  // Derive webPreviewIsSelecting from annotationMode
  let webPreviewIsSelecting = (task: Task.t): option<bool> => {
    switch task {
    | Task.Unloaded(_) => None
    | _ => Some(Task.getWebPreviewIsSelecting(task))
    }
  }

  // Check if any annotation is still enriching (async details not yet resolved)
  let hasEnrichingAnnotations = (task: Task.t): option<bool> => {
    annotations(task)->Option.map(anns =>
      anns->Array.some(a => a.enrichmentStatus == Annotation.Enriching)
    )
  }

  // Get animation frozen state
  let isAnimationFrozen = (task: Task.t): option<bool> => {
    switch task {
    | Task.Unloaded(_) => None
    | _ => Some(Task.getIsAnimationFrozen(task))
    }
  }

  // Get active popup annotation ID
  let activePopupAnnotationId = (task: Task.t): option<option<string>> => {
    switch task {
    | Task.Unloaded(_) => None
    | _ => Some(Task.getActivePopupAnnotationId(task))
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
    | Message.Error(err) => Message.ErrorMessage.createdAt(err)
    }
  }

  // Get the streaming message from a task (at most one per task)
  let streamingMessage = (task: Task.t): option<Message.assistantMessage> => {
    Lens.getStreamingMessage(task)
  }

  // Get the pending question (only available on Loaded tasks)
  let pendingQuestion = (task: Task.t): option<Client__Question__Types.pendingQuestion> => {
    switch task {
    | Task.Loaded({pendingQuestion}) => pendingQuestion
    | _ => None
    }
  }
}

// ============================================================================
// Task Actions - operate on a single Task (no taskId needed)
// ============================================================================

// Element data for batch annotation (drag selection)
type annotationElement = {
  element: WebAPI.DOMAPI.element,
  position: Annotation.position,
  tagName: string,
}

type action =
  // Streaming actions
  | StreamingStarted
  | TextDeltaReceived({text: string, timestamp: string})
  // Tool call actions
  | ToolInputReceived({id: string, input: JSON.t})
  | ToolResultReceived({id: string, result: JSON.t})
  | ToolErrorReceived({id: string, error: string})
  | ToolCallReceived({toolCall: Message.toolCall})
  // Content actions
  | AddUserMessage({id: string, content: array<UserContentPart.t>, annotations: array<Message.MessageAnnotation.t>})
  // Annotation actions — unified selection mode
  | SetAnnotationMode({mode: Annotation.annotationMode})
  | ToggleAnnotationMode
  | ToggleAnnotation({element: WebAPI.DOMAPI.element, position: Annotation.position, tagName: string})
  | AddAnnotation({element: WebAPI.DOMAPI.element, position: Annotation.position, tagName: string})
  | AnnotationDetailsResolved({
      id: string,
      selector: result<option<string>, string>,
      screenshot: result<option<string>, string>,
      sourceLocation: result<option<Client__Types.SourceLocation.t>, string>,
      cssClasses: option<string>,
      nearbyText: option<string>,
      boundingBox: option<Annotation.boundingBox>,
      enrichmentStatus: Annotation.enrichmentStatus,
    })
  | AddAnnotations({elements: array<annotationElement>})
  | RemoveAnnotation({id: string})
  | ClearAnnotations
  | UpdateAnnotationComment({id: string, comment: string})
  | SetActivePopupAnnotationId({id: option<string>})
  | ToggleAnimationFrozen
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
  | AgentError({error: string, timestamp: string})
  | ClearTurnError
  // Load state actions
  | LoadStarted({previewUrl: string})
  | LoadComplete
  | LoadError({error: string})
  // Hydration actions
  | UserMessageReceived({id: string, content: array<UserContentPart.t>, annotations: array<Message.MessageAnnotation.t>, timestamp: string})
  // Question tool actions
  | QuestionReceived({
      questions: array<Client__Question__Types.questionItem>,
      toolCallId: string,
      resolveOk: JSON.t => unit,
      resolveError: string => unit,
    })
  | QuestionStepChanged({step: int})
  | QuestionOptionToggled({questionIndex: int, label: string})
  | QuestionCustomTextChanged({questionIndex: int, text: string})
  | QuestionPerQuestionSkipped({questionIndex: int})
  | QuestionSubmitted
  | QuestionAllSkipped
  | QuestionCancelled

// ============================================================================
// Effects - side effects that the task reducer requests
// ============================================================================

type effect =
  | FetchAnnotationDetails({
      id: string,
      element: WebAPI.DOMAPI.element,
      document: option<WebAPI.DOMAPI.document>,
      contentWindow: option<WebAPI.DOMAPI.window>,
    })
  | SendMessage({
      text: string,
      attachments: array<Message.fileAttachmentData>,
      annotations: array<Message.MessageAnnotation.t>,
    })
  | NotifyTurnCompleted
  | CancelPrompt
  // Resolve the question tool's blocking promise with the user's answer
  | ResolveQuestionToolEffect({resolveOk: JSON.t => unit, answerJson: JSON.t})
  // Reject the question tool's blocking promise (cancellation)
  | RejectQuestionToolEffect({resolveError: string => unit, message: string})

// Delegated effects - things the task needs from its parent
type delegated =
  | NeedSendMessage({
      text: string,
      attachments: array<Message.fileAttachmentData>,
      annotations: array<Message.MessageAnnotation.t>,
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
  | SetAnnotationMode(_) => "SetAnnotationMode"
  | ToggleAnnotationMode => "ToggleAnnotationMode"
  | ToggleAnnotation(_) => "ToggleAnnotation"
  | AddAnnotation(_) => "AddAnnotation"
  | AnnotationDetailsResolved(_) => "AnnotationDetailsResolved"
  | AddAnnotations(_) => "AddAnnotations"
  | RemoveAnnotation(_) => "RemoveAnnotation"
  | ClearAnnotations => "ClearAnnotations"
  | UpdateAnnotationComment(_) => "UpdateAnnotationComment"
  | SetActivePopupAnnotationId(_) => "SetActivePopupAnnotationId"
  | ToggleAnimationFrozen => "ToggleAnimationFrozen"
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
  | QuestionReceived(_) => "QuestionReceived"
  | QuestionStepChanged(_) => "QuestionStepChanged"
  | QuestionOptionToggled(_) => "QuestionOptionToggled"
  | QuestionCustomTextChanged(_) => "QuestionCustomTextChanged"
  | QuestionPerQuestionSkipped(_) => "QuestionPerQuestionSkipped"
  | QuestionSubmitted => "QuestionSubmitted"
  | QuestionAllSkipped => "QuestionAllSkipped"
  | QuestionCancelled => "QuestionCancelled"
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

// ============================================================================
// Question helpers - shared logic for question tool state mutations
// ============================================================================

// Update pendingQuestion on a Loaded task (no-op if no pending question)
let updatePendingQuestion = (
  task: Task.t,
  fn: Client__Question__Types.pendingQuestion => Client__Question__Types.pendingQuestion,
): (Task.t, array<effect>) =>
  switch task {
  | Task.Loaded({pendingQuestion: Some(pq)} as data) =>
    (Task.Loaded({...data, pendingQuestion: Some(fn(pq))}), [])
  | _ => (task, [])
  }

// Build question tool output JSON from pending question state.
// Format matches Client__Tool__Question.output schema.
let buildQuestionToolOutput = (
  pq: Client__Question__Types.pendingQuestion,
  ~skippedAll: bool,
  ~cancelled: bool,
): JSON.t => {
  let answersJson = pq.questions->Array.mapWithIndex((q, i) => {
    let key = i->Int.toString
    let answer = switch pq.answers->Dict.get(key) {
    | Some(Client__Question__Types.Answered(labels)) =>
      Some(labels->Array.map(JSON.Encode.string)->JSON.Encode.array)
    | Some(Client__Question__Types.CustomText(text)) =>
      Some([JSON.Encode.string(text)]->JSON.Encode.array)
    | Some(Client__Question__Types.Skipped) | None => None
    }
    let obj = Dict.make()
    obj->Dict.set("question", JSON.Encode.string(q.question))
    switch answer {
    | Some(a) => obj->Dict.set("answer", a)
    | None => ()
    }
    JSON.Encode.object(obj)
  })

  let obj = Dict.make()
  obj->Dict.set("answers", JSON.Encode.array(answersJson))
  obj->Dict.set("skippedAll", JSON.Encode.bool(skippedAll))
  obj->Dict.set("cancelled", JSON.Encode.bool(cancelled))
  JSON.Encode.object(obj)
}

// Resolve the question tool: clear pendingQuestion and emit resolve effect.
// Resolves the MCP tool promise directly — the MCP response flow handles
// both live and reconnect cases (server re-sends tools/call on reconnect).
let resolveQuestion = (
  task: Task.t,
  ~skippedAll: bool,
  ~cancelled: bool,
): (Task.t, array<effect>) =>
  switch task {
  | Task.Loaded({pendingQuestion: Some(pq)} as data) =>
    switch cancelled {
    | true => (
        Task.Loaded({...data, pendingQuestion: None, isAgentRunning: false}),
        [RejectQuestionToolEffect({resolveError: pq.resolveError, message: "Cancelled by user"})],
      )
    | false =>
      let answerJson = buildQuestionToolOutput(pq, ~skippedAll, ~cancelled)
      (
        // Set isAgentRunning: true because resolving the tool promise will resume
        // the agent. Without this, the streaming guard (isAgentRunning: false drops
        // all TextDeltaReceived) would silently discard the agent's response.
        Task.Loaded({...data, pendingQuestion: None, isAgentRunning: true}),
        [ResolveQuestionToolEffect({resolveOk: pq.resolveOk, answerJson})],
      )
    }
  | _ => (task, [])
  }


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

    // Clear annotations and popup on actual navigation, not initial iframe mount
    switch urlChanged {
    | true =>
      let updated = Lens.setAnnotations(updated, [])
      let updated = Lens.setActivePopupAnnotationId(updated, None)
      (updated, [])
    | false => (updated, [])
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

  // Annotation actions — unified selection mode
  | (Task.Unloaded(_), SetAnnotationMode(_) | ToggleAnnotationMode) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetAnnotationMode({mode})) => {
    let updated = Lens.setAnnotationMode(task, mode)
    // Close popup and unfreeze when switching to Off
    let updated = switch mode {
    | Annotation.Off =>
      updated
      ->Lens.setActivePopupAnnotationId(None)
      ->Lens.setAnimationFrozen(false)
    | _ => updated
    }
    (updated, [])
  }
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), ToggleAnnotationMode) => {
    let newMode = switch Task.getAnnotationMode(task) {
    | Annotation.Off => Annotation.Selecting
    | _ => Annotation.Off
    }
    let updated = Lens.setAnnotationMode(task, newMode)
    // Close popup and unfreeze when toggling off
    let updated = switch newMode {
    | Annotation.Off =>
      updated
      ->Lens.setActivePopupAnnotationId(None)
      ->Lens.setAnimationFrozen(false)
    | _ => updated
    }
    (updated, [])
  }

  // Toggle annotation: click already-annotated element removes it, click new element adds it
  | (Task.Unloaded(_), ToggleAnnotation(_)) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), ToggleAnnotation({element, position, tagName})) => {
    let existing = Annotation.findByElement(Task.getAnnotations(task), element)
    switch existing {
    | Some(ann) =>
      // Element already annotated — deselect it and close popup
      let annotations = Task.getAnnotations(task)->Array.filter(a => a.id != ann.id)
      let updated = Lens.setAnnotations(task, annotations)
      let updated = Lens.setActivePopupAnnotationId(updated, None)
      (updated, [])
    | None =>
      // New element — add annotation immediately, open popup, fetch details
      let annotation = Annotation.make(~element, ~position, ~tagName)
      let previewFrame = Task.getPreviewFrame(task, ~defaultUrl="")
      let effects = [
        FetchAnnotationDetails({
          id: annotation.id,
          element,
          document: previewFrame.contentDocument,
          contentWindow: previewFrame.contentWindow,
        }),
      ]
      let allAnnotations = Array.concat(Task.getAnnotations(task), [annotation])
      let updated = Lens.setAnnotations(task, allAnnotations)
      let updated = Lens.setActivePopupAnnotationId(updated, Some(annotation.id))
      (updated, effects)
    }
  }

  // AddAnnotation: always adds without toggle semantics (used for tree navigation)
  | (Task.Unloaded(_), AddAnnotation(_)) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), AddAnnotation({element, position, tagName})) => {
    let annotation = Annotation.make(~element, ~position, ~tagName)
    let previewFrame = Task.getPreviewFrame(task, ~defaultUrl="")
    let effects = [
      FetchAnnotationDetails({
        id: annotation.id,
        element,
        document: previewFrame.contentDocument,
        contentWindow: previewFrame.contentWindow,
      }),
    ]
    let allAnnotations = Array.concat(Task.getAnnotations(task), [annotation])
    let updated = Lens.setAnnotations(task, allAnnotations)
    let updated = Lens.setActivePopupAnnotationId(updated, Some(annotation.id))
    (updated, effects)
  }

  // Async annotation fetch completed after task transitioned to Unloaded — discard silently
  | (Task.Unloaded(_), AnnotationDetailsResolved(_)) => (task, [])

  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), AnnotationDetailsResolved({id, selector, screenshot, sourceLocation, cssClasses, nearbyText, boundingBox, enrichmentStatus})) => (
    Lens.updateAnnotation(task, id, a => {
      ...a,
      selector,
      screenshot,
      sourceLocation,
      cssClasses,
      nearbyText,
      boundingBox,
      enrichmentStatus,
    }),
    [],
  )

  // Add multiple annotations at once (for drag selection)
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), AddAnnotations({elements})) => {
    let previewFrame = Task.getPreviewFrame(task, ~defaultUrl="")
    let newAnnotations = elements->Array.map(el =>
      Annotation.make(~element=el.element, ~position=el.position, ~tagName=el.tagName)
    )
    let effects = newAnnotations->Array.map(annotation =>
      FetchAnnotationDetails({
        id: annotation.id,
        element: annotation.element,
        document: previewFrame.contentDocument,
        contentWindow: previewFrame.contentWindow,
      })
    )
    let allAnnotations = Array.concat(Task.getAnnotations(task), newAnnotations)
    (Lens.setAnnotations(task, allAnnotations), effects)
  }

  | (Task.Unloaded(_), RemoveAnnotation(_)) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), RemoveAnnotation({id})) => {
    let annotations = Task.getAnnotations(task)->Array.filter(a => a.id != id)
    let updated = Lens.setAnnotations(task, annotations)
    // Close popup if it was for the removed annotation
    let updated = switch Task.getActivePopupAnnotationId(task) {
    | Some(activeId) if activeId == id => Lens.setActivePopupAnnotationId(updated, None)
    | _ => updated
    }
    (updated, [])
  }

  | (Task.Unloaded(_), ClearAnnotations) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), ClearAnnotations) => {
    let updated = Lens.setAnnotations(task, [])
    let updated = Lens.setActivePopupAnnotationId(updated, None)
    (updated, [])
  }

  // Toggle animation freeze (only when in selection mode)
  | (Task.Unloaded(_), ToggleAnimationFrozen) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), ToggleAnimationFrozen) =>
    (Lens.setAnimationFrozen(task, !Task.getIsAnimationFrozen(task)), [])

  // Set active popup annotation ID (for opening/closing the comment popup)
  | (Task.Unloaded(_), SetActivePopupAnnotationId(_)) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), SetActivePopupAnnotationId({id})) =>
    (Lens.setActivePopupAnnotationId(task, id), [])

  // Update comment on an existing annotation
  | (Task.Unloaded(_), UpdateAnnotationComment(_)) => (task, [])
  | (Task.New(_) | Task.Loading(_) | Task.Loaded(_), UpdateAnnotationComment({id, comment})) => {
    let trimmed = comment->String.trim
    let commentValue = trimmed->String.length > 0 ? Some(trimmed) : None
    (
      Lens.updateAnnotation(task, id, a => {...a, comment: commentValue}),
      [],
    )
  }

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

  | (Task.Loading(_) | Task.Loaded(_), TextDeltaReceived({text, timestamp})) =>
    let resolvedCreatedAt = Date.fromString(timestamp)->Date.getTime
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
          Streaming({id: msgId, textBuffer: text, createdAt: resolvedCreatedAt}),
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
  | (Task.Loading(_), UserMessageReceived({id, content, annotations, timestamp})) =>
    let createdAt = Date.fromString(timestamp)->Date.getTime
    let userMessage = Message.User({id, content, annotations, createdAt})
    (task->Lens.completeStreamingMessage->Lens.insertMessage(userMessage), [])

  // ============================================================================
  // Loaded-only Actions - require isAgentRunning or planEntries
  // ============================================================================
  | (Task.Loaded(data), AddUserMessage({id, content, annotations})) =>
    let text = extractTextFromUserContent(content)
    let attachments = extractAttachmentsFromUserContent(content)
    let message = Message.User({id, content, annotations, createdAt: Date.now()})

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
        // Clear annotations from task state — they now live on the message
        annotations: [],
        annotationMode: Annotation.Off,
        activePopupAnnotationId: None,
      }),
      [SendMessage({text, attachments, annotations})],
    )

  | (Task.Loaded(data), PlanReceived({entries})) => (
      Task.Loaded({...data, planEntries: entries}),
      [],
    )

  | (Task.Loaded(data), TurnCompleted) =>
    // The ACP protocol has two overlapping signals for turn completion:
    // 1. The session/prompt RPC response (request-response channel)
    // 2. The agent_turn_complete notification (event channel)
    // The server sends both when an RPC is pending, so TurnCompleted may
    // arrive twice per turn. The state transitions below are idempotent —
    // only the NotifyTurnCompleted effect (usage refresh) is gated.
    let completed = task->Lens.completeStreamingMessage
    let updatedTask = completed->Task.updateLoadedData(d => {...d, isAgentRunning: false})
    let effects = if data.isAgentRunning {
      [NotifyTurnCompleted]
    } else {
      []
    }
    (updatedTask, effects)

  // Cancel the current turn: complete any partial response, stop agent, dismiss pending question
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
      // Also dismiss any pending question — reject the tool promise
      let questionEffects = switch data.pendingQuestion {
      | Some(pq) =>
        [RejectQuestionToolEffect({resolveError: pq.resolveError, message: "Cancelled by user"})]
      | None => []
      }
      let final = withCancelledTools->Task.updateLoadedData(d => {
        ...d,
        isAgentRunning: false,
        turnError: None,
        pendingQuestion: None,
      })
      (final, Array.concat([CancelPrompt], questionEffects))
    }

  | (Task.Loading(_), AgentError({error, timestamp})) =>
    let id = `error-${getTaskIdForError(task)}-${timestamp}`
    let errorMsg = Message.Error(Message.ErrorMessage.make(~id, ~error, ~timestamp))
    (task->Lens.completeStreamingMessage->Lens.insertMessage(errorMsg), [])

  | (Task.Loaded(data), AgentError({error, _})) =>
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
        annotationMode: Annotation.Off,
        annotations: [],
        activePopupAnnotationId: None,
        isAnimationFrozen: false,
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
        annotationMode,
        annotations,
        activePopupAnnotationId,
        isAnimationFrozen,
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
          annotationMode,
          annotations,
          activePopupAnnotationId,
          isAnimationFrozen,
          isAgentRunning: false,
          planEntries: [],
          turnError: None,
          imageAttachments: Dict.make(),
          pendingQuestion: None,
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
  // Question Tool Actions
  // ============================================================================

  | (Task.Loaded(data), QuestionReceived({questions, toolCallId, resolveOk, resolveError})) =>
    (
      Task.Loaded({
        ...data,
        pendingQuestion: Some({
          Client__Question__Types.questions,
          answers: Dict.make(),
          currentStep: 0,
          toolCallId,
          resolveOk,
          resolveError,
        }),
      }),
      [],
    )


  | (Task.Loaded(_), QuestionStepChanged({step})) =>
    updatePendingQuestion(task, pq => {...pq, currentStep: step})

  | (Task.Loaded(_), QuestionOptionToggled({questionIndex, label})) =>
    updatePendingQuestion(task, pq => {
      let key = questionIndex->Int.toString
      let question = pq.questions->Array.get(questionIndex)
      let isMultiple = question->Option.flatMap(q => q.multiple)->Option.getOr(false)
      let currentAnswer = pq.answers->Dict.get(key)

      let newAnswer = switch (isMultiple, currentAnswer) {
      | (true, Some(Client__Question__Types.Answered(labels))) =>
        switch labels->Array.includes(label) {
        | true =>
          let filtered = labels->Array.filter(l => l != label)
          switch Array.length(filtered) > 0 {
          | true => Client__Question__Types.Answered(filtered)
          | false => Client__Question__Types.Skipped
          }
        | false => Client__Question__Types.Answered(Array.concat(labels, [label]))
        }
      | (false, Some(Client__Question__Types.Answered(labels))) =>
        switch labels->Array.get(0) == Some(label) {
        | true => Client__Question__Types.Skipped
        | false => Client__Question__Types.Answered([label])
        }
      | _ =>
        Client__Question__Types.Answered([label])
      }

      let answers = pq.answers->Dict.copy
      answers->Dict.set(key, newAnswer)
      {...pq, answers}
    })

  | (Task.Loaded(_), QuestionCustomTextChanged({questionIndex, text})) =>
    updatePendingQuestion(task, pq => {
      let key = questionIndex->Int.toString
      let answers = pq.answers->Dict.copy
      switch String.trim(text)->String.length > 0 {
      | true => answers->Dict.set(key, Client__Question__Types.CustomText(text))
      | false => answers->Dict.delete(key)
      }
      {...pq, answers}
    })

  | (Task.Loaded(_), QuestionPerQuestionSkipped({questionIndex})) =>
    let (task, effects) = updatePendingQuestion(task, pq => {
      let key = questionIndex->Int.toString
      let answers = pq.answers->Dict.copy
      answers->Dict.set(key, Client__Question__Types.Skipped)
      let isLastQuestion = questionIndex >= Array.length(pq.questions) - 1
      let nextStep = switch isLastQuestion {
      | true => questionIndex
      | false => questionIndex + 1
      }
      {...pq, answers, currentStep: nextStep}
    })
    // Auto-submit when the last question is skipped — the UI can't submit
    // because the Submit button requires hasAnswer which excludes Skipped.
    switch task {
    | Task.Loaded({pendingQuestion: Some(pq)})
      if questionIndex >= Array.length(pq.questions) - 1 => {
        let (task, resolveEffects) = resolveQuestion(task, ~skippedAll=false, ~cancelled=false)
        (task, Array.concat(effects, resolveEffects))
      }
    | _ => (task, effects)
    }

  | (Task.Loaded(_), QuestionSubmitted) =>
    resolveQuestion(task, ~skippedAll=false, ~cancelled=false)

  | (Task.Loaded(_), QuestionAllSkipped) =>
    resolveQuestion(task, ~skippedAll=true, ~cancelled=false)

  | (Task.Loaded(_), QuestionCancelled) =>
    // "Cancel (stop agent)" — reject the question AND stop the agent turn.
    // resolveQuestion handles the question dismissal + late tool result submission.
    // CancelPrompt tells the server to cancel the running prompt/agent loop.
    let (task, questionEffects) = resolveQuestion(task, ~skippedAll=false, ~cancelled=true)
    (task, Array.concat(questionEffects, [CancelPrompt]))

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

// Extract error message from a caught JS exception
let formatError = (exn: exn): string =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")

let handleEffect = (effect: effect, ~dispatch: action => unit, ~delegate: delegated => unit) => {
  switch effect {
  | FetchAnnotationDetails({id, element, document, contentWindow}) => {
      // Fetch selector — result captures success or per-field error
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
          Promise.resolve(Ok(Some(selector)))
        })
        ->Promise.catch(error => {
          let msg = formatError(error)
          Log.error(~ctx={"error": error, "annotationId": id}, "Selector generation failed")
          Promise.resolve(Error(msg))
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
            Promise.resolve(Ok(Some(img)))
          })
        })
        ->Promise.catch(error => {
          let msg = formatError(error)
          Log.error(~ctx={"error": error, "annotationId": id}, "Screenshot capture failed")
          Promise.resolve(Error(msg))
        })
      }

      // Fetch source location (cascading: React fiber first, then Astro annotations)
      // Race against a timeout to prevent hanging when source map resolution stalls (e.g., CORS on RSC URLs)
      let sourceLocationPromise = {
        let detectionPromise = switch contentWindow {
        | Some(window) =>
          Client__SourceDetection.getElementSourceLocation(~element, ~window)
          ->Promise.then(result => Promise.resolve(Ok(result)))
          ->Promise.catch(error => {
            let msg = formatError(error)
            Log.error(~ctx={"error": error, "annotationId": id}, "Source location detection failed")
            Promise.resolve(Error(msg))
          })
        | None => Promise.resolve(Ok(None))
        }
        let timeoutPromise = Promise.make((resolve, _) => {
          let _ = Js.Global.setTimeout(() => resolve(Ok(None)), 5000)
        })
        Promise.race([detectionPromise, timeoutPromise])
      }

      // Extract enrichment data synchronously from the DOM element
      // Use getAttribute("class") instead of element.className because SVG elements
      // return an SVGAnimatedString object for className, not a plain string
      let cssClasses =
        element
        ->WebAPI.Element.getAttribute("class")
        ->Null.toOption
        ->Option.flatMap(cls => {
          let trimmed = cls->String.trim
          trimmed->String.length > 0 ? Some(trimmed) : None
        })

      let nearbyText = {
        let own =
          element
          ->WebAPI.Element.asNode
          ->WebAPI.Node.textContent
          ->Null.toOption
          ->Option.getOr("")
          ->String.trim
        // Truncate to 200 chars to keep payload reasonable
        let truncated = own->String.length > 200 ? own->String.slice(~start=0, ~end=200) ++ "..." : own
        truncated->String.length > 0 ? Some(truncated) : None
      }

      let rect = WebAPI.Element.getBoundingClientRect(element)
      let boundingBox: Annotation.boundingBox = {
        x: rect.left,
        y: rect.top,
        width: rect.width,
        height: rect.height,
      }

      // Wait for all promises and update state once
      let _ =
        Promise.all3((selectorPromise, screenshotPromise, sourceLocationPromise))
        ->Promise.then(((selector, screenshotResult, sourceLocation)) => {
          // Strip query strings from source location file paths
          let sourceLocationWithTagName = sourceLocation->Result.map(opt =>
            opt->Option.map(sourceLoc => {
              {
                ...sourceLoc,
                file: sourceLoc.file
                ->String.split("?")
                ->Array.get(0)
                ->Option.getOr(sourceLoc.file),
              }
            })
          )

          // Resolve source location via server to get relative file paths
          let resolvedSourceLocationPromise = switch sourceLocationWithTagName {
          | Ok(Some(sourceLoc)) =>
            Client__SourceLocationResolver.resolve(sourceLoc)->Promise.then(result => {
              switch result {
              | Ok(resolved) => Promise.resolve(Ok(Some(resolved)))
              | Error(err) =>
                Log.warning(~ctx={"error": err}, "Source location resolution failed, using original")
                Promise.resolve(Ok(Some(sourceLoc)))
              }
            })
          | Ok(None) => Promise.resolve(Ok(None))
          | Error(_) as err => Promise.resolve(err)
          }

          // Extract screenshot src from the result
          let screenshot = screenshotResult->Result.map(opt => opt->Option.map(s => s.src))

          // Dispatch only after resolution completes (or fails with fallback)
          resolvedSourceLocationPromise->Promise.then(finalSourceLocation => {
            dispatch(
              AnnotationDetailsResolved({
                id,
                selector,
                screenshot,
                sourceLocation: finalSourceLocation,
                cssClasses,
                nearbyText,
                boundingBox: Some(boundingBox),
                enrichmentStatus: Enriched,
              }),
            )
            Promise.resolve()
          })
        })
        ->Promise.catch(err => {
          // Outer chain failure — total enrichment failure
          let errorMsg = formatError(err)
          Log.error(~ctx={"error": err, "annotationId": id}, "FetchAnnotationDetails failed")
          dispatch(
            AnnotationDetailsResolved({
              id,
              selector: Error(errorMsg),
              screenshot: Error(errorMsg),
              sourceLocation: Error(errorMsg),
              cssClasses,
              nearbyText,
              boundingBox: Some(boundingBox),
              enrichmentStatus: Failed({error: errorMsg}),
            }),
          )
          Promise.resolve()
        })
    }
  | SendMessage({text, attachments, annotations}) => delegate(NeedSendMessage({text, attachments, annotations}))
  | NotifyTurnCompleted => delegate(NeedUsageRefresh)
  | CancelPrompt => delegate(NeedCancelPrompt)
  // Question tool resolution — call the resolve/reject callback directly.
  // No delegation needed since the callback is self-contained (captured in the pending question).
  | ResolveQuestionToolEffect({resolveOk, answerJson}) => resolveOk(answerJson)
  | RejectQuestionToolEffect({resolveError, message}) => resolveError(message)
  }
}
