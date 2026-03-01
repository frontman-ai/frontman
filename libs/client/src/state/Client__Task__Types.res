// Task domain types - extracted from Client__State__Types for modularity
S.enableJson()

// Re-export Message types for backward compatibility
module UserContentPart = Client__Message.UserContentPart
module AssistantContentPart = Client__Message.AssistantContentPart
module Message = Client__Message

module Annotation = Client__Annotation__Types

module FigmaNode = {
  // Selected node with DSL representation or full node data, and image
  type selectedNodeData = {
    nodeId: string,
    nodeData: string, // DSL representation OR full JSON node data
    image: option<string>, // Base64 data URL (data:image/jpeg;base64,... or data:image/png;base64,...)
    isDsl: bool, // true if nodeData is DSL text, false if full JSON data
  }

  type t =
    | NoSelection
    | WaitingForSelection
    | SelectedNode(selectedNodeData)
}

// Todo - single source of truth for todo state (updated by reducer)
module Todo = {
  type status =
    | Pending
    | InProgress
    | Completed

  type t = {
    id: string,
    content: string,
    activeForm: string,
    status: status,
    createdAt: float,
    updatedAt: float,
  }

  let parseStatus = (statusStr: string): status => {
    switch String.toLowerCase(statusStr) {
    | "in_progress" | "in-progress" | "inprogress" => InProgress
    | "completed" | "complete" | "done" => Completed
    | _ => Pending
    }
  }

  // Parse a Todo from JSON tool result
  let fromResult = (json: JSON.t): t => {
    let statusSchema = S.string->S.transform(_ => {
      parser: str => parseStatus(str),
      serializer: status =>
        switch status {
        | Pending => "pending"
        | InProgress => "in_progress"
        | Completed => "completed"
        },
    })

    let schema = S.object(s => (
      s.field("id", S.string),
      s.field("content", S.string),
      s.field("active_form", S.string),
      s.field("status", statusSchema),
    ))

    let (id, content, activeForm, status) = S.parseOrThrow(json, schema)
    let now = Date.now()
    {id, content, activeForm, status, createdAt: now, updatedAt: now}
  }

  // Extract todo ID from a remove result
  let idFromResult = (json: JSON.t): string => {
    S.parseOrThrow(json, S.object(s => s.field("id", S.string)))
  }
}

// Re-export ACP types for convenience
module ACPTypes = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

module Task = {
  // ============================================================================
  // Types
  // ============================================================================

  type previewFrame = {
    url: string,
    contentDocument: option<WebAPI.DOMAPI.document>,
    contentWindow: option<WebAPI.DOMAPI.window>,
    deviceMode: Client__DeviceMode.deviceMode,
    orientation: Client__DeviceMode.orientation,
  }

