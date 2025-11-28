// Request handlers for Frontman endpoints

module Protocol = AskTheLlmFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Relay = Protocol.FrontmanProtocol__Relay
module Tool = Protocol.FrontmanProtocol__Tool
module ToolRegistry = FrontmanNextjs__ToolRegistry
module SSE = FrontmanNextjs__SSE
module WebStreams = AskTheLlmBindings.WebStreams

type config = {
  projectRoot: string,
  serverName: string,
  serverVersion: string,
}

type t = {
  config: config,
  registry: ToolRegistry.t,
}

let make = (~projectRoot: string, ~serverName="frontman-nextjs", ~serverVersion="1.0.0"): t => {
  config: {
    projectRoot,
    serverName,
    serverVersion,
  },
  registry: ToolRegistry.make(),
}

// GET /__frontman/tools
let handleGetTools = (server: t): WebAPI.FetchAPI.response => {
  let response: Relay.toolsResponse = {
    tools: server.registry->ToolRegistry.getToolDefinitions,
    serverInfo: {
      name: server.config.serverName,
      version: server.config.serverVersion,
    },
  }

  let json = response->S.reverseConvertToJsonOrThrow(Relay.toolsResponseSchema)
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "application/json")]))
  WebAPI.Response.jsonR(~data=json, ~init={headers: headers})
}

// Execute tool and return result
let executeToolInternal = async (
  server: t,
  toolModule: module(Tool.ServerTool),
  ~arguments: option<Dict.t<JSON.t>>,
): MCP.callToolResult => {
  module T = unpack(toolModule)

  let ctx: Tool.serverExecutionContext = {
    projectRoot: server.config.projectRoot,
  }

  let inputJson = arguments->Option.getOr(Dict.make())->JSON.Encode.object

  try {
    let input = inputJson->S.parseOrThrow(T.inputSchema)
    let result = await T.execute(ctx, input)

    switch result {
    | Ok(output) =>
      let outputJson = output->S.reverseConvertToJsonOrThrow(T.outputSchema)
      {
        content: [{type_: "text", text: JSON.stringify(outputJson)}],
        isError: None,
      }
    | Error(msg) => {
        content: [{type_: "text", text: msg}],
        isError: Some(true),
      }
    }
  } catch {
  | S.Error(e) => {
      content: [{type_: "text", text: `Invalid input: ${e.message}`}],
      isError: Some(true),
    }
  }
}

// POST /__frontman/tools/call - executes tool with SSE streaming
let handleToolCall = async (server: t, req: WebAPI.FetchAPI.request): WebAPI.FetchAPI.response => {
  let body = await req->WebAPI.Request.json

  let request = try {
    Ok(body->S.parseOrThrow(Relay.toolCallRequestSchema))
  } catch {
  | S.Error(e) => Error(e.message)
  }

  switch request {
  | Error(msg) =>
    let errorResult: MCP.callToolResult = {
      content: [{type_: "text", text: `Invalid request: ${msg}`}],
      isError: Some(true),
    }
    let json = errorResult->S.reverseConvertToJsonOrThrow(MCP.callToolResultSchema)
    WebAPI.Response.jsonR(~data=json, ~init={status: 400})

  | Ok(request) =>
    switch server.registry->ToolRegistry.getToolByName(request.name) {
    | None =>
      let errorResult: MCP.callToolResult = {
        content: [{type_: "text", text: `Tool not found: ${request.name}`}],
        isError: Some(true),
      }
      let json = errorResult->S.reverseConvertToJsonOrThrow(MCP.callToolResultSchema)
      WebAPI.Response.jsonR(~data=json, ~init={status: 404})

    | Some(toolModule) =>
      // Execute tool and stream result via SSE
      let resultPromise = executeToolInternal(
        server,
        toolModule,
        ~arguments=request.arguments,
      )

      let encoder = WebStreams.makeTextEncoder()
      let stream = WebStreams.makeReadableStream({
        start: controller => {
          let _ = resultPromise->Promise.then(result => {
            let eventData = switch result.isError {
            | Some(true) => SSE.errorEvent(result)
            | _ => SSE.resultEvent(result)
            }
            controller->WebStreams.enqueue(encoder->WebStreams.encode(eventData))
            controller->WebStreams.close
            Promise.resolve()
          })
        },
      })

      WebAPI.Response.fromReadableStream(stream, ~init={headers: SSE.headers()})
    }
  }
}
