module Log = FrontmanLogs.Logs.Make({
  let component = #TaskReducer
})

module UserContentPart = Client__Message.UserContentPart
module AssistantContentPart = Client__Message.AssistantContentPart
module Message = Client__Message

module Annotation = Client__Annotation__Types
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock

module Task = {
  type turnErrorInfo = {
    id: string,
    message: string,
    category: Client__ErrorCategory.t,
  }

  type retryStatus = {
    attempt: int,
    maxAttempts: int,
    retryAt: float,
    error: string,
  }

  type submissionStatus =
    | Preparing
    | WaitingForSession
    | Sending
    | Accepted
    | Running
    | Failed(string)

  type submission = {
    id: string,
    displayContent: array<UserContentPart.t>,
    preparedContent: option<array<UserContentPart.t>>,
    annotations: array<Message.MessageAnnotation.t>,
    agentId: string,
    model: option<string>,
    status: submissionStatus,
  }

  type previewFrame = {
    url: string,
    contentDocument: option<WebAPI.DomTypes.document>,
    contentWindow: option<WebAPI.DomTypes.window>,
    deviceMode: Client__DeviceMode.deviceMode,
    orientation: Client__DeviceMode.orientation,
  }

  type t =
    | New({
        clientId: string,
        previewFrame: previewFrame,
        annotationMode: Annotation.annotationMode,
        annotations: array<Annotation.t>,
        activePopupAnnotationId: option<string>,
        submissions: array<submission>,
      })
    | Unloaded({
        id: string,
        title: string,
        createdAt: float,
        updatedAt: float,
        submissions: array<submission>,
      })
    | Loading({
        id: string,
        title: string,
        createdAt: float,
        updatedAt: float,
        messages: Client__MessageStore.t,
        previewFrame: previewFrame,
        annotationMode: Annotation.annotationMode,
        annotations: array<Annotation.t>,
        activePopupAnnotationId: option<string>,
        isAgentRunning: bool,
        submissions: array<submission>,
      })
    | Loaded({
        id: string,
        clientId: option<string>,
        title: string,
        createdAt: float,
        updatedAt: float,
        messages: Client__MessageStore.t,
        submissions: array<submission>,
        previewFrame: previewFrame,
        annotationMode: Annotation.annotationMode,
        annotations: array<Annotation.t>,
        activePopupAnnotationId: option<string>,
        isAgentRunning: bool,
        lastTurnCancelled: bool,
        planEntries: array<ACPTypes.planEntry>,
        turnError: option<turnErrorInfo>,
        retryStatus: option<retryStatus>,
        imageAttachments: Dict.t<Client__Message.fileAttachmentData>,
        pendingQuestion: option<Client__Question__Types.pendingQuestion>,
        completedFileChanges: Client__FileChanges.snapshot,
      })

  type currentTask =
    | New(t)
    | Selected(string)

  let normalizeTitle = (title: string): string => {
    switch String.trim(title) {
    | "" => "New Chat"
    | text => {
        let sliced = text->String.slice(~start=0, ~end=50)
        String.length(sliced) < String.length(text) ? sliced ++ "..." : sliced
      }
    }
  }

  let getId = (task: t): option<string> =>
    switch task {
    | New(_) => None
    | Unloaded({id}) | Loading({id}) | Loaded({id}) => Some(id)
    }

  let getClientId = (task: t): string =>
    switch task {
    | New({clientId}) => clientId
    | Loaded({clientId: Some(clientId)}) => clientId
    | Unloaded({id}) | Loading({id}) | Loaded({id}) => id
    }

  let getTitle = (task: t): option<string> =>
    switch task {
    | New(_) => None
    | Unloaded({title}) | Loading({title}) | Loaded({title}) => Some(title)
    }

  let getUpdatedAt = (task: t): option<float> =>
    switch task {
    | New(_) => None
    | Unloaded({updatedAt}) | Loading({updatedAt}) | Loaded({updatedAt}) => Some(updatedAt)
    }

  let getMessages = (task: t): array<Message.t> =>
    switch task {
    | New(_) | Unloaded(_) => []
    | Loading({messages}) | Loaded({messages}) => Client__MessageStore.toArray(messages)
    }