  // Task lifecycle states (unified - includes New)
  type t =
    // New: local-only, ephemeral (no server session yet)
    // clientId is a stable identifier used for React keys to prevent iframe remounts
    | New({
        clientId: string,
        previewFrame: previewFrame,
        annotationMode: Annotation.annotationMode,
        annotations: array<Annotation.t>,
        activePopupAnnotationId: option<string>,
        isAnimationFrozen: bool,
      })
    // Unloaded: persisted but only metadata loaded
    | Unloaded({
        id: string,
        title: string,
        createdAt: float,
        updatedAt: float,
      })
    // Loading: fetching full data from server
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
        isAnimationFrozen: bool,
      })
    // Loaded: fully interactive
    // clientId is preserved from New state during promotion to maintain iframe identity
    | Loaded({
        id: string,
        clientId: option<string>,
        title: string,
        createdAt: float,
        updatedAt: float,
        messages: Client__MessageStore.t,
        previewFrame: previewFrame,
        annotationMode: Annotation.annotationMode,
        annotations: array<Annotation.t>,
        activePopupAnnotationId: option<string>,
        isAnimationFrozen: bool,
        isAgentRunning: bool,
        planEntries: array<ACPTypes.planEntry>,
        turnError: option<string>,
        // User-attached images keyed by URI (e.g., "attachment://att_abc123/image.png")
        // Accumulated across messages so the agent can save them to disk via write_file
        imageAttachments: Dict.t<Client__Message.fileAttachmentData>,
      })

  // What user is currently viewing
  type currentTask =
    | New(t) // Inline New task (not in dict)
    | Selected(string) // ID reference to task in dict

  // ============================================================================
  // Helpers
  // ============================================================================

  let normalizeTitle = (title: string): string => {
    switch String.trim(title) {
    | "" => "New Chat"
    | text => {
        let sliced = text->String.slice(~start=0, ~end=50)
        String.length(sliced) < String.length(text) ? sliced ++ "..." : sliced
      }
    }
  }

  // Getters for common fields
  // Note: New tasks don't have id/title/timestamps - these return option
  let getId = (task: t): option<string> =>
    switch task {
    | New(_) => None
    | Unloaded({id}) | Loading({id}) | Loaded({id}) => Some(id)
    }

  // Get the stable client-side identifier for React keys (prevents iframe remounts)
  // For New tasks: returns the clientId
  // For Loaded tasks promoted from New: returns clientId if present, otherwise id
  // For other tasks: returns the server id
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

  let getCreatedAt = (task: t): option<float> =>
    switch task {
    | New(_) => None
    | Unloaded({createdAt}) | Loading({createdAt}) | Loaded({createdAt}) => Some(createdAt)
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

  let getPreviewFrame = (task: t, ~defaultUrl: string): previewFrame =>
    switch task {
    | New({previewFrame}) => previewFrame
    | Unloaded(_) => {url: defaultUrl, contentDocument: None, contentWindow: None, deviceMode: Client__DeviceMode.defaultDeviceMode, orientation: Client__DeviceMode.defaultOrientation}
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
    | Loading({activePopupAnnotationId}) | Loaded({activePopupAnnotationId}) => activePopupAnnotationId
    }

  let getIsAnimationFrozen = (task: t): bool =>
    switch task {
    | New({isAnimationFrozen}) => isAnimationFrozen
    | Unloaded(_) => false
    | Loading({isAnimationFrozen}) | Loaded({isAnimationFrozen}) => isAnimationFrozen
    }

  let getImageAttachments = (task: t): Dict.t<Client__Message.fileAttachmentData> =>
    switch task {
    | Loaded({imageAttachments}) => imageAttachments
    | New(_) | Unloaded(_) | Loading(_) => Dict.make()
    }

  // Derived: is any selection mode active?
  let getWebPreviewIsSelecting = (task: t): bool =>
    getAnnotationMode(task) != Annotation.Off

  // State predicates
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

  // Setters for persisted tasks (New tasks don't have these fields)
  let setTitle = (task: t, title: string): t =>
    switch task {
    | New(_) => failwith("[Task.setTitle] Cannot set title on New task")
    | Unloaded(data) => Unloaded({...data, title: normalizeTitle(title)})
    | Loading(data) => Loading({...data, title: normalizeTitle(title)})
    | Loaded(data) => Loaded({...data, title: normalizeTitle(title)})
    }

  // ============================================================================
  // Constructors
  // ============================================================================

  // Create a new ephemeral task (for "new chat" state)
  // Generates a stable clientId for React keying to prevent iframe remounts during promotion
  let makeNew = (~previewUrl: string): t => {
    New({
      clientId: WebAPI.Global.crypto->WebAPI.Crypto.randomUUID,
      previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None, deviceMode: Client__DeviceMode.defaultDeviceMode, orientation: Client__DeviceMode.defaultOrientation},
      annotationMode: Annotation.Off,
      annotations: [],
      activePopupAnnotationId: None,
      isAnimationFrozen: false,
    })
  }

  // Create an Unloaded task (for hydrating from SessionsLoadSuccess)
  let makeUnloaded = (~id: string, ~title: string, ~createdAt: float, ~updatedAt: float): t => {
    Unloaded({
      id,
      title: normalizeTitle(title),
      createdAt,
      updatedAt,
    })
  }

  // Transition Unloaded -> Loading
  let startLoading = (task: t, ~previewUrl: string): t =>
    switch task {
    | Unloaded({id, title, createdAt, updatedAt}) =>
      Loading({
        id,
        title,
        createdAt,
        updatedAt,
        messages: Client__MessageStore.make(),
        previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None, deviceMode: Client__DeviceMode.defaultDeviceMode, orientation: Client__DeviceMode.defaultOrientation},
        annotationMode: Annotation.Off,
        annotations: [],
        activePopupAnnotationId: None,
        isAnimationFrozen: false,
      })
    | New(_) => failwith("[Task.startLoading] Cannot load a New task - it has no server session")
    | Loading(_) | Loaded(_) => task
    }

  // Atomic transition: New → Loaded (promotion when first message is sent)
  // Message insertion is handled separately by the task reducer's AddUserMessage
  // Preserves clientId for stable React keying (prevents iframe remount)
  let newToLoaded = (
    task: t,
    ~id: string,
    ~title: string,
  ): t => {
    switch task {
    | New({clientId, previewFrame, annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen}) =>
      let timestamp = Date.now()
      Loaded({
        id,
        clientId: Some(clientId),
        title: normalizeTitle(title),
        createdAt: timestamp,
        updatedAt: timestamp,
        messages: Client__MessageStore.make(),
        previewFrame,
        annotationMode,
        annotations,
        activePopupAnnotationId,
        isAnimationFrozen,
        isAgentRunning: false,
        planEntries: [],
        turnError: None,
        imageAttachments: Dict.make(),
      })
    | Unloaded(_) | Loading(_) | Loaded(_) =>
      failwith("[Task.newToLoaded] Can only transition from New state")
    }
  }

  // Create a Loaded task directly (for new tasks with known session ID)
  let makeLoaded = (
    ~id: string,
    ~title: string,
    ~previewUrl: string,
    ~createdAt: float,
    ~messages: array<Message.t>=[],
    ~isAgentRunning: bool=false,
  ): t => {
    Loaded({
      id,
      clientId: None,
      title: normalizeTitle(title),
      createdAt,
      updatedAt: createdAt,
      messages: Client__MessageStore.fromArray(messages),
      previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None, deviceMode: Client__DeviceMode.defaultDeviceMode, orientation: Client__DeviceMode.defaultOrientation},
      annotationMode: Annotation.Off,
      annotations: [],
      activePopupAnnotationId: None,
      isAnimationFrozen: false,
      isAgentRunning,
      planEntries: [],
      turnError: None,
      imageAttachments: Dict.make(),
    })
  }

  // ============================================================================
  // Helper types and convenience constructors
  // ============================================================================

  type loadedData = {
    messages: array<Message.t>,
    annotationMode: Annotation.annotationMode,
    annotations: array<Annotation.t>,
    activePopupAnnotationId: option<string>,
    isAnimationFrozen: bool,
    isAgentRunning: bool,
    planEntries: array<ACPTypes.planEntry>,
    turnError: option<string>,
  }

  type loadState =
    | NotLoaded
    | Loading(loadedData)
    | Loaded(loadedData)

  let makeLoadedData = (~messages=[]): loadedData => {
    messages,
    annotationMode: Annotation.Off,
    annotations: [],
    activePopupAnnotationId: None,
    isAnimationFrozen: false,
    isAgentRunning: false,
    planEntries: [],
    turnError: None,
  }

  let make = (~title: string, ~previewUrl: string, ~messages=[]): t => {
    let newId = WebAPI.Global.crypto->WebAPI.Crypto.randomUUID
    makeLoaded(~id=newId, ~title, ~previewUrl, ~createdAt=Date.now(), ~messages)
  }

  let makeWithId = (~id: string, ~title: string, ~previewUrl: string, ~createdAt: float, ~updatedAt: option<float>=?): t => {
    let _ = previewUrl
    makeUnloaded(~id, ~title, ~createdAt, ~updatedAt=updatedAt->Option.getOr(createdAt))
  }

  let makeWithIdLoaded = (~id: string, ~title: string, ~previewUrl: string, ~createdAt: float): t => {
    makeLoaded(~id, ~title, ~previewUrl, ~createdAt)
  }

  let getLoadedData = (task: t): option<loadedData> => {
    switch task {
    | Loaded({messages, annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen, isAgentRunning, planEntries, turnError}) =>
      Some({messages: Client__MessageStore.toArray(messages), annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen, isAgentRunning, planEntries, turnError})
    | Loading({messages, annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen}) =>
      Some({messages: Client__MessageStore.toArray(messages), annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen, isAgentRunning: false, planEntries: [], turnError: None})
    | New({annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen}) =>
      Some({messages: [], annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen, isAgentRunning: false, planEntries: [], turnError: None})
    | Unloaded(_) => None
    }
  }

  let updateLoadedData = (task: t, fn: loadedData => loadedData): t => {
    switch task {
    | Loaded({id, clientId, title, createdAt, updatedAt, messages, previewFrame, annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen, isAgentRunning, planEntries, turnError, imageAttachments}) => {
        let data = {messages: Client__MessageStore.toArray(messages), annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen, isAgentRunning, planEntries, turnError}
        let updated = fn(data)
        Loaded({
          id,
          clientId,
          title,
          createdAt,
          updatedAt,
          messages: Client__MessageStore.fromArray(updated.messages),
          previewFrame,
          annotationMode: updated.annotationMode,
          annotations: updated.annotations,
          activePopupAnnotationId: updated.activePopupAnnotationId,
          isAnimationFrozen: updated.isAnimationFrozen,
          isAgentRunning: updated.isAgentRunning,
          planEntries: updated.planEntries,
          turnError: updated.turnError,
          imageAttachments,
        })
      }
    | Loading({id, title, createdAt, updatedAt, messages, previewFrame, annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen}) => {
        let data = {messages: Client__MessageStore.toArray(messages), annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen, isAgentRunning: false, planEntries: [], turnError: None}
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
          isAnimationFrozen: updated.isAnimationFrozen,
        })
      }
    | New({clientId, previewFrame, annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen}) => {
        let data = {messages: [], annotationMode, annotations, activePopupAnnotationId, isAnimationFrozen, isAgentRunning: false, planEntries: [], turnError: None}
        let updated = fn(data)
        New({
          clientId,
          previewFrame,
          annotationMode: updated.annotationMode,
          annotations: updated.annotations,
          activePopupAnnotationId: updated.activePopupAnnotationId,
          isAnimationFrozen: updated.isAnimationFrozen,
        })
      }
    | Unloaded(_) => task
    }
  }
}

