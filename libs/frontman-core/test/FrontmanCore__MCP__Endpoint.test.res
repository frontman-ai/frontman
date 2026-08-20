open Vitest

module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module Endpoint = FrontmanCore__MCP__Endpoint
module HttpSecurity = FrontmanCore__MCP__HttpSecurity
module Chassis = FrontmanCore__NodeWebChassis
module RawHeaders = FrontmanCore__MCP__RawHeaders
module Tool = Protocol.FrontmanProtocol__Tool
module JsonRpc = Protocol.FrontmanProtocol__JsonRpc

type callResponse = {
  @live
  jsonrpc: string,
  @live
  id: JsonRpc.Id.t,
  result: MCP.CallToolResult.t,
}

let callResponseSchema = S.object(s => {
  jsonrpc: s.field("jsonrpc", S.literal("2.0")),
  id: s.field("id", JsonRpc.Id.schema),
  result: s.field("result", MCP.CallToolResult.schema),
})

type resultMetadata = {_meta: option<MCP.ResultMeta.t>}

let resultMetadataSchema = S.object(s => {
  _meta: s.field("_meta", S.option(MCP.ResultMeta.schema)),
})

let allowedOrigin = "https://client.example"

let makeConfig = (
  ~authorize,
  ~principal=?,
  ~allowedPreflightHeaders=[],
  ~registry=FrontmanCore__ToolRegistry.make(),
): Endpoint.config => {
  security: HttpSecurity.make(~allowedOrigins=[allowedOrigin], ~authorize, ~principal?),
  registry,
  projectRoot: "/project",
  sourceRoot: "/project",
  serverName: "frontman-test",
  serverVersion: "1.0.0",
  allowedPreflightHeaders,
}

module SignalTool = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "signal_tool",
    "Captures its execution signal",
    Tool.Read,
    true,
    None,
  )

  @schema
  type input = {}

  let receivedSignal = ref(None)
  let execute = async (context: Tool.serverExecutionContext, _input) => {
    receivedSignal := Some(context.signal)
    MCP.CallToolResult.makeText("ok")
  }
}

module RequiredInputTool = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "required_input_tool",
    "Requires one input",
    Tool.Read,
    true,
    None,
  )

  @schema
  type input = {@live value: string}

  let executionCount = ref(0)
  let execute = async (_context, _input) => {
    executionCount := executionCount.contents + 1
    MCP.CallToolResult.makeText("unexpected")
  }
}

module RequestStateInvariantTool = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "request_state_invariant_tool",
    "Probes request-state isolation",
    Tool.Read,
    true,
    None,
  )

  @schema
  type input = {
    value: string,
    requestState?: string,
    inputResponses?: JSON.t,
  }

  type observation = {
    value: string,
    requestState: option<string>,
    inputResponses: option<JSON.t>,
    projectRoot: string,
    sourceRoot: string,
  }

  let observations = ref([])
  let execute = async (context: Tool.serverExecutionContext, input: input) => {
    observations :=
      observations.contents->Array.concat([
        {
          value: input.value,
          requestState: input.requestState,
          inputResponses: input.inputResponses,
          projectRoot: context.projectRoot,
          sourceRoot: context.sourceRoot,
        },
      ])
    MCP.CallToolResult.makeText(input.value)
  }
}

module RequestStateDecoyTool = {
  include RequestStateInvariantTool

  let name = "request_state_decoy_tool"
  let executionCount = ref(0)
  let execute = async (_context, _input) => {
    executionCount := executionCount.contents + 1
    MCP.CallToolResult.makeText("attacker-selected")
  }
}

let headers = entries => WebAPI.Headers.fromKeyValueArray(entries)

let adapted = (~method, ~headers, ~body=?, ~context): Chassis.adaptedRequest<Endpoint.context> => {
  let init: WebAPI.FetchAPI.requestInit = switch body {
  | Some(body) => {
      method,
      headers: headers->WebAPI.HeadersInit.fromHeaders,
      body: WebAPI.BodyInit.fromString(body),
    }
  | None => {method, headers: headers->WebAPI.HeadersInit.fromHeaders}
  }
  let controller = WebAPI.AbortController.make()
  {
    request: WebAPI.Request.fromURL("http://localhost/mcp", ~init),
    rawHeaders: RawHeaders.make([]),
    context,
    signal: controller.signal,
  }
}

