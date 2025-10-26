// Next.js API Routes Module
// This module provides API route handlers for Next.js applications

S.enableJson()
module Agent = AskTheLlmAgent.Agent
module Bindings = AskTheLlmBindings
module Dotenv = AskTheLlmBindings.Dotenv
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

let getOrCreateAgent = () => {
  switch agentInstance.contents {
  | Some(agent) => agent
  | None =>
    let projectRoot = Bindings.Process.env->Dict.get("PWD")->Option.getOr(".")
    let apiKey = Dotenv.getExn("OPENAI_API_KEY")
    let agent = Agent.make({projectRoot, apiKey})
    let _shutdown = Agent.initialize(agent)
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
              let agent = getOrCreateAgent()
              agent
              ->Agent.sendMessage(Agent.TaskMessage.User({content: String(str)}))
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
    let _ = res->ApiResponse.setHeader("Content-Type", "text/event-stream")
    let _ = res->ApiResponse.setHeader("Cache-Control", "no-cache, no-transform")
    let _ = res->ApiResponse.setHeader("Connection", "keep-alive")

    let send = (msg: Agent.TaskMessage.t) => {
      let jsonValue = msg->S.reverseConvertOrThrow(Agent.TaskMessage.schema)
      let data = JSON.stringify(jsonValue->Obj.magic)
      res->ApiResponse.write(`data: ${data}\n\n`)
    }

    let unsubsribe = agent->Agent.subscribe(event => {
      switch event {
      | TaskEvent(_task, MessageAdded({message})) =>
        Console.log2("taskMessageAdded", message)
        send(message)
      | _ => Console.log("other event")
      }
    })

    req->ApiRequest.on("close", () => {
      unsubsribe()
      res->ApiResponse.end("")
    })

    res->ApiResponse.write(
      `data: ${JSON.stringifyAny({"type": "connected"})->Option.getOr("{}")}\n\n`,
    )
  }
}
