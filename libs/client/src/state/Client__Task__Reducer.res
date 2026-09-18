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
module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP

module MessageStore = Client__MessageStore

let requireSameAgent = (~existingAgentId, ~agentId, ~message) =>
  switch existingAgentId == agentId {
  | true => ()
  | false => failwith(message)
  }

let mergeUserMessage = (message, ~id, ~content, ~annotations, ~agentId) =>
  switch message {
  | Message.User({
      content: existingContent,
      annotations: existingAnnotations,
      agentId: existingAgentId,
    }) =>
    requireSameAgent(
      ~existingAgentId,
      ~agentId,
      ~message=`[TaskReducer] Agent changed within message ${id}`,
    )
    Message.User({
      id,
      content: Array.concat(existingContent, content),
      annotations: Array.concat(existingAnnotations, annotations),
      agentId,
    })
  | _ => failwith(`[TaskReducer] Message ${id} changed roles`)
  }

module Lens = {
  let updatePreviewFrame = (task: Task.t, fn: Task.previewFrame => Task.previewFrame): Task.t =>
    switch task.session {
    | New | Loading(_) | Loaded(_) => {...task, previewFrame: fn(task.previewFrame)}
    | Unloaded(_) =>
      failwith("[Lens.updatePreviewFrame] Cannot update preview frame on Unloaded task")
    }

  let updateMessages = (task: Task.t, fn: MessageStore.t => MessageStore.t): Task.t => {
    switch task.session {
    | New | Unloaded(_) =>
      failwith("[Lens.updateMessages] Cannot update messages on New/Unloaded task")
    | Loading(_) | Loaded(_) => {...task, messages: fn(task.messages)}
    }
  }

  let updateMessage = (task: Task.t, msgId: string, fn: Message.t => Message.t): Task.t => {
    updateMessages(task, store => MessageStore.update(store, msgId, fn))
  }

  let insertMessage = (task: Task.t, message: Message.t): Task.t => {
    updateMessages(task, store => MessageStore.insert(store, message))
  }

  let drainQueuedUserMessages = (task: Task.t): Task.t =>
    switch task {
    | {session: Task.Loaded(_), queuedUserMessages: []} => task
    | {session: Task.Loaded(_)} as data =>
      let messageAgentId = message =>
        switch message {
        | Message.User({agentId, _}) => agentId
        | _ => failwith("[Lens.drainQueuedUserMessages] Queue contains non-user message")
        }
      let firstAgentId = data.queuedUserMessages->Array.getUnsafe(0)->messageAgentId
      let prefixLength = switch data.queuedUserMessages->Array.findIndex(message =>
        data.pendingUserMessageIds->Array.includes(Message.getId(message)) ||
          message->messageAgentId != firstAgentId
      ) {
      | -1 => data.queuedUserMessages->Array.length
      | index => index
      }
      {
        ...data,
        messages: MessageStore.fromArray(
          Array.concat(
            MessageStore.toArray(data.messages),
            data.queuedUserMessages->Array.slice(~start=0, ~end=prefixLength),
          ),
        ),
        queuedUserMessages: data.queuedUserMessages->Array.slice(
          ~start=prefixLength,
          ~end=data.queuedUserMessages->Array.length,
        ),
      }
    | _ => task
    }

  let getStreamingMessage = (task: Task.t): option<Message.assistantMessage> => {
    let messages = Task.getMessages(task)
    let streaming = messages->Array.filterMap(msg => {
      switch msg {
      | Message.Assistant(Streaming(_) as streaming) => Some(streaming)
      | _ => None
      }
    })

    streaming->Array.get(Array.length(streaming) - 1)
  }

  let completeStreamingMessage = (task: Task.t): Task.t => {
    updateMessages(task, store =>
      MessageStore.map(store, msg =>
        switch msg {
        | Message.Assistant(Streaming({id, textBuffer, agentId})) =>
          let content = if String.length(textBuffer) > 0 {
            [AssistantContentPart.Text({text: textBuffer})]
          } else {
            []
          }
          Message.Assistant(Completed({id, content, agentId}))
        | other => other
        }
      )
    )
  }

  let setPreviewUrl = (task: Task.t, url: string): Task.t =>
    updatePreviewFrame(task, pf => {...pf, url})

  let setPreviewFrame = (
    task: Task.t,
    ~runtime: option<Client__PreviewRuntime.t>,
    ~contentDocument: option<WebAPI.DomTypes.document>,
    ~contentWindow: option<WebAPI.DomTypes.window>,
  ): Task.t => updatePreviewFrame(task, pf => {...pf, runtime, contentDocument, contentWindow})

  let setDeviceMode = (task: Task.t, deviceMode: Client__DeviceMode.deviceMode): Task.t =>
    updatePreviewFrame(task, pf => {...pf, deviceMode})

  let setOrientation = (task: Task.t, orientation: Client__DeviceMode.orientation): Task.t =>
    updatePreviewFrame(task, pf => {...pf, orientation})

  let setAnnotationMode = (task: Task.t, mode: Annotation.annotationMode): Task.t => {
    ...task,
    annotationMode: mode,
    activePopupAnnotationId: switch mode {
    | Off => None
    | Selecting => task.activePopupAnnotationId
    },
  }

