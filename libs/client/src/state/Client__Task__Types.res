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
    retryErrorId: option<string>,
  }

  type retryStatus = {
    attempt: int,
    maxAttempts: int,
    retryAt: float,
    error: string,
  }

  type previewFrame = {
    runtime: option<Client__PreviewRuntime.t>,
    url: string,
    contentDocument: option<WebAPI.DomTypes.document>,
    contentWindow: option<WebAPI.DomTypes.window>,
    deviceMode: Client__DeviceMode.deviceMode,
    orientation: Client__DeviceMode.orientation,
  }

  type sessionInfo = {id: string, title: string, @live createdAt: float, updatedAt: float}
  type session = New | Unloaded(sessionInfo) | Loading(sessionInfo) | Loaded(sessionInfo)

  type t = {
    clientId: string,
    session: session,
    messages: Client__MessageStore.t,
    previewFrame: previewFrame,
    annotationMode: Annotation.annotationMode,
    annotations: array<Annotation.t>,
    activePopupAnnotationId: option<string>,
    isAgentRunning: bool,
    lastTurnCancelled: bool,
    planEntries: array<ACPTypes.planEntry>,
    queuedUserMessages: array<Message.t>,
    pendingUserMessageIds: array<string>,
    turnError: option<turnErrorInfo>,
    retryStatus: option<retryStatus>,
    imageAttachments: Dict.t<Client__Message.fileAttachmentData>,
    pendingQuestion: option<Client__Question__Types.pendingQuestion>,
    completedFileChanges: Client__FileChanges.snapshot,
  }

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
    switch task.session {
    | New => None
    | Unloaded({id}) | Loading({id}) | Loaded({id}) => Some(id)
    }

  let getClientId = (task: t): string => task.clientId

  let getTitle = (task: t): option<string> =>
    switch task.session {
    | New => None
    | Unloaded({title}) | Loading({title}) | Loaded({title}) => Some(title)
    }

  let getUpdatedAt = (task: t): option<float> =>
    switch task.session {
    | New => None
    | Unloaded({updatedAt}) | Loading({updatedAt}) | Loaded({updatedAt}) => Some(updatedAt)
    }

  let getMessages = (task: t): array<Message.t> => Client__MessageStore.toArray(task.messages)

  let getPreviewFrame = (task: t, ~defaultUrl: string): previewFrame =>
    switch task.session {
    | Unloaded(_) => {...task.previewFrame, url: defaultUrl}
    | New | Loading(_) | Loaded(_) => task.previewFrame
    }

  let getAnnotationMode = (task: t): Annotation.annotationMode => task.annotationMode
  let getAnnotations = (task: t): array<Annotation.t> => task.annotations
  let getActivePopupAnnotationId = (task: t): option<string> => task.activePopupAnnotationId
  let getImageAttachments = (task: t): Dict.t<Client__Message.fileAttachmentData> =>
    task.imageAttachments
  let getCompletedFileChanges = (task: t): Client__FileChanges.snapshot => task.completedFileChanges
  let getWebPreviewIsSelecting = (task: t): bool => task.annotationMode != Annotation.Off

  let isNew = (task: t): bool => task.session == New
  let isUnloaded = (task: t): bool =>
    switch task.session {
    | Unloaded(_) => true
    | New | Loading(_) | Loaded(_) => false
    }
  let isLoading = (task: t): bool =>
    switch task.session {
    | Loading(_) => true
    | New | Unloaded(_) | Loaded(_) => false
    }
  let isLoaded = (task: t): bool =>
    switch task.session {
    | Loaded(_) => true
    | New | Unloaded(_) | Loading(_) => false
    }

  let stateToString = (task: t): string =>
    switch task.session {
    | New => "New"
    | Unloaded(_) => "Unloaded"
    | Loading(_) => "Loading"
    | Loaded(_) => "Loaded"
    }

  let setTitle = (task: t, title: string): t => {
    let title = normalizeTitle(title)
    let session = switch task.session {
    | New => failwith("[Task.setTitle] Cannot set title on New task")
    | Unloaded(info) => Unloaded({...info, title})
    | Loading(info) => Loading({...info, title})
    | Loaded(info) => Loaded({...info, title})
    }
    {...task, session}
  }

  let make = (~clientId: string, ~session: session, ~previewUrl: string): t => {
    clientId,
    session,
    messages: Client__MessageStore.make(),
    previewFrame: {
      runtime: None,
      url: previewUrl,
      contentDocument: None,
      contentWindow: None,
      deviceMode: Client__DeviceMode.defaultDeviceMode,
      orientation: Client__DeviceMode.defaultOrientation,
    },
    annotationMode: Annotation.Off,
    annotations: [],
    activePopupAnnotationId: None,
    isAgentRunning: false,
    lastTurnCancelled: false,
    planEntries: [],
    queuedUserMessages: [],
    pendingUserMessageIds: [],
    turnError: None,
    retryStatus: None,
    imageAttachments: Dict.make(),
    pendingQuestion: None,
    completedFileChanges: Client__FileChanges.empty,
  }

  let makeNew = (~previewUrl: string): t =>
    make(
      ~clientId=WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.randomUUID,
      ~session=New,
      ~previewUrl,
    )

  let makeUnloaded = (
    ~id: string,
    ~title: string,
    ~createdAt: float,
    ~updatedAt: float,
    ~previewUrl: string,
  ): t =>
    make(
      ~clientId=id,
      ~session=Unloaded({id, title: normalizeTitle(title), createdAt, updatedAt}),
      ~previewUrl,
    )

  let newToLoaded = (task: t, ~id: string, ~title: string): t =>
    switch task.session {
    | New =>
      let timestamp = Date.now()
      {
        ...task,
        session: Loaded({
          id,
          title: normalizeTitle(title),
          createdAt: timestamp,
          updatedAt: timestamp,
        }),
      }
    | Unloaded(_) | Loading(_) | Loaded(_) =>
      failwith("[Task.newToLoaded] Can only transition from New state")
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

type promptMessage = {
  id: Message.UserMessageId.t,
  text: string,
  attachments: array<Message.fileAttachmentData>,
  annotations: array<Message.MessageAnnotation.t>,
  agentId: string,
  preview: Task.previewFrame,
}

@schema
type promptMetadata = {
  @live framework: string,
  @live traits: option<array<string>>,
  @live model: option<string>,
  @live @as("frontman.dev/messageId") messageId: string,
  @live agent: string,
}

@schema
type deviceMetadata = {
  @live active: bool,
  @live width: int,
  @live height: int,
  name: string,
  orientation: string,
  @live dpr: option<float>,
}

@schema
type pageMetadata = {
  @live current_page: bool,
  @live url: string,
  @live viewport_width: int,
  @live viewport_height: int,
  @live device_pixel_ratio: float,
  title: option<string>,
  @live color_scheme: option<[#dark | #light]>,
  @live scroll_y: int,
  @live device_emulation: option<deviceMetadata>,
  @live
  astro_client_routing: option<FrontmanAiFrontmanProtocol.FrontmanProtocol__AstroClientRouting.t>,
}

let currentPageToContentBlock = (
  page: FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview.pageContext,
  ~deviceMode: Client__DeviceMode.deviceMode,
  ~orientation: Client__DeviceMode.orientation,
  ~isAstro: bool,
): ContentBlock.t => {
  let device = switch Client__DeviceMode.getEffectiveDimensions(deviceMode, orientation) {
  | None => None
  | Some((width, height)) =>
    Some({
      active: true,
      width,
      height,
      name: Client__DeviceMode.getDeviceName(deviceMode),
      orientation: Client__DeviceMode.orientationToString(orientation),
      dpr: Client__DeviceMode.getDeviceDpr(deviceMode),
    })
  }
  let metadata: pageMetadata = {
    current_page: true,
    url: page.url,
    viewport_width: page.viewportWidth,
    viewport_height: page.viewportHeight,
    device_pixel_ratio: page.devicePixelRatio,
    title: switch page.title {
    | "" => None
    | title => Some(title)
    },
    color_scheme: Some(page.colorScheme),
    scroll_y: page.scrollY,
    device_emulation: device,
    astro_client_routing: isAstro ? Some(page.astroClientRouting) : None,
  }
  let summaryText =
    [
      Some(`URL: ${page.url}`),
      Some(`Viewport: ${page.viewportWidth->Int.toString}x${page.viewportHeight->Int.toString}`),
      Some(`DPR: ${page.devicePixelRatio->Float.toString}`),
      metadata.title->Option.map(title => `Title: ${title}`),
      device->Option.map(device => `Device: ${device.name} (${device.orientation})`),
    ]
    ->Array.filterMap(x => x)
    ->Array.join(", ")

  ContentBlock.EmbeddedResource({
    resource: ContentBlock.TextResourceContents({
      uri: `page://${page.url}`,
      mimeType: Some("text/plain"),
      text: `Current page: ${summaryText}`,
    }),
    _meta: Some(S.decodeOrThrow(metadata, ~from=pageMetadataSchema, ~to=S.json)),
    annotations: None,
  })
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

@schema
type attachmentMetadata = {@live user_image: bool, @live filename: string}

let buildAttachmentContentBlocks = (attachments: array<Message.fileAttachmentData>) =>
  attachments->Array.map(att => {
    let meta = S.decodeOrThrow(
      {user_image: true, filename: att.filename},
      ~from=attachmentMetadataSchema,
      ~to=S.json,
    )
    ContentBlock.EmbeddedResource({
      resource: ContentBlock.BlobResourceContents({
        uri: `attachment://${att.id}/${att.filename}`,
        mimeType: Some(att.mediaType),
        blob: Message.resolveAttachmentImage(att).base64,
      }),
      _meta: Some(meta),
      annotations: None,
    })
  })

let buildPrompt = (message: promptMessage, page, ~framework, ~traits, ~model) => (
  [
    currentPageToContentBlock(
      page,
      ~deviceMode=message.preview.deviceMode,
      ~orientation=message.preview.orientation,
      ~isAstro=framework == "astro",
    ),
    ...messageAnnotationsToContentBlocks(message.annotations),
    ...buildAttachmentContentBlocks(message.attachments),
  ],
  S.decodeOrThrow(
    {
      framework,
      traits,
      model,
      messageId: Message.UserMessageId.toString(message.id),
      agent: message.agentId,
    },
    ~from=promptMetadataSchema,
    ~to=S.json,
  ),
)
