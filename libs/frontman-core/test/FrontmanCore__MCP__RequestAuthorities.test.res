open Vitest

module RequestAuthorities = FrontmanCore__MCP__RequestAuthorities
module RequestEnvelope = FrontmanCore__MCP__RequestEnvelope

module Helpers = {
  let json = source => source->S.decodeOrThrow(~from=S.jsonString, ~to=S.json)
  let extract = source =>
    source
    ->json
    ->RequestEnvelope.classify
    ->Result.getOrThrow
    ->RequestAuthorities.extract
}

describe("MCP Streamable HTTP request body authorities", _t => {
  test("extracts raw protocol, capability, method, and tool-name authorities", t => {
    let authorities = Helpers.extract(`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{"extensions":{"vendor/example":{"version":1}}}},"name":"get_weather","arguments":{}}}`)

    t
    ->expect(authorities.headers.protocolVersion)
    ->Expect.toEqual(Some(Helpers.json(`"2026-07-28"`)))
    t->expect(authorities.headers.method)->Expect.toBe("tools/call")
    t->expect(authorities.headers.name)->Expect.toEqual(Some(Helpers.json(`"get_weather"`)))
    t
    ->expect(authorities.clientCapabilities)
    ->Expect.toEqual(Some(Helpers.json(`{"extensions":{"vendor/example":{"version":1}}}`)))
  })

  test("selects the standard name authority by method", t => {
    [
      (
        `{"jsonrpc":"2.0","id":1,"method":"prompts/get","params":{"name":"prompt","uri":"ignored"}}`,
        Some(Helpers.json(`"prompt"`)),
      ),
      (
        `{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"name":"ignored","uri":"file:///project"}}`,
        Some(Helpers.json(`"file:///project"`)),
      ),
      (
        `{"jsonrpc":"2.0","id":3,"method":"server/discover","params":{"name":"ignored","uri":"ignored"}}`,
        None,
      ),
    ]->Array.forEach(
      ((source, expected)) =>
        t->expect(Helpers.extract(source).headers.name)->Expect.toEqual(expected),
    )
  })

  test("preserves type-confused authorities for ordered validation", t => {
    let authorities = Helpers.extract(`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":1,"io.modelcontextprotocol/clientCapabilities":[]},"name":false}}`)

    t->expect(authorities.headers.protocolVersion)->Expect.toEqual(Some(Helpers.json("1")))
    t->expect(authorities.headers.name)->Expect.toEqual(Some(Helpers.json("false")))
    t->expect(authorities.clientCapabilities)->Expect.toEqual(Some(Helpers.json("[]")))
  })

  test("keeps independently readable authorities when nested objects are malformed", t => {
    let malformedMetadata = Helpers.extract(`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"_meta":true,"name":"get_weather"}}`)
    let malformedParams = Helpers.extract(`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":"invalid"}`)

    t->expect(malformedMetadata.headers.protocolVersion)->Expect.toBeNone
    t
    ->expect(malformedMetadata.headers.name)
    ->Expect.toEqual(Some(Helpers.json(`"get_weather"`)))
    t->expect(malformedMetadata.clientCapabilities)->Expect.toBeNone
    t->expect(malformedParams.headers.protocolVersion)->Expect.toBeNone
    t->expect(malformedParams.headers.name)->Expect.toBeNone
    t->expect(malformedParams.clientCapabilities)->Expect.toBeNone
  })
})