  let getSubmissions = (task: t): array<submission> =>
    switch task {
    | New({submissions})
    | Unloaded({submissions})
    | Loading({submissions})
    | Loaded({submissions}) => submissions
    }

  let updateSubmissions = (task: t, fn: array<submission> => array<submission>): t =>
    switch task {
    | New(data) => New({...data, submissions: fn(data.submissions)})
    | Unloaded(data) => Unloaded({...data, submissions: fn(data.submissions)})
    | Loading(data) => Loading({...data, submissions: fn(data.submissions)})
    | Loaded(data) => Loaded({...data, submissions: fn(data.submissions)})
    }

  let getPreviewFrame = (task: t, ~defaultUrl: string): previewFrame =>
    switch task {
    | New({previewFrame}) => previewFrame
    | Unloaded(_) => {
        url: defaultUrl,
        contentDocument: None,
        contentWindow: None,
        deviceMode: Client__DeviceMode.defaultDeviceMode,
        orientation: Client__DeviceMode.defaultOrientation,
      }
    | Loading({previewFrame}) | Loaded({previewFrame}) => previewFrame
    }

  let getAnnotationMode = (task: t): Annotation.annotationMode =>
    switch task {
    | New({annotationMode}) => annotationMode
    | Unloaded(_) => Annotation.Off
    | Loading({annotationMode}) | Loaded({annotationMode}) => annotationMode
    }

  let getAnnotations = (task: t): array<Annotation.t> =>
    switch task {
    | New({annotations}) => annotations
    | Unloaded(_) => []
    | Loading({annotations}) | Loaded({annotations}) => annotations
    }

  let getActivePopupAnnotationId = (task: t): option<string> =>
    switch task {
    | New({activePopupAnnotationId}) => activePopupAnnotationId
    | Unloaded(_) => None
    | Loading({activePopupAnnotationId})
    | Loaded({activePopupAnnotationId}) => activePopupAnnotationId
    }

  let getImageAttachments = (task: t): Dict.t<Client__Message.fileAttachmentData> =>
    switch task {
    | Loaded({imageAttachments}) => imageAttachments
    | New(_) | Unloaded(_) | Loading(_) => Dict.make()
    }

  let getCompletedFileChanges = (task: t): Client__FileChanges.snapshot =>
    switch task {
    | Loaded({completedFileChanges}) => completedFileChanges
    | New(_) | Unloaded(_) | Loading(_) => Client__FileChanges.empty
    }

  let getWebPreviewIsSelecting = (task: t): bool => getAnnotationMode(task) != Annotation.Off

  let isNew = (task: t): bool =>
    switch task {
    | New(_) => true
    | Unloaded(_) | Loading(_) | Loaded(_) => false
    }

  let isUnloaded = (task: t): bool =>
    switch task {
    | Unloaded(_) => true
    | New(_) | Loading(_) | Loaded(_) => false
    }

  let isLoading = (task: t): bool =>
    switch task {
    | Loading(_) => true
    | New(_) | Unloaded(_) | Loaded(_) => false
    }

  let isLoaded = (task: t): bool =>
    switch task {
    | Loaded(_) => true
    | New(_) | Unloaded(_) | Loading(_) => false
    }

  let stateToString = (task: t): string =>
    switch task {
    | New(_) => "New"
    | Unloaded(_) => "Unloaded"
    | Loading(_) => "Loading"
    | Loaded(_) => "Loaded"
    }

  let setTitle = (task: t, title: string): t =>
    switch task {
    | New(_) => failwith("[Task.setTitle] Cannot set title on New task")
    | Unloaded(data) => Unloaded({...data, title: normalizeTitle(title)})
    | Loading(data) => Loading({...data, title: normalizeTitle(title)})
    | Loaded(data) => Loaded({...data, title: normalizeTitle(title)})
    }

  let makeNew = (~previewUrl: string): t => {
    New({
      clientId: WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.randomUUID,
      previewFrame: {
        url: previewUrl,
        contentDocument: None,
        contentWindow: None,
        deviceMode: Client__DeviceMode.defaultDeviceMode,
        orientation: Client__DeviceMode.defaultOrientation,
      },
      annotationMode: Annotation.Off,
      annotations: [],
      activePopupAnnotationId: None,
      submissions: [],
    })
  }

