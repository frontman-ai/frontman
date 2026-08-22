open Vitest

module MCP = FrontmanProtocol__MCP

describe("MCP 2026-07-28 wire contracts", () => {
  test("accepts official discovery metadata with empty capabilities and no client identity", t => {
    let json = JSON.parseOrThrow(`{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}}`)

    let {_meta} = json->S.parseOrThrow(~to=MCP.discoverParamsSchema)

    t->expect(_meta.clientInfo)->Expect.toEqual(None)
    t->expect(MCP.SupportedRequestMeta.validate(_meta)->Result.isOk)->Expect.toBe(true)
  })

  test("parses unsupported versions before rejecting them semantically", t => {
    let json = JSON.parseOrThrow(`{"_meta":{"io.modelcontextprotocol/protocolVersion":"2025-11-25","io.modelcontextprotocol/clientCapabilities":{}}}`)

    let {_meta} = json->S.parseOrThrow(~to=MCP.discoverParamsSchema)

    switch MCP.SupportedRequestMeta.validate(_meta) {
    | Error(UnsupportedProtocolVersion({requested, supported})) =>
      t->expect(requested)->Expect.toBe("2025-11-25")
      t->expect(supported)->Expect.toEqual(["2026-07-28"])
    | Ok(_) => t->expect("unsupported version")->Expect.toBe("rejected")
    }
  })

  test("accepts open capabilities before applying Frontman tool-call requirements", t => {
    let json = JSON.parseOrThrow(`{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{"extensions":{"io.modelcontextprotocol/ui":{"mimeTypes":["text/html"]}}}},"name":"question"}`)

    let params = json->S.parseOrThrow(~to=MCP.toolCallParamsSchema)

    switch MCP.ValidToolCall.validate(params) {
    | Error(MissingExecutionContextCapability) => t->expect(true)->Expect.toBe(true)
    | Error(ToolCallMetadata(_)) | Error(MissingExecutionContext) | Ok(_) =>
      t->expect("missing capability")->Expect.toBe("reported")
    }
  })
})
