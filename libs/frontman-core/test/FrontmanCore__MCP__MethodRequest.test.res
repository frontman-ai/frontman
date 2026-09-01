open Vitest

module Protocol = FrontmanAiFrontmanProtocol
module MCP = Protocol.FrontmanProtocol__MCP
module RequestEnvelope = FrontmanCore__MCP__RequestEnvelope
module MethodRequest = FrontmanCore__MCP__MethodRequest
module ToolRegistry = FrontmanCore__ToolRegistry

let json = source => source->S.decodeOrThrow(~from=S.jsonString, ~to=S.json)

let metadata = `"_meta":{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{}}`

let envelope = (~method, ~params) => {
  let raw = json(
    `{"jsonrpc":"2.0","id":"request-1","method":"${method}","params":{${metadata}${params}}}`,
  )
  RequestEnvelope.classify(raw)->Result.getOrThrow
}

describe("MCP method request validation", _t => {
  test("parses each initially supported method through its shared schema", t => {
    switch MethodRequest.validate(envelope(~method="server/discover", ~params="")) {
    | Ok(MethodRequest.Discover(params)) =>
      params._meta->S.parseOrThrow(~to=MCP.RequestMeta.schema)->ignore
    | Ok(_) | Error(_) => failwith("Expected discovery request")
    }

    switch MethodRequest.validate(envelope(~method="tools/list", ~params="")) {
    | Ok(MethodRequest.ListTools(params)) => t->expect(params.cursor)->Expect.toBeNone
    | Ok(_) | Error(_) => failwith("Expected list-tools request")
    }

    switch MethodRequest.validate(
      envelope(
        ~method="tools/call",
        ~params=`,"name":"read_file","arguments":{"path":"README.md"}`,
      ),
    ) {
    | Ok(MethodRequest.CallTool(params)) =>
      t->expect(params.name)->Expect.toBe("read_file")
      t->expect(params.arguments->Option.isSome)->Expect.toBe(true)
    | Ok(_) | Error(_) => failwith("Expected call-tool request")
    }
  })

  test("rejects malformed parameters for each supported method", t => {
    let assertInvalid = request => {
      t->expect(MethodRequest.validate(request))->Expect.toEqual(Error(MethodRequest.InvalidParams))
    }

    assertInvalid(envelope(~method="server/discover", ~params=`,"_meta":null`))
    assertInvalid(envelope(~method="tools/list", ~params=`,"cursor":1`))
    assertInvalid(envelope(~method="tools/call", ~params=`,"name":"read_file","arguments":[]`))
  })

  test("rejects every supplied list cursor without interpreting it", t => {
    let assertInvalid = cursor =>
      t
      ->expect(
        MethodRequest.validate(envelope(~method="tools/list", ~params=`,"cursor":${cursor}`)),
      )
      ->Expect.toEqual(Error(MethodRequest.InvalidParams))

    assertInvalid(`""`)
    assertInvalid(`"opaque/continuation=="`)
  })

  test("classifies an unsupported method independently of its parameters", t => {
    let request = envelope(~method="resources/list", ~params=`,"cursor":1`)
    t->expect(MethodRequest.validate(request))->Expect.toEqual(Error(MethodRequest.MethodNotFound))
  })

  test("selects only exact call-tool names while preserving other request variants", t => {
    let registry = ToolRegistry.coreTools()
    let requestMetadata =
      json(
        `{"io.modelcontextprotocol/protocolVersion":"${MCP.protocolVersion}","io.modelcontextprotocol/clientCapabilities":{}}`,
      )->S.parseOrThrow(~to=MCP.RequestMeta.schema)

    switch MethodRequest.select(
      ~registry,
      MethodRequest.Discover({
        _meta: requestMetadata,
      }),
    ) {
    | Ok(MethodRequest.SelectedDiscover(_)) => ()
    | Ok(_) | Error(_) => failwith("Expected selected discovery request")
    }

    switch MethodRequest.select(
      ~registry,
      MethodRequest.ListTools({
        _meta: requestMetadata,
        cursor: None,
      }),
    ) {
    | Ok(MethodRequest.SelectedListTools(_)) => ()
    | Ok(_) | Error(_) => failwith("Expected selected list-tools request")
    }

    let call =
      MethodRequest.validate(
        envelope(~method="tools/call", ~params=`,"name":"read_file","arguments":{"wrong":true}`),
      )->Result.getOrThrow
    switch MethodRequest.select(~registry, call) {
    | Ok(MethodRequest.SelectedCallTool({params, tool})) =>
      module SelectedTool = unpack(tool)
      t->expect(params.name)->Expect.toBe("read_file")
      t->expect(SelectedTool.name)->Expect.toBe("read_file")
    | Ok(_) | Error(_) => failwith("Expected selected call-tool request")
    }

    switch MethodRequest.select(
      ~registry,
      MethodRequest.CallTool({
        _meta: requestMetadata,
        name: "READ_FILE",
        arguments: None,
        inputResponses: None,
        requestState: None,
      }),
    ) {
    | Error(MethodRequest.UnknownTool("READ_FILE")) => ()
    | Ok(_) | Error(_) => failwith("Expected exact-name selection failure")
    }
  })
})