  let makeUnloaded = (~id: string, ~title: string, ~createdAt: float, ~updatedAt: float): t => {
    Unloaded({
      id,
      title: normalizeTitle(title),
      createdAt,
      updatedAt,
      submissions: [],
    })
  }

  let newToLoaded = (task: t, ~id: string, ~title: string): t => {
    switch task {
    | New({
        clientId,
        previewFrame,
        annotationMode,
        annotations,
        activePopupAnnotationId,
        submissions,
      }) =>
      let timestamp = Date.now()
      Loaded({
        id,
        clientId: Some(clientId),
        title: normalizeTitle(title),
        createdAt: timestamp,
        updatedAt: timestamp,
        messages: Client__MessageStore.make(),
        submissions,
        previewFrame,
        annotationMode,
        annotations,
        activePopupAnnotationId,
        isAgentRunning: false,
        lastTurnCancelled: false,
        planEntries: [],
        turnError: None,
        retryStatus: None,
        imageAttachments: Dict.make(),
        pendingQuestion: None,
        completedFileChanges: Client__FileChanges.empty,
      })
    | Unloaded(_) | Loading(_) | Loaded(_) =>
      failwith("[Task.newToLoaded] Can only transition from New state")
    }
  }

  type loadedData = {
    messages: array<Message.t>,
    annotationMode: Annotation.annotationMode,
    annotations: array<Annotation.t>,
    activePopupAnnotationId: option<string>,
    isAgentRunning: bool,
    lastTurnCancelled: bool,
    planEntries: array<ACPTypes.planEntry>,
    turnError: option<turnErrorInfo>,
    pendingQuestion: option<Client__Question__Types.pendingQuestion>,
  }

  let makeWithId = (
    ~id: string,
    ~title: string,
    ~previewUrl: string,
    ~createdAt: float,
    ~updatedAt: float,
  ): t => {
    let _ = previewUrl
    makeUnloaded(~id, ~title, ~createdAt, ~updatedAt)
  }

  let updateLoadedData = (task: t, fn: loadedData => loadedData): t => {
    switch task {
    | Loaded({
        id,
        clientId,
        title,
        createdAt,
        updatedAt,
        messages,
        submissions,
        previewFrame,
        annotationMode,
        annotations,
        activePopupAnnotationId,
        isAgentRunning,
        lastTurnCancelled,
        planEntries,
        turnError,
        retryStatus,
        imageAttachments,
        pendingQuestion,
        completedFileChanges,
      }) => {
        let data = {
          messages: Client__MessageStore.toArray(messages),
          annotationMode,
          annotations,
          activePopupAnnotationId,
          isAgentRunning,
          lastTurnCancelled,
          planEntries,
          turnError,
          pendingQuestion,
        }
        let updated = fn(data)
        Loaded({
          id,
          clientId,
          title,
          createdAt,
          updatedAt,
          messages: Client__MessageStore.fromArray(updated.messages),
          submissions,
          previewFrame,
          annotationMode: updated.annotationMode,
          annotations: updated.annotations,
          activePopupAnnotationId: updated.activePopupAnnotationId,
          isAgentRunning: updated.isAgentRunning,
          lastTurnCancelled: updated.lastTurnCancelled,
          planEntries: updated.planEntries,
          turnError: updated.turnError,
          retryStatus,
          imageAttachments,
          pendingQuestion: updated.pendingQuestion,
          completedFileChanges,
        })
      }
    | Loading({
        id,
        title,
        createdAt,
        updatedAt,
        messages,
        previewFrame,
        annotationMode,
        annotations,
        activePopupAnnotationId,
        isAgentRunning,
        submissions,
      }) => {
        let data = {
          messages: Client__MessageStore.toArray(messages),
          annotationMode,
          annotations,
          activePopupAnnotationId,
          isAgentRunning,
          lastTurnCancelled: false,
          planEntries: [],
          turnError: None,
          pendingQuestion: None,
        }
        let updated = fn(data)
        Loading({
          id,
          title,
          createdAt,
          updatedAt,
          messages: Client__MessageStore.fromArray(updated.messages),
          previewFrame,
          annotationMode: updated.annotationMode,
          annotations: updated.annotations,
          activePopupAnnotationId: updated.activePopupAnnotationId,
          isAgentRunning: updated.isAgentRunning,
          submissions,
        })
      }
    | New({
        clientId,
        previewFrame,
        annotationMode,
        annotations,
        activePopupAnnotationId,
        submissions,
      }) => {
        let data = {
          messages: [],
          annotationMode,
          annotations,
          activePopupAnnotationId,
          isAgentRunning: false,
          lastTurnCancelled: false,
          planEntries: [],
          turnError: None,
          pendingQuestion: None,
        }
        let updated = fn(data)
        New({
          clientId,
          previewFrame,
          annotationMode: updated.annotationMode,
          annotations: updated.annotations,
          activePopupAnnotationId: updated.activePopupAnnotationId,
          submissions,
        })
      }
    | Unloaded(_) => task
    }
  }
}

