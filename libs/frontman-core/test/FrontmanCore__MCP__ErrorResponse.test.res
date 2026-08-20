open Vitest

module Protocol = FrontmanAiFrontmanProtocol
module JsonRpc = Protocol.FrontmanProtocol__JsonRpc
module MCP = Protocol.FrontmanProtocol__MCP
module RequestHeaders = FrontmanCore__MCP__RequestHeaders
module ErrorResponse = FrontmanCore__MCP__ErrorResponse

let stringId = value => value->S.decodeOrThrow(~from=S.string, ~to=JsonRpc.Id.schema)

describe("MCP Streamable HTTP validation error responses", _t => {
  testAsync("returns a schema-valid HeaderMismatch response", async t => {
    let response = ErrorResponse.make(
      ~id=JsonRpc.Id.fromInt(7),
      ~error=RequestHeaders.HeaderMismatch("Mcp-Method"),
    )

    t->expect(response.status)->Expect.toBe(400)
    t
    ->expect(response.headers->WebAPI.Headers.get("Content-Type"))
    ->Expect.toEqual(Null.Value("application/json"))

    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=MCP.HeaderMismatchError.schema)->ignore
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
    let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
    t->expect(fields.id->Option.flatMap(JsonRpc.Id.toInt))->Expect.toEqual(Some(7))
    t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.headerMismatch))
    t->expect(fields.error.message)->Expect.toBe("Header mismatch: Mcp-Method")
    t->expect(fields.error.data)->Expect.toEqual(None)
  })

  testAsync("returns a schema-valid UnsupportedProtocolVersion response", async t => {
    let response = ErrorResponse.make(
      ~id=stringId("request-1"),
      ~error=RequestHeaders.UnsupportedProtocolVersion({
        requested: "1900-01-01",
        supported: [MCP.protocolVersion],
      }),
    )

    t->expect(response.status)->Expect.toBe(400)
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=MCP.UnsupportedProtocolVersionError.schema)->ignore
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
    let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
    let id = fields.id->Option.getOrThrow
    let data =
      fields.error.data
      ->Option.getOrThrow
      ->S.parseOrThrow(~to=ErrorResponse.unsupportedVersionDataSchema)

    t->expect(id->S.decodeOrThrow(~from=JsonRpc.Id.schema, ~to=S.string))->Expect.toBe("request-1")
    t
    ->expect(fields.error.code)
    ->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.unsupportedProtocolVersion))
    t->expect(fields.error.message)->Expect.toBe("Unsupported protocol version")
    t->expect(data.requested)->Expect.toBe("1900-01-01")
    t->expect(data.supported)->Expect.toEqual([MCP.protocolVersion])
  })

  testAsync(
    "returns schema-valid InvalidRequest responses with readable or omitted IDs",
    async t => {
      let assertResponse = async id => {
        let response = ErrorResponse.invalidRequest(~id)

        t->expect(response.status)->Expect.toBe(400)
        let body = await response->WebAPI.Response.json
        body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
        let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
        fields.error
        ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
        ->S.parseOrThrow(~to=MCP.InvalidRequestError.schema)
        ->ignore
        t->expect(fields.id)->Expect.toEqual(id)
        t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidRequest))
        t->expect(fields.error.message)->Expect.toBe("Invalid Request")
        t->expect(fields.error.data)->Expect.toBeNone
      }

      await assertResponse(Some(stringId("request-2")))
      await assertResponse(None)
    },
  )

  testAsync("returns a schema-valid ID-less ParseError response", async t => {
    let response = ErrorResponse.parseError()

    t->expect(response.status)->Expect.toBe(400)
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
    let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
    fields.error
    ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
    ->S.parseOrThrow(~to=MCP.ParseError.schema)
    ->ignore
    t->expect(fields.id)->Expect.toBeNone
    t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.parseError))
    t->expect(fields.error.message)->Expect.toBe("Parse error: Invalid JSON")
    t->expect(fields.error.data)->Expect.toBeNone
  })

  testAsync(
    "returns a schema-valid HTTP InvalidParams response for malformed metadata",
    async t => {
      let response = ErrorResponse.invalidRequestMetadata(~id=stringId("request-3"))

      t->expect(response.status)->Expect.toBe(400)
      let body = await response->WebAPI.Response.json
      body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
      let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
      fields.error
      ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
      ->S.parseOrThrow(~to=MCP.InvalidParamsError.schema)
      ->ignore
      t->expect(fields.id)->Expect.toEqual(Some(stringId("request-3")))
      t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidParams))
      t->expect(fields.error.message)->Expect.toBe("Invalid request metadata")
      t->expect(fields.error.data)->Expect.toBeNone
    },
  )

  testAsync("returns a schema-valid MissingRequiredClientCapability response", async t => {
    let requiredCapabilities = MCP.ExecutionContextExtension.clientCapabilities()
    let response = ErrorResponse.missingRequiredClientCapability(
      ~id=JsonRpc.Id.fromInt(11),
      ~requiredCapabilities,
    )

    t->expect(response.status)->Expect.toBe(400)
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=MCP.MissingRequiredClientCapabilityError.schema)->ignore
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
    let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
    let data =
      fields.error.data
      ->Option.getOrThrow
      ->S.parseOrThrow(~to=MCP.MissingRequiredClientCapabilityError.dataSchema)
    t->expect(fields.id->Option.flatMap(JsonRpc.Id.toInt))->Expect.toEqual(Some(11))
    t
    ->expect(fields.error.code)
    ->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.missingRequiredClientCapability))
    t
    ->expect(data.requiredCapabilities->MCP.ClientCapabilities.toJson)
    ->Expect.toEqual(requiredCapabilities->MCP.ClientCapabilities.toJson)
  })

  testAsync("returns a schema-valid HTTP 200 InvalidParams method response", async t => {
    let response = ErrorResponse.invalidMethodParams(~id=stringId("request-4"))

    t->expect(response.status)->Expect.toBe(200)
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
    let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
    fields.error
    ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
    ->S.parseOrThrow(~to=MCP.InvalidParamsError.schema)
    ->ignore
    t->expect(fields.id)->Expect.toEqual(Some(stringId("request-4")))
    t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidParams))
    t->expect(fields.error.message)->Expect.toBe("Invalid method parameters")
  })

  testAsync("returns the official HTTP 200 InvalidParams unknown-tool response", async t => {
    let response = ErrorResponse.unknownTool(~id=stringId("request-5"), ~name="invalid_tool_name")

    t->expect(response.status)->Expect.toBe(200)
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
    let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
    fields.error
    ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
    ->S.parseOrThrow(~to=MCP.InvalidParamsError.schema)
    ->ignore
    t->expect(fields.id)->Expect.toEqual(Some(stringId("request-5")))
    t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.invalidParams))
    t->expect(fields.error.message)->Expect.toBe("Unknown tool: invalid_tool_name")
    t->expect(fields.error.data)->Expect.toBeNone
  })

  testAsync("returns a schema-valid HTTP 404 MethodNotFound response", async t => {
    let response = ErrorResponse.methodNotFound(~id=JsonRpc.Id.fromInt(12))

    t->expect(response.status)->Expect.toBe(404)
    let body = await response->WebAPI.Response.json
    body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseSchema)->ignore
    let fields = body->S.parseOrThrow(~to=JsonRpc.Wire.errorResponseFieldsSchema)
    fields.error
    ->S.decodeOrThrow(~from=JsonRpc.Wire.errorSchema, ~to=S.json)
    ->S.parseOrThrow(~to=MCP.MethodNotFoundError.schema)
    ->ignore
    t->expect(fields.id->Option.flatMap(JsonRpc.Id.toInt))->Expect.toEqual(Some(12))
    t->expect(fields.error.code)->Expect.toBe(Int.toFloat(MCP.ModernErrorCode.methodNotFound))
    t->expect(fields.error.message)->Expect.toBe("Method not found")
  })
})
