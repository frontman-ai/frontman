S.enableJson()
/**
 * Client__StateSnapshot - Serializable state snapshots for debugging
 * 
 * Provides types and utilities to capture the chatbox state in a format
 * that can be serialized to JSON and loaded in Storybook stories.
 * 
 * Uses Sury for type-safe serialization/deserialization.
 */

// Re-export plan entry types from frontman-client (they already have Sury schemas)
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

// ============================================================================
// Schema Helpers
// ============================================================================

// Helper to handle JSON fields that can be null, undefined, or a value
// Converts null/undefined to None, value to Some(value)
let nullableToOption = (innerSchema: S.t<'a>): S.t<option<'a>> => {
  S.nullable(innerSchema)->S.transform(_ => {
    parser: nullable => Nullable.toOption(nullable),
    serializer: opt =>
      switch opt {
      | Some(v) => Nullable.make(v)
      | None => Nullable.null
      },
  })
}

// ============================================================================
// Snapshot Types - Serializable versions of state types
// ============================================================================

module SourceLocation = {
  type rec t = {
    componentName: option<string>,
    tagName: string,
    file: string,
    line: int,
    column: int,
    parent: option<t>,
    componentProps: option<Dict.t<JSON.t>>,
  }

  let schema: S.t<t> = S.recursive("SourceLocation", schema =>
    S.object(s => {
      componentName: s.field("componentName", nullableToOption(S.string)),
      tagName: s.field("tagName", S.string),
      file: s.field("file", S.string),
      line: s.field("line", S.int),
      column: s.field("column", S.int),
      parent: s.field("parent", nullableToOption(schema)),
      componentProps: s.field("componentProps", nullableToOption(S.dict(S.json))),
    })
  )
}

module AnnotationMode = {
  type t =
    | @as("off") Off
    | @as("selecting") Selecting

  let schema = S.union([
    S.literal(Off),
    S.literal(Selecting),
  ])
}

module BoundingBox = {
  type t = {
    x: float,
    y: float,
    width: float,
    height: float,
  }

  let schema = S.object(s => {
    x: s.field("x", S.float),
    y: s.field("y", S.float),
    width: s.field("width", S.float),
    height: s.field("height", S.float),
  })
}

module Position = {
  type t = {
    xPercent: float,
    yAbsolute: float,
  }

  let schema = S.object(s => {
    xPercent: s.field("xPercent", S.float),
    yAbsolute: s.field("yAbsolute", S.float),
  })
}

module Annotation = {
  // Snapshot version - no DOM element reference
  type t = {
    id: string,
    comment: option<string>,
    selector: option<string>,
    screenshot: option<string>,
    sourceLocation: option<SourceLocation.t>,
    tagName: string,
    cssClasses: option<string>,
    boundingBox: option<BoundingBox.t>,
    nearbyText: option<string>,
    position: Position.t,
    timestamp: float,
  }

  let schema = S.object(s => {
    id: s.field("id", S.string),
    comment: s.field("comment", S.option(S.string)),
    selector: s.field("selector", S.option(S.string)),
    screenshot: s.field("screenshot", S.option(S.string)),
    sourceLocation: s.field("sourceLocation", S.option(SourceLocation.schema)),
    tagName: s.field("tagName", S.string),
    cssClasses: s.field("cssClasses", S.option(S.string)),
    boundingBox: s.field("boundingBox", S.option(BoundingBox.schema)),
    nearbyText: s.field("nearbyText", S.option(S.string)),
    position: s.field("position", Position.schema),
    timestamp: s.field("timestamp", S.float),
  })
}

module UserContentPart = {
  type t =
    | Text({text: string})
    | Image({image: string, mediaType: option<string>, name: option<string>})
    | File({file: string})

  let schema = S.union([
    S.object(s => {
      s.tag("type", "text")
      Text({text: s.field("text", S.string)})
    }),
    S.object(s => {
      s.tag("type", "image")
      Image({
        image: s.field("image", S.string),
        mediaType: s.field("mediaType", S.option(S.string)),
        name: s.field("name", S.option(S.string)),
      })
    }),
    S.object(s => {
      s.tag("type", "file")
      File({file: s.field("file", S.string)})
    }),
  ])
}

module AssistantContentPart = {
  type t =
    | Text({text: string})
    | ToolCall({toolCallId: string, toolName: string, input: JSON.t})

  let schema = S.union([
    S.object(s => {
      s.tag("type", "text")
      Text({text: s.field("text", S.string)})
    }),
    S.object(s => {
      s.tag("type", "tool_call")
      ToolCall({
        toolCallId: s.field("toolCallId", S.string),
        toolName: s.field("toolName", S.string),
        input: s.field("input", S.json),
      })
    }),
  ])
}

module ToolCallState = {
  type t =
    | @as("input_streaming") InputStreaming
    | @as("input_available") InputAvailable
    | @as("output_available") OutputAvailable
    | @as("output_error") OutputError

  let schema = S.union([
    S.literal(InputStreaming),
    S.literal(InputAvailable),
    S.literal(OutputAvailable),
    S.literal(OutputError),
  ])
}

module ToolCall = {
  type t = {
    id: string,
    toolName: string,
    state: ToolCallState.t,
    inputBuffer: string,
    input: option<JSON.t>,
    result: option<JSON.t>,
    errorText: option<string>,
    createdAt: float,
    parentAgentId: option<string>,
    spawningToolName: option<string>,
  }

  let schema = S.object(s => {
    id: s.field("id", S.string),
    toolName: s.field("toolName", S.string),
    state: s.field("state", ToolCallState.schema),
    inputBuffer: s.field("inputBuffer", S.string),
    input: s.field("input", S.option(S.json)),
    result: s.field("result", S.option(S.json)),
    errorText: s.field("errorText", nullableToOption(S.string)),
    createdAt: s.field("createdAt", S.float),
    parentAgentId: s.field("parentAgentId", nullableToOption(S.string)),
    spawningToolName: s.field("spawningToolName", nullableToOption(S.string)),
  })
}

module AssistantMessage = {
  type t =
    | Streaming({id: string, textBuffer: string, createdAt: float})
    | Completed({id: string, content: array<AssistantContentPart.t>, createdAt: float})

  let schema = S.union([
    S.object(s => {
      s.tag("variant", "streaming")
      Streaming({
        id: s.field("id", S.string),
        textBuffer: s.field("textBuffer", S.string),
        createdAt: s.field("createdAt", S.float),
      })
    }),
    S.object(s => {
      s.tag("variant", "completed")
      Completed({
        id: s.field("id", S.string),
        content: s.field("content", S.array(AssistantContentPart.schema)),
        createdAt: s.field("createdAt", S.float),
      })
    }),
  ])
}

// Serializable annotation snapshot for state snapshots
module SnapshotAnnotation = {
  type boundingBox = {
    x: float,
    y: float,
    width: float,
    height: float,
  }

  type t = {
    id: string,
    selector: option<string>,
    tagName: string,
    cssClasses: option<string>,
    comment: option<string>,
    nearbyText: option<string>,
  }

  let schema = S.object(s => {
    id: s.field("id", S.string),
    selector: s.field("selector", nullableToOption(S.string)),
    tagName: s.field("tagName", S.string),
    cssClasses: s.field("cssClasses", nullableToOption(S.string)),
    comment: s.field("comment", nullableToOption(S.string)),
    nearbyText: s.field("nearbyText", nullableToOption(S.string)),
  })
}

module Message = {
  type t =
    | User({id: string, content: array<UserContentPart.t>, annotations: array<SnapshotAnnotation.t>, createdAt: float})
    | Assistant(AssistantMessage.t)
    | ToolCall(ToolCall.t)
    | Error({id: string, error: string, createdAt: float})

  let schema = S.union([
    S.object(s => {
      s.tag("type", "user")
      User({
        id: s.field("id", S.string),
        content: s.field("content", S.array(UserContentPart.schema)),
        annotations: s.fieldOr("annotations", S.array(SnapshotAnnotation.schema), []),
        createdAt: s.field("createdAt", S.float),
      })
    }),
    S.object(s => {
      s.tag("type", "assistant")
      Assistant(s.field("message", AssistantMessage.schema))
    }),
    S.object(s => {
      s.tag("type", "tool_call")
      ToolCall(s.field("toolCall", ToolCall.schema))
    }),
    S.object(s => {
      s.tag("type", "error")
      Error({
        id: s.field("id", S.string),
        error: s.field("error", S.string),
        createdAt: s.field("createdAt", S.float),
      })
    }),
  ])

  let getId = (msg: t): string => {
    switch msg {
    | User({id, _}) => id
    | Assistant(Streaming({id, _})) => id
    | Assistant(Completed({id, _})) => id
    | ToolCall({id, _}) => id
    | Error({id, _}) => id
    }
  }
}

module Task = {
  type t = {
    id: string,
    title: string,
    messages: array<Message.t>,
    createdAt: float,
    updatedAt: float,
    annotationMode: AnnotationMode.t,
    annotations: array<Annotation.t>,
    previewUrl: string,
  }

  // Parse with optional updatedAt, then transform to apply fallback to createdAt
  let schema = S.object(s => {
    (
      s.field("id", S.string),
      s.field("title", S.string),
      s.field("messages", S.array(Message.schema)),
      s.field("createdAt", S.float),
      s.field("updatedAt", S.option(S.float)),
      s.field("annotationMode", AnnotationMode.schema),
      s.field("annotations", S.array(Annotation.schema)),
      s.field("previewUrl", S.string),
    )
  })->S.transform(_ => {
    parser: ((id, title, messages, createdAt, maybeUpdatedAt, annotationMode, annotations, previewUrl)) => {
      id,
      title,
      messages,
      createdAt,
      updatedAt: maybeUpdatedAt->Option.getOr(createdAt),
      annotationMode,
      annotations,
      previewUrl,
    },
    serializer: task => (
      task.id,
      task.title,
      task.messages,
      task.createdAt,
      Some(task.updatedAt),
      task.annotationMode,
      task.annotations,
      task.previewUrl,
    ),
  })
}

// Main snapshot type
type t = {
  tasks: array<Task.t>,
  currentTaskId: option<string>,
  sessionInitialized: bool,
  capturedAt: float,
}

let schema = S.object(s => {
  tasks: s.field("tasks", S.array(Task.schema)),
  currentTaskId: s.field("currentTaskId", S.option(S.string)),
  sessionInitialized: s.field("sessionInitialized", S.bool),
  capturedAt: s.field("capturedAt", S.float),
})

// ============================================================================
// Conversion from live state to snapshot
// ============================================================================

let convertSourceLocation = (loc: Client__Types.SourceLocation.t): SourceLocation.t => {
  let rec convert = (l: Client__Types.SourceLocation.t): SourceLocation.t => {
    componentName: l.componentName,
    tagName: l.tagName,
    file: l.file,
    line: l.line,
    column: l.column,
    parent: l.parent->Option.map(convert),
    componentProps: l.componentProps,
  }
  convert(loc)
}

let convertAnnotationMode = (mode: Client__Annotation__Types.annotationMode): AnnotationMode.t => {
  switch mode {
  | Off => Off
  | Selecting => Selecting
  }
}

let convertAnnotation = (ann: Client__Annotation__Types.t): Annotation.t => {
  id: ann.id,
  comment: ann.comment,
  // Unwrap result<option<T>, string> to option<T> for serialization — errors become None
  selector: ann.selector->Result.getOr(None),
  screenshot: ann.screenshot->Result.getOr(None),
  sourceLocation: ann.sourceLocation->Result.getOr(None)->Option.map(convertSourceLocation),
  tagName: ann.tagName,
  cssClasses: ann.cssClasses,
  boundingBox: ann.boundingBox->Option.map(bb => {
    BoundingBox.x: bb.x,
    y: bb.y,
    width: bb.width,
    height: bb.height,
  }),
  nearbyText: ann.nearbyText,
  position: {
    Position.xPercent: ann.position.xPercent,
    yAbsolute: ann.position.yAbsolute,
  },
  timestamp: ann.timestamp,
}

let convertUserContentPart = (part: Client__State__Types.UserContentPart.t): UserContentPart.t => {
  switch part {
  | Text({text}) => Text({text: text})
  | Image({image, mediaType, name, id: _}) => Image({image, mediaType, name})
  | File({file}) => File({file: file})
  }
}

let convertAssistantContentPart = (
  part: Client__State__Types.AssistantContentPart.t,
): AssistantContentPart.t => {
  switch part {
  | Text({text}) => Text({text: text})
  | ToolCall({toolCallId, toolName, input}) => ToolCall({toolCallId, toolName, input})
  }
}

let convertToolCallState = (state: Client__State__Types.Message.toolCallState): ToolCallState.t => {
  switch state {
  | InputStreaming => InputStreaming
  | InputAvailable => InputAvailable
  | OutputAvailable => OutputAvailable
  | OutputError => OutputError
  }
}

let convertToolCall = (tc: Client__State__Types.Message.toolCall): ToolCall.t => {
  id: tc.id,
  toolName: tc.toolName,
  state: convertToolCallState(tc.state),
  inputBuffer: tc.inputBuffer,
  input: tc.input,
  result: tc.result,
  errorText: tc.errorText,
  createdAt: tc.createdAt,
  parentAgentId: tc.parentAgentId,
  spawningToolName: tc.spawningToolName,
}

let convertAssistantMessage = (
  msg: Client__State__Types.Message.assistantMessage,
): AssistantMessage.t => {
  switch msg {
  | Streaming({id, textBuffer, createdAt}) => Streaming({id, textBuffer, createdAt})
  | Completed({id, content, createdAt}) =>
    Completed({
      id,
      content: content->Array.map(convertAssistantContentPart),
      createdAt,
    })
  }
}

let convertMessageAnnotation = (ann: Client__Message.MessageAnnotation.t): SnapshotAnnotation.t => {
  id: ann.id,
  selector: ann.selector->Result.getOr(None),
  tagName: ann.tagName,
  cssClasses: ann.cssClasses,
  comment: ann.comment,
  nearbyText: ann.nearbyText,
}

let convertMessage = (msg: Client__State__Types.Message.t): Message.t => {
  switch msg {
  | User({id, content, annotations, createdAt}) =>
    User({
      id,
      content: content->Array.map(convertUserContentPart),
      annotations: annotations->Array.map(convertMessageAnnotation),
      createdAt,
    })
  | Assistant(assistantMsg) => Assistant(convertAssistantMessage(assistantMsg))
  | ToolCall(tc) => ToolCall(convertToolCall(tc))
  | Error({id, error, createdAt}) => Error({id, error, createdAt})
  }
}

let convertTask = (task: Client__State__Types.Task.t, ~defaultUrl: string): Task.t => {
  module Task = Client__State__Types.Task

  // Only persisted tasks should be converted (not New tasks)
  // Use getOrThrow since this is called from state.tasks dict which only has persisted tasks
  let id = Task.getId(task)->Option.getOrThrow(~message="[convertTask] Cannot convert New task - no ID")
  let title = Task.getTitle(task)->Option.getOrThrow(~message="[convertTask] Cannot convert New task - no title")
  let createdAt = Task.getCreatedAt(task)->Option.getOrThrow(~message="[convertTask] Cannot convert New task - no createdAt")
  let updatedAt = Task.getUpdatedAt(task)->Option.getOrThrow(~message="[convertTask] Cannot convert New task - no updatedAt")

  // Get loaded data if available
  let loadedData = Task.getLoadedData(task)

  // Messages are already maintained in sorted order
  let messages =
    loadedData
    ->Option.mapOr([], data => data.messages->Array.map(convertMessage))

  let annotationMode = loadedData->Option.mapOr(
    Client__Annotation__Types.Off,
    d => d.annotationMode,
  )
  let annotations = loadedData->Option.mapOr([], d => d.annotations)

  {
    id,
    title,
    messages,
    createdAt,
    updatedAt,
    annotationMode: convertAnnotationMode(annotationMode),
    annotations: annotations->Array.map(convertAnnotation),
    previewUrl: Task.getPreviewFrame(task, ~defaultUrl).url,
  }
}

// ============================================================================
// Public API
// ============================================================================

/** Capture a snapshot from the live state */
let captureFromState = (state: Client__State__Types.state): t => {
  let defaultUrl = Client__BrowserUrl.getInitialUrl()
  let tasks = state.tasks->Dict.valuesToArray->Array.map(task => convertTask(task, ~defaultUrl))

  let currentTaskId = switch state.currentTask {
  | Client__State__Types.Task.New(_) => None
  | Client__State__Types.Task.Selected(id) => Some(id)
  }

  {
    tasks,
    currentTaskId,
    sessionInitialized: state.sessionInitialized,
    capturedAt: Date.now(),
  }
}

// ============================================================================
// Manual JSON Serialization
// Sury's s.tag() only works for parsing, not serialization, so we need
// to manually construct the JSON with the correct discriminator fields.
// ============================================================================

// Helper to create JSON object from key-value pairs
let obj = (pairs: array<(string, JSON.t)>): JSON.t => {
  JSON.Encode.object(Dict.fromArray(pairs))
}

let userContentPartToJson = (part: UserContentPart.t): JSON.t => {
  switch part {
  | Text({text}) =>
    obj([("type", JSON.Encode.string("text")), ("text", JSON.Encode.string(text))])
  | Image({image, mediaType, name}) =>
    obj([
      ("type", JSON.Encode.string("image")),
      ("image", JSON.Encode.string(image)),
      ("mediaType", mediaType->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
      ("name", name->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ])
  | File({file}) =>
    obj([("type", JSON.Encode.string("file")), ("file", JSON.Encode.string(file))])
  }
}

let assistantContentPartToJson = (part: AssistantContentPart.t): JSON.t => {
  switch part {
  | Text({text}) =>
    obj([("type", JSON.Encode.string("text")), ("text", JSON.Encode.string(text))])
  | ToolCall({toolCallId, toolName, input}) =>
    obj([
      ("type", JSON.Encode.string("tool_call")),
      ("toolCallId", JSON.Encode.string(toolCallId)),
      ("toolName", JSON.Encode.string(toolName)),
      ("input", input),
    ])
  }
}

let toolCallStateToJson = (state: ToolCallState.t): JSON.t => {
  switch state {
  | InputStreaming => JSON.Encode.string("input_streaming")
  | InputAvailable => JSON.Encode.string("input_available")
  | OutputAvailable => JSON.Encode.string("output_available")
  | OutputError => JSON.Encode.string("output_error")
  }
}

let toolCallToJson = (tc: ToolCall.t): JSON.t => {
  obj([
    ("id", JSON.Encode.string(tc.id)),
    ("toolName", JSON.Encode.string(tc.toolName)),
    ("state", toolCallStateToJson(tc.state)),
    ("inputBuffer", JSON.Encode.string(tc.inputBuffer)),
    ("input", tc.input->Option.getOr(JSON.Encode.null)),
    ("result", tc.result->Option.getOr(JSON.Encode.null)),
    ("errorText", tc.errorText->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("createdAt", JSON.Encode.float(tc.createdAt)),
    ("parentAgentId", tc.parentAgentId->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("spawningToolName", tc.spawningToolName->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
  ])
}

let assistantMessageToJson = (msg: AssistantMessage.t): JSON.t => {
  switch msg {
  | Streaming({id, textBuffer, createdAt}) =>
    obj([
      ("variant", JSON.Encode.string("streaming")),
      ("id", JSON.Encode.string(id)),
      ("textBuffer", JSON.Encode.string(textBuffer)),
      ("createdAt", JSON.Encode.float(createdAt)),
    ])
  | Completed({id, content, createdAt}) =>
    obj([
      ("variant", JSON.Encode.string("completed")),
      ("id", JSON.Encode.string(id)),
      ("content", JSON.Encode.array(content->Array.map(assistantContentPartToJson))),
      ("createdAt", JSON.Encode.float(createdAt)),
    ])
  }
}

let snapshotAnnotationToJson = (ann: SnapshotAnnotation.t): JSON.t => {
  obj([
    ("id", JSON.Encode.string(ann.id)),
    ("selector", ann.selector->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("tagName", JSON.Encode.string(ann.tagName)),
    ("cssClasses", ann.cssClasses->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("comment", ann.comment->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("nearbyText", ann.nearbyText->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
  ])
}

let messageToJson = (msg: Message.t): JSON.t => {
  switch msg {
  | User({id, content, annotations, createdAt}) =>
    obj([
      ("type", JSON.Encode.string("user")),
      ("id", JSON.Encode.string(id)),
      ("content", JSON.Encode.array(content->Array.map(userContentPartToJson))),
      ("annotations", JSON.Encode.array(annotations->Array.map(snapshotAnnotationToJson))),
      ("createdAt", JSON.Encode.float(createdAt)),
    ])
  | Assistant(assistantMsg) =>
    obj([
      ("type", JSON.Encode.string("assistant")),
      ("message", assistantMessageToJson(assistantMsg)),
    ])
  | ToolCall(tc) =>
    obj([("type", JSON.Encode.string("tool_call")), ("toolCall", toolCallToJson(tc))])
  | Error({id, error, createdAt}) =>
    obj([
      ("type", JSON.Encode.string("error")),
      ("id", JSON.Encode.string(id)),
      ("error", JSON.Encode.string(error)),
      ("createdAt", JSON.Encode.float(createdAt)),
    ])
  }
}

let rec sourceLocationToJson = (loc: SourceLocation.t): JSON.t => {
  obj([
    ("componentName", loc.componentName->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("tagName", JSON.Encode.string(loc.tagName)),
    ("file", JSON.Encode.string(loc.file)),
    ("line", JSON.Encode.int(loc.line)),
    ("column", JSON.Encode.int(loc.column)),
    ("parent", loc.parent->Option.mapOr(JSON.Encode.null, sourceLocationToJson)),
  ])
}

let annotationModeToJson = (mode: AnnotationMode.t): JSON.t => {
  switch mode {
  | Off => JSON.Encode.string("off")
  | Selecting => JSON.Encode.string("selecting")
  }
}

let positionToJson = (pos: Position.t): JSON.t => {
  obj([
    ("xPercent", JSON.Encode.float(pos.xPercent)),
    ("yAbsolute", JSON.Encode.float(pos.yAbsolute)),
  ])
}

let boundingBoxToJson = (bb: BoundingBox.t): JSON.t => {
  obj([
    ("x", JSON.Encode.float(bb.x)),
    ("y", JSON.Encode.float(bb.y)),
    ("width", JSON.Encode.float(bb.width)),
    ("height", JSON.Encode.float(bb.height)),
  ])
}

let annotationToJson = (ann: Annotation.t): JSON.t => {
  obj([
    ("id", JSON.Encode.string(ann.id)),
    ("comment", ann.comment->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("selector", ann.selector->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("screenshot", ann.screenshot->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("sourceLocation", ann.sourceLocation->Option.mapOr(JSON.Encode.null, sourceLocationToJson)),
    ("tagName", JSON.Encode.string(ann.tagName)),
    ("cssClasses", ann.cssClasses->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("boundingBox", ann.boundingBox->Option.mapOr(JSON.Encode.null, boundingBoxToJson)),
    ("nearbyText", ann.nearbyText->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("position", positionToJson(ann.position)),
    ("timestamp", JSON.Encode.float(ann.timestamp)),
  ])
}

let taskToJson = (task: Task.t): JSON.t => {
  obj([
    ("id", JSON.Encode.string(task.id)),
    ("title", JSON.Encode.string(task.title)),
    ("messages", JSON.Encode.array(task.messages->Array.map(messageToJson))),
    ("createdAt", JSON.Encode.float(task.createdAt)),
    ("updatedAt", JSON.Encode.float(task.updatedAt)),
    ("annotationMode", annotationModeToJson(task.annotationMode)),
    ("annotations", JSON.Encode.array(task.annotations->Array.map(annotationToJson))),
    ("previewUrl", JSON.Encode.string(task.previewUrl)),
  ])
}

let snapshotToJson = (snapshot: t): JSON.t => {
  obj([
    ("tasks", JSON.Encode.array(snapshot.tasks->Array.map(taskToJson))),
    ("currentTaskId", snapshot.currentTaskId->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("sessionInitialized", JSON.Encode.bool(snapshot.sessionInitialized)),
    ("capturedAt", JSON.Encode.float(snapshot.capturedAt)),
  ])
}

/** Serialize snapshot to JSON */
let toJson = (snapshot: t): JSON.t => {
  snapshotToJson(snapshot)
}

/** Serialize snapshot to JSON string - uses native JSON.stringify for bulletproof escaping */
let toJsonString = (snapshot: t): string => {
  let json = snapshotToJson(snapshot)
  JSON.stringify(json, ~space=2)
}

/** Deserialize snapshot from JSON */
let fromJson = (json: JSON.t): result<t, string> => {
  try {
    Ok(S.parseOrThrow(json, schema))
  } catch {
  | S.Error(error) => Error(error.message)
  | exn =>
    Error(
      exn
      ->JsExn.fromException
      ->Option.flatMap(JsExn.message)
      ->Option.getOr("Unknown error parsing snapshot"),
    )
  }
}

/** Deserialize snapshot from JSON string */
let fromJsonString = (jsonString: string): result<t, string> => {
  try {
    Ok(S.parseJsonStringOrThrow(jsonString, schema))
  } catch {
  | S.Error(error) => Error(error.message)
  | exn =>
    Error(
      exn
      ->JsExn.fromException
      ->Option.flatMap(JsExn.message)
      ->Option.getOr("Unknown error parsing snapshot"),
    )
  }
}

// Enable JSON support for Sury
let _ = S.enableJson()