let stripFileUriPrefix = (path: string): string => {
  if path->String.startsWith("file:///") {
    let afterPrefix = path->String.slice(~start=8, ~end=path->String.length)

    if afterPrefix->String.length >= 2 && afterPrefix->String.charAt(1) == ":" {
      afterPrefix
    } else {
      "/" ++ afterPrefix
    }
  } else if path->String.startsWith("file://") {
    "/" ++ path->String.slice(~start=7, ~end=path->String.length)
  } else {
    path
  }
}

type boundingBoxMeta = {
  x: float,
  y: float,
  width: float,
  height: float,
}

let boundingBoxMetaSchema: S.t<boundingBoxMeta> = S.object(s => {
  x: s.field("x", S.float),
  y: s.field("y", S.float),
  width: s.field("width", S.float),
  height: s.field("height", S.float),
})

type rec parentLocationMeta = {
  file: string,
  line: int,
  column: int,
  componentName: option<string>,
  componentProps: option<Dict.t<JSON.t>>,
  parent: option<parentLocationMeta>,
}

let rec parentLocationToJson = (loc: parentLocationMeta): JSON.t => {
  let obj = Dict.make()
  obj->Dict.set("file", JSON.Encode.string(loc.file))
  obj->Dict.set("line", JSON.Encode.int(loc.line))
  obj->Dict.set("column", JSON.Encode.int(loc.column))
  switch loc.componentName {
  | Some(name) => obj->Dict.set("component_name", JSON.Encode.string(name))
  | None => ()
  }
  switch loc.componentProps {
  | Some(props) => obj->Dict.set("component_props", JSON.Encode.object(props))
  | None => ()
  }
  switch loc.parent {
  | Some(p) => obj->Dict.set("parent", parentLocationToJson(p))
  | None => ()
  }
  JSON.Encode.object(obj)
}

type annotationMeta = {
  annotation: bool,
  @live
  annotationIndex: int,
  annotationId: string,
  tagName: string,
  selector: option<string>,
  elementContext: option<string>,
  comment: option<string>,
  file: option<string>,
  line: option<int>,
  column: option<int>,
  componentName: option<string>,
  componentProps: option<Dict.t<JSON.t>>,
  parent: option<JSON.t>,
  @live
  sourceLocationError: option<string>,
  cssClasses: option<string>,
  nearbyText: option<string>,
  elementorContext: option<Client__ElementorDetection.t>,
  boundingBox: option<boundingBoxMeta>,
}

let annotationMetaSchema: S.t<annotationMeta> = S.object(s => {
  annotation: s.field("annotation", S.bool),
  annotationIndex: s.field("annotation_index", S.int),
  annotationId: s.field("annotation_id", S.string),
  tagName: s.field("tag_name", S.string),
  selector: s.field("selector", S.option(S.string)),
  elementContext: s.field("element_context", S.option(S.string)),
  comment: s.field("comment", S.option(S.string)),
  file: s.field("file", S.option(S.string)),
  line: s.field("line", S.option(S.int)),
  column: s.field("column", S.option(S.int)),
  componentName: s.field("component_name", S.option(S.string)),
  componentProps: s.field("component_props", S.option(S.dict(S.json))),
  parent: s.field("parent", S.option(S.json)),
  sourceLocationError: s.field("source_location_error", S.option(S.string)),
  cssClasses: s.field("css_classes", S.option(S.string)),
  nearbyText: s.field("nearby_text", S.option(S.string)),
  elementorContext: s.field("elementor", S.option(Client__ElementorDetection.schema)),
  boundingBox: s.field("bounding_box", S.option(boundingBoxMetaSchema)),
})

