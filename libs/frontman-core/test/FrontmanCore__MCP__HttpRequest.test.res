open Vitest

module Protocol = FrontmanAiFrontmanProtocol
module JsonRpc = Protocol.FrontmanProtocol__JsonRpc
module MCP = Protocol.FrontmanProtocol__MCP
module HttpRequest = FrontmanCore__MCP__HttpRequest
module RequestBody = FrontmanCore__MCP__RequestBody
module BodyReader = FrontmanCore__MCP__BodyReader
module BodyDecoder = FrontmanCore__MCP__BodyDecoder
module DecodedRequest = FrontmanCore__MCP__DecodedRequest
module MethodRequest = FrontmanCore__MCP__MethodRequest
module ToolRegistry = FrontmanCore__ToolRegistry
module Tool = Protocol.FrontmanProtocol__Tool
module RawHeaders = FrontmanCore__MCP__RawHeaders
module HttpSecurity = FrontmanCore__MCP__HttpSecurity

let executionCount = ref(0)

module NoExecutionTool = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "no_execution_tool",
    "Proves pre-decode failures cannot execute",
    Tool.Read,
    true,
    None,
  )

  @schema
  type input = {value?: string}

  let execute = async (_context, _input) => {
    executionCount.contents = executionCount.contents + 1
    MCP.CallToolResult.makeText("unexpected execution")
  }
}

type annotatedProperty = {
  @as("type") type_: string,
  @as("x-mcp-header") header: string,
}

external annotatedPropertyAsSchema: annotatedProperty => JSONSchema.t = "%identity"

module PhysicalHeaderTool = {
  let (name, description, access, visibleToAgent, outputJsonSchema) = (
    "physical_header_tool",
    "Proves physical custom header validation",
    Tool.Read,
    true,
    None,
  )

  @schema
  type payload = {value: string}

  type input = payload

  let inputSchema = payloadSchema->S.extendJSONSchema({
    properties: Dict.fromArray([
      ("value", JSONSchema.Schema(annotatedPropertyAsSchema({type_: "string", header: "Value"}))),
    ]),
  })

  let execute = async (_context, _input) => {
    executionCount.contents = executionCount.contents + 1
    MCP.CallToolResult.makeText("unexpected execution")
  }
}

module Helpers = {
  let allowedOrigin = "https://client.example"

  let validMedia = [
    ("Content-Type", "application/json"),
    ("Accept", "application/json, text/event-stream"),
  ]

  let request = (~body=?, ~headers=validMedia, ~origin=Some(allowedOrigin)) => {
    let headers = switch origin {
    | Some(origin) => [...headers, ("Origin", origin)]
    | None => headers
    }
    let headers = WebAPI.HeadersInit.fromKeyValueArray(headers)
    switch body {
    | Some(body) =>
      WebAPI.Request.fromURL(
        "http://localhost/mcp",
        ~init={method: "POST", headers, body: WebAPI.BodyInit.fromString(body)},
      )
    | None => WebAPI.Request.fromURL("http://localhost/mcp", ~init={method: "POST", headers})
    }
  }

  let security = HttpSecurity.make(~allowedOrigins=[allowedOrigin], ~authorize=async _headers =>
    HttpSecurity.Authorized
  )

  let responseFields = async response => {
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
  }
}

