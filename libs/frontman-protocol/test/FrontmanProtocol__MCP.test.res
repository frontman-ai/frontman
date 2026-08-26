open Vitest

module MCP = FrontmanProtocol__MCP

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
      "ttlMs":1,
      "cacheScope":"public"
    }`

    t->expect(parses(MCP.discoverResultWireSchema, json))->Expect.toBe(true)
  })

  test("accepts broad tools/list results", t => {
    let json = `{
      "resultType":"complete",
      "tools":[{"name":"search","inputSchema":{"type":"object"},"title":"Search"}],
      "nextCursor":"opaque",
      "ttlMs":2,
      "cacheScope":"public"
    }`
    let invalid = `{"resultType":"complete","tools":[{"name":"search","inputSchema":{"type":"object"},"_meta":{"ai.frontman/tool-metadata":{"executionMode":"invalid"}}}],"ttlMs":2,"cacheScope":"public"}`

    t->expect(parses(MCP.toolsListResultWireSchema, json))->Expect.toBe(true)
    t->expect(parses(MCP.toolsListResultWireSchema, invalid))->Expect.toBe(false)
  })

  test("requires finite nonnegative ttlMs", t => {
    t->expect(JSON.Encode.int(1)->S.parseOrThrow(~to=MCP.ttlMsSchema))->Expect.toBe(1)
    t->expect(() => JSON.Encode.float(0.5)->S.parseOrThrow(~to=MCP.ttlMsSchema))->Expect.toThrow
    t->expect(() => JSON.Encode.int(-1)->S.parseOrThrow(~to=MCP.ttlMsSchema))->Expect.toThrow
  })

  test("requires extension settings to be objects", t => {
    let valid = `{
      "_meta":{
        "io.modelcontextprotocol/protocolVersion":"2026-07-28",
        "io.modelcontextprotocol/clientCapabilities":{
          "extensions":{"ai.frontman/execution-context":{"version":1}}
        }
      }
    }`
    let invalid = valid->String.replace(`{"version":1}`, `true`)

    t->expect(parses(MCP.discoverParamsSchema, valid))->Expect.toBe(true)
    t->expect(parses(MCP.discoverParamsSchema, invalid))->Expect.toBe(false)
  })
})