let elementorText = (context: Client__ElementorDetection.t, ~tagName: string): string =>
  Client__ElementorDetection.summary(context, ~tagName)

let elementorTargetText = (context: Client__ElementorDetection.t): string =>
  switch context.postId {
  | Some(postId) => `post_id=${postId->Int.toString}, element_id=${context.elementId}`
  | None => `element_id=${context.elementId}`
  }

let nearbyTextWithElementorHint = (
  ~nearbyText: option<string>,
  ~elementorContext: option<Client__ElementorDetection.t>,
  ~tagName: string,
): option<string> =>
  switch elementorContext {
  | Some(context) => {
      let hint = `Detected editing context: Elementor ${elementorTargetText(
          context,
        )}. ${elementorText(context, ~tagName)}`
      switch nearbyText {
      | Some(text) =>
        switch text->String.includes("Detected editing context: Elementor") {
        | true => Some(text)
        | false => Some(`${text}\n\n${hint}`)
        }
      | None => Some(hint)
      }
    }
  | None => nearbyText
  }

type screenshotMeta = {
  annotationScreenshot: bool,
  @live
  annotationIndex: int,
  annotationId: string,
}

let screenshotMetaSchema: S.t<screenshotMeta> = S.object(s => {
  annotationScreenshot: s.field("annotation_screenshot", S.bool),
  annotationIndex: s.field("annotation_index", S.int),
  annotationId: s.field("annotation_id", S.string),
})

type annotationBlockData = {
  id: string,
  tagName: string,
  comment: option<string>,
  selector: option<string>,
  elementContext: option<string>,
  screenshot: option<string>,
  sourceLocation: option<parentLocationMeta>,
  sourceLocationError: option<string>,
  cssClasses: option<string>,
  nearbyText: option<string>,
  elementorContext: option<Client__ElementorDetection.t>,
  boundingBox: option<boundingBoxMeta>,
}

let rec sourceLocationFromMessageAnnotation = (
  loc: Message.MessageAnnotation.sourceLocation,
): parentLocationMeta => {
  file: stripFileUriPrefix(loc.file),
  line: loc.line,
  column: loc.column,
  componentName: loc.componentName,
  componentProps: loc.componentProps,
  parent: loc.parent->Option.map(sourceLocationFromMessageAnnotation),
}

let makeAnnotationMeta = (annotation: annotationBlockData, ~index: int): JSON.t => {
  let (
    file,
    line,
    column,
    componentName,
    componentProps,
    parent,
  ) = switch annotation.sourceLocation {
  | Some(loc) => (
      Some(loc.file),
      Some(loc.line),
      Some(loc.column),
      loc.componentName,
      loc.componentProps,
      loc.parent->Option.map(parentLocationToJson),
    )
  | None => (None, None, None, None, None, None)
  }

  {
    annotation: true,
    annotationIndex: index,
    annotationId: annotation.id,
    tagName: annotation.tagName,
    selector: annotation.selector,
    elementContext: annotation.elementContext,
    comment: annotation.comment,
    file,
    line,
    column,
    componentName,
    componentProps,
    parent,
    sourceLocationError: annotation.sourceLocationError,
    cssClasses: annotation.cssClasses,
    nearbyText: nearbyTextWithElementorHint(
      ~nearbyText=annotation.nearbyText,
      ~elementorContext=annotation.elementorContext,
      ~tagName=annotation.tagName,
    ),
    elementorContext: annotation.elementorContext,
    boundingBox: annotation.boundingBox,
  }->S.decodeOrThrow(~from=annotationMetaSchema, ~to=S.json->S.noValidation(true))
}

