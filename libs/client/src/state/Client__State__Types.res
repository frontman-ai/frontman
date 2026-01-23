// State type definitions - extracted to avoid circular dependencies
S.enableJson()

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
    isAgentRunning: bool,
    planEntries: array<FrontmanFrontmanClient.FrontmanClient__ACP__Types.planEntry>,
  }

  let make = (~title: string, ~previewUrl: string, ~messages=Dict.make()): t => {
    let newId = WebAPI.Global.crypto->WebAPI.Crypto.randomUUID
    let timestamp = Date.now()

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
      isAgentRunning: false,
      planEntries: [],
    }
  }
}

// Re-export ACP types for convenience
module ACPTypes = FrontmanFrontmanClient.FrontmanClient__ACP__Types

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

type sendPromptFn = (
  string,
  ~additionalBlocks: array<ACPTypes.contentBlock>,
  ~onComplete: result<ACPTypes.promptResult, string> => unit,
  ~metadata: option<JSON.t>,
) => unit

// Connection state for the Frontman ACP session
type connectionState =
  | Disconnected
  | Connected(sendPromptFn)

// Usage info from API
@schema
type usageInfo = {
  limit: option<int>,
  remaining: option<int>,
  hasUserKey: option<bool>,
  hasServerKey: option<bool>,
}

// API key source status for settings display
type apiKeySource =
  | None // No key configured
  | FromEnv // Key loaded from environment variable
  | UserOverride // User has saved their own key (stored in DB)

// API key save operation status
type apiKeySaveStatus =
  | Idle
  | Saving
  | Saved
  | SaveError(string)

// API key settings for a provider
type apiKeySettings = {
  source: apiKeySource,
  saveStatus: apiKeySaveStatus,
}

// Model configuration types
@schema
type modelConfig = {
  displayName: string,
  value: string,
}

@schema
type providerConfig = {
  id: string,
  name: string,
  models: array<modelConfig>,
}

@schema
type modelsConfigDefaultModel = {
  provider: string,
  value: string,
}

@schema
type modelsConfig = {
  providers: array<providerConfig>,
  defaultModel: modelsConfigDefaultModel,
}

// Selected model - what gets sent to the server
@schema
type selectedModel = {
  provider: string,
  value: string,
}

// Anthropic OAuth connection status
type anthropicOAuthStatus =
  | NotConnected
  | FetchingStatus
  | Authorizing({authorizeUrl: string, verifier: string})
  | Exchanging
  | Connected({expiresAt: float})
  | Error(string)

type state = {
  tasks: Dict.t<Task.t>,
  currentTaskId: option<string>,
  connectionState: connectionState,
  sessionInitialized: bool,
  usageInfo: option<usageInfo>,
  apiBaseUrl: option<string>,
  openrouterKeySettings: apiKeySettings,
  anthropicOAuthStatus: anthropicOAuthStatus,
  modelsConfig: option<modelsConfig>,
  selectedModel: option<selectedModel>,
}
