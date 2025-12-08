open AskTheLlmBindings

// Monkey patch Error.prototype.stack to hide chrome-extension:// URLs
let patchErrorStack: unit => unit = %raw(`
  function() {
    const originalStackDescriptor = Object.getOwnPropertyDescriptor(Error.prototype, 'stack');
    const originalStackGetter = originalStackDescriptor?.get;
    const chromeExtRegex = new RegExp('chrome-extension://[^/]+/', 'g');
    
    function cleanStack(stack) {
      if (typeof stack === 'string') {
        return stack
          .split('\\n')
          .map(line => line.replace(chromeExtRegex, ''))
          .join('\\n');
      }
      // If stack is not a string (e.g., array of CallSites), return as-is
      return stack;
    }
    
    if (originalStackGetter) {
      // For browsers that use a getter
      Object.defineProperty(Error.prototype, 'stack', {
        get: function() {
          const stack = originalStackGetter.call(this);
          return cleanStack(stack);
        },
        configurable: true
      });
    } else {
      // Fallback: override stack on each Error instance
      const OriginalError = Error;
      Error = function(...args) {
        const err = new OriginalError(...args);
        const originalStack = err.stack;
        if (originalStack) {
          Object.defineProperty(err, 'stack', {
            get: function() {
              return cleanStack(originalStack);
            },
            configurable: true
          });
        }
        return err;
      };
      Error.prototype = OriginalError.prototype;
    }
  }
`)

// Check if window.figma and window.figma.on exist
let figmaExists: unit => bool = %raw(`
  function() {
    return typeof window !== 'undefined' && 
           typeof window.figma !== 'undefined';
  }
`)

// Wait for window.figma and window.figma.on to be available
let waitForFigma: unit => promise<FigmaClientApiBindings.figmaApi> = %raw(`
  function() {
    return new Promise((resolve) => {
      let timeoutId = null;
      if (typeof window !== 'undefined' && 
          typeof window.figma !== 'undefined') {
        resolve(window.figma);
        return;
      }
      
      const checkInterval = setInterval(() => {
        if (typeof window !== 'undefined' && 
            typeof window.figma !== 'undefined') {
          clearInterval(checkInterval);
          clearTimeout(timeoutId);
          resolve(window.figma);
        }
      }, 100);
      
      timeoutId = setTimeout(() => {
        if (timeoutId) {
          clearInterval(checkInterval);
          console.warn('[Frontman] Figma API not found after 10 seconds');
          resolve();
        }
      }, 10000);
    });
  }
`)

// Helper to post any message through a port (bypasses type checking)
let postMessageRaw: ('port, 'message) => unit = %raw(`
  function(port, message) {
    port.postMessage(message);
  }
`)