let annotationResourceUriAndText = (annotation: annotationBlockData): (string, string) =>
  switch annotation.sourceLocation {
  | Some(loc) => {
      let l = loc.line->Int.toString
      let c = loc.column->Int.toString
      (
        `file://${loc.file}:${l}:${c}`,
        `Annotated element: <${annotation.tagName}> at ${loc.file}:${l}:${c}`,
      )
    }
  | None =>
    switch annotation.elementorContext {
    | Some(context) => (
        Client__ElementorDetection.uri(context),
        elementorText(context, ~tagName=annotation.tagName),
      )
    | None =>
      switch annotation.selector {
      | Some(sel) => (
          `selector://${sel}`,
          `Annotated element: <${annotation.tagName}> matching ${sel}`,
        )
      | None => (`element://${annotation.tagName}`, `Annotated element: <${annotation.tagName}>`)
      }
    }
  }

let annotationTextResourceBlock = (annotation: annotationBlockData, ~index): ContentBlock.t => {
  let (uri, text) = annotationResourceUriAndText(annotation)
  let _meta = makeAnnotationMeta(annotation, ~index)

  ContentBlock.EmbeddedResource({
    resource: ContentBlock.TextResourceContents({uri, mimeType: Some("text/plain"), text}),
    _meta: Some(_meta),
    annotations: None,
  })
}

let parseDataUrl = (dataUrl: string): (string, string) => {
  switch dataUrl->String.split(";base64,") {
  | [prefix, base64] =>
    let mimeType = switch prefix->String.split("data:") {
    | [_, mediaType] => mediaType
    | _ => panic(`parseDataUrl: unexpected data URL prefix format: ${prefix}`)
    }
    (mimeType, base64)
  | _ =>
    panic(
      `parseDataUrl: expected data:<mime>;base64,<data> format, got: ${dataUrl->String.slice(
          ~start=0,
          ~end=50,
        )}`,
    )
  }
}

let annotationScreenshotBlock = (annotation: annotationBlockData, ~index: int): option<
  ContentBlock.t,
> =>
  annotation.screenshot->Option.map(screenshotDataUrl => {
    let (mimeType, base64Data) = parseDataUrl(screenshotDataUrl)

    let screenshotMeta: JSON.t = {
      annotationScreenshot: true,
      annotationIndex: index,
      annotationId: annotation.id,
    }->S.decodeOrThrow(~from=screenshotMetaSchema, ~to=S.json->S.noValidation(true))

    ContentBlock.EmbeddedResource({
      resource: ContentBlock.BlobResourceContents({
        uri: `annotation://${annotation.id}/screenshot`,
        mimeType: Some(mimeType),
        blob: base64Data,
      }),
      _meta: Some(screenshotMeta),
      annotations: None,
    })
  })

let annotationContentBlocks = (annotation: annotationBlockData, ~index: int): array<
  ContentBlock.t,
> => {
  [
    Some(annotationTextResourceBlock(annotation, ~index)),
    annotationScreenshotBlock(annotation, ~index),
  ]->Array.filterMap(x => x)
}

let messageAnnotationBoundingBoxMeta = (
  bb: Message.MessageAnnotation.boundingBox,
): boundingBoxMeta => {
  x: bb.x,
  y: bb.y,
  width: bb.width,
  height: bb.height,
}

let messageAnnotationToBlockData = (
  annotation: Message.MessageAnnotation.t,
): annotationBlockData => {
  let (sourceLocation, sourceLocationError) = switch annotation.sourceLocation {
  | Ok(sourceLocation) => (sourceLocation->Option.map(sourceLocationFromMessageAnnotation), None)
  | Error(error) => (None, Some(error))
  }

  {
    id: annotation.id,
    tagName: annotation.tagName,
    comment: annotation.comment,
    selector: annotation.selector->Result.getOr(None),
    elementContext: annotation.elementContext->Result.getOr(None),
    screenshot: annotation.screenshot->Result.getOr(None),
    sourceLocation,
    sourceLocationError,
    cssClasses: annotation.cssClasses,
    nearbyText: annotation.nearbyText,
    elementorContext: annotation.elementorContext,
    boundingBox: annotation.boundingBox->Option.map(messageAnnotationBoundingBoxMeta),
  }
}

let getDocumentTitle: WebAPI.DomTypes.document => string = %raw(`
  function(doc) { return doc.title || ""; }
`)

let getColorScheme: WebAPI.DomTypes.window => string = %raw(`
  function(win) {
    try {
      return win.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    } catch(e) {
      return "unknown";
    }
  }
`)