// ============================================================================
// ContentBlock builders for embedded context (ACP embeddedContext)
// ============================================================================

// Helper to strip file:// URI prefix and convert to filesystem path
// Handles both Unix (file:///path) and Windows (file:///C:/path) URIs
let stripFileUriPrefix = (path: string): string => {
  if path->String.startsWith("file:///") {
    // Check if it's a Windows path (file:///C:/...)
    let afterPrefix = path->String.slice(~start=8, ~end=path->String.length) // Skip "file:///"
    // Windows paths have a drive letter followed by colon (e.g., "C:/...")
    if afterPrefix->String.length >= 2 && afterPrefix->String.charAt(1) == ":" {
      // Windows path - return without the file:/// prefix (keeps drive letter)
      afterPrefix
    } else {
      // Unix path - return with leading slash
      "/" ++ afterPrefix
    }
  } else if path->String.startsWith("file://") {
    // Malformed URI with only two slashes - strip and add leading slash
    "/" ++ path->String.slice(~start=7, ~end=path->String.length)
  } else {
    // Not a file:// URI, return as-is
    path
  }
}

// Helper to serialize parent chain to JSON recursively
let rec serializeParentToJson = (parent: option<Client__Types.SourceLocation.t>): option<JSON.t> => {
  parent->Option.map(p => {
    let cleanFilePath = stripFileUriPrefix(p.file)
    let obj = Dict.make()
    obj->Dict.set("file", JSON.Encode.string(cleanFilePath))
    obj->Dict.set("line", JSON.Encode.int(p.line))
    obj->Dict.set("column", JSON.Encode.int(p.column))

    switch p.componentName {
    | Some(name) => obj->Dict.set("component_name", JSON.Encode.string(name))
    | None => ()
    }

    switch p.componentProps {
    | Some(props) => obj->Dict.set("component_props", JSON.Encode.object(props))
    | None => ()
    }

    // Recursively serialize parent's parent
    switch serializeParentToJson(p.parent) {
    | Some(parentJson) => obj->Dict.set("parent", parentJson)
    | None => ()
    }

    JSON.Encode.object(obj)
  })
}

