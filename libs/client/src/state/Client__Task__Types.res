// Task domain types - extracted from Client__State__Types for modularity
S.enableJson()

// Re-export Message types for backward compatibility
module UserContentPart = Client__Message.UserContentPart
module AssistantContentPart = Client__Message.AssistantContentPart
module Message = Client__Message

module SelectedElement = {
  type t = {
    element: WebAPI.DOMAPI.element,
    selector: option<string>,
    screenshot: option<string>,
    sourceLocation: option<Client__Types.SourceLocation.t>,
  }

  let make = (
    ~element: WebAPI.DOMAPI.element,
    ~selector: option<string>,
    ~screenshot: option<string>,
    ~sourceLocation: option<Client__Types.SourceLocation.t>,
  ) => {
    {
      element,
      selector,
      screenshot,
      sourceLocation,
    }
  }
}

module FigmaNode = {
  // Selected node with DSL representation or full node data, and image
  type selectedNodeData = {
    nodeId: string,
    nodeData: string, // DSL representation OR full JSON node data
    image: option<string>, // Base64 data URL (data:image/png;base64,...)
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
module ACPTypes = FrontmanFrontmanClient.FrontmanClient__ACP__Types

module Task = {
  // ============================================================================
  // Types
  // ============================================================================

  type previewFrame = {
    url: string,
    contentDocument: option<WebAPI.DOMAPI.document>,
    contentWindow: option<WebAPI.DOMAPI.window>,
  }

  // Task lifecycle states (unified - includes New)
  type t =
    // New: local-only, ephemeral (no server session yet)
    | New({
        previewFrame: previewFrame,
        webPreviewIsSelecting: bool,
        selectedElement: option<SelectedElement.t>,
        figmaNode: FigmaNode.t,
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
        webPreviewIsSelecting: bool,
        selectedElement: option<SelectedElement.t>,
        figmaNode: FigmaNode.t,
      })
    // Loaded: fully interactive
    | Loaded({
        id: string,
        title: string,
        createdAt: float,
        updatedAt: float,
        messages: Client__MessageStore.t,
        previewFrame: previewFrame,
        webPreviewIsSelecting: bool,
        selectedElement: option<SelectedElement.t>,
        figmaNode: FigmaNode.t,
        isAgentRunning: bool,
        planEntries: array<ACPTypes.planEntry>,
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
    | Unloaded(_) => {url: defaultUrl, contentDocument: None, contentWindow: None}
    | Loading({previewFrame}) | Loaded({previewFrame}) => previewFrame
    }

  let getWebPreviewIsSelecting = (task: t): bool =>
    switch task {
    | New({webPreviewIsSelecting}) => webPreviewIsSelecting
    | Unloaded(_) => false
    | Loading({webPreviewIsSelecting}) | Loaded({webPreviewIsSelecting}) => webPreviewIsSelecting
    }

  let getSelectedElement = (task: t): option<SelectedElement.t> =>
    switch task {
    | New({selectedElement}) => selectedElement
    | Unloaded(_) => None
    | Loading({selectedElement}) | Loaded({selectedElement}) => selectedElement
    }

  let getFigmaNode = (task: t): FigmaNode.t =>
    switch task {
    | New({figmaNode}) => figmaNode
    | Unloaded(_) => FigmaNode.NoSelection
    | Loading({figmaNode}) | Loaded({figmaNode}) => figmaNode
    }

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
  let makeNew = (~previewUrl: string): t => {
    New({
      previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None},
      webPreviewIsSelecting: false,
      selectedElement: None,
      figmaNode: FigmaNode.NoSelection,
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
        previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None},
        webPreviewIsSelecting: false,
        selectedElement: None,
        figmaNode: FigmaNode.NoSelection,
      })
    | New(_) => failwith("[Task.startLoading] Cannot load a New task - it has no server session")
    | Loading(_) | Loaded(_) => task
    }

  // Atomic transition: New → Loaded (when first message is sent)
  let newToLoaded = (
    task: t,
    ~id: string,
    ~title: string,
    ~firstMessage: Message.t,
  ): t => {
    switch task {
    | New({previewFrame, webPreviewIsSelecting, selectedElement, figmaNode}) =>
      let timestamp = Date.now()
      Loaded({
        id,
        title: normalizeTitle(title),
        createdAt: timestamp,
        updatedAt: timestamp,
        messages: Client__MessageStore.fromArray([firstMessage]),
        previewFrame,
        webPreviewIsSelecting,
        selectedElement,
        figmaNode,
        isAgentRunning: true,
        planEntries: [],
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
  ): t => {
    Loaded({
      id,
      title: normalizeTitle(title),
      createdAt,
      updatedAt: createdAt,
      messages: Client__MessageStore.fromArray(messages),
      previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None},
      webPreviewIsSelecting: false,
      selectedElement: None,
      figmaNode: FigmaNode.NoSelection,
      isAgentRunning: false,
      planEntries: [],
    })
  }

  // ============================================================================
  // Backward Compatibility (to be removed after migration)
  // ============================================================================

  type loadedData = {
    messages: array<Message.t>,
    webPreviewIsSelecting: bool,
    selectedElement: option<SelectedElement.t>,
    figmaNode: FigmaNode.t,
    isAgentRunning: bool,
    planEntries: array<ACPTypes.planEntry>,
  }

  type loadState =
    | NotLoaded
    | Loading(loadedData)
    | Loaded(loadedData)

  let makeLoadedData = (~messages=[]): loadedData => {
    messages,
    webPreviewIsSelecting: false,
    selectedElement: None,
    figmaNode: FigmaNode.NoSelection,
    isAgentRunning: false,
    planEntries: [],
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
    | Loaded({messages, webPreviewIsSelecting, selectedElement, figmaNode, isAgentRunning, planEntries}) =>
      Some({messages: Client__MessageStore.toArray(messages), webPreviewIsSelecting, selectedElement, figmaNode, isAgentRunning, planEntries})
    | Loading({messages, webPreviewIsSelecting, selectedElement, figmaNode}) =>
      Some({messages: Client__MessageStore.toArray(messages), webPreviewIsSelecting, selectedElement, figmaNode, isAgentRunning: false, planEntries: []})
    | New({webPreviewIsSelecting, selectedElement, figmaNode}) =>
      Some({messages: [], webPreviewIsSelecting, selectedElement, figmaNode, isAgentRunning: false, planEntries: []})
    | Unloaded(_) => None
    }
  }

  let updateLoadedData = (task: t, fn: loadedData => loadedData): t => {
    switch task {
    | Loaded({id, title, createdAt, updatedAt, messages, previewFrame, webPreviewIsSelecting, selectedElement, figmaNode, isAgentRunning, planEntries}) => {
        let data = {messages: Client__MessageStore.toArray(messages), webPreviewIsSelecting, selectedElement, figmaNode, isAgentRunning, planEntries}
        let updated = fn(data)
        Loaded({
          id,
          title,
          createdAt,
          updatedAt,
          messages: Client__MessageStore.fromArray(updated.messages),
          previewFrame,
          webPreviewIsSelecting: updated.webPreviewIsSelecting,
          selectedElement: updated.selectedElement,
          figmaNode: updated.figmaNode,
          isAgentRunning: updated.isAgentRunning,
          planEntries: updated.planEntries,
        })
      }
    | Loading({id, title, createdAt, updatedAt, messages, previewFrame, webPreviewIsSelecting, selectedElement, figmaNode}) => {
        let data = {messages: Client__MessageStore.toArray(messages), webPreviewIsSelecting, selectedElement, figmaNode, isAgentRunning: false, planEntries: []}
        let updated = fn(data)
        Loading({
          id,
          title,
          createdAt,
          updatedAt,
          messages: Client__MessageStore.fromArray(updated.messages),
          previewFrame,
          webPreviewIsSelecting: updated.webPreviewIsSelecting,
          selectedElement: updated.selectedElement,
          figmaNode: updated.figmaNode,
        })
      }
    | New({previewFrame, webPreviewIsSelecting, selectedElement, figmaNode}) => {
        let data = {messages: [], webPreviewIsSelecting, selectedElement, figmaNode, isAgentRunning: false, planEntries: []}
        let updated = fn(data)
        New({
          previewFrame,
          webPreviewIsSelecting: updated.webPreviewIsSelecting,
          selectedElement: updated.selectedElement,
          figmaNode: updated.figmaNode,
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

// Helper to create _meta JSON for selected component
let makeSelectedComponentMeta: (string, int, int) => JSON.t = %raw(`
  function(file, line, column) {
    return {
      "selected_component": true,
      "file": file,
      "line": line,
      "column": column
    };
  }
`)

// Build a Resource ContentBlock from SelectedElement with _meta annotation
// Contains the source location as structured data in _meta for safe extraction
let selectedElementToContentBlock = (sel: SelectedElement.t): option<ACPTypes.contentBlock> => {
  sel.sourceLocation->Option.map(loc => {
    // Strip file:// prefix to get clean filesystem path for the agent
    let cleanFilePath = stripFileUriPrefix(loc.file)

    // Build URI with the original file path (preserve for display purposes)
    let uri = `file://${cleanFilePath}:${loc.line->Int.toString}:${loc.column->Int.toString}`

    let textResource: ACPTypes.textResourceContents = {
      uri,
      mimeType: Some("text/plain"),
      text: `Selected component: ${loc.tagName} at ${cleanFilePath}:${loc.line->Int.toString}:${loc.column->Int.toString}`,
    }

    // Create _meta with selected_component annotation containing the clean path
    let _meta = makeSelectedComponentMeta(cleanFilePath, loc.line, loc.column)

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
  })
}

// Build an Image ContentBlock from SelectedElement screenshot
// Uses resource type with image/png mimeType and selected_component_screenshot meta
let selectedElementScreenshotToContentBlock = (
  screenshotDataUrl: string,
): ACPTypes.contentBlock => {
  // Extract base64 data from data URL (data:image/png;base64,<data>)
  let base64Data = switch screenshotDataUrl->String.split(";base64,") {
  | [_, base64] => base64
  | _ => screenshotDataUrl // Fallback to full string if format unexpected
  }

  let blobResource: ACPTypes.blobResourceContents = {
    uri: "component://screenshot",
    mimeType: Some("image/png"),
    blob: base64Data,
  }

  // Create _meta with selected_component_screenshot annotation
  let _meta: JSON.t = %raw(`{"selected_component_screenshot": true}`)

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
// Uses resource type with image/png mimeType
let figmaImageToContentBlock = (imageDataUrl: string): ACPTypes.contentBlock => {
  // Extract base64 data from data URL (data:image/png;base64,<data>)
  // Remove the "data:image/png;base64," prefix to get just the base64 data
  let base64Data = switch imageDataUrl->String.split(";base64,") {
  | [_, base64] => base64
  | _ =>
    // If no "base64," found, try to extract after "data:image/png,"
    switch imageDataUrl->String.split("data:image/png,") {
    | [_, base64] => base64
    | _ => imageDataUrl // Fallback to full string if format unexpected
    }
  }

  let blobResource: ACPTypes.blobResourceContents = {
    uri: "figma://node/image",
    mimeType: Some("image/png"),
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

// Build ContentBlocks array from Task
// Returns array of ContentBlocks to be added to the prompt
let taskToContentBlocks = (task: Task.t): array<ACPTypes.contentBlock> => {
  switch task {
  | Task.Unloaded(_) => []
  | Task.New({selectedElement, figmaNode})
  | Task.Loading({selectedElement, figmaNode})
  | Task.Loaded({selectedElement, figmaNode}) => {
      let blocks = []

      // Add selectedElement as Resource if available (with source location)
      let blocks = switch selectedElement->Option.flatMap(selectedElementToContentBlock) {
      | Some(block) => Array.concat(blocks, [block])
      | None => blocks
      }

      // Add selectedElement screenshot as Image if available
      let blocks = switch selectedElement->Option.flatMap(sel => sel.screenshot) {
      | Some(screenshot) => Array.concat(blocks, [selectedElementScreenshotToContentBlock(screenshot)])
      | None => blocks
      }

      // Add figmaNode as Resource and Image if available
      let blocks = switch figmaNode {
      | FigmaNode.SelectedNode({nodeId, nodeData, image, isDsl}) => {
          let blocks = Array.concat(blocks, [figmaNodeToContentBlock(nodeId, nodeData, isDsl)])
          // Add image as separate content block if available
          switch image {
          | Some(imageDataUrl) => Array.concat(blocks, [figmaImageToContentBlock(imageDataUrl)])
          | None => blocks
          }
        }
      | FigmaNode.NoSelection | FigmaNode.WaitingForSelection => blocks
      }

      blocks
    }
  }
}
