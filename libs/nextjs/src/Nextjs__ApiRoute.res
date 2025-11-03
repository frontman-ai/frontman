// Next.js API Routes Module
// This module provides API route handlers for Next.js applications

S.enableJson()
module Agent = AskTheLlmAgent.Agent
module AgentEventBus = AskTheLlmAgent.Agent__EventBus
module Bindings = AskTheLlmBindings
module Dotenv = AskTheLlmBindings.Dotenv
module DOMElementToComponentSource = AskTheLlmBindings.DOMElementToComponentSource
// Next.js API Route Request type (Pages Router)
module ApiRequest = {
  type t

  @get external method: t => string = "method"
  @get external body: t => JSON.t = "body"
  @get external query: t => Dict.t<string> = "query"
  @get external headers: t => Dict.t<string> = "headers"
  @send external on: (t, string, unit => unit) => unit = "on"
}

// Next.js API Route Response type (Pages Router)
module ApiResponse = {
  type t

  @send external status: (t, int) => t = "status"
  @send external json: (t, 'a) => unit = "json"
  @send external send: (t, string) => unit = "send"
  @send external write: (t, string) => unit = "write"
  @send external setHeader: (t, string, string) => t = "setHeader"
  @send external end: (t, string) => unit = "end"
}

// API handler type for Next.js Pages Router
type apiHandler = (ApiRequest.t, ApiResponse.t) => promise<unit>

// Singleton agent instance
let agentInstance: ref<option<AskTheLlmAgent.Agent.t>> = ref(None)
// Global event buffer - stores all events for late-connecting clients
let eventBuffer: ref<array<AgentEventBus.events>> = ref([])

let getOrCreateAgent = () => {
  switch agentInstance.contents {
  | Some(agent) => agent
  | None =>
    let projectRoot = Bindings.Process.env->Dict.get("PWD")->Option.getOr(".")
    let apiKey = Dotenv.getExn("OPENAI_API_KEY")
    let agent = Agent.make({projectRoot, apiKey})
    let _shutdown = Agent.initialize(agent)

    // Subscribe buffer to agent events at module initialization
    let _ = agent->Agent.subscribe(event => {
      let newSize = eventBuffer.contents->Array.length + 1
      Console.log(`[SSE Buffer] Event buffered, buffer size: ${newSize->Int.toString}`)
      eventBuffer := Array.concat(eventBuffer.contents, [event])
    })

    agentInstance := Some(agent)
    agent
  }
}

let agent = getOrCreateAgent()

// Handler for /api/ask-the-llm (serves the UI)
let createUIHandler = (isDev: bool): apiHandler => {
  async (_req, res) => {
    let askTheLlmHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ask the LLM</title>
</head>
<body>
    <div id="root"></div>
    <script type="module" src="${Nextjs__Config.askTheLlmClientJsUrl(isDev)}"></script>
</body>
</html>`

    let _ = res->ApiResponse.setHeader("Content-Type", "text/html")
    res->ApiResponse.status(200)->ApiResponse.end(askTheLlmHtml)
  }
}

// Helper to decode source location from JSON
let decodeSourceLocation = (json: JSON.t): option<DOMElementToComponentSource.sourceLocation> => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(obj => {
    let componentName = obj->Dict.get("componentName")->Option.flatMap(JSON.Decode.string)
    let file = obj->Dict.get("file")->Option.flatMap(JSON.Decode.string)
    let line = obj->Dict.get("line")->Option.flatMap(JSON.Decode.float)->Option.map(Float.toInt)
    let column = obj->Dict.get("column")->Option.flatMap(JSON.Decode.float)->Option.map(Float.toInt)

    switch (componentName, file, line, column) {
    | (Some(componentName), Some(file), Some(line), Some(column)) => {
        let location: DOMElementToComponentSource.sourceLocation = {
          componentName,
          file,
          line,
          column,
        }
        Some(location)
      }
    | _ => None
    }
  })
}

// Handler for /api/ask-the-llm/chat (handles chat messages)
let createChatHandler = (): apiHandler => {
  async (req, res) => {
    let method = ApiRequest.method(req)

    if method !== "POST" {
      res->ApiResponse.status(405)->ApiResponse.json({"error": "Method not allowed"})
    } else {
      let body = ApiRequest.body(req)
      switch JSON.Decode.object(body) {
      | Some(obj) =>
        switch Dict.get(obj, "message") {
        | Some(messageJson) =>
          switch JSON.Decode.string(messageJson) {
          | Some(str) =>
            if str === "" {
              res->ApiResponse.status(400)->ApiResponse.json({"error": "Message cannot be empty"})
            } else {
              // Extract and resolve source location if present
              let resolvedSourceLocation = switch obj->Dict.get("selectedElement") {
              | Some(selectedElementJson) =>
                switch selectedElementJson->JSON.Decode.object {
                | Some(selectedElementObj) =>
                  switch selectedElementObj->Dict.get("sourceLocation") {
                  | Some(sourceLocationJson) =>
                    switch decodeSourceLocation(sourceLocationJson) {
                    | Some(sourceLocation) =>
                      // Call resolveSourceLocationInServer
                      Console.log2(
                        "[API] Resolving source location:",
                        sourceLocation,
                      )
                      let resolved = await DOMElementToComponentSource.resolveSourceLocationInServer(
                        sourceLocation,
                      )
                      Console.log2("[API] Resolved source location:", resolved)
                      Some(resolved)
                    | None => None
                    }
                  | None => None
                  }
                | None => None
                }
              | None => None
              }

              // Log the resolved source location for debugging
              switch resolvedSourceLocation {
              | Some(location) =>
                Console.log2(
                  "[API] Using resolved source location:",
                  location,
                )
              | None => Console.log("[API] No source location resolved")
              }

              let agent = getOrCreateAgent()
              agent
              ->Agent.sendMessage(
                Agent.TaskMessage.User({
                  taskId: Agent.TaskId.make(),
                  content: String(str),
                  selectedElementSourceLocation: resolvedSourceLocation,
                }),
              )
              ->ignore
              // Message is now processed asynchronously via command queue
              res
              ->ApiResponse.status(202)
              ->ApiResponse.json({
                "status": "accepted",
                "message": "Message received and processing started",
              })
            }
          | None =>
            res
            ->ApiResponse.status(400)
            ->ApiResponse.json({"error": "Message field must be a string"})
          }
        | None =>
          res
          ->ApiResponse.status(400)
          ->ApiResponse.json({"error": "Missing required field: message"})
        }
      | None => res->ApiResponse.status(400)->ApiResponse.json({"error": "Invalid JSON body"})
      }
    }
  }
}

// Handler for /api/ask-the-llm/stream (SSE streaming endpoint)
let createStreamHandler = (): apiHandler => {
  async (req, res) => {
    Console.log("[SSE] Client connected - sending buffered events first")

    // Set SSE headers
    let _ = res->ApiResponse.setHeader("Content-Type", "text/event-stream")
    let _ = res->ApiResponse.setHeader("Cache-Control", "no-cache, no-transform")
    let _ = res->ApiResponse.setHeader("Connection", "keep-alive")

    // Send all buffered events to this client
    let bufferedEvents = eventBuffer.contents
    Console.log(`[SSE] Sending ${bufferedEvents->Array.length->Int.toString} buffered events`)
    bufferedEvents->Array.forEach(event => {
      let jsonValue = event->S.reverseConvertOrThrow(AgentEventBus.eventsSchema)
      let data = JSON.stringifyAny(jsonValue)->Option.getOrThrow
      res->ApiResponse.write(`data: ${data}\n\n`)
    })

    // Flush buffer after sending
    Console.log("[SSE] Flushing event buffer")
    eventBuffer := []

    // Subscribe to new events
    let unsubsribe = agent->Agent.subscribe(event => {
      let jsonValue = event->S.reverseConvertOrThrow(AgentEventBus.eventsSchema)
      let data = JSON.stringifyAny(jsonValue)->Option.getOrThrow
      res->ApiResponse.write(`data: ${data}\n\n`)
    })
    Console.log("[SSE] Subscribed to new agent events")

    // Keep connection open until client disconnects
    // Return a Promise that only resolves when the connection closes
    await Promise.make((resolve, _reject) => {
      req->ApiRequest.on("close", () => {
        Console.log("[SSE] Client disconnected")
        unsubsribe()
        res->ApiResponse.end("")
        resolve()
      })
    })
  }
}