// Set an optional field on a JSON dict — no-op when None
let setOpt = (obj: Dict.t<JSON.t>, key: string, encode: 'a => JSON.t, value: option<'a>) =>
  switch value {
  | Some(v) => obj->Dict.set(key, encode(v))
  | None => ()
  }

let boundingBoxToJson = (bb: Annotation.boundingBox): JSON.t => {
  let obj = Dict.make()
  obj->Dict.set("x", JSON.Encode.float(bb.x))
  obj->Dict.set("y", JSON.Encode.float(bb.y))
  obj->Dict.set("width", JSON.Encode.float(bb.width))
  obj->Dict.set("height", JSON.Encode.float(bb.height))
  JSON.Encode.object(obj)
}

// Build _meta JSON for an annotation from its data + source location fields
let makeAnnotationMeta = (annotation: Annotation.t, ~index: int, ~sourceLocation: option<Client__Types.SourceLocation.t>): JSON.t => {
  let obj = Dict.make()
  obj->Dict.set("annotation", JSON.Encode.bool(true))
  obj->Dict.set("annotation_index", JSON.Encode.int(index))
  obj->Dict.set("annotation_id", JSON.Encode.string(annotation.id))
  obj->Dict.set("tag_name", JSON.Encode.string(annotation.tagName))

  let (file, line, column, componentName, componentProps, parent) = switch sourceLocation {
  | Some(loc) => {
      let cleanFile = stripFileUriPrefix(loc.file)
      (Some(cleanFile), Some(loc.line), Some(loc.column), loc.componentName, loc.componentProps, loc.parent)
    }
  | None => (None, None, None, None, None, None)
  }

  obj->setOpt("comment", JSON.Encode.string, annotation.comment)
  obj->setOpt("file", JSON.Encode.string, file)
  obj->setOpt("line", JSON.Encode.int, line)
  obj->setOpt("column", JSON.Encode.int, column)
  obj->setOpt("component_name", JSON.Encode.string, componentName)
  obj->setOpt("component_props", JSON.Encode.object, componentProps)
  obj->setOpt("parent", x => x, serializeParentToJson(parent))
  obj->setOpt("css_classes", JSON.Encode.string, annotation.cssClasses)
  obj->setOpt("nearby_text", JSON.Encode.string, annotation.nearbyText)
  obj->setOpt("bounding_box", boundingBoxToJson, annotation.boundingBox)

  JSON.Encode.object(obj)
}

