// Message types - extracted to break circular dependency with MessageStore

// Data for file/image attachments extracted from user content parts
type fileAttachmentData = {
  id: string,
  dataUrl: string,
  mediaType: string,
  filename: string,
}

// Raw base64 + mediaType extracted from a fileAttachmentData's data URL
type resolvedImageData = {
  base64: string,
  mediaType: string,
}

// Strip the "data:mime;base64," prefix from a data URL to get raw base64
let resolveAttachmentImage = (att: fileAttachmentData): resolvedImageData => {
  let base64 = switch att.dataUrl->String.indexOf(";base64,") {
  | -1 => att.dataUrl
  | idx => att.dataUrl->String.slice(~start=idx + 8, ~end=String.length(att.dataUrl))
  }
  {base64, mediaType: att.mediaType}
}

// Serializable annotation snapshot — stored on user messages.
// Captures all annotation metadata at send time, dropping the live DOM element ref.
module MessageAnnotation = {
  type boundingBox = {
    x: float,
    y: float,
    width: float,
    height: float,
  }

  type rec sourceLocation = {
    componentName: option<string>,
    tagName: string,
    file: string,
    line: int,
    column: int,
    parent: option<sourceLocation>,
    componentProps: option<Dict.t<JSON.t>>,
  }

  type t = {
    id: string,
    // Async enrichment fields — result captures per-field success/failure
    selector: result<option<string>, string>,
    tagName: string,
    cssClasses: option<string>,
    comment: option<string>,
    screenshot: result<option<string>, string>,
    sourceLocation: result<option<sourceLocation>, string>,
    boundingBox: option<boundingBox>,
    nearbyText: option<string>,
    elementorContext: option<Client__ElementorDetection.t>,
  }

  // Convert a SourceLocation.t to the local sourceLocation type (same shape, just decoupled)
  let rec sourceLocationFromClientTypes = (loc: Client__Types.SourceLocation.t): sourceLocation => {
    componentName: loc.componentName,
    tagName: loc.tagName,
    file: loc.file,
    line: loc.line,
    column: loc.column,
    parent: loc.parent->Option.map(sourceLocationFromClientTypes),
    componentProps: loc.componentProps,
  }

  // Snapshot a live Annotation.t into a serializable MessageAnnotation.t
  // Drops the live DOM element reference.
  // sourceLocation needs conversion from Client__Types.SourceLocation.t to the local type;
  // selector and screenshot are pass-through (same result<option<string>, string> shape).
  let fromAnnotation = (annotation: Client__Annotation__Types.t): t => {
    id: annotation.id,
    selector: annotation.selector,
    tagName: annotation.tagName,
    cssClasses: annotation.cssClasses,
    comment: annotation.comment,
    screenshot: annotation.screenshot,
    sourceLocation: annotation.sourceLocation->Result.map(opt =>
      opt->Option.map(sourceLocationFromClientTypes)
    ),
    boundingBox: annotation.boundingBox->Option.map(bb => {
      x: bb.x,
      y: bb.y,
      width: bb.width,
      height: bb.height,
    }),
    nearbyText: annotation.nearbyText,
    elementorContext: annotation.elementorContext,
  }
}

// Content part types for messages (simplified from Vercel AI SDK)
module UserContentPart = {
  type t =
    | Text({text: string})
    | Image({id: option<string>, image: string, mediaType: option<string>, name: option<string>})
    | File({file: string})

  let text = (text: string): t => Text({text: text})
}

module AssistantContentPart = {
  type t =
    | Text({text: string})
    | ToolCall({toolCallId: string, toolName: string, input: JSON.t})

  let text = (text: string): t => Text({text: text})
}

type toolCallState =
  | InputStreaming
  | InputAvailable
  | OutputAvailable
  | OutputError

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
  parentAgentId: option<string>,
  spawningToolName: option<string>,
}

module ErrorMessage: {
  type t
  let make: (
    ~id: string,
    ~error: string,
    ~timestamp: string,
    ~retryable: bool,
    ~category: string,
  ) => t
  let restore: (
    ~id: string,
    ~error: string,
    ~createdAt: float,
    ~retryable: bool,
    ~category: string,
  ) => t
  let id: t => string
  let error: t => string
  let createdAt: t => float
  let retryable: t => bool
  let category: t => string
} = {
  type t = {id: string, error: string, createdAt: float, retryable: bool, category: string}

  let make = (~id, ~error, ~timestamp, ~retryable, ~category) => {
    {id, error, createdAt: Date.fromString(timestamp)->Date.getTime, retryable, category}
  }

  let restore = (~id, ~error, ~createdAt, ~retryable, ~category) => {
    {id, error, createdAt, retryable, category}
  }

  let id = t => t.id
  let error = t => t.error
  let createdAt = t => t.createdAt
  let retryable = t => t.retryable
  let category = t => t.category
}

type t =
  | User({
      id: string,
      content: array<UserContentPart.t>,
      annotations: array<MessageAnnotation.t>,
      createdAt: float,
    })
  | Assistant(assistantMessage)
  | ToolCall(toolCall)
  | Error(ErrorMessage.t)

let getId = (msg: t): string => {
  switch msg {
  | User({id, _}) => id
  | Assistant(Streaming({id, _})) => id
  | Assistant(Completed({id, _})) => id
  | ToolCall({id, _}) => id
  | Error(err) => ErrorMessage.id(err)
  }
}