  let updateAnnotation = (task: Task.t, id: string, fn: Annotation.t => Annotation.t): Task.t => {
    ...task,
    annotations: task.annotations->Array.map(a => a.id == id ? fn(a) : a),
  }

  let refreshCompletedFileChanges = (task: Task.t): Task.t =>
    switch task {
    | {session: Task.Loaded(_)} as data => {
        ...data,
        completedFileChanges: Client__FileChanges.refresh(
          Task.getCompletedFileChanges(task),
          MessageStore.toArray(data.messages),
        ),
      }
    | {session: Task.New | Task.Unloaded(_) | Task.Loading(_)} =>
      failwith("[Lens.refreshCompletedFileChanges] Expected a loaded task")
    }
}

type completedIdleTurn = {taskId: string, agentId: string}

module Selectors = {
  let messages = (task: Task.t): option<array<Message.t>> =>
    switch task.session {
    | Unloaded(_) => None
    | New | Loading(_) | Loaded(_) => Some(Task.getMessages(task))
    }

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

  let annotations = (task: Task.t): option<array<Annotation.t>> =>
    switch task.session {
    | Unloaded(_) => None
    | New | Loading(_) | Loaded(_) => Some(task.annotations)
    }

  let webPreviewIsSelecting = (task: Task.t): option<bool> =>
    switch task.session {
    | Unloaded(_) => None
    | New | Loading(_) | Loaded(_) => Some(Task.getWebPreviewIsSelecting(task))
    }

  let hasEnrichingAnnotations = (task: Task.t): option<bool> => {
    annotations(task)->Option.map(anns =>
      anns->Array.some(a => a.enrichmentStatus == Annotation.Enriching)
    )
  }

  let activePopupAnnotationId = (task: Task.t): option<option<string>> =>
    switch task.session {
    | Unloaded(_) => None
    | New | Loading(_) | Loaded(_) => Some(task.activePopupAnnotationId)
    }

  let isAgentRunning = (task: Task.t): option<bool> =>
    switch task.session {
    | New | Unloaded(_) | Loading(_) => None
    | Loaded(_) => Some(task.isAgentRunning)
    }

  let queuedUserMessages = (task: Task.t): option<array<Message.t>> =>
    switch task.session {
    | New | Unloaded(_) | Loading(_) => None
    | Loaded(_) => Some(task.queuedUserMessages)
    }

  let planEntries = (task: Task.t): option<array<ACPTypes.planEntry>> =>
    switch task.session {
    | New | Unloaded(_) | Loading(_) => None
    | Loaded(_) => Some(task.planEntries)
    }

  let deviceMode = (task: Task.t): Client__DeviceMode.deviceMode => task.previewFrame.deviceMode

  let orientation = (task: Task.t): Client__DeviceMode.orientation => task.previewFrame.orientation

  let turnError = (task: Task.t): option<Task.turnErrorInfo> => task.turnError

  let streamingMessage = (task: Task.t): option<Message.assistantMessage> => {
    Lens.getStreamingMessage(task)
  }

  let pendingQuestion = (task: Task.t): option<Client__Question__Types.pendingQuestion> =>
    task.pendingQuestion

  let completedIdleTurn = (task: Task.t): option<completedIdleTurn> => {
    switch (task, Task.getMessages(task)->Array.last) {
    | (
        {
          session: Task.Loaded({id: taskId}),
          isAgentRunning: false,
          lastTurnCancelled: false,
          pendingQuestion: None,
          queuedUserMessages: [],
        },
        Some(Message.Assistant(Message.Completed({agentId, _}))),
      ) =>
      Some({taskId, agentId})
    | _ => None
    }
  }

  let retryStatus = (task: Task.t): option<Types.Task.retryStatus> => task.retryStatus

  let completedFileChanges = (task: Task.t): Client__FileChanges.snapshot =>
    Task.getCompletedFileChanges(task)
}

type annotationElement = {
  element: WebAPI.DomTypes.element,
  tagName: string,
}