// Helper to extract media type and base64 data from a data URL
// Returns (mimeType, base64Data)
let parseDataUrl = (dataUrl: string): (string, string) => {
  // Format: data:<mediaType>;base64,<data>
  switch dataUrl->String.split(";base64,") {
  | [prefix, base64] =>
    // Extract media type from "data:<mediaType>" prefix
    let mimeType = switch prefix->String.split("data:") {
    | [_, mediaType] => mediaType
    | _ => panic(`parseDataUrl: unexpected data URL prefix format: ${prefix}`)
    }
    (mimeType, base64)
  | _ => panic(`parseDataUrl: expected data:<mime>;base64,<data> format, got: ${dataUrl->String.slice(~start=0, ~end=50)}`)
  }
}

// Build content blocks for a single annotation
// Returns 1-2 blocks: resource block with annotation _meta, optional screenshot blob
let annotationToContentBlocks = (annotation: Annotation.t, ~index: int): array<ACPTypes.contentBlock> => {
  let _meta = makeAnnotationMeta(annotation, ~index, ~sourceLocation=annotation.sourceLocation)

  // Build text description and URI from source location, falling back to selector
  let (uri, text) = switch annotation.sourceLocation {
  | Some(loc) => {
      let f = stripFileUriPrefix(loc.file)
      let l = loc.line->Int.toString
      let c = loc.column->Int.toString
      (`file://${f}:${l}:${c}`, `Annotated element: <${annotation.tagName}> at ${f}:${l}:${c}`)
    }
  | None =>
    switch annotation.selector {
    | Some(sel) => (`selector://${sel}`, `Annotated element: <${annotation.tagName}> matching ${sel}`)
    | None => (`element://${annotation.tagName}`, `Annotated element: <${annotation.tagName}>`)
    }
  }

  let resourceBlock: ACPTypes.contentBlock = {
    type_: "resource",
    text: None,
    uri: None,
    resource: Some({
      _meta: Some(_meta),
      annotations: None,
      resource: ACPTypes.TextResourceContents({uri, mimeType: Some("text/plain"), text}),
    }),
    content: None,
  }

  let screenshotBlock = annotation.screenshot->Option.map(screenshotDataUrl => {
    let (mimeType, base64Data) = parseDataUrl(screenshotDataUrl)

    let screenshotMeta: JSON.t = {
      let obj = Dict.make()
      obj->Dict.set("annotation_screenshot", JSON.Encode.bool(true))
      obj->Dict.set("annotation_index", JSON.Encode.int(index))
      obj->Dict.set("annotation_id", JSON.Encode.string(annotation.id))
      JSON.Encode.object(obj)
    }

    let block: ACPTypes.contentBlock = {
      type_: "resource",
      text: None,
      uri: None,
      resource: Some({
        _meta: Some(screenshotMeta),
        annotations: None,
        resource: ACPTypes.BlobResourceContents({
          uri: `annotation://${annotation.id}/screenshot`,
          mimeType: Some(mimeType),
          blob: base64Data,
        }),
      }),
      content: None,
    }
    block
  })

  [Some(resourceBlock), screenshotBlock]->Array.filterMap(x => x)
}

