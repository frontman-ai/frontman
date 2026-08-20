open Vitest

module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP
module RequestHeaders = FrontmanCore__MCP__RequestHeaders

module Helpers = {
  let makeHeaders = entries => WebAPI.Headers.fromKeyValueArray(entries)
  let json = source => source->S.decodeOrThrow(~from=S.jsonString, ~to=S.json)

  let makeRequest = (
    ~protocolVersion=MCP.protocolVersion,
    ~method,
    ~name=None,
  ): RequestHeaders.requestFields => {
    protocolVersion: Some(json(`"${protocolVersion}"`)),
    method,
    name: name->Option.map(name => json(`"${name}"`)),
  }
}

describe("MCP Streamable HTTP request headers", _t => {
  test("accepts matching standard headers without a name", t => {
    let headers = Helpers.makeHeaders([
      ("mcp-protocol-version", MCP.protocolVersion),
      ("MCP-METHOD", "server/discover"),
    ])
    let request = Helpers.makeRequest(~method="server/discover")

    t->expect(RequestHeaders.validate(~headers, ~request))->Expect.toEqual(Ok())
  })

  test("accepts and decodes a matching name", t => {
    let headers = Helpers.makeHeaders([
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Method", "tools/call"),
      ("Mcp-Name", "=?base64?SGVsbG8sIOS4lueVjA==?="),
    ])
    let request = Helpers.makeRequest(~method="tools/call", ~name=Some("Hello, 世界"))

    t->expect(RequestHeaders.validate(~headers, ~request))->Expect.toEqual(Ok())
  })

  test("rejects missing standard headers", t => {
    let request = Helpers.makeRequest(~method="server/discover")
    let versionOnly = Helpers.makeHeaders([("MCP-Protocol-Version", MCP.protocolVersion)])
    let methodOnly = Helpers.makeHeaders([("Mcp-Method", "server/discover")])

    t
    ->expect(RequestHeaders.validate(~headers=versionOnly, ~request))
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Method")))
    t
    ->expect(RequestHeaders.validate(~headers=methodOnly, ~request))
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("MCP-Protocol-Version")))
  })

  test("rejects mismatched standard header values", t => {
    let request = Helpers.makeRequest(~method="server/discover")
    let wrongVersion = Helpers.makeHeaders([
      ("MCP-Protocol-Version", "1900-01-01"),
      ("Mcp-Method", "server/discover"),
    ])
    let wrongMethod = Helpers.makeHeaders([
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Method", "Server/Discover"),
    ])

    t
    ->expect(RequestHeaders.validate(~headers=wrongVersion, ~request))
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("MCP-Protocol-Version")))
    t
    ->expect(RequestHeaders.validate(~headers=wrongMethod, ~request))
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Method")))
  })

  test("rejects missing, malformed, mismatched, and unexpected names", t => {
    let baseHeaders = [("MCP-Protocol-Version", MCP.protocolVersion), ("Mcp-Method", "tools/call")]
    let namedRequest = Helpers.makeRequest(~method="tools/call", ~name=Some("get_weather"))
    let namelessCall = Helpers.makeRequest(~method="tools/call")
    let unnamedRequest = Helpers.makeRequest(~method="server/discover")

    [
      Helpers.makeHeaders(baseHeaders),
      Helpers.makeHeaders([...baseHeaders, ("Mcp-Name", "get_forecast")]),
      Helpers.makeHeaders([...baseHeaders, ("Mcp-Name", "=?base64?AB==?=")]),
    ]->Array.forEach(
      headers =>
        t
        ->expect(RequestHeaders.validate(~headers, ~request=namedRequest))
        ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Name"))),
    )

    t
    ->expect(
      RequestHeaders.validate(~headers=Helpers.makeHeaders(baseHeaders), ~request=namelessCall),
    )
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Name")))

    let unexpectedName = Helpers.makeHeaders([
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Method", "server/discover"),
      ("Mcp-Name", "get_weather"),
    ])
    t
    ->expect(RequestHeaders.validate(~headers=unexpectedName, ~request=unnamedRequest))
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Name")))
  })

  test("classifies a matching unsupported version separately", t => {
    let headers = Helpers.makeHeaders([
      ("MCP-Protocol-Version", "1900-01-01"),
      ("Mcp-Method", "server/discover"),
    ])
    let request = Helpers.makeRequest(~protocolVersion="1900-01-01", ~method="server/discover")

    t
    ->expect(RequestHeaders.validate(~headers, ~request))
    ->Expect.toEqual(
      Error(
        RequestHeaders.UnsupportedProtocolVersion({
          requested: "1900-01-01",
          supported: [MCP.protocolVersion],
        }),
      ),
    )
  })

  test("classifies header mismatch before unsupported protocol version", t => {
    let headers = Helpers.makeHeaders([
      ("MCP-Protocol-Version", "1900-01-01"),
      ("Mcp-Method", "Server/Discover"),
    ])
    let request = Helpers.makeRequest(~protocolVersion="1900-01-01", ~method="server/discover")

    t
    ->expect(RequestHeaders.validate(~headers, ~request))
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Method")))
  })

  test("validates all required headers before comparing values", t => {
    let missingMethod = Helpers.makeHeaders([("MCP-Protocol-Version", "1900-01-01")])
    let missingName = Helpers.makeHeaders([
      ("MCP-Protocol-Version", "1900-01-01"),
      ("Mcp-Method", "tools/call"),
    ])

    t
    ->expect(
      RequestHeaders.validate(
        ~headers=missingMethod,
        ~request=Helpers.makeRequest(~method="server/discover"),
      ),
    )
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Method")))
    t
    ->expect(
      RequestHeaders.validate(
        ~headers=missingName,
        ~request=Helpers.makeRequest(~method="tools/call", ~name=Some("get_weather")),
      ),
    )
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Name")))
  })

  test("classifies type-confused body mirrors after required-header presence", t => {
    let completeHeaders = Helpers.makeHeaders([
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Method", "tools/call"),
      ("Mcp-Name", "get_weather"),
    ])
    let wrongVersion: RequestHeaders.requestFields = {
      protocolVersion: Some(Helpers.json("1")),
      method: "tools/call",
      name: Some(Helpers.json(`"get_weather"`)),
    }
    let wrongName: RequestHeaders.requestFields = {
      protocolVersion: Some(Helpers.json(`"${MCP.protocolVersion}"`)),
      method: "tools/call",
      name: Some(Helpers.json("true")),
    }
    let missingMethod = Helpers.makeHeaders([
      ("MCP-Protocol-Version", MCP.protocolVersion),
      ("Mcp-Name", "get_weather"),
    ])

    t
    ->expect(RequestHeaders.validate(~headers=missingMethod, ~request=wrongVersion))
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Method")))
    t
    ->expect(RequestHeaders.validate(~headers=completeHeaders, ~request=wrongVersion))
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("MCP-Protocol-Version")))
    t
    ->expect(RequestHeaders.validate(~headers=completeHeaders, ~request=wrongName))
    ->Expect.toEqual(Error(RequestHeaders.HeaderMismatch("Mcp-Name")))
  })
})
