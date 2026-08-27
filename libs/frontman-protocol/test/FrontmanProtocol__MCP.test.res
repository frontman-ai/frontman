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

    let longLived = `{
      "resultType":"complete",
      "supportedVersions":["2026-07-28"],
      "capabilities":{},
      "ttlMs":2592000000,
      "cacheScope":"public"
    }`

    t->expect(parses(MCP.discoverResultWireSchema, longLived))->Expect.toBe(true)
  })

  test("requires valid extension identifiers and object settings", t => {
    let valid = ["a/", "ai.frontman/execution-context", "com.example-1/name_1.part-2"]
    let invalid = [
      "execution-context",
      "1.example/name",
      "com.-example/name",
      "com.example-/name",
      "com.example/_name",
      "com.example/name_",
      "com.example/name/extra",
    ]

    valid->Array.forEach(
      key => t->expect(parses(MCP.extensionsSchema, `{"${key}":{}}`))->Expect.toBe(true),
    )
    invalid->Array.forEach(
      key => t->expect(parses(MCP.extensionsSchema, `{"${key}":{}}`))->Expect.toBe(false),
    )
    t
    ->expect(parses(MCP.extensionsSchema, `{"ai.frontman/execution-context":true}`))
    ->Expect.toBe(false)
  })
})
