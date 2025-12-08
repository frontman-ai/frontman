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
  // Selected node with DSL representation and image
  type selectedNodeData = {
    nodeId: string,
    nodeDSL: string, // DSL representation of the Figma node
    image: option<string>, // Base64 data URL (data:image/png;base64,...)
  }

  type t =
    | NoSelection
    | WaitingForSelection
    | SelectedNode(selectedNodeData)
}

module Task = {
  type previewFrame = {
    url: string,
    contentDocument: option<WebAPI.DOMAPI.document>,
    contentWindow: option<WebAPI.DOMAPI.window>,
    errors: array<Client__Types.consoleError>,
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
    planEntries: array<AskTheLlmFrontmanClient.FrontmanClient__ACP__Types.planEntry>,
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
      previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None, errors: []},
      lastMessageAt: None,
      webPreviewIsSelecting: false,
      selectedElement: None,
      figmaNode: FigmaNode.NoSelection,
      planEntries: [],
    }
  }
}

// Re-export ACP types for convenience
module ACPTypes = AskTheLlmFrontmanClient.FrontmanClient__ACP__Types

// ============================================================================
// ContentBlock builders for embedded context (ACP embeddedContext)
// ============================================================================

// Build a ResourceLink ContentBlock from SelectedElement
// URI format: file://{path}:{line}:{column}
let selectedElementToContentBlock = (sel: SelectedElement.t): option<ACPTypes.contentBlock> => {
  sel.sourceLocation->Option.map(loc => {
    let uri = `file://${loc.file}:${loc.line->Int.toString}:${loc.column->Int.toString}`
    {
      ACPTypes.type_: "resource_link",
      uri: Some(uri),
      text: None,
      resource: None,
      content: None,
    }
  })
}

// Build a Resource ContentBlock from FigmaNode DSL data
// Contains the Figma node as DSL string (compact, token-efficient format)
let figmaNodeToContentBlock = (nodeId: string, nodeDSL: string): ACPTypes.contentBlock => {
  let textResource: ACPTypes.textResourceContents = {
    uri: `figma://node/${nodeId}`,
    mimeType: Some("text/plain"),
    text: nodeDSL,
  }

  // Create _meta with figma_node annotation
  let _meta: JSON.t = %raw(`{"figma_node": true}`)
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

  // Add selectedElement as ResourceLink if available
  let blocks = switch task.selectedElement->Option.flatMap(selectedElementToContentBlock) {
  | Some(block) => Array.concat(blocks, [block])
  | None => blocks
  }

  // Add figmaNode as Resource and Image if available
  let blocks = switch task.figmaNode {
  | FigmaNode.SelectedNode({nodeId, nodeDSL, image}) => {
      let blocks = Array.concat(blocks, [figmaNodeToContentBlock(nodeId, nodeDSL)])
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
}
