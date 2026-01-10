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
module ACPTypes = FrontmanFrontmanClient.FrontmanClient__ACP__Types

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
  }

  let schema: S.t<t> = S.recursive("SourceLocation", schema =>
    S.object(s => {
      componentName: s.field("componentName", nullableToOption(S.string)),
      tagName: s.field("tagName", S.string),
      file: s.field("file", S.string),
      line: s.field("line", S.int),
      column: s.field("column", S.int),
      parent: s.field("parent", nullableToOption(schema)),
    })
  )
}

module SelectedElement = {
  // Snapshot version - no DOM element reference
  type t = {
    selector: option<string>,
    screenshot: option<string>,
    sourceLocation: option<SourceLocation.t>,
  }

  let schema = S.object(s => {
    selector: s.field("selector", S.option(S.string)),
    screenshot: s.field("screenshot", S.option(S.string)),
    sourceLocation: s.field("sourceLocation", S.option(SourceLocation.schema)),
  })
}

module FigmaNode = {
  type selectedNodeData = {
    nodeId: string,
    nodeData: string,
    image: option<string>,
    isDsl: bool,
  }

  let selectedNodeDataSchema = S.object(s => {
    nodeId: s.field("nodeId", S.string),
    nodeData: s.field("nodeData", S.string),
    image: s.field("image", S.option(S.string)),
    isDsl: s.field("isDsl", S.bool),
  })

  type t =
    | @as("no_selection") NoSelection
    | @as("waiting") WaitingForSelection
    | SelectedNode(selectedNodeData)

  let schema = S.union([
    S.literal(NoSelection),
    S.literal(WaitingForSelection),
    S.object(s => {
      s.tag("type", "selected")
      SelectedNode({
        nodeId: s.field("nodeId", S.string),
        nodeData: s.field("nodeData", S.string),
        image: s.field("image", S.option(S.string)),
        isDsl: s.field("isDsl", S.bool),
      })
    }),
  ])
}

module UserContentPart = {
  type t =
    | Text({text: string})
    | Image({image: string, mediaType: option<string>})
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

module Message = {
  type t =
    | User({id: string, content: array<UserContentPart.t>, createdAt: float})
    | Assistant(AssistantMessage.t)
    | ToolCall(ToolCall.t)

