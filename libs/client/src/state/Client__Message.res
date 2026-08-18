type fileAttachmentData = {
  id: string,
  dataUrl: string,
  mediaType: string,
  filename: string,
}

type resolvedImageData = {
  base64: string,
  mediaType: string,
}

let resolveAttachmentImage = (att: fileAttachmentData): resolvedImageData => {
  let base64 = switch att.dataUrl->String.indexOf(";base64,") {
  | -1 => att.dataUrl
  | idx => att.dataUrl->String.slice(~start=idx + 8, ~end=String.length(att.dataUrl))
  }
  {base64, mediaType: att.mediaType}
}

module MessageAnnotation = {
  type boundingBox = {
    x: float,
    y: float,
    width: float,
    height: float,
  }

  @@live
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
    selector: result<option<string>, string>,
    elementContext: result<option<string>, string>,
    tagName: string,
    cssClasses: option<string>,
    comment: option<string>,
    screenshot: result<option<string>, string>,
    sourceLocation: result<option<sourceLocation>, string>,
    boundingBox: option<boundingBox>,
    nearbyText: option<string>,
    elementorContext: option<Client__ElementorDetection.t>,
  }

  let rec sourceLocationFromClientTypes = (loc: Client__Types.SourceLocation.t): sourceLocation => {
    componentName: loc.componentName,
    tagName: loc.tagName,
    file: loc.file,
    line: loc.line,
    column: loc.column,
    parent: loc.parent->Option.map(sourceLocationFromClientTypes),
    componentProps: loc.componentProps,
  }

  let fromAnnotation = (annotation: Client__Annotation__Types.t): t => {
    id: annotation.id,
    selector: annotation.selector,
    elementContext: annotation.elementContext,
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

module UserContentPart = {
  @@live
  type t =
    | Text({text: string})
    | Image({id: option<string>, image: string, mediaType: option<string>, name: option<string>})
    | File({file: string})

  let text = (text: string): t => Text({text: text})
}

module AssistantContentPart = {
  @@live
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

type toolResult = {
  rawOutput: option<JSON.t>,
  content: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.toolCallContentItem>,
}

type assistantMessage =
  | Streaming({id: string, textBuffer: string, agentId: string})
  | Completed({id: string, content: array<AssistantContentPart.t>, agentId: string})

type toolCall = {
  id: string,
  toolName: string,
  state: toolCallState,
  inputBuffer: string,
  input: option<JSON.t>,
  result: option<toolResult>,
  errorText: option<string>,
  parentAgentId: option<string>,
  spawningToolName: option<string>,
}

module ErrorMessage: {
  type t
  let make: (~id: string, ~error: string, ~category: Client__ErrorCategory.t) => t
  let id: t => string
  let error: t => string
  let category: t => Client__ErrorCategory.t
} = {
  type t = {id: string, error: string, category: Client__ErrorCategory.t}

  let make = (~id, ~error, ~category) => {id, error, category}

  let id = t => t.id
  let error = t => t.error
  let category = t => t.category
}

type t =
  | User({
      id: string,
      content: array<UserContentPart.t>,
      annotations: array<MessageAnnotation.t>,
      agentId: string,
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