// Helper to create _meta JSON for figma node with nodeId and is_dsl flag
let makeFigmaNodeMeta: (string, bool) => JSON.t = %raw(`
  function(nodeId, isDsl) {
    return {
      "figma_node": true,
      "node_id": nodeId,
      "is_dsl": isDsl
    };
  }
`)

// Build a Resource ContentBlock from FigmaNode data
// Contains the Figma node as DSL string (compact, token-efficient format) or full JSON data
let figmaNodeToContentBlock = (
  nodeId: string,
  nodeData: string,
  isDsl: bool,
): ACPTypes.contentBlock => {
  let textResource: ACPTypes.textResourceContents = {
    uri: nodeId,
    mimeType: Some("text/plain"),
    text: nodeData,
  }

  // Create _meta with figma_node annotation, nodeId, and is_dsl flag
  let _meta = makeFigmaNodeMeta(nodeId, isDsl)
  let embeddedResource: ACPTypes.embeddedResource = {
    _meta: Some(_meta),
    annotations: None,
    resource: ACPTypes.TextResourceContents(textResource),
  }

  {
    ACPTypes.type_: "resource",
    text: None,
    uri: None,
    resource: Some(embeddedResource),
    content: None,
  }
}

// Build an Image ContentBlock from FigmaNode image data
// Uses resource type with mimeType extracted from the data URL
let figmaImageToContentBlock = (imageDataUrl: string): ACPTypes.contentBlock => {
  let (mimeType, base64Data) = parseDataUrl(imageDataUrl)

  let blobResource: ACPTypes.blobResourceContents = {
    uri: "figma://node/image",
    mimeType: Some(mimeType),
    blob: base64Data,
  }

  // Create _meta with figma_image annotation
  let _meta: JSON.t = %raw(`{"figma_image": true}`)

  let embeddedResource: ACPTypes.embeddedResource = {
    _meta: Some(_meta),
    annotations: None,
    resource: ACPTypes.BlobResourceContents(blobResource),
  }

  {
    ACPTypes.type_: "resource",
    text: None,
    uri: None,
    resource: Some(embeddedResource),
    content: None,
  }
}

// Helper: read document.title from a document reference
let getDocumentTitle: WebAPI.DOMAPI.document => string = %raw(`
  function(doc) { return doc.title || ""; }
`)