describe("active MCP endpoint", _t => {
  test(
    "uses the authorization policy's trusted principal instead of request credential text",
    t => {
      let headers = WebAPI.Headers.fromKeyValueArray([
        ("Cookie", "theme=dark; frontman_mcp_session=credential-1; experiment=random"),
        ("Authorization", "Bearer attacker-controlled"),
      ])
      let policy = HttpSecurity.make(
        ~allowedOrigins=[allowedOrigin],
        ~authorize=async _headers => HttpSecurity.Authorized,
        ~principal=(_headers, _origin) => "configured-browser-session",
      )

      t
      ->expect(HttpSecurity.principal(~headers, ~origin=allowedOrigin, ~policy))
      ->Expect.toEqual(Some("configured-browser-session"))
    },
  )

  testAsync(
    "authorizes once before dispatch and executes a synchronous discovery request",
    async t => {
      let authorizationCount = ref(0)
      let config = makeConfig(
        ~authorize=async _headers => {
          authorizationCount.contents = authorizationCount.contents + 1
          HttpSecurity.Authorized
        },
      )
      let requestHeaders = headers([
        ("Origin", allowedOrigin),
        ("Content-Type", "application/json"),
        ("Accept", "application/json, text/event-stream"),
        ("MCP-Protocol-Version", MCP.protocolVersion),
        ("Mcp-Method", "server/discover"),
      ])
      let context = switch await Endpoint.gate(~config, ~method="POST", ~headers=requestHeaders) {
      | Chassis.Granted(context) => context
      | Chassis.Denied(_) => failwith("Expected the endpoint gate to authorize")
      }
      let body = `{"jsonrpc":"2.0","id":"discover","method":"server/discover","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{}}}}`
      let response =
        (
          await Endpoint.dispatch(
            ~config,
            adapted(~method="POST", ~headers=requestHeaders, ~body, ~context),
          )
        )->Option.getOrThrow

      t->expect(authorizationCount.contents)->Expect.toBe(1)
      t->expect(response.status)->Expect.toBe(200)
      t
      ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin")->Null.toOption)
      ->Expect.toBe(Some(allowedOrigin))
      let json = await response->WebAPI.Response.json
      let parsed = json->S.parseOrThrow(~to=MCP.DiscoverResultResponse.schema)
      let capabilities =
        parsed.result.capabilities->S.parseOrThrow(~to=MCP.ServerCapabilities.knownFieldsSchema)
      t->expect(capabilities.tools)->Expect.toEqual(Some({listChanged: Some(false)}))
      t->expect(capabilities.completions)->Expect.toBeNone
      t->expect(capabilities.logging)->Expect.toBeNone
      t->expect(capabilities.prompts)->Expect.toBeNone
      t->expect(capabilities.resources)->Expect.toBeNone
      t->expect(response.headers->WebAPI.Headers.has("Mcp-Session-Id"))->Expect.toBe(false)
      t->expect(response.headers->WebAPI.Headers.has("Last-Event-ID"))->Expect.toBe(false)
    },
  )

  testAsync("passes the chassis signal through endpoint execution", async t => {
    let registry =
      FrontmanCore__ToolRegistry.make()->FrontmanCore__ToolRegistry.addTools([module(SignalTool)])
    let config = makeConfig(~authorize=async _headers => HttpSecurity.Authorized, ~registry)
    let requestHeaders = headers([
      ("Origin", allowedOrigin),
      ("Content-Type", "application/json"),
      ("Accept", "application/json, text/event-stream"),
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Method", "tools/call"),
      ("Mcp-Name", SignalTool.name),
    ])
    let context = switch await Endpoint.gate(~config, ~method="POST", ~headers=requestHeaders) {
    | Chassis.Granted(context) => context
    | Chassis.Denied(_) => failwith("Expected the endpoint gate to authorize")
    }
    let body = `{"jsonrpc":"2.0","id":"call","method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{}},"name":"${SignalTool.name}","arguments":{}}}`
    let adaptedRequest = adapted(~method="POST", ~headers=requestHeaders, ~body, ~context)

    let _ = await Endpoint.dispatch(~config, adaptedRequest)

    t->expect(SignalTool.receivedSignal.contents == Some(adaptedRequest.signal))->Expect.toBe(true)
  })

  testAsync(
    "keeps structurally valid requestState and inputResponses behavior-invariant",
    async t => {
      RequestStateInvariantTool.observations := []
      RequestStateDecoyTool.executionCount := 0
      let authorizationCount = ref(0)
      let registry =
        FrontmanCore__ToolRegistry.make()->FrontmanCore__ToolRegistry.addTools([
          module(RequestStateInvariantTool),
          module(RequestStateDecoyTool),
        ])
      let config = makeConfig(
        ~authorize=async _headers => {
          authorizationCount := authorizationCount.contents + 1
          HttpSecurity.Authorized
        },
        ~principal=(_headers, _origin) => "trusted-principal",
        ~registry,
      )
      let requestHeaders = headers([
        ("Origin", allowedOrigin),
        ("Content-Type", "application/json"),
        ("Accept", "application/json, text/event-stream"),
        ("MCP-Protocol-Version", MCP.protocolVersion),
        ("Mcp-Method", "tools/call"),
        ("Mcp-Name", RequestStateInvariantTool.name),
      ])
      let dispatch = async (~id, ~continuationFields) => {
        let context = switch await Endpoint.gate(~config, ~method="POST", ~headers=requestHeaders) {
        | Chassis.Granted(context) => context
        | Chassis.Denied(_) => failwith("Expected request-state probe authorization")
        }
        let authorizationContext = switch context {
        | Endpoint.Post({origin, principal}) => (origin, principal)
        | Endpoint.Preflight(_) | Endpoint.Unsupported(_) =>
          failwith("Expected authorized POST context")
        }
        let body = `{"jsonrpc":"2.0","id":"${id}","method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{}},"name":"${RequestStateInvariantTool.name}","arguments":{"value":"trusted-argument"}${continuationFields}}}`
        let response =
          (
            await Endpoint.dispatch(
              ~config,
              adapted(~method="POST", ~headers=requestHeaders, ~body, ~context),
            )
          )->Option.getOrThrow
        let json = await response->WebAPI.Response.json
        let parsed = json->S.parseOrThrow(~to=callResponseSchema)
        let output = parsed.result->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json)
        (authorizationContext, output)
      }

      let (baselineAuthorization, baselineOutput) = await dispatch(
        ~id="baseline",
        ~continuationFields="",
      )
      let (attackerAuthorization, attackerOutput) = await dispatch(
        ~id="attacker",
        ~continuationFields=`,"requestState":"${RequestStateDecoyTool.name}|attacker-argument|/attacker|attacker-principal","inputResponses":{"attacker":{"action":"accept","content":{"name":"${RequestStateDecoyTool.name}","value":"attacker-argument","projectRoot":"/attacker","principal":"attacker-principal"}}}`,
      )
      let observations = RequestStateInvariantTool.observations.contents

      t->expect(authorizationCount.contents)->Expect.toBe(2)
      t
      ->expect(baselineAuthorization)
      ->Expect.toEqual((allowedOrigin, "trusted-principal"))
      t->expect(attackerAuthorization)->Expect.toEqual(baselineAuthorization)
      t->expect(RequestStateDecoyTool.executionCount.contents)->Expect.toBe(0)
      t->expect(observations->Array.length)->Expect.toBe(2)
      observations->Array.forEach(
        observation => {
          t->expect(observation.value)->Expect.toBe("trusted-argument")
          t->expect(observation.requestState)->Expect.toBeNone
          t->expect(observation.inputResponses)->Expect.toBeNone
          t->expect(observation.projectRoot)->Expect.toBe("/project")
          t->expect(observation.sourceRoot)->Expect.toBe("/project")
        },
      )
      t->expect(attackerOutput)->Expect.toEqual(baselineOutput)
      t
      ->expect(attackerOutput->JSON.stringify->String.includes("trusted-argument"))
      ->Expect.toBe(true)
      t
      ->expect(attackerOutput->JSON.stringify->String.includes("attacker-argument"))
      ->Expect.toBe(false)
    },
  )

  testAsync(
    "rate limits the authorization principal before parsing or execution and isolates another principal",
    async t => {
      SignalTool.receivedSignal := None
      let registry =
        FrontmanCore__ToolRegistry.make()->FrontmanCore__ToolRegistry.addTools([module(SignalTool)])
      let config = makeConfig(
        ~authorize=async _headers => HttpSecurity.Authorized,
        ~principal=(headers, _origin) =>
          "authorization:" ++
          headers->WebAPI.Headers.get("Authorization")->Null.toOption->Option.getOrThrow,
        ~registry,
      )
      let nowMs = Date.now()
      for _request in 1 to FrontmanCore__MCP__RateLimiter.requestLimit {
        config.security.limiter
        ->FrontmanCore__MCP__RateLimiter.check(
          ~principal="authorization:Bearer principal-a",
          ~nowMs,
        )
        ->ignore
      }
      let limitedHeaders = headers([
        ("Origin", allowedOrigin),
        ("Authorization", "Bearer principal-a"),
        ("Content-Type", "application/json"),
        ("Accept", "application/json, text/event-stream"),
        ("MCP-Protocol-Version", MCP.protocolVersion),
        ("Mcp-Method", "tools/call"),
        ("Mcp-Name", SignalTool.name),
        ("Mcp-Session-Id", "spoofed-session"),
        ("Last-Event-ID", "spoofed-event"),
      ])
      let limitedContext = switch await Endpoint.gate(
        ~config,
        ~method="POST",
        ~headers=limitedHeaders,
      ) {
      | Chassis.Granted(context) => context
      | Chassis.Denied(_) => failwith("Expected authorized limited principal")
      }
      let limitedResponse =
        (
          await Endpoint.dispatch(
            ~config,
            adapted(
              ~method="POST",
              ~headers=limitedHeaders,
              ~body="not-json",
              ~context=limitedContext,
            ),
          )
        )->Option.getOrThrow

      t->expect(limitedResponse.status)->Expect.toBe(429)
      t
      ->expect(limitedResponse.headers->WebAPI.Headers.get("Retry-After")->Null.toOption)
      ->Expect.toBe(Some("60"))
      t
      ->expect(limitedResponse.headers->WebAPI.Headers.has("Mcp-Session-Id"))
      ->Expect.toBe(false)
      t->expect(limitedResponse.headers->WebAPI.Headers.has("Last-Event-ID"))->Expect.toBe(false)
      t->expect(await limitedResponse->WebAPI.Response.text)->Expect.toBe("")
      t->expect(SignalTool.receivedSignal.contents)->Expect.toBeNone

      let isolatedHeaders = headers([
        ("Origin", allowedOrigin),
        ("Authorization", "Bearer principal-b"),
        ("Content-Type", "application/json"),
        ("Accept", "application/json, text/event-stream"),
        ("MCP-Protocol-Version", MCP.protocolVersion),
        ("Mcp-Method", "tools/call"),
        ("Mcp-Name", SignalTool.name),
      ])
      let isolatedContext = switch await Endpoint.gate(
        ~config,
        ~method="POST",
        ~headers=isolatedHeaders,
      ) {
      | Chassis.Granted(context) => context
      | Chassis.Denied(_) => failwith("Expected isolated principal authorization")
      }
      let body = `{"jsonrpc":"2.0","id":"isolated","method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{},"io.modelcontextprotocol/clientInfo":{"name":"spoofed-server","version":"999"}},"name":"${SignalTool.name}","arguments":{}}}`
      let isolatedResponse =
        (
          await Endpoint.dispatch(
            ~config,
            adapted(~method="POST", ~headers=isolatedHeaders, ~body, ~context=isolatedContext),
          )
        )->Option.getOrThrow
      t->expect(isolatedResponse.status)->Expect.toBe(200)
      t->expect(SignalTool.receivedSignal.contents->Option.isSome)->Expect.toBe(true)
      t
      ->expect(isolatedResponse.headers->WebAPI.Headers.has("Mcp-Session-Id"))
      ->Expect.toBe(false)
      t->expect(isolatedResponse.headers->WebAPI.Headers.has("Last-Event-ID"))->Expect.toBe(false)
      let result = await isolatedResponse->WebAPI.Response.json
      let parsed = result->S.parseOrThrow(~to=callResponseSchema)
      let metadata =
        parsed.result
        ->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=resultMetadataSchema)
        ->(fields => fields._meta)
        ->Option.getOrThrow
      let metadataFields = metadata->S.parseOrThrow(~to=MCP.ResultMeta.knownFieldsSchema)
      let serverInfo = metadataFields.serverInfo->Option.getOrThrow
      t->expect(serverInfo.name)->Expect.toBe("frontman-test")
      t->expect(serverInfo.version)->Expect.toBe("1.0.0")
    },
  )

  testAsync("adds server identity to selected argument errors without execution", async t => {
    RequiredInputTool.executionCount := 0
    let registry =
      FrontmanCore__ToolRegistry.make()->FrontmanCore__ToolRegistry.addTools([
        module(RequiredInputTool),
      ])
    let config = makeConfig(~authorize=async _headers => HttpSecurity.Authorized, ~registry)
    let requestHeaders = headers([
      ("Origin", allowedOrigin),
      ("Content-Type", "application/json"),
      ("Accept", "application/json, text/event-stream"),
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Method", "tools/call"),
      ("Mcp-Name", RequiredInputTool.name),
    ])
    let context = switch await Endpoint.gate(~config, ~method="POST", ~headers=requestHeaders) {
    | Chassis.Granted(context) => context
    | Chassis.Denied(_) => failwith("Expected authorized argument-error request")
    }
    let body = `{"jsonrpc":"2.0","id":"invalid-arguments","method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{}},"name":"${RequiredInputTool.name}","arguments":{}}}`
    let response =
      (
        await Endpoint.dispatch(
          ~config,
          adapted(~method="POST", ~headers=requestHeaders, ~body, ~context),
        )
      )->Option.getOrThrow
    let json = await response->WebAPI.Response.json
    let parsed = json->S.parseOrThrow(~to=callResponseSchema)
    let fields =
      parsed.result->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=resultMetadataSchema)
    let metadata = fields._meta->Option.getOrThrow
    let metadataFields = metadata->S.parseOrThrow(~to=MCP.ResultMeta.knownFieldsSchema)
    let serverInfo = metadataFields.serverInfo->Option.getOrThrow

    t->expect(response.status)->Expect.toBe(200)
    t->expect(RequiredInputTool.executionCount.contents)->Expect.toBe(0)
    t->expect(serverInfo.name)->Expect.toBe("frontman-test")
    t->expect(serverInfo.version)->Expect.toBe("1.0.0")
  })

  testAsync("handles preflight after Origin validation without authentication", async t => {
    let authorizationCount = ref(0)
    let config = makeConfig(
      ~allowedPreflightHeaders=["X-Application-Token"],
      ~authorize=async _headers => {
        authorizationCount.contents = authorizationCount.contents + 1
        HttpSecurity.MissingAuthentication
      },
    )
    let requestHeaders = headers([
      ("Origin", allowedOrigin),
      ("Access-Control-Request-Method", "POST"),
      (
        "Access-Control-Request-Headers",
        "Content-Type, MCP-Protocol-Version, Mcp-Method, Mcp-Param-Region, X-Application-Token",
      ),
    ])
    let context = switch await Endpoint.gate(~config, ~method="OPTIONS", ~headers=requestHeaders) {
    | Chassis.Granted(context) => context
    | Chassis.Denied(_) => failwith("Expected the preflight Origin to be accepted")
    }
    let response =
      (
        await Endpoint.dispatch(
          ~config,
          adapted(~method="OPTIONS", ~headers=requestHeaders, ~context),
        )
      )->Option.getOrThrow

    t->expect(authorizationCount.contents)->Expect.toBe(0)
    t->expect(response.status)->Expect.toBe(204)
    t
    ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Methods")->Null.toOption)
    ->Expect.toBe(Some("POST, OPTIONS"))
    t
    ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Headers")->Null.toOption)
    ->Expect.toBe(
      Some("Content-Type, MCP-Protocol-Version, Mcp-Method, Mcp-Param-Region, X-Application-Token"),
    )
  })

  testAsync("returns authenticated 405 responses for unsupported methods", async t => {
    let config = makeConfig(~authorize=async _headers => HttpSecurity.Authorized)
    let requestHeaders = headers([("Origin", allowedOrigin)])
    let context = switch await Endpoint.gate(~config, ~method="DELETE", ~headers=requestHeaders) {
    | Chassis.Granted(context) => context
    | Chassis.Denied(_) => failwith("Expected the endpoint gate to authorize")
    }
    let response =
      (
        await Endpoint.dispatch(
          ~config,
          adapted(~method="DELETE", ~headers=requestHeaders, ~context),
        )
      )->Option.getOrThrow

    t->expect(response.status)->Expect.toBe(405)
    t
    ->expect(response.headers->WebAPI.Headers.get("Allow")->Null.toOption)
    ->Expect.toBe(Some("POST, OPTIONS"))
    t->expect(await response->WebAPI.Response.text)->Expect.toBe("")
  })

  testAsync(
    "does not normalize lowercase methods into POST or unauthenticated preflight",
    async t => {
      let authorizationCount = ref(0)
      let config = makeConfig(
        ~authorize=async _headers => {
          authorizationCount.contents = authorizationCount.contents + 1
          HttpSecurity.Authorized
        },
      )
      let requestHeaders = headers([("Origin", allowedOrigin)])
      let context = switch await Endpoint.gate(
        ~config,
        ~method="options",
        ~headers=requestHeaders,
      ) {
      | Chassis.Granted(context) => context
      | Chassis.Denied(_) => failwith("Expected the lowercase method to complete authorization")
      }
      let response =
        (
          await Endpoint.dispatch(
            ~config,
            adapted(~method="options", ~headers=requestHeaders, ~context),
          )
        )->Option.getOrThrow

      t->expect(authorizationCount.contents)->Expect.toBe(1)
      t->expect(response.status)->Expect.toBe(405)

      let postContext = switch await Endpoint.gate(
        ~config,
        ~method="post",
        ~headers=requestHeaders,
      ) {
      | Chassis.Granted(context) => context
      | Chassis.Denied(_) => failwith("Expected the lowercase method to complete authorization")
      }
      let postResponse =
        (
          await Endpoint.dispatch(
            ~config,
            adapted(~method="post", ~headers=requestHeaders, ~context=postContext),
          )
        )->Option.getOrThrow
      t->expect(authorizationCount.contents)->Expect.toBe(2)
      t->expect(postResponse.status)->Expect.toBe(405)
    },
  )

  testAsync("varies rejected preflight responses on every preflight authority", async t => {
    let config = makeConfig(~authorize=async _headers => HttpSecurity.Authorized)
    let requestHeaders = headers([
      ("Origin", allowedOrigin),
      ("Access-Control-Request-Method", "GET"),
      ("Access-Control-Request-Headers", "Content-Type"),
    ])
    let context = switch await Endpoint.gate(~config, ~method="OPTIONS", ~headers=requestHeaders) {
    | Chassis.Granted(context) => context
    | Chassis.Denied(_) => failwith("Expected the preflight Origin to be accepted")
    }
    let response =
      (
        await Endpoint.dispatch(
          ~config,
          adapted(~method="OPTIONS", ~headers=requestHeaders, ~context),
        )
      )->Option.getOrThrow

    t->expect(response.status)->Expect.toBe(400)
    t
    ->expect(response.headers->WebAPI.Headers.get("Vary")->Null.toOption)
    ->Expect.toBe(Some("Origin, Access-Control-Request-Method, Access-Control-Request-Headers"))
  })
})
