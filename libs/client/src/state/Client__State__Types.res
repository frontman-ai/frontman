// State type definitions - extracted to avoid circular dependencies

// Content part types for messages (simplified from Vercel AI SDK)
module UserContentPart = {
  type t =
    | Text({text: string})
    | Image({image: string, mediaType: option<string>})
    | File({file: string})

  let text = (text: string): t => Text({text: text})
}

module AssistantContentPart = {
  type t =
    | Text({text: string})
    | ToolCall({toolCallId: string, toolName: string, input: JSON.t})

  let text = (text: string): t => Text({text: text})
}

module Message = {
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
    parentAgentId: option<string>, // If present, this is a sub-agent tool call
    spawningToolName: option<string>, // Tool name that spawned the sub-agent (e.g., "breakdown_figma_design")
  }

  type t =
    | User({id: string, content: array<UserContentPart.t>, createdAt: float})
    | Assistant(assistantMessage)
    | ToolCall(toolCall)

  let getId = (msg: t): string => {
    switch msg {
    | User({id, _}) => id
    | Assistant(Streaming({id, _})) => id
    | Assistant(Completed({id, _})) => id
    | ToolCall({id, _}) => id
    }
  }
}

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

// Todo batch event - represents "Added X todos" in the chat
module TodoBatchEvent = {
  // Re-export the entry type from ACP
  type entry = FrontmanFrontmanClient.FrontmanClient__ACP__Types.todoBatchEntry

  type t = {
    id: string,
    entries: array<entry>,
    count: int,
    createdAt: float,
  }

  let make = (~entries: array<entry>, ~count: int): t => {
    {
      id: WebAPI.Global.crypto->WebAPI.Crypto.randomUUID,
      entries,
      count,
      createdAt: Date.now(),
    }
  }
}

// Todo status event - represents "Starting: X" or "Finished: X" notifications
module TodoStatusEvent = {
  type eventType = [#started | #completed]

  type t = {
    id: string,
    todoId: string,
    content: string,
    eventType: eventType,
    createdAt: float,
  }

  let make = (~todoId: string, ~content: string, ~eventType: eventType): t => {
    {
      id: WebAPI.Global.crypto->WebAPI.Crypto.randomUUID,
      todoId,
      content,
      eventType,
      createdAt: Date.now(),
    }
  }
}

module Task = {
  type previewFrame = {
    url: string,
    contentDocument: option<WebAPI.DOMAPI.document>,
    contentWindow: option<WebAPI.DOMAPI.window>,
  }

  type t = {
    id: string,
    title: string,
    messages: Dict.t<Message.t>,
    createdAt: float,
    lastMessageAt: option<float>,
    previewFrame: previewFrame,
    webPreviewIsSelecting: bool,
    selectedElement: option<SelectedElement.t>,
    figmaNode: FigmaNode.t,
    planEntries: array<FrontmanFrontmanClient.FrontmanClient__ACP__Types.planEntry>,
    isAgentRunning: bool, // True when waiting for agent response, false when turn is complete
    // Todo UX events
    todoBatchEvents: array<TodoBatchEvent.t>,
    todoStatusEvents: array<TodoStatusEvent.t>,
  }

  let make = (~title: string, ~previewUrl: string, ~messages=Dict.make()): t => {
    let newId = WebAPI.Global.crypto->WebAPI.Crypto.randomUUID
    let timestamp = Date.now()

    // Normalize title: trim, truncate, add ellipsis, or default
    let normalizedTitle = switch String.trim(title) {
    | "" => "New Chat"
    | text => {
        let sliced = text->String.slice(~start=0, ~end=50)
        String.length(sliced) < String.length(text) ? sliced ++ "..." : sliced
      }
    }
    {
      id: newId,
      title: normalizedTitle,
      messages,
      createdAt: timestamp,
      previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None},
      lastMessageAt: None,
      webPreviewIsSelecting: false,
      selectedElement: None,
      figmaNode: FigmaNode.NoSelection,
      planEntries: [],
      isAgentRunning: false,
      todoBatchEvents: [],
      todoStatusEvents: [],
    }
  }
}

// Re-export ACP types for convenience
module ACPTypes = FrontmanFrontmanClient.FrontmanClient__ACP__Types

// ============================================================================
// ContentBlock builders for embedded context (ACP embeddedContext)
// ============================================================================

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
    let uri = `file://${loc.file}:${loc.line->Int.toString}:${loc.column->Int.toString}`

    let textResource: ACPTypes.textResourceContents = {
      uri,
      mimeType: Some("text/plain"),
      text: `Selected component: ${loc.tagName} at ${loc.file}:${loc.line->Int.toString}:${loc.column->Int.toString}`,
    }

    // Create _meta with selected_component annotation containing structured data
    let _meta = makeSelectedComponentMeta(loc.file, loc.line, loc.column)

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
  let blocks = []

  // Add selectedElement as Resource if available (with source location)
  let blocks = switch task.selectedElement->Option.flatMap(selectedElementToContentBlock) {
  | Some(block) => Array.concat(blocks, [block])
  | None => blocks
  }

  // Add selectedElement screenshot as Image if available
  let blocks = switch task.selectedElement->Option.flatMap(sel => sel.screenshot) {
  | Some(screenshot) => Array.concat(blocks, [selectedElementScreenshotToContentBlock(screenshot)])
  | None => blocks
  }

  // Add figmaNode as Resource and Image if available
  let blocks = switch task.figmaNode {
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

// Send prompt function type (from ACP) - now accepts ContentBlocks
type sendPromptFn = (
  string,
  ~additionalBlocks: array<ACPTypes.contentBlock>,
) => promise<result<ACPTypes.promptResult, string>>

// Connection state for the Frontman ACP session
type connectionState =
  | Disconnected
  | Connected(sendPromptFn)

type state = {
  tasks: Dict.t<Task.t>,
  currentTaskId: option<string>,
  connectionState: connectionState,
  sessionInitialized: bool,
}