type action =
  | TextDeltaReceived({messageId: string, text: string, agentId: string})
  | ToolInputReceived({id: string, input: JSON.t})
  | ToolResultReceived({
      id: string,
      rawOutput: option<JSON.t>,
      content: option<array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.toolCallContentItem>>,
      complete: bool,
    })
  | ToolErrorReceived({id: string, error: string})
  | ToolCallReceived({toolCall: Message.toolCall})
  | AddUserMessage({
      id: Message.UserMessageId.t,
      content: array<UserContentPart.t>,
      annotations: array<Message.MessageAnnotation.t>,
      agentId: string,
    })
  | SetAnnotationMode({mode: Annotation.annotationMode})
  | ToggleAnnotationMode
  | ToggleAnnotation({element: WebAPI.DomTypes.element, tagName: string})
  | AddAnnotation({element: WebAPI.DomTypes.element, tagName: string})
  | AnnotationDetailsResolved({
      id: string,
      selector: result<option<string>, string>,
      elementContext: result<option<string>, string>,
      screenshot: result<option<string>, string>,
      sourceLocation: result<option<Client__Types.SourceLocation.t>, string>,
      cssClasses: option<string>,
      nearbyText: option<string>,
      boundingBox: option<Annotation.boundingBox>,
      elementorContext: option<Client__ElementorDetection.t>,
      enrichmentStatus: Annotation.enrichmentStatus,
    })
  | AddAnnotations({elements: array<annotationElement>})
  | RemoveAnnotation({id: string})
  | ClearAnnotations
  | UpdateAnnotationComment({id: string, comment: string})
  | SetActivePopupAnnotationId({id: option<string>})
  | SetPreviewUrl({url: string})
  | SetPreviewFrame({
      runtime: option<Client__PreviewRuntime.t>,
      contentDocument: option<WebAPI.DomTypes.document>,
      contentWindow: option<WebAPI.DomTypes.window>,
    })
  | SetDeviceMode({deviceMode: Client__DeviceMode.deviceMode})
  | SetOrientation({orientation: Client__DeviceMode.orientation})
  | ToggleDeviceMode
  | PlanReceived({entries: array<ACPTypes.planEntry>})
  | ExecutionStateRunning
  | ExecutionStateIdle
  | ExecutionStateRequiresAction
  | CancelTurn
  | AgentError({id: string, error: string, category: Client__ErrorCategory.t})
  | UserMessageSendFailed({id: Message.UserMessageId.t, error: string})
  | RetryingUpdate({retryStatus: Types.Task.retryStatus})
  | RetryTurn({retriedErrorId: string})
  | UnqueueMessage({messageId: string})
  | MessageUnqueued({messageId: string})
  | ClearTurnError
  | LoadStarted({previewUrl: string})
  | LoadComplete
  | LoadError({error: string})
  | UserMessageReceived({
      id: string,
      content: array<UserContentPart.t>,
      annotations: array<Message.MessageAnnotation.t>,
      agentId: string,
    })
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

type effect =
  | FetchAnnotationDetails({
      id: string,
      element: WebAPI.DomTypes.element,
      document: option<WebAPI.DomTypes.document>,
      contentWindow: option<WebAPI.DomTypes.window>,
    })
  | SendMessage(Client__Task__Types.promptMessage)
  | SessionCommand(ACP.sessionCommand)
  | ResolveQuestionToolEffect({resolveOk: JSON.t => unit, answerJson: JSON.t})
  | RejectQuestionToolEffect({resolveError: string => unit, message: string})
  | SyncBrowserUrl(string)

let actionToString = (action: action): string =>
  switch action {
  | AddUserMessage(_) => "AddUserMessage"
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
  | SetPreviewUrl(_) => "SetPreviewUrl"
  | SetPreviewFrame(_) => "SetPreviewFrame"
  | SetDeviceMode(_) => "SetDeviceMode"
  | SetOrientation(_) => "SetOrientation"
  | ToggleDeviceMode => "ToggleDeviceMode"
  | PlanReceived(_) => "PlanReceived"
  | ExecutionStateRunning => "ExecutionStateRunning"
  | ExecutionStateIdle => "ExecutionStateIdle"
  | ExecutionStateRequiresAction => "ExecutionStateRequiresAction"
  | CancelTurn => "CancelTurn"
  | AgentError(_) => "AgentError"
  | UserMessageSendFailed(_) => "UserMessageSendFailed"
  | RetryingUpdate(_) => "RetryingUpdate"
  | RetryTurn(_) => "RetryTurn"
  | UnqueueMessage(_) => "UnqueueMessage"
  | MessageUnqueued(_) => "MessageUnqueued"
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

let normalizeUrl = (url: string): string => {
  switch url->String.endsWith("/") && String.length(url) > 1 {
  | true => url->String.slice(~start=0, ~end=String.length(url) - 1)
  | false => url
  }
}

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

let extractAttachmentsFromUserContent = (content: array<UserContentPart.t>): array<
  Message.fileAttachmentData,
> => {
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
        Message.id: WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.randomUUID,
        dataUrl: file,
        mediaType: "application/octet-stream",
        filename: "file",
      })
    | Text(_) => None
    }
  })
}

let getTaskIdForError = (task: Task.t): string => Task.getId(task)->Option.getOr("(no id)")

let updatePendingQuestion = (
  task: Task.t,
  fn: Client__Question__Types.pendingQuestion => Client__Question__Types.pendingQuestion,
): (Task.t, array<effect>) =>
  switch task {
  | {session: Task.Loaded(_), pendingQuestion: Some(pq)} as data => (
      {...data, pendingQuestion: Some(fn(pq))},
      [],
    )
  | _ => (task, [])
  }

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

let resolveQuestion = (task: Task.t, ~skippedAll: bool, ~cancelled: bool): (
  Task.t,
  array<effect>,
) =>
  switch task {
  | {session: Task.Loaded(_), pendingQuestion: Some(pq)} as data =>
    switch cancelled {
    | true => (
        {
          ...data,
          pendingQuestion: None,
          isAgentRunning: false,
        }->Lens.refreshCompletedFileChanges,
        [RejectQuestionToolEffect({resolveError: pq.resolveError, message: "Cancelled by user"})],
      )
    | false =>
      let answerJson = buildQuestionToolOutput(pq, ~skippedAll, ~cancelled)
      (
        {...data, pendingQuestion: None, isAgentRunning: true},
        [ResolveQuestionToolEffect({resolveOk: pq.resolveOk, answerJson})],
      )
    }
  | _ => (task, [])
  }