let currentPageToContentBlock = (previewFrame: Task.previewFrame): ContentBlock.t => {
  let url = previewFrame.url

  let (viewportWidth, viewportHeight, dpr, scrollY) = switch previewFrame.contentWindow {
  | Some(win) =>
    try {
      (
        Some(win->WebAPI.Window.innerWidth),
        Some(win->WebAPI.Window.innerHeight),
        Some(win->WebAPI.Window.devicePixelRatio),
        Some(win->WebAPI.Window.scrollY->Float.toInt),
      )
    } catch {
    | exn =>
      Log.warning(
        ~ctx={"error": exn, "url": previewFrame.url},
        "Cross-origin SecurityError reading iframe viewport/display info",
      )
      (None, None, None, None)
    }
  | None => (None, None, None, None)
  }

  let title = switch previewFrame.contentDocument {
  | Some(doc) =>
    try {
      let t = getDocumentTitle(doc)
      switch t {
      | "" => None
      | value => Some(value)
      }
    } catch {
    | exn =>
      Log.warning(
        ~ctx={"error": exn, "url": previewFrame.url},
        "Cross-origin SecurityError reading iframe document title",
      )
      None
    }
  | None => None
  }

  let colorScheme = switch previewFrame.contentWindow {
  | Some(win) =>
    let scheme = getColorScheme(win)
    switch scheme {
    | "unknown" => None
    | value => Some(value)
    }
  | None => None
  }

  let obj = Dict.make()
  obj->Dict.set("current_page", JSON.Encode.bool(true))
  obj->Dict.set("url", JSON.Encode.string(url))

  switch viewportWidth {
  | Some(w) => obj->Dict.set("viewport_width", JSON.Encode.int(w))
  | None => ()
  }
  switch viewportHeight {
  | Some(h) => obj->Dict.set("viewport_height", JSON.Encode.int(h))
  | None => ()
  }
  switch dpr {
  | Some(d) => obj->Dict.set("device_pixel_ratio", JSON.Encode.float(d))
  | None => ()
  }
  switch title {
  | Some(t) => obj->Dict.set("title", JSON.Encode.string(t))
  | None => ()
  }
  switch colorScheme {
  | Some(s) => obj->Dict.set("color_scheme", JSON.Encode.string(s))
  | None => ()
  }
  switch scrollY {
  | Some(y) => obj->Dict.set("scroll_y", JSON.Encode.int(y))
  | None => ()
  }

  if Client__DeviceMode.isActive(previewFrame.deviceMode) {
    let emulationObj = Dict.make()
    emulationObj->Dict.set("active", JSON.Encode.bool(true))
    let effectiveDims = Client__DeviceMode.getEffectiveDimensions(
      previewFrame.deviceMode,
      previewFrame.orientation,
    )
    switch effectiveDims {
    | Some((w, h)) =>
      emulationObj->Dict.set("width", JSON.Encode.int(w))
      emulationObj->Dict.set("height", JSON.Encode.int(h))
    | None => ()
    }
    emulationObj->Dict.set(
      "name",
      JSON.Encode.string(Client__DeviceMode.getDeviceName(previewFrame.deviceMode)),
    )
    emulationObj->Dict.set(
      "orientation",
      JSON.Encode.string(Client__DeviceMode.orientationToString(previewFrame.orientation)),
    )
    switch Client__DeviceMode.getDeviceDpr(previewFrame.deviceMode) {
    | Some(dpr) => emulationObj->Dict.set("dpr", JSON.Encode.float(dpr))
    | None => ()
    }
    obj->Dict.set("device_emulation", JSON.Encode.object(emulationObj))
  }

  let _meta = JSON.Encode.object(obj)

  let summaryParts = [Some(`URL: ${url}`)]
  let summaryParts = switch (viewportWidth, viewportHeight) {
  | (Some(w), Some(h)) =>
    Array.concat(summaryParts, [Some(`Viewport: ${w->Int.toString}x${h->Int.toString}`)])
  | _ => summaryParts
  }
  let summaryParts = switch dpr {
  | Some(d) => Array.concat(summaryParts, [Some(`DPR: ${d->Float.toString}`)])
  | None => summaryParts
  }
  let summaryParts = switch title {
  | Some(t) => Array.concat(summaryParts, [Some(`Title: ${t}`)])
  | None => summaryParts
  }
  let summaryParts = if Client__DeviceMode.isActive(previewFrame.deviceMode) {
    let deviceName = Client__DeviceMode.getDeviceName(previewFrame.deviceMode)
    let orientationStr = Client__DeviceMode.orientationToString(previewFrame.orientation)
    Array.concat(summaryParts, [Some(`Device: ${deviceName} (${orientationStr})`)])
  } else {
    summaryParts
  }

  let summaryText = summaryParts->Array.filterMap(x => x)->Array.join(", ")

  ContentBlock.EmbeddedResource({
    resource: ContentBlock.TextResourceContents({
      uri: `page://${url}`,
      mimeType: Some("text/plain"),
      text: `Current page: ${summaryText}`,
    }),
    _meta: Some(_meta),
    annotations: None,
  })
}

