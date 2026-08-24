open Vitest

module MCP = FrontmanProtocol__MCP

@val
external infinity: float = "Infinity"

let parses = (schema, json) => {
  try {
    json->JSON.parseOrThrow->S.parseOrThrow(~to=schema)->ignore
    true
  } catch {
  | _ => false
  }
}

describe("MCP wire contracts", () => {
  test("accepts broad discovery results", t => {
    let json = `{
      "resultType":"complete",
      "supportedVersions":["2026-07-28","2027-01-01"],
      "capabilities":{"tools":{},"logging":{}},
      "instructions":"Use tools carefully",
      "ttlMs":0.5,
      "cacheScope":"public"
    }`

    t->expect(parses(MCP.discoverResultWireSchema, json))->Expect.toBe(true)
  })

  test("accepts broad tools/list results", t => {
    let json = `{
      "resultType":"complete",
      "tools":[{"name":"search","inputSchema":{"type":"object"},"title":"Search"}],
      "nextCursor":"opaque",
      "ttlMs":1.5,
      "cacheScope":"public"
    }`

    t->expect(parses(MCP.toolsListResultWireSchema, json))->Expect.toBe(true)
  })

  test("requires finite nonnegative ttlMs", t => {
    t->expect(JSON.Encode.float(0.5)->S.parseOrThrow(~to=MCP.ttlMsSchema))->Expect.toBe(0.5)
    t->expect(() => JSON.Encode.float(-0.5)->S.parseOrThrow(~to=MCP.ttlMsSchema))->Expect.toThrow
    t
    ->expect(() => JSON.Encode.float(infinity)->S.parseOrThrow(~to=MCP.ttlMsSchema))
    ->Expect.toThrow
  })
})