// Helper: read color scheme preference from a window reference
let getColorScheme: WebAPI.DOMAPI.window => string = %raw(`
  function(win) {
    try {
      return win.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    } catch(e) {
      return "unknown";
    }
  }
`)

// Build a Resource ContentBlock from current page context
// Contains page URL, viewport dimensions, DPR, title, color scheme, and scroll position
let currentPageToContentBlock = (previewFrame: Task.previewFrame): ACPTypes.contentBlock => {
  let url = previewFrame.url

  // Read viewport and display info from iframe's contentWindow
  let (viewportWidth, viewportHeight, dpr, scrollY) = switch previewFrame.contentWindow {
  | Some(win) => (
      Some(win.innerWidth),
      Some(win.innerHeight),
      Some(win.devicePixelRatio),
      Some(win.scrollY->Float.toInt),
    )
  | None => (None, None, None, None)
  }

  // Read page title from iframe's contentDocument
  let title = switch previewFrame.contentDocument {
  | Some(doc) =>
    let t = getDocumentTitle(doc)
    switch t {
    | "" => None
    | value => Some(value)
    }
  | None => None
  }

  // Read color scheme preference from iframe's contentWindow
  let colorScheme = switch previewFrame.contentWindow {
  | Some(win) =>
    let scheme = getColorScheme(win)
    switch scheme {
    | "unknown" => None
    | value => Some(value)
    }
  | None => None
  }

  // Build _meta JSON with current_page marker and all fields
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

  // Add device emulation context if active
  if Client__DeviceMode.isActive(previewFrame.deviceMode) {
    let emulationObj = Dict.make()
    emulationObj->Dict.set("active", JSON.Encode.bool(true))
    let effectiveDims = Client__DeviceMode.getEffectiveDimensions(previewFrame.deviceMode, previewFrame.orientation)
    switch effectiveDims {
    | Some((w, h)) =>
      emulationObj->Dict.set("width", JSON.Encode.int(w))
      emulationObj->Dict.set("height", JSON.Encode.int(h))
    | None => ()
    }
    emulationObj->Dict.set("name", JSON.Encode.string(Client__DeviceMode.getDeviceName(previewFrame.deviceMode)))
    emulationObj->Dict.set("orientation", JSON.Encode.string(Client__DeviceMode.orientationToString(previewFrame.orientation)))
    switch Client__DeviceMode.getDeviceDpr(previewFrame.deviceMode) {
    | Some(dpr) => emulationObj->Dict.set("dpr", JSON.Encode.float(dpr))
    | None => ()
    }
    obj->Dict.set("device_emulation", JSON.Encode.object(emulationObj))
  }

  let _meta = JSON.Encode.object(obj)

  // Build summary text for the resource
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

  let summaryText =
    summaryParts->Array.filterMap(x => x)->Array.join(", ")

  let textResource: ACPTypes.textResourceContents = {
    uri: `page://${url}`,
    mimeType: Some("text/plain"),
    text: `Current page: ${summaryText}`,
  }

  let embeddedResource: ACPTypes.embeddedResource = {
    _meta: Some(_meta),
    annotations: None,
    resource: ACPTypes.TextResourceContents(textResource),
  }

  {
    ACPTypes.type_: "resource",
    text: None,
    uri: None,
    resource: Some(embeddedResource),
    content: None,
  }
}

// Build ContentBlocks array from Task
// Returns array of ContentBlocks to be added to the prompt
// Each annotation produces 1-2 blocks (resource + optional screenshot)
let taskToContentBlocks = (task: Task.t): array<ACPTypes.contentBlock> => {
  switch task {
  | Task.Unloaded(_) => []
  | Task.New({annotations, previewFrame})
  | Task.Loading({annotations, previewFrame})
  | Task.Loaded({annotations, previewFrame}) => {
      let blocks = []

      // Add current page context (always included — implicit context)
      let blocks = Array.concat(blocks, [currentPageToContentBlock(previewFrame)])

      // Add annotation content blocks
      let annotationBlocks = annotations->Array.flatMapWithIndex((annotation, index) =>
        annotationToContentBlocks(annotation, ~index)
      )
      let blocks = Array.concat(blocks, annotationBlocks)

      blocks
    }
  }
}
