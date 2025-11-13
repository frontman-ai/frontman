module Dotenv = AskTheLlmBindings.Dotenv
module Agent = AskTheLlmAgent.Agent
module AgentEventBus = AskTheLlmAgent.Agent__EventBus
module DOMElementToComponentSource = AskTheLlmBindings.DOMElementToComponentSource

//TODO(danni) - move all of these to our bindings folder
module NextResponse = {
  type t = WebAPI.FetchAPI.response
  type init = {
    status: int,
    headers?: WebAPI.FetchAPI.headersInit,
    statusText?: string,
  }

  @module("next/server") @scope("NextResponse")
  external json: (Js.t<'a>, ~init: init=?) => t = "json"
  @module("next/server") @scope("NextResponse")
  external next: unit => t = "next"
}

module NextRequest = {
  type t = WebAPI.FetchAPI.request
}

module TextEncoder = {
  type t
  @send external encode: (t, string) => Js.Typed_array.Uint8Array.t = "encode"
  @new external create: string => t = "TextEncoder"

  let encode = s => {
    let encoder = create("utf-8")
    encoder->encode(s)
  }
}

module ReadableStreamController = {
  type t
  @send external enqueue: (t, Js.Typed_array.Uint8Array.t) => unit = "enqueue"
  @send external close: t => unit = "close"
}

module ReadableStream = {
  type underlyingSource<'chunk> = {
    start?: ReadableStreamController.t => unit,
    pull?: ReadableStreamController.t => promise<unit>,
    cancel?: string => promise<unit>,
  }

  @module("stream/web") @new
  external make: underlyingSource<'chunk> => WebAPI.FileAPI.readableStream<'chunk> =
    "ReadableStream"
}

@val external queueMicrotask: (unit => unit) => unit = "queueMicrotask"

let agentInstance = ref(None)

let getOrCreateAgent = async (config: Nextjs__Config.t) => {
  switch agentInstance.contents {
  | Some(agent) => agent
  | None =>
    Js.log("CREATING NEW AGENT")
    let apiKey = Dotenv.getOrThrow("ANTHROPIC_API_KEY")
    let agent = await Agent.make({projectRoot: config.projectRoot, apiKey})
    agentInstance := Some(agent)
    let _shutdown = Agent.initialize(agent)
    agent
  }
}

let ui = (_req, config: Nextjs__Config.t) => {
  let askTheLlmHtml = `
  <!DOCTYPE html>
  <html lang="en" class="${config.theme}">
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Ask the LLM</title>
  </head>
  <body>
      <div id="root"></div>
      <script type="module" src="${config.clientJs}"></script>
  </body>
  </html>
`

  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "text/html")]))
  // Return HTML response
  WebAPI.Response.fromString(
    askTheLlmHtml,
    ~init={
      headers: headers,
    },
  )
}

let resolveSourceLocationFromBody = async (sourceLocation: Nextjs__Types.sourceLocation): option<
  DOMElementToComponentSource.sourceLocation,
> => {
  let sourceLocation: DOMElementToComponentSource.sourceLocation = {
    componentName: sourceLocation.componentName,
    file: sourceLocation.file,
    line: sourceLocation.line,
    column: sourceLocation.column,
  }

  let resolved = await DOMElementToComponentSource.resolveSourceLocationInServer(sourceLocation)
  Some(resolved)
}

let chat = async (req, config) => {
  let body = await req->WebAPI.Request.json
  let chat = body->S.parseJsonOrThrow(Nextjs__Types.chatSchema)

  let resolvedSourceLocation = switch chat.selectedElement {
  | None => None
  | Some({sourceLocation: Some(sourceLocation)}) =>
    await resolveSourceLocationFromBody(sourceLocation)
  | Some({sourceLocation: None}) => None
  }

  switch resolvedSourceLocation {
  | Some(location) => Console.log2("[API] Using resolved source location:", location)
  | None => Console.log("[API] No source location resolved")
  }

  let agent = await getOrCreateAgent(config)

  agent
  ->Agent.sendMessage(
    Agent.TaskMessage.User({
      taskId: chat.taskId,
      content: String(chat.message),
      selectedElementSourceLocation: resolvedSourceLocation,
    }),
  )
  ->ignore

  NextResponse.json(
    {
      "status": "accepted",
      "message": "Message received and processing started",
    },
    ~init={status: 202},
  )
}

let eventToSSEData = (event: AgentEventBus.events): string => {
  let jsonValue = event->S.reverseConvertOrThrow(AgentEventBus.eventsSchema)
  let data = JSON.stringifyAny(jsonValue)->Option.getOr("{}")
  `data: ${data}\n\n`
}

let events = async (_req, config) => {
  Console.log("[SSE] Client connected to events stream")

  let agent = await getOrCreateAgent(config)

  let unsubscribeRef = ref(None)

  let stream = ReadableStream.make({
    start: controller => {
      queueMicrotask(() => {
        let unsubscribe = AskTheLlmAgent.Agent.subscribe(agent, event => {
          try {
            let sseData = eventToSSEData(event)
            let encoded = TextEncoder.encode(sseData)
            controller->ReadableStreamController.enqueue(encoded)
          } catch {
          | _ => Console.error("[SSE] Error encoding/enqueuing event")
          }
        })
        unsubscribeRef := Some(unsubscribe)
      })
    },
    cancel: _reason => {
      Console.log("[SSE] Client disconnected, cleaning up subscription")
      switch unsubscribeRef.contents {
      | Some(unsubscribe) => unsubscribe()
      | None => ()
      }
      Promise.resolve()
    },
  })

  let headers = WebAPI.HeadersInit.fromDict(
    Dict.fromArray([
      ("Content-Type", "text/event-stream"),
      ("Cache-Control", "no-cache, no-transform"),
      ("Connection", "keep-alive"),
    ]),
  )

  WebAPI.Response.fromReadableStream(stream, ~init={headers: headers})
}

let toolResult = async (req, conf) => {
  let body = await req->WebAPI.Request.json
  let result =
    body->S.parseJsonOrThrow(AskTheLlmAgent.Agent__Task__Message__Part.ToolResultPart.schema)

  let agent = await getOrCreateAgent(conf)
  let resolved = Agent.submitClientToolResult(agent, result)

  if resolved {
    NextResponse.json({"success": true}, ~init={status: 200})
  } else {
    NextResponse.json({"error": "No pending execution found"}, ~init={status: 404})
  }
}
let createMiddleware = (conf: Nextjs__Config.t) => {
  let middleware: NextRequest.t => Promise.t<NextResponse.t> = async (req: NextRequest.t) => {
    let method = req.method->String.toLowerCase
    let path =
      WebAPI.URL.parse(~url=req.url).pathname
      ->String.split("/")
      ->Array.filter(p => !String.isEmpty(p))
      ->Array.join("/")
      ->String.toLowerCase

    switch (method, path) {
    | ("get", "ask-the-llm") => ui(req, conf)
    | ("post", "ask-the-llm/chat") => await chat(req, conf)
    | ("get", "ask-the-llm/events") => await events(req, conf)
    | ("post", "ask-the-llm/tool-results") => await toolResult(req, conf)
    | _ => NextResponse.next()
    }
  }
  middleware
}
