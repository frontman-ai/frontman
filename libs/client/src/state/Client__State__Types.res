// State type definitions - extracted to avoid circular dependencies
module Agent = AskTheLlmAgent.Agent
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel
module Nextjs__Types = AskTheLlmNextjs.Nextjs__Types
module UserContentPart = Vercel.UserPart
module AssistantContentPart = Vercel.AssistantPart

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

  // Helper to convert to API-safe format (without DOM element reference)
  let withoutElement = (selected: option<t>): option<Nextjs__Types.selectedElement> => {
    selected->Option.map(sel => {
      let result: Nextjs__Types.selectedElement = {
        selector: sel.selector,
        screenshot: sel.screenshot,
        sourceLocation: sel.sourceLocation->Option.map(Client__Types.SourceLocation.toNextJsType),
      }
      result
    })
  }
}

module FigmaNode = {
  // Node data is now JSON - can be either:
  // - Legacy format: { id, name, type, css, width, height, x, y, visible, locked, children }
  // - Optimized format: { _: legend, $: { root node with N, T, C, K, H } }
  type nodeData = JSON.t

  type t =
    | NoSelection
    | WaitingForSelection
    | SelectedNode(nodeData)
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
      mimeType: None,
      content: None,
    }
  })
}

// Build a Resource ContentBlock from FigmaNode
// Contains the full Figma node data encoded as TOON (30-60% fewer tokens than JSON)
let figmaNodeToContentBlock = (node: FigmaNode.nodeData): ACPTypes.contentBlock => {
  // Encode node as TOON string (more token-efficient than JSON)
  let nodeToon = Client__Toon.encode(node)
  
  // Try to extract ID for URI (works with both formats)
  let nodeId = switch node->JSON.Decode.object {
  | Some(obj) =>
    // Try optimized format: { $: { ... } }
    switch obj->Dict.get("$") {
    | Some(root) =>
      switch root->JSON.Decode.object {
      | Some(rootObj) =>
        switch rootObj->Dict.get("i") {
        | Some(id) => id->JSON.Decode.string->Option.getOr("unknown")
        | None => "unknown"
        }
      | None => "unknown"
      }
    // Try legacy format: { id: "..." }
    | None =>
      switch obj->Dict.get("id") {
      | Some(id) => id->JSON.Decode.string->Option.getOr("unknown")
      | None => "unknown"
      }
    }
  | None => "unknown"
  }

  let embeddedResource: ACPTypes.embeddedResource = {
    uri: `figma://node/${nodeId}`,
    mimeType: "application/x-toon",
    text: Some(nodeToon),
  }

  {
    ACPTypes.type_: "resource",
    text: None,
    uri: None,
    resource: Some(embeddedResource),
    mimeType: Some("application/x-toon"),
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

  // Add figmaNode as Resource if available
  let blocks = switch task.figmaNode {
  | FigmaNode.SelectedNode(nodeData) => Array.concat(blocks, [figmaNodeToContentBlock(nodeData)])
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