let next = (task: Task.t, action: action): (Task.t, array<effect>) => {
  switch (task.session, action) {
  | (Task.Unloaded(_), SetPreviewUrl(_)) => (task, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), SetPreviewUrl({url})) =>
    let currentUrl = Task.getPreviewFrame(task, ~defaultUrl="").url
    let urlChanged = normalizeUrl(currentUrl) != normalizeUrl(url)
    let updated = Lens.setPreviewUrl(task, url)

    switch urlChanged {
    | true => ({...updated, annotations: [], activePopupAnnotationId: None}, [SyncBrowserUrl(url)])
    | false => (updated, [])
    }

  | (Task.Unloaded(_), SetPreviewFrame(_)) => (task, [])
  | (
      Task.New | Task.Loading(_) | Task.Loaded(_),
      SetPreviewFrame({runtime, contentDocument, contentWindow}),
    ) => (Lens.setPreviewFrame(task, ~runtime, ~contentDocument, ~contentWindow), [])

  | (Task.Unloaded(_), SetDeviceMode(_) | SetOrientation(_) | ToggleDeviceMode) => (task, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), SetDeviceMode({deviceMode})) =>
    let updated = Lens.setDeviceMode(task, deviceMode)
    (updated, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), SetOrientation({orientation})) =>
    let updated = Lens.setOrientation(task, orientation)
    (updated, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), ToggleDeviceMode) =>
    let currentDeviceMode = Selectors.deviceMode(task)
    let newDeviceMode = switch currentDeviceMode {
    | Client__DeviceMode.Responsive =>
      Client__DeviceMode.DevicePreset(Client__DeviceMode.presets->Array.get(1)->Option.getOrThrow)
    | _ => Client__DeviceMode.Responsive
    }
    (Lens.setDeviceMode(task, newDeviceMode), [])

  | (Task.Unloaded(_), SetAnnotationMode(_) | ToggleAnnotationMode) => (task, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), SetAnnotationMode({mode})) => (
      Lens.setAnnotationMode(task, mode),
      [],
    )
  | (Task.New | Task.Loading(_) | Task.Loaded(_), ToggleAnnotationMode) => {
      let newMode = switch Task.getAnnotationMode(task) {
      | Annotation.Off => Annotation.Selecting
      | _ => Annotation.Off
      }
      (Lens.setAnnotationMode(task, newMode), [])
    }

  | (Task.Unloaded(_), ToggleAnnotation(_)) => (task, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), ToggleAnnotation({element, tagName})) => {
      let existing = Annotation.findByElement(Task.getAnnotations(task), element)
      switch existing {
      | Some(ann) =>
        let annotations = Task.getAnnotations(task)->Array.filter(a => a.id != ann.id)
        ({...task, annotations, activePopupAnnotationId: None}, [])
      | None =>
        let annotation = Annotation.make(~element, ~tagName)
        let previewFrame = Task.getPreviewFrame(task, ~defaultUrl="")
        let effects = [
          FetchAnnotationDetails({
            id: annotation.id,
            element,
            document: previewFrame.contentDocument,
            contentWindow: previewFrame.contentWindow,
          }),
        ]
        (
          {
            ...task,
            annotations: [...task.annotations, annotation],
            activePopupAnnotationId: Some(annotation.id),
          },
          effects,
        )
      }
    }

  | (Task.Unloaded(_), AddAnnotation(_)) => (task, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), AddAnnotation({element, tagName})) => {
      let annotation = Annotation.make(~element, ~tagName)
      let previewFrame = Task.getPreviewFrame(task, ~defaultUrl="")
      let effects = [
        FetchAnnotationDetails({
          id: annotation.id,
          element,
          document: previewFrame.contentDocument,
          contentWindow: previewFrame.contentWindow,
        }),
      ]
      (
        {
          ...task,
          annotations: [...task.annotations, annotation],
          activePopupAnnotationId: Some(annotation.id),
        },
        effects,
      )
    }

  | (Task.Unloaded(_), AnnotationDetailsResolved(_)) => (task, [])

  | (
      Task.New | Task.Loading(_) | Task.Loaded(_),
      AnnotationDetailsResolved({
        id,
        selector,
        elementContext,
        screenshot,
        sourceLocation,
        cssClasses,
        nearbyText,
        boundingBox,
        elementorContext,
        enrichmentStatus,
      }),
    ) => (
      Lens.updateAnnotation(task, id, a => {
        ...a,
        selector,
        elementContext,
        screenshot,
        sourceLocation,
        cssClasses,
        nearbyText,
        boundingBox,
        elementorContext,
        enrichmentStatus,
      }),
      [],
    )

  | (Task.New | Task.Loading(_) | Task.Loaded(_), AddAnnotations({elements})) => {
      let previewFrame = Task.getPreviewFrame(task, ~defaultUrl="")
      let newAnnotations =
        elements->Array.map(el => Annotation.make(~element=el.element, ~tagName=el.tagName))
      let effects = newAnnotations->Array.map(annotation => FetchAnnotationDetails({
        id: annotation.id,
        element: annotation.element,
        document: previewFrame.contentDocument,
        contentWindow: previewFrame.contentWindow,
      }))
      ({...task, annotations: Array.concat(task.annotations, newAnnotations)}, effects)
    }

  | (Task.Unloaded(_), RemoveAnnotation(_)) => (task, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), RemoveAnnotation({id})) => {
      let annotations = Task.getAnnotations(task)->Array.filter(a => a.id != id)
      let activePopupAnnotationId = switch task.activePopupAnnotationId {
      | Some(activeId) if activeId == id => None
      | other => other
      }
      ({...task, annotations, activePopupAnnotationId}, [])
    }
  | (Task.Unloaded(_), ClearAnnotations) => (task, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), ClearAnnotations) => (
      {...task, annotations: [], activePopupAnnotationId: None},
      [],
    )
  | (Task.Unloaded(_), SetActivePopupAnnotationId(_)) => (task, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), SetActivePopupAnnotationId({id})) => (
      {...task, activePopupAnnotationId: id},
      [],
    )

  | (Task.Unloaded(_), UpdateAnnotationComment(_)) => (task, [])
  | (Task.New | Task.Loading(_) | Task.Loaded(_), UpdateAnnotationComment({id, comment})) => {
      let trimmed = comment->String.trim
      let commentValue = switch trimmed->String.length > 0 {
      | true => Some(trimmed)
      | false => None
      }
      (Lens.updateAnnotation(task, id, a => {...a, comment: commentValue}), [])
    }

  | (Task.Loading(_) | Task.Loaded(_), TextDeltaReceived({messageId, text, agentId})) =>
    switch Task.getMessages(task)->Array.find(message => Message.getId(message) == messageId) {
    | Some(Message.Assistant(Streaming({textBuffer, agentId: existingAgentId}))) =>
      requireSameAgent(
        ~existingAgentId,
        ~agentId,
        ~message=`[TaskReducer] Agent changed within message ${messageId}`,
      )
      let updatedMsg = Message.Assistant(
        Streaming({id: messageId, textBuffer: textBuffer ++ text, agentId}),
      )
      (Lens.updateMessage(task, messageId, _ => updatedMsg), [])
    | Some(Message.Assistant(Completed(_))) =>
      failwith(`[TaskReducer] Message ${messageId} is already completed`)
    | Some(_) => failwith(`[TaskReducer] Message ${messageId} changed roles`)
    | None =>
      let newMessage = Message.Assistant(Streaming({id: messageId, textBuffer: text, agentId}))
      (Lens.insertMessage(task, newMessage), [])
    }

  | (Task.Loading(_) | Task.Loaded(_), ToolCallReceived({toolCall})) =>
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
        | Message.ToolCall(tool) =>
          Message.ToolCall({
            ...tool,
            input: Some(input),
            state: switch tool.state {
            | Message.InputStreaming => Message.InputAvailable
            | state => state
            },
          })
        | _ => failwith(`[TaskReducer] ToolInputReceived but message ${id} is not a ToolCall`)
        }
      ),
      [],
    )

  | (Task.Loading(_) | Task.Loaded(_), ToolResultReceived({id, rawOutput, content, complete})) => (
      Lens.updateMessage(task, id, msg =>
        switch msg {
        | Message.ToolCall(tool) => {
            let current: Message.toolResult = tool.result->Option.getOr({
              rawOutput: None,
              content: [],
            })
            let result: Message.toolResult = {
              rawOutput: rawOutput->Option.orElse(current.rawOutput),
              content: content->Option.getOr(current.content),
            }
            let state = switch complete {
            | true => Message.OutputAvailable
            | false => tool.state
            }
            Message.ToolCall({...tool, result: Some(result), state})
          }
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

  | (Task.Loading(_), UserMessageReceived({id, content, annotations, agentId})) =>
    switch Task.getMessages(task)->Array.find(message => Message.getId(message) == id) {
    | Some(message) =>
      let updated = mergeUserMessage(message, ~id, ~content, ~annotations, ~agentId)
      (Lens.updateMessage(task, id, _ => updated), [])
    | None =>
      let userMessage = Message.User({id, content, annotations, agentId})
      (task->Lens.completeStreamingMessage->Lens.insertMessage(userMessage), [])
    }

  | (Task.Loaded(_), UserMessageReceived({id, content, annotations, agentId})) =>
    let wasPending = task.pendingUserMessageIds->Array.includes(id)
    let pendingUserMessageIds =
      task.pendingUserMessageIds->Array.filter(pendingId => pendingId != id)
    switch task.queuedUserMessages->Array.findIndex(message => Message.getId(message) == id) {
    | index if index >= 0 =>
      let queuedUserMessages = task.queuedUserMessages->Array.copy
      let existing = queuedUserMessages->Array.getUnsafe(index)
      let updated = switch wasPending {
      | true =>
        switch existing {
        | Message.User({agentId: existingAgentId, _}) =>
          requireSameAgent(
            ~existingAgentId,
            ~agentId,
            ~message=`[TaskReducer] Agent changed within message ${id}`,
          )
          Message.User({id, content, annotations, agentId})
        | _ => failwith(`[TaskReducer] Message ${id} changed roles`)
        }
      | false => mergeUserMessage(existing, ~id, ~content, ~annotations, ~agentId)
      }
      queuedUserMessages->Array.setUnsafe(index, updated)
      ({...task, queuedUserMessages, pendingUserMessageIds}, [])
    | _ =>
      switch Task.getMessages(task)->Array.find(message => Message.getId(message) == id) {
      | Some(message) =>
        let updated = mergeUserMessage(message, ~id, ~content, ~annotations, ~agentId)
        (Lens.updateMessage({...task, pendingUserMessageIds}, id, _ => updated), [])
      | None =>
        let userMessage = Message.User({id, content, annotations, agentId})
        (
          {
            ...task,
            queuedUserMessages: Array.concat(task.queuedUserMessages, [userMessage]),
            pendingUserMessageIds,
          },
          [],
        )
      }
    }

  | (Task.Loaded(info), AddUserMessage({id, content, annotations, agentId})) =>
    let text = extractTextFromUserContent(content)
    let attachments = extractAttachmentsFromUserContent(content)
    let messageId = Message.UserMessageId.toString(id)
    let pendingMessage = Message.User({
      id: messageId,
      content,
      annotations,
      agentId,
    })

    let updatedImageAttachments = task.imageAttachments->Dict.copy
    attachments->Array.forEach(att => {
      let uri = `attachment://${att.id}/${att.filename}`
      updatedImageAttachments->Dict.set(uri, att)
    })

    (
      {
        ...task,
        session: Task.Loaded({...info, updatedAt: Date.now()}),
        turnError: None,
        retryStatus: None,
        imageAttachments: updatedImageAttachments,
        queuedUserMessages: Array.concat(task.queuedUserMessages, [pendingMessage]),
        pendingUserMessageIds: Array.concat(task.pendingUserMessageIds, [messageId]),
        annotations: [],
        annotationMode: Annotation.Off,
        activePopupAnnotationId: None,
      },
      [SendMessage({id, text, attachments, annotations, agentId, preview: task.previewFrame})],
    )

  | (Task.Loaded(_), UserMessageSendFailed({id, error})) => {
      let messageId = Message.UserMessageId.toString(id)
      switch task.pendingUserMessageIds->Array.includes(messageId) {
      | true => (
          {
            ...task,
            turnError: Some({
              id: messageId,
              message: error,
              category: #unknown,
              retryErrorId: Some(messageId),
            }),
          },
          [],
        )
      | false => (task, [])
      }
    }

  | (Task.Loaded(_), PlanReceived({entries})) => ({...task, planEntries: entries}, [])

  | (Task.Loaded(_), ExecutionStateRunning) =>
    let task = {
      ...task,
      isAgentRunning: true,
      lastTurnCancelled: false,
      turnError: None,
      retryStatus: None,
    }
    (Lens.drainQueuedUserMessages(task), [])

  | (Task.Loaded(_), ExecutionStateIdle) =>
    let completed = task->Lens.completeStreamingMessage
    ({...completed, isAgentRunning: false, retryStatus: None}->Lens.refreshCompletedFileChanges, [])

  | (Task.Loaded(_), ExecutionStateRequiresAction) => (
      {...task, isAgentRunning: false, retryStatus: None},
      [],
    )

  | (Task.Loading(_), ExecutionStateRunning) => ({...task, isAgentRunning: true}, [])

  | (Task.Loading(_), ExecutionStateIdle | ExecutionStateRequiresAction) => (
      {...task, isAgentRunning: false},
      [],
    )

  | (Task.Loaded(_), CancelTurn) =>
    switch task.isAgentRunning || task.pendingQuestion->Option.isSome {
    | false => (task, [])
    | true =>
      let completed = Lens.completeStreamingMessage(task)
      let withCancelledTools = Lens.updateMessages(completed, store =>
        MessageStore.map(store, msg =>
          switch msg {
          | Message.ToolCall(tool)
            if tool.state == Message.InputStreaming || tool.state == Message.InputAvailable =>
            Message.ToolCall({...tool, state: Message.OutputError, errorText: Some("Cancelled")})
          | other => other
          }
        )
      )
      let questionEffects = switch task.pendingQuestion {
      | Some(pq) => [
          RejectQuestionToolEffect({resolveError: pq.resolveError, message: "Cancelled by user"}),
        ]
      | None => []
      }
      let allEffects = Array.concat([SessionCommand(ACP.Cancel)], questionEffects)
      (
        {
          ...withCancelledTools,
          isAgentRunning: false,
          lastTurnCancelled: true,
          turnError: None,
          retryStatus: None,
          pendingQuestion: None,
        }->Lens.refreshCompletedFileChanges,
        allEffects,
      )
    }

  | (Task.Loading(_), AgentError({id, error, category})) =>
    let errorMsg = Message.Error(Message.ErrorMessage.make(~id, ~error, ~category))
    (task->Lens.completeStreamingMessage->Lens.insertMessage(errorMsg), [])

  | (Task.Loaded(_), AgentError({id, error, category})) =>
    let errorMsg = Message.Error(Message.ErrorMessage.make(~id, ~error, ~category))
    let completed = task->Lens.completeStreamingMessage->Lens.insertMessage(errorMsg)
    (
      {
        ...completed,
        turnError: Some({id, message: error, category, retryErrorId: Some(id)}),
        isAgentRunning: false,
        retryStatus: None,
      }->Lens.refreshCompletedFileChanges,
      [],
    )

  | (Task.Loaded(_), ClearTurnError) => ({...task, turnError: None}, [])

  | (Task.Loaded(_), RetryingUpdate({retryStatus})) => (
      {
        ...task,
        retryStatus: Some(retryStatus),
        isAgentRunning: true,
        lastTurnCancelled: false,
      },
      [],
    )

  | (Task.Loaded(_), UnqueueMessage({messageId}) | MessageUnqueued({messageId})) =>
    switch action {
    | _
      if !(task.queuedUserMessages->Array.some(message => Message.getId(message) == messageId)) => (
        task,
        [],
      )
    | UnqueueMessage(_)
      if !(
        task.pendingUserMessageIds->Array.includes(messageId) &&
          task.turnError->Option.mapOr(false, error => error.id == messageId)
      ) => (task, [SessionCommand(ACP.UnqueueMessage(messageId))])
    | _ => (
        {
          ...task,
          turnError: switch task.turnError {
          | Some(error) if error.id == messageId => None
          | error => error
          },
          queuedUserMessages: task.queuedUserMessages->Array.filter(message =>
            Message.getId(message) != messageId
          ),
          pendingUserMessageIds: task.pendingUserMessageIds->Array.filter(id => id != messageId),
        },
        [],
      )
    }

  | (Task.Loaded(_), RetryTurn({retriedErrorId})) =>
    switch task.pendingUserMessageIds->Array.includes(retriedErrorId) {
    | true =>
      let message =
        task.queuedUserMessages
        ->Array.find(message => Message.getId(message) == retriedErrorId)
        ->Option.getOrThrow
      switch message {
      | Message.User({content, annotations, agentId}) => (
          {...task, turnError: None},
          [
            SendMessage({
              id: Message.UserMessageId.fromString(retriedErrorId),
              text: extractTextFromUserContent(content),
              attachments: extractAttachmentsFromUserContent(content),
              annotations,
              agentId,
              preview: task.previewFrame,
            }),
          ],
        )
      | _ => failwith("Pending message must be user-authored")
      }
    | false => (
        {...task, turnError: None, isAgentRunning: true, lastTurnCancelled: false},
        [SessionCommand(ACP.RetryTurn(retriedErrorId))],
      )
    }

  | (Task.Unloaded(info), LoadStarted({previewUrl})) => (
      {...task, session: Task.Loading(info), previewFrame: {...task.previewFrame, url: previewUrl}},
      [],
    )

  | (Task.Loading(info), LoadComplete) =>
    let completed = task->Lens.completeStreamingMessage
    (
      {
        ...completed,
        session: Task.Loaded(info),
        completedFileChanges: Client__FileChanges.aggregateCompleted(
          ~revision=1,
          ~isAgentRunning=completed.isAgentRunning,
          MessageStore.toArray(completed.messages),
        ),
      },
      [],
    )

  | (Task.Loading(info), LoadError({error})) =>
    Log.error(~ctx={"error": error}, "Task load failed")
    (
      Task.make(
        ~clientId=task.clientId,
        ~session=Task.Unloaded(info),
        ~previewUrl=task.previewFrame.url,
      ),
      [],
    )

  | (Task.Loaded(_), QuestionReceived({questions, toolCallId, resolveOk, resolveError})) => (
      {
        ...task,
        pendingQuestion: Some({
          Client__Question__Types.questions,
          answers: Dict.make(),
          currentStep: 0,
          toolCallId,
          resolveOk,
          resolveError,
        }),
      },
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
      | _ => Client__Question__Types.Answered([label])
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
    switch task {
    | {session: Task.Loaded(_), pendingQuestion: Some(pq)}
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
    let (task, questionEffects) = resolveQuestion(task, ~skippedAll=false, ~cancelled=true)
    (task, Array.concat(questionEffects, [SessionCommand(ACP.Cancel)]))

  | (
    Task.New | Task.Unloaded(_),
    TextDeltaReceived(_)
    | ToolCallReceived(_)
    | ToolInputReceived(_)
    | ToolResultReceived(_)
    | ToolErrorReceived(_)
    | UserMessageReceived(_)
    | AgentError(_)
    | AddUserMessage(_)
    | UserMessageSendFailed(_)
    | PlanReceived(_)
    | ExecutionStateRunning
    | ExecutionStateIdle
    | ExecutionStateRequiresAction
    | CancelTurn
    | ClearTurnError
    | RetryingUpdate(_)
    | RetryTurn(_)
    | UnqueueMessage(_)
    | MessageUnqueued(_)
    | QuestionReceived(_)
    | QuestionStepChanged(_)
    | QuestionOptionToggled(_)
    | QuestionCustomTextChanged(_)
    | QuestionPerQuestionSkipped(_)
    | QuestionSubmitted
    | QuestionAllSkipped
    | QuestionCancelled,
  )
  | (Task.New | Task.Loading(_) | Task.Loaded(_), LoadStarted(_))
  | (Task.New | Task.Loaded(_) | Task.Unloaded(_), LoadComplete | LoadError(_))
  | (Task.Unloaded(_), AddAnnotations(_))
  | (Task.Loading(_), _) =>
    failwith(
      `[TaskReducer] ${actionToString(action)} on ${Task.stateToString(
          task,
        )} task ${getTaskIdForError(task)}`,
    )
  }
}

let formatError = (exn: exn): string =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")

let fetchAnnotationDetails = (
  ~id: string,
  ~element: WebAPI.DomTypes.element,
  ~document: option<WebAPI.DomTypes.document>,
  ~contentWindow: option<WebAPI.DomTypes.window>,
  ~dispatch: action => unit,
) => {
  let inspection = switch document {
  | Some(document) =>
    try {
      let additionalAttributes = switch Client__RuntimeConfig.read().framework {
      | Astro => Some(FrontmanAiAstroBrowser.FrontmanAstroBrowser__Persistence.inspectionAttributes)
      | Nextjs | Vite | Wordpress => None
      }
      Ok(
        Client__ElementInspector.inspect(
          ~element,
          ~document,
          ~maxDepth=1,
          ~maxNodes=200,
          ~additionalAttributes?,
        ),
      )
    } catch {
    | exn =>
      let message = formatError(exn)
      Log.error(
        ~ctx={"annotationId": id},
        ~error=JsExn.fromException(exn),
        "Element inspection failed",
      )
      Error(message)
    }
  | None => Error("Preview document not available")
  }

  let selectorPromise = Promise.resolve(inspection->Result.flatMap(result => result.selector))
  let elementContext = inspection->Result.map(result => Some(result.html))

  let screenshotPromise = {
    let limits = Client__ImageLimits.conservative
    let scale = Client__ImageLimits.computeScale(element, limits.maxDimension)

    FrontmanBindings.Bindings__Snapdom.snapdom(element)
    ->Promise.then(captureResult => {
      captureResult.toJpg({scale, quality: limits.quality})->Promise.then(img => {
        Promise.resolve(Ok(Some(img)))
      })
    })
    ->Promise.catch(error => {
      let msg = formatError(error)
      Log.error(
        ~ctx={"annotationId": id},
        ~error=JsExn.fromException(error),
        "Screenshot capture failed",
      )
      Promise.resolve(Error(msg))
    })
  }

  let sourceLocationPromise = {
    let sourceLocationWork = switch contentWindow {
    | Some(window) =>
      Client__SourceDetection.getElementSourceLocation(~element, ~window)
      ->Promise.then(result => {
        let context = result->Option.map(Client__SourceContext.stripFileQueries)
        switch context {
        | Some(context) if Client__SourceContext.hasReactLocation(context) =>
          Client__SourceLocationResolver.resolve(context)->Promise.then(result =>
            Promise.resolve(result->Result.map(resolved => Some(resolved)))
          )
        | Some(context) => Promise.resolve(Ok(Client__SourceContext.toSourceLocation(context)))
        | None => Promise.resolve(Ok(None))
        }
      })
      ->Promise.catch(error => {
        let msg = formatError(error)
        Log.error(
          ~ctx={"annotationId": id},
          ~error=JsExn.fromException(error),
          "Source location detection or resolution failed",
        )
        Promise.resolve(Error(msg))
      })
    | None => Promise.resolve(Ok(None))
    }
    let timeoutPromise = Promise.make((resolve, _) => {
      let _ = setTimeout(
        () => resolve(Error("Source location detection or resolution timed out")),
        5000,
      )
    })
    Promise.race([sourceLocationWork, timeoutPromise])
  }

  let (cssClasses, nearbyText, boundingBox) = switch inspection {
  | Ok(result) => (result.cssClasses, result.nearbyText, Some(result.boundingBox))
  | Error(_) => (None, None, None)
  }

  let elementorContext =
    document->Option.flatMap(doc =>
      Client__ElementorDetection.getElementorContext(~element, ~document=doc)
    )

  let _ =
    Promise.all3((selectorPromise, screenshotPromise, sourceLocationPromise))
    ->Promise.then(((selector, screenshotResult, sourceLocation)) => {
      let screenshot = screenshotResult->Result.map(opt => opt->Option.map(s => s.src))
      dispatch(
        AnnotationDetailsResolved({
          id,
          selector,
          elementContext,
          screenshot,
          sourceLocation,
          cssClasses,
          nearbyText,
          boundingBox,
          elementorContext,
          enrichmentStatus: Enriched,
        }),
      )
      Promise.resolve()
    })
    ->Promise.catch(err => {
      let errorMsg = formatError(err)
      Log.error(
        ~ctx={"annotationId": id},
        ~error=JsExn.fromException(err),
        "FetchAnnotationDetails failed",
      )
      dispatch(
        AnnotationDetailsResolved({
          id,
          selector: Error(errorMsg),
          elementContext: Error(errorMsg),
          screenshot: Error(errorMsg),
          sourceLocation: Error(errorMsg),
          cssClasses,
          nearbyText,
          boundingBox,
          elementorContext,
          enrichmentStatus: Failed({error: errorMsg}),
        }),
      )
      Promise.resolve()
    })
}
