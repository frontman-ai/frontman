// Client tool that fetches a Figma node's JSON representation via the chrome extension
// The request is forwarded to the Figma content script which calls getFigmaNodeJSON

S.enableJson()
module Tool = AskTheLlmFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = "get_figma_node"
let visibleToAgent = true
let description = "Get the full JSON representation of a Figma node by its ID. The node must be in the currently open Figma document. Returns the node structure including tailwind classes, text content, SVG data, and children."

@schema
type input = {
  @s.describe("The Figma node ID")
  nodeId: string,
  @s.describe("Whether to embed vector graphics as SVG strings (default: true)")
  embedVectors: option<bool>,
  @s.describe("Whether to embed images as base64 strings (default: true)")
  embedImages: option<bool>,
  @s.describe("Maximum size (width or height) for icons to be exported as SVG (default: 64)")
  maxIconSize: option<int>,
  @s.describe("Whether to include children in the response (auto disabled if volume > 6)")
  withChildren: option<bool>,
  @s.describe("Optional volume score (1-10) used to decide child loading")
  volume: option<int>,
  @s.describe("Whether to include the node image as a PNG data URL (default: false)")
  includeImage: option<bool>,
}

// Output type matches the ConvertedNode from figma-client-api
@schema
type textSpan = {
  text: string,
  tailwind: string,
}

// Using JSON for flexible output that can contain either string or array of textSpans
@schema
type output = {
  @s.describe("The converted Figma node data")
  node: option<JSON.t>,
  @s.describe("Error message if the node could not be fetched")
  error: option<string>,
  @s.describe("PNG image data URL if includeImage was true")
  image: option<string>,
}

// Request ID counter for tracking pending requests
let requestIdCounter = ref(0)

// Response type containing both node and image
type responseData = {
  node: JSON.t,
  image: option<string>,
}

// Pending requests map - resolvers waiting for responses
let pendingRequests: Dict.t<result<responseData, string> => unit> = Dict.make()

// Handle incoming response messages from the extension
let handleResponse = (requestId: string, result: result<responseData, string>) => {
  switch Dict.get(pendingRequests, requestId) {
  | Some(resolve) =>
    Dict.delete(pendingRequests, requestId)
    resolve(result)
  | None => Console.warn2("[GetFigmaNode] No pending request found for ID:", requestId)
  }
}

// Register the response handler - called once during initialization
let responseHandlerRegistered = ref(false)

let registerResponseHandler = () => {
  if !responseHandlerRegistered.contents {
    responseHandlerRegistered.contents = true
    // The response handler is registered via the port message listener in Client__App.res
    // This function is a no-op placeholder as the actual routing happens there
  }
}

let execute = async (input: input): toolResult<output> => {
  registerResponseHandler()

  let extensionState = AskTheLlmReactStatestore.StateStore.getState(
    Client__ExtensionState.Store.store,
  )

  switch Client__ExtensionState.Selectors.getPort(extensionState) {
  | None => Ok({node: None, error: Some("Chrome extension is not connected"), image: None})
  | Some(port) =>
    // Generate unique request ID
    requestIdCounter.contents = requestIdCounter.contents + 1
    let requestId = `figma_node_${requestIdCounter.contents->Int.toString}`

    // Create settings object
    let volume = input.volume
    let withChildren = switch input.withChildren {
    | Some(value) => value
    | None =>
      switch volume {
      | Some(v) if v > 6 => false
      | _ => true
      }
    }
    let settings = {
      "embedVectors": input.embedVectors->Option.getOr(true),
      "embedImages": input.embedImages->Option.getOr(true),
      "maxIconSize": input.maxIconSize->Option.getOr(64),
      "withChildren": withChildren,
      "includeImage": input.includeImage->Option.getOr(false),
    }

    // Create promise that will be resolved when response arrives
    let responsePromise = Promise.make((resolve, _reject) => {
      Dict.set(pendingRequests, requestId, resolve)
    })

    // Send request through the port (use raw to bypass type checking since we're sending a different message shape)
    let postMessageRaw: ('port, 'message) => unit = %raw(`
      function(port, message) {
        port.postMessage(message);
      }
    `)
    let message = {
      "type": "GetFigmaNodeRequest",
      "requestId": requestId,
      "nodeId": input.nodeId,
      "settings": settings,
    }
    postMessageRaw(port, message)

    // Wait for response with timeout
    let timeoutPromise = Promise.make((resolve, _reject) => {
      let _ = WebAPI.Global.setTimeout(~handler=() => {
        // Remove pending request on timeout
        Dict.delete(pendingRequests, requestId)
        resolve(Error("Request timed out after 30 seconds"))
      }, ~timeout=30000)
    })

    let result = await Promise.race([responsePromise, timeoutPromise])

    switch result {
    | Ok({node: nodeJson, image: imageData}) =>
      Ok({
        node: Some(nodeJson),
        error: None,
        image: imageData,
      })
    | Error(errorMsg) => Ok({node: None, error: Some(errorMsg), image: None})
    }
  }
}