let taskToPageContextBlocks = (task: Task.t): array<ContentBlock.t> => {
  switch task {
  | Task.Unloaded(_) => []
  | Task.New({previewFrame})
  | Task.Loading({previewFrame})
  | Task.Loaded({previewFrame}) => [currentPageToContentBlock(previewFrame)]
  }
}

let annotationMetaToMessageAnnotation = (
  meta: annotationMeta,
  ~screenshot: option<string>,
): Message.MessageAnnotation.t => {
  let rec parseParentLocation = (json: JSON.t): option<
    Message.MessageAnnotation.sourceLocation,
  > => {
    switch json->JSON.Decode.object {
    | Some(d) =>
      switch (
        d->Dict.get("file")->Option.flatMap(JSON.Decode.string),
        d->Dict.get("line")->Option.flatMap(JSON.Decode.float)->Option.map(Float.toInt),
        d->Dict.get("column")->Option.flatMap(JSON.Decode.float)->Option.map(Float.toInt),
      ) {
      | (Some(file), Some(line), Some(column)) =>
        Some({
          file,
          line,
          column,
          tagName: "unknown",
          componentName: d->Dict.get("component_name")->Option.flatMap(JSON.Decode.string),
          componentProps: d->Dict.get("component_props")->Option.flatMap(JSON.Decode.object),
          parent: d->Dict.get("parent")->Option.flatMap(parseParentLocation),
        })
      | _ => None
      }
    | None => None
    }
  }

  let sourceLocation = switch (meta.sourceLocationError, meta.file, meta.line, meta.column) {
  | (Some(_), Some(_), Some(_), Some(_)) =>
    panic("Annotation metadata contains both a source location and a source location error")
  | (Some(error), _, _, _) => Error(error)
  | (None, Some(file), Some(line), Some(column)) =>
    Ok(
      Some({
        Message.MessageAnnotation.file,
        line,
        column,
        tagName: meta.tagName,
        componentName: meta.componentName,
        componentProps: meta.componentProps,
        parent: meta.parent->Option.flatMap(parseParentLocation),
      }),
    )
  | (None, _, _, _) => Ok(None)
  }

  {
    id: meta.annotationId,
    tagName: meta.tagName,
    selector: Ok(meta.selector),
    elementContext: Ok(meta.elementContext),
    cssClasses: meta.cssClasses,
    comment: meta.comment,
    screenshot: Ok(screenshot),
    sourceLocation,
    boundingBox: meta.boundingBox->Option.map(bb => {
      Message.MessageAnnotation.x: bb.x,
      y: bb.y,
      width: bb.width,
      height: bb.height,
    }),
    nearbyText: meta.nearbyText,
    elementorContext: meta.elementorContext,
  }
}

let messageAnnotationToContentBlocks = (
  annotation: Message.MessageAnnotation.t,
  ~index: int,
): array<ContentBlock.t> => {
  annotationContentBlocks(messageAnnotationToBlockData(annotation), ~index)
}

let messageAnnotationsToContentBlocks = (annotations: array<Message.MessageAnnotation.t>): array<
  ContentBlock.t,
> => {
  annotations->Array.flatMapWithIndex((annotation, index) =>
    messageAnnotationToContentBlocks(annotation, ~index)
  )
}