let main = () => {
  patchErrorStack()

  let runAsync = async () => {
    let figma = await waitForFigma()

    Console.log("[Frontman] Figma API is ready!")

    // Connect to the extension background via port for bidirectional communication
    let port = Chrome.Runtime.Connect.connectExternal(
      "kfdpjbmabcelpgoipaccjijhehdmeghp",
      Some({name: "FigmaContentScript"}),
    )
    Console.log("[Frontman] Connected to extension via port")

    // Listen for messages from the background (tool calls)
    Chrome.Port.addMessageListener(port, message => {
      let messageType = %raw(`message.type`)

      switch messageType {
      | "GetFigmaNodeRequest" =>
        Console.log2("[Frontman] Received GetFigmaNodeRequest:", message)
        let requestId: string = %raw(`message.requestId`)
        let nodeId: string = %raw(`message.nodeId`)
        let settings = %raw(`message.settings`)

        // Process the request asynchronously
        let handleRequest = async () => {
          try {
            let conversionSettings: FigmaClientApiBindings.conversionSettings = {
              embedVectors: settings["embedVectors"],
              embedImages: settings["embedImages"],
              maxIconSize: settings["maxIconSize"],
              withChildren: settings["withChildren"],
            }

            let includeImage = settings["includeImage"] == true

            let nodeResult = await FigmaClientApiBindings.getFigmaNodeJSON(nodeId, conversionSettings)

            switch nodeResult->Js.Nullable.toOption {
            | Some(node) =>
              // Export image if requested
              let imageDataUrl = if includeImage {
                try {
                  let figmaNodeOpt = await FigmaClientApiBindings.getNodeByIdAsync(figma, nodeId)
                  switch figmaNodeOpt {
                  | Some(figmaNode) =>
                    try {
                      let bytes = await FigmaClientApiBindings.exportAsync(figmaNode, {format: "PNG"})
                      let base64 = FigmaClientApiBindings.base64Encode(bytes)
                      Some(`data:image/png;base64,${base64}`)
                    } catch {
                    | exn =>
                      let errorMsg =
                        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
                      Console.warn2("[Frontman] Failed to export node image:", errorMsg)
                      None
                    }
                  | None => None
                  }
                } catch {
                | exn =>
                  let errorMsg =
                    exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
                  Console.warn2("[Frontman] Failed to get node for image export:", errorMsg)
                  None
                }
              } else {
                None
              }

              postMessageRaw(port, {
                "type": "GetFigmaNodeResponse",
                "requestId": requestId,
                "node": Js.Nullable.return(node->Obj.magic),
                "error": Js.Nullable.null,
                "image": imageDataUrl->Option.map(dataUrl => dataUrl->Obj.magic)->Option.getOr(Js.Nullable.null)->Obj.magic,
              })
            | None =>
              postMessageRaw(port, {
                "type": "GetFigmaNodeResponse",
                "requestId": requestId,
                "node": Js.Nullable.null,
                "error": Js.Nullable.return(`Node with ID "${nodeId}" not found in the current document`),
                "image": Js.Nullable.null,
              })
            }
          } catch {
          | exn =>
            let errorMsg =
              exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
            Console.error2("[Frontman] Error fetching node:", errorMsg)
            postMessageRaw(port, {
              "type": "GetFigmaNodeResponse",
              "requestId": requestId,
              "node": Js.Nullable.null,
              "error": Js.Nullable.return(errorMsg),
              "image": Js.Nullable.null,
            })
          }
        }
        handleRequest()->ignore
      | _ => ()
      }
    })

    // Serialize first selected node when selection changes
    FigmaClientApiBindings.onSelectionChange(figma, () => {
      let runSerialize = async () => {
        let selection =
          figma->FigmaClientApiBindings.currentPage->FigmaClientApiBindings.selection
        switch selection[0] {
        | Some(firstNode) =>
          // Get node ID
          let nodeId = firstNode->FigmaClientApiBindings.id
          
          // Get node DSL representation
          let nodeDSL = await FigmaClientApiBindings.figmaToDSL(
            firstNode,
            FigmaClientApiBindings.defaultSettings,
            FigmaClientApiBindings.defaultDslOptions,
          )
          
          // Export node as PNG image
          let imageDataUrl = try {
            let bytes = await FigmaClientApiBindings.exportAsync(firstNode, {format: "PNG"})
            let base64 = FigmaClientApiBindings.base64Encode(bytes)
            Some(`data:image/png;base64,${base64}`)
          } catch {
          | exn =>
            let errorMsg =
              exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
            Console.warn2("[Frontman] Failed to export node image:", errorMsg)
            None
          }

          // Send to extension with both node DSL and image
          let dslData = switch nodeDSL->Js.Nullable.toOption {
          | Some(dsl) => dsl->Obj.magic
          | None => %raw(`null`)->Obj.magic
          }
          
          let figmaNodeData = {
            "nodeId": nodeId,
            "nodeDSL": dslData,
            "image": imageDataUrl->Option.map(dataUrl => dataUrl->Obj.magic)->Option.getOr(Js.Nullable.null)->Obj.magic,
          }
          
          let data = {"selectedFigmaNode": Js.Nullable.return(figmaNodeData), "type": "FigmaNodeSelected"}
          Chrome.Runtime.sendMessageExternal("kfdpjbmabcelpgoipaccjijhehdmeghp", data, response => {
            Console.log2("[Frontman] Response from extension:", response)
          })
        | None => ()
        }
      }
      runSerialize()->ignore
    })
  }

  runAsync()->ignore
}

let config = {
  "matches": ["https://figma.com/design/*", "https://www.figma.com/design/*"],
}