  let schema = S.union([
    S.object(s => {
      s.tag("type", "user")
      User({
        id: s.field("id", S.string),
        content: s.field("content", S.array(UserContentPart.schema)),
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
  ])

  let getId = (msg: t): string => {
    switch msg {
    | User({id, _}) => id
    | Assistant(Streaming({id, _})) => id
    | Assistant(Completed({id, _})) => id
    | ToolCall({id, _}) => id
    }
  }
}

module Task = {
  type t = {
    id: string,
    title: string,
    messages: array<Message.t>,
    createdAt: float,
    lastMessageAt: option<float>,
    webPreviewIsSelecting: bool,
    selectedElement: option<SelectedElement.t>,
    figmaNode: FigmaNode.t,
    previewUrl: string,
  }

  let schema = S.object(s => {
    id: s.field("id", S.string),
    title: s.field("title", S.string),
    messages: s.field("messages", S.array(Message.schema)),
    createdAt: s.field("createdAt", S.float),
    lastMessageAt: s.field("lastMessageAt", S.option(S.float)),
    webPreviewIsSelecting: s.field("webPreviewIsSelecting", S.bool),
    selectedElement: s.field("selectedElement", nullableToOption(SelectedElement.schema)),
    figmaNode: s.field("figmaNode", FigmaNode.schema),
    previewUrl: s.field("previewUrl", S.string),
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
  }
  convert(loc)
}

let convertSelectedElement = (sel: Client__State__Types.SelectedElement.t): SelectedElement.t => {
  selector: sel.selector,
  screenshot: sel.screenshot,
  sourceLocation: sel.sourceLocation->Option.map(convertSourceLocation),
}

let convertFigmaNode = (node: Client__State__Types.FigmaNode.t): FigmaNode.t => {
  switch node {
  | NoSelection => NoSelection
  | WaitingForSelection => WaitingForSelection
  | SelectedNode({nodeId, nodeData, image, isDsl}) =>
    SelectedNode({nodeId, nodeData, image, isDsl})
  }
}

let convertUserContentPart = (part: Client__State__Types.UserContentPart.t): UserContentPart.t => {
  switch part {
  | Text({text}) => Text({text: text})
  | Image({image, mediaType}) => Image({image, mediaType})
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

let convertMessage = (msg: Client__State__Types.Message.t): Message.t => {
  switch msg {
  | User({id, content, createdAt}) =>
    User({
      id,
      content: content->Array.map(convertUserContentPart),
      createdAt,
    })
  | Assistant(assistantMsg) => Assistant(convertAssistantMessage(assistantMsg))
  | ToolCall(tc) => ToolCall(convertToolCall(tc))
  }
}

let convertTask = (task: Client__State__Types.Task.t): Task.t => {
  // Sort messages by createdAt for consistent ordering
  let messages =
    task.messages
    ->Dict.valuesToArray
    ->Array.toSorted((a, b) => {
      let getCreatedAt = (msg: Client__State__Types.Message.t) =>
        switch msg {
        | User({createdAt, _}) => createdAt
        | Assistant(Streaming({createdAt, _})) => createdAt
        | Assistant(Completed({createdAt, _})) => createdAt
        | ToolCall({createdAt, _}) => createdAt
        }
      getCreatedAt(a) -. getCreatedAt(b)
    })
    ->Array.map(convertMessage)

  {
    id: task.id,
    title: task.title,
    messages,
    createdAt: task.createdAt,
    lastMessageAt: task.lastMessageAt,
    webPreviewIsSelecting: task.webPreviewIsSelecting,
    selectedElement: task.selectedElement->Option.map(convertSelectedElement),
    figmaNode: convertFigmaNode(task.figmaNode),
    previewUrl: task.previewFrame.url,
  }
}

// ============================================================================
// Public API
// ============================================================================

/** Capture a snapshot from the live state */
let captureFromState = (state: Client__State__Types.state): t => {
  let tasks = state.tasks->Dict.valuesToArray->Array.map(convertTask)

  {
    tasks,
    currentTaskId: state.currentTaskId,
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
  | Image({image, mediaType}) =>
    obj([
      ("type", JSON.Encode.string("image")),
      ("image", JSON.Encode.string(image)),
      ("mediaType", mediaType->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
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

let messageToJson = (msg: Message.t): JSON.t => {
  switch msg {
  | User({id, content, createdAt}) =>
    obj([
      ("type", JSON.Encode.string("user")),
      ("id", JSON.Encode.string(id)),
      ("content", JSON.Encode.array(content->Array.map(userContentPartToJson))),
      ("createdAt", JSON.Encode.float(createdAt)),
    ])
  | Assistant(assistantMsg) =>
    obj([
      ("type", JSON.Encode.string("assistant")),
      ("message", assistantMessageToJson(assistantMsg)),
    ])
  | ToolCall(tc) =>
    obj([("type", JSON.Encode.string("tool_call")), ("toolCall", toolCallToJson(tc))])
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

let selectedElementToJson = (sel: SelectedElement.t): JSON.t => {
  obj([
    ("selector", sel.selector->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("screenshot", sel.screenshot->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
    ("sourceLocation", sel.sourceLocation->Option.mapOr(JSON.Encode.null, sourceLocationToJson)),
  ])
}

let figmaNodeToJson = (node: FigmaNode.t): JSON.t => {
  switch node {
  | NoSelection => JSON.Encode.string("no_selection")
  | WaitingForSelection => JSON.Encode.string("waiting")
  | SelectedNode({nodeId, nodeData, image, isDsl}) =>
    obj([
      ("type", JSON.Encode.string("selected")),
      ("nodeId", JSON.Encode.string(nodeId)),
      ("nodeData", JSON.Encode.string(nodeData)),
      ("image", image->Option.mapOr(JSON.Encode.null, JSON.Encode.string)),
      ("isDsl", JSON.Encode.bool(isDsl)),
    ])
  }
}

let taskToJson = (task: Task.t): JSON.t => {
  obj([
    ("id", JSON.Encode.string(task.id)),
    ("title", JSON.Encode.string(task.title)),
    ("messages", JSON.Encode.array(task.messages->Array.map(messageToJson))),
    ("createdAt", JSON.Encode.float(task.createdAt)),
    ("lastMessageAt", task.lastMessageAt->Option.mapOr(JSON.Encode.null, JSON.Encode.float)),
    ("webPreviewIsSelecting", JSON.Encode.bool(task.webPreviewIsSelecting)),
    ("selectedElement", task.selectedElement->Option.mapOr(JSON.Encode.null, selectedElementToJson)),
    ("figmaNode", figmaNodeToJson(task.figmaNode)),
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

