open FrontmanBindings

module ImportFigmaNodeRequest = {
  type t = {tabId: int}

  let make = (~tabId: int) => {
    {
      tabId: tabId,
    }
  }
}

// Helper to post any message through a port (bypasses type checking)
let postMessageRaw: ('port, 'message) => unit = %raw(`
  function(port, message) {
    port.postMessage(message);
  }
`)

let main = () => {
  let importFigmaNodeRequest: ref<option<ImportFigmaNodeRequest.t>> = ref(None)
  let figmaNodeDisplayPort: ref<option<Chrome.port<'message>>> = ref(None)
  // Figma page port for tool calls (bidirectional communication)
  let figmaPort: ref<option<Chrome.port<'message>>> = ref(None)
  // Client port for sending responses back
  let clientPort: ref<option<Chrome.port<'message>>> = ref(None)

  // Listen for port connections from external sources (client and Figma page)
  Chrome.Runtime.Connect.addConnectExternalListener("kfdpjbmabcelpgoipaccjijhehdmeghp", port => {
    let portName = %raw(`port.name`)
    Console.log2("[Background] External port connected:", portName)

    switch portName {
    | "FigmaContentScript" =>
      // This is the Figma page connecting
      Console.log("[Background] Figma page port connected")
      figmaPort := Some(port)

      // Listen for messages from Figma (responses to tool calls)
      Chrome.Port.addMessageListener(port, message => {
        let messageType = %raw(`message.type`)
        Console.log2("[Background] Message from Figma port:", message)

        switch messageType {
        | "GetFigmaNodeResponse" =>
          // Forward response back to client
          clientPort.contents->Option.forEach(p => {
            Console.log("[Background] Forwarding GetFigmaNodeResponse to client")
            postMessageRaw(p, message)
          })
        | _ => ()
        }
      })

      Chrome.Runtime.Connect.addDisconnectListener(port, _port => {
        Console.log("[Background] Figma port disconnected")
        figmaPort := None
      })

    | _ =>
      // This is the client/dev server connecting
      Console.log("[Background] Client port connected")
      figmaNodeDisplayPort := Some(port)
      clientPort := Some(port)

      Chrome.Port.addMessageListener(port, message => {
        let messageType = %raw(`message.type`)
        Console.log2("[Background] Message from client port:", message)

        switch messageType {
        | "GetFigmaNodeRequest" =>
          // Forward the request to the Figma page via port
          switch figmaPort.contents {
          | Some(fPort) =>
            Console.log("[Background] Forwarding GetFigmaNodeRequest to Figma port")
            postMessageRaw(fPort, message)
          | None =>
            Console.warn("[Background] No Figma port connected for GetFigmaNodeRequest")
            // Send error response back to client
            let requestId = %raw(`message.requestId`)
            let errorResponse = {
              "type": "GetFigmaNodeResponse",
              "requestId": requestId,
              "error": "No Figma tab is connected. Please open a Figma design file.",
              "node": Js.Nullable.null,
            }
            postMessageRaw(port, errorResponse)
          }
        | _ => ()
        }
      })

      // Handle port disconnect
      Chrome.Runtime.Connect.addDisconnectListener(port, _port => {
        Console.log("[Background] Client port disconnected")
        figmaNodeDisplayPort := None
        clientPort := None
      })
    }
  })

  let runtimeId = %raw(`chrome.runtime.id`)
  Console.log2("Browser runtime ID:", runtimeId)

  Chrome.Runtime.addMessageExternalListener((message, sender, sendResponse) => {
    let messageType = %raw(`message.type`)

    switch messageType {
    | "FigmaNodeDisplayHandshake" =>
      Console.log2("[Background] Received FigmaNodeDisplayHandshake from tab:", sender.tab.id)
      sendResponse({"success": true})

    | "FigmaNodeSelected" =>
      Console.log2("[Background] Received FigmaNodeSelected message:", message)

      // Send to the dev server tab if we have a request
      switch importFigmaNodeRequest.contents {
      | Some(_request) =>
        let msg = {
          "type": "DevServerImportFigmaNodeResponse",
          "selectedFigmaNode": message["selectedFigmaNode"],
        }

        // Also send through the FigmaNodeDisplay port if connected
        figmaNodeDisplayPort.contents->Option.forEach(port => {
          Console.log("[Background] Sending to FigmaNodeDisplay port")
          postMessageRaw(port, msg)
        })
      | None => ()
      }

    | "DevServerImportFigmaNodeRequest" =>
      Console.log2("[Background] Received DevServerImportFigmaNodeRequest message:", message)
      importFigmaNodeRequest := Some(ImportFigmaNodeRequest.make(~tabId=sender.tab.id))
    | _ => ()
    }
  })
}