describe("MCP route-independent HTTP request boundary", _t => {
  testAsync("orders Origin and authorization before media and body processing", async t => {
    executionCount.contents = 0
    let authorizationCount = ref(0)
    let invalidRequest = Helpers.request(
      ~origin=Some("https://evil.example"),
      ~body=`{"not":"read"}`,
      ~headers=[
        ("Content-Type", "text/plain"),
        ("Accept", "text/plain"),
        ("Content-Length", Int.toString(BodyDecoder.maxBodyBytes + 1)),
      ],
    )
    let security = HttpSecurity.make(
      ~allowedOrigins=[Helpers.allowedOrigin],
      ~authorize=async _headers => {
        authorizationCount.contents = authorizationCount.contents + 1
        HttpSecurity.Authorized
      },
    )
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(NoExecutionTool)])

    switch await HttpRequest.validate(~request=invalidRequest, ~security, ~registry) {
    | HttpRequest.Accepted(_) | HttpRequest.Completed(_) => failwith("Expected Origin rejection")
    | HttpRequest.Rejected(response) =>
      t->expect(response.status)->Expect.toBe(403)
      t->expect(await response->WebAPI.Response.text)->Expect.toBe("")
      t->expect(invalidRequest.bodyUsed)->Expect.toBe(false)
      t->expect(authorizationCount.contents)->Expect.toBe(0)
      t->expect(executionCount.contents)->Expect.toBe(0)
      t
      ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin"))
      ->Expect.toEqual(Null.Null)
    }

    let unauthorizedRequest = Helpers.request(
      ~body=`{"not":"read"}`,
      ~headers=[
        ("Content-Type", "text/plain"),
        ("Accept", "text/plain"),
        ("Content-Length", Int.toString(BodyDecoder.maxBodyBytes + 1)),
      ],
    )
    let security = HttpSecurity.make(
      ~allowedOrigins=[Helpers.allowedOrigin],
      ~authorize=async _headers => {
        authorizationCount.contents = authorizationCount.contents + 1
        HttpSecurity.MissingAuthentication
      },
    )

    switch await HttpRequest.validate(~request=unauthorizedRequest, ~security, ~registry) {
    | HttpRequest.Accepted(_) | HttpRequest.Completed(_) =>
      failwith("Expected authentication rejection")
    | HttpRequest.Rejected(response) =>
      t->expect(response.status)->Expect.toBe(401)
      t->expect(await response->WebAPI.Response.text)->Expect.toBe("")
      t->expect(unauthorizedRequest.bodyUsed)->Expect.toBe(false)
      t->expect(authorizationCount.contents)->Expect.toBe(1)
      t->expect(executionCount.contents)->Expect.toBe(0)
      t
      ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin")->Null.toOption)
      ->Expect.toBe(Some(Helpers.allowedOrigin))
      t
      ->expect(response.headers->WebAPI.Headers.get("Vary")->Null.toOption)
      ->Expect.toBe(Some("Origin"))
    }
  })

  testAsync("returns empty media errors before reading the body", async t => {
    let assertMediaError = async (~headers, ~status) => {
      let request = Helpers.request(~body=`{"not":"read"}`, ~headers)
      let result = await HttpRequest.validate(
        ~request,
        ~security=Helpers.security,
        ~registry=ToolRegistry.make(),
      )

      switch result {
      | HttpRequest.Accepted(_) | HttpRequest.Completed(_) => failwith("Expected media rejection")
      | HttpRequest.Rejected(response) =>
        t->expect(response.status)->Expect.toBe(status)
        t->expect(await response->WebAPI.Response.text)->Expect.toBe("")
        t
        ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
        ->Expect.toEqual(Null.Null)
        t
        ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin")->Null.toOption)
        ->Expect.toBe(Some(Helpers.allowedOrigin))
        t
        ->expect(response.headers->WebAPI.Headers.get("Vary")->Null.toOption)
        ->Expect.toBe(Some("Origin"))
        t->expect(request.bodyUsed)->Expect.toBe(false)
      }
    }

    await assertMediaError(
      ~headers=[
        ("Content-Type", "text/plain"),
        ("Accept", "text/plain"),
        ("Content-Length", Int.toString(BodyDecoder.maxBodyBytes + 1)),
      ],
      ~status=415,
    )
    await assertMediaError(
      ~headers=[("Content-Type", "application/json"), ("Accept", "application/json")],
      ~status=406,
    )
  })

  testAsync("maps controlled malformed body categories to ID-less ParseError", async t => {
    let errors = [
      RequestBody.MissingBody,
      RequestBody.ReaderError(BodyReader.InvalidContentLength),
      RequestBody.ReaderError(BodyReader.BodyTooFragmented),
      RequestBody.DecoderError(BodyDecoder.InvalidUtf8),
      RequestBody.DecoderError(BodyDecoder.JsonTooDeep),
      RequestBody.DecoderError(BodyDecoder.InvalidJson),
    ]

    let _ = await errors
    ->Array.map(
      async error => {
        let response = HttpRequest.bodyErrorResponse(error)
        let fields = await Helpers.responseFields(response)
        fields.error
        ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
        ->S.parseOrThrow(~to=MCP.ParseError.schema)
        ->ignore
        t->expect(response.status)->Expect.toBe(400)
        t->expect(fields.id)->Expect.toBeNone
        t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.parseError))
        t->expect(fields.error.message)->Expect.toBe("Parse error: Invalid JSON")
      },
    )
    ->Promise.all
  })

  testAsync("maps body limits and idle timeout to empty transport responses", async t => {
    let assertEmpty = async (~error, ~status) => {
      let response = HttpRequest.bodyErrorResponse(error)
      t->expect(response.status)->Expect.toBe(status)
      t->expect(await response->WebAPI.Response.text)->Expect.toBe("")
      t
      ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
      ->Expect.toEqual(Null.Null)
    }

    await assertEmpty(~error=RequestBody.ReaderError(BodyReader.BodyTooLarge), ~status=413)
    await assertEmpty(~error=RequestBody.DecoderError(BodyDecoder.BodyTooLarge), ~status=413)
    await assertEmpty(~error=RequestBody.ReaderError(BodyReader.BodyTimedOut), ~status=408)
  })

  testAsync("rejects malformed JSON before decoded request validation", async t => {
    executionCount.contents = 0
    let request = Helpers.request(~body=`{"jsonrpc":"2.0"`)
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(NoExecutionTool)])
    let result = await HttpRequest.validate(~request, ~security=Helpers.security, ~registry)

    switch result {
    | HttpRequest.Accepted(_) | HttpRequest.Completed(_) => failwith("Expected parse rejection")
    | HttpRequest.Rejected(response) =>
      let fields = await Helpers.responseFields(response)
      t->expect(response.status)->Expect.toBe(400)
      t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.parseError))
      t->expect(request.bodyUsed)->Expect.toBe(true)
      t->expect(executionCount.contents)->Expect.toBe(0)
      t
      ->expect(response.headers->WebAPI.Headers.get("Access-Control-Allow-Origin")->Null.toOption)
      ->Expect.toBe(Some(Helpers.allowedOrigin))
    }
  })

  testAsync("maps missing bodies and malformed Content-Length before decoding", async t => {
    let assertParseError = async request => {
      let result = await HttpRequest.validate(
        ~request,
        ~security=Helpers.security,
        ~registry=ToolRegistry.make(),
      )
      switch result {
      | HttpRequest.Accepted(_) | HttpRequest.Completed(_) =>
        failwith("Expected pre-decode rejection")
      | HttpRequest.Rejected(response) =>
        let fields = await Helpers.responseFields(response)
        t->expect(response.status)->Expect.toBe(400)
        t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.parseError))
        t->expect(request.bodyUsed)->Expect.toBe(false)
      }
    }

    await assertParseError(Helpers.request())
    await assertParseError(
      Helpers.request(~body=`{}`, ~headers=[...Helpers.validMedia, ("Content-Length", "-1")]),
    )
  })

  testAsync("rejects oversized declared bodies before reader acquisition", async t => {
    let request = Helpers.request(
      ~body=`{}`,
      ~headers=[
        ...Helpers.validMedia,
        ("Content-Length", Int.toString(BodyDecoder.maxBodyBytes + 1)),
      ],
    )
    let result = await HttpRequest.validate(
      ~request,
      ~security=Helpers.security,
      ~registry=ToolRegistry.make(),
    )

    switch result {
    | HttpRequest.Accepted(_) | HttpRequest.Completed(_) => failwith("Expected body-size rejection")
    | HttpRequest.Rejected(response) =>
      t->expect(response.status)->Expect.toBe(413)
      t->expect(await response->WebAPI.Response.text)->Expect.toBe("")
      t->expect(request.bodyUsed)->Expect.toBe(false)
    }
  })

  testAsync("passes decoded JSON roots into envelope validation", async t => {
    let request = Helpers.request(~body=`[]`)
    let result = await HttpRequest.validate(
      ~request,
      ~security=Helpers.security,
      ~registry=ToolRegistry.make(),
    )

    switch result {
    | HttpRequest.Accepted(_) | HttpRequest.Completed(_) =>
      failwith("Expected invalid envelope rejection")
    | HttpRequest.Rejected(response) =>
      let fields = await Helpers.responseFields(response)
      t->expect(response.status)->Expect.toBe(400)
      t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidRequest))
    }
  })

  testAsync("accepts a complete request only after media and body validation", async _t => {
    let body = `{"jsonrpc":"2.0","id":"request-1","method":"server/discover","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{}}}}`
    let request = Helpers.request(
      ~body,
      ~headers=[
        ...Helpers.validMedia,
        ("MCP-Protocol-Version", MCP.protocolVersion),
        ("Mcp-Method", "server/discover"),
      ],
    )
    let result = await HttpRequest.validate(
      ~request,
      ~security=Helpers.security,
      ~registry=ToolRegistry.make(),
    )

    switch result {
    | HttpRequest.Accepted({
        origin: "https://client.example",
        request: {request: MethodRequest.SelectedDiscover(_)},
      }) => ()
    | HttpRequest.Accepted(_) | HttpRequest.Completed(_) | HttpRequest.Rejected(_) =>
      failwith("Expected validated discovery request")
    }
  })

  testAsync("preserves physical custom-header multiplicity through the HTTP boundary", async t => {
    executionCount.contents = 0
    let body = `{"jsonrpc":"2.0","id":"request-1","method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{}},"name":"physical_header_tool","arguments":{"value":"a, b"}}}`
    let headers = [
      ...Helpers.validMedia,
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Method", "tools/call"),
      ("Mcp-Name", "physical_header_tool"),
      ("Mcp-Param-Value", "a, b"),
    ]
    let registry = ToolRegistry.make()->ToolRegistry.addTools([module(PhysicalHeaderTool)])
    let assertResult = async (~rawHeaders, ~accepted) => {
      let request = Helpers.request(~body, ~headers)
      let result = await HttpRequest.validate(
        ~request,
        ~security=Helpers.security,
        ~rawHeaders=Some(rawHeaders),
        ~registry,
      )
      switch (result, accepted) {
      | (HttpRequest.Accepted(_), true) => t->expect(executionCount.contents)->Expect.toBe(0)
      | (HttpRequest.Rejected(response), false) =>
        let fields = await Helpers.responseFields(response)
        t->expect(response.status)->Expect.toBe(400)
        t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.headerMismatch))
        t->expect(fields.error.message)->Expect.toBe("Header mismatch: Mcp-Param-Value")
        t->expect(executionCount.contents)->Expect.toBe(0)
      | (HttpRequest.Accepted(_), false)
      | (HttpRequest.Completed(_), _)
      | (HttpRequest.Rejected(_), true) =>
        failwith("Unexpected physical-header result")
      }
    }

    await assertResult(~rawHeaders=RawHeaders.make(headers), ~accepted=true)
    await assertResult(
      ~rawHeaders=RawHeaders.make([...headers, ("mcp-param-value", "a, b")]),
      ~accepted=false,
    )
  })

  testAsync("crashes when called with an already-consumed body", async t => {
    let request = Helpers.request(~body=`{}`)
    let _ = await request->WebAPI.Request.text
    let crashed = try {
      let _ = await HttpRequest.validate(
        ~request,
        ~security=Helpers.security,
        ~registry=ToolRegistry.make(),
      )
      false
    } catch {
    | Failure(message) =>
      t->expect(message)->Expect.toBe("MCP request body was already consumed")
      true
    | exn => throw(exn)
    }
    t->expect(crashed)->Expect.toBe(true)
  })
})
