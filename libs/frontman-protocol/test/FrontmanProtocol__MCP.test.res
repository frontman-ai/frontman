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

let parseJson = (schema, json) => json->JSON.parseOrThrow->S.parseOrThrow(~to=schema)
let typedRoundTrip = (schema, json) =>
  json
  ->JSON.parseOrThrow
  ->S.parseOrThrow(~to=schema)
  ->S.decodeOrThrow(~from=schema, ~to=S.json->S.noValidation(true))

describe("MCP wire contracts", () => {
  test("round-trips discovery implementation metadata", t => {
    let json = `{
      "resultType":"complete",
      "supportedVersions":["2026-07-28","2027-01-01"],
      "capabilities":{"tools":{},"logging":{}},
      "instructions":"Use tools carefully",
      "ttlMs":1,
      "cacheScope":"public",
      "_meta":{
        "io.modelcontextprotocol/serverInfo":{
          "name":"server",
          "title":"Server",
          "version":"1.0.0",
          "description":"A test MCP server"
        }
      }
    }`

    t
    ->expect(parseJson(MCP.discoverResultWireSchema, json))
    ->Expect.toEqual(JSON.parseOrThrow(json))
  })

  test("round-trips official tool metadata and rejects malformed known fields", t => {
    let json = `{
      "resultType":"complete",
      "tools":[{
        "name":"search",
        "title":"Search",
        "description":"Search files",
        "icons":[{"src":"data:image/png;base64,AA==","mimeType":"image/png","sizes":["48x48"],"theme":"dark"}],
        "inputSchema":{"type":"object","properties":{"q":{"type":"string","title":"Query"}}},
        "outputSchema":{"type":"object","properties":{"matches":{"type":"array"}}},
        "annotations":{
          "title":"Search files",
          "readOnlyHint":true,
          "destructiveHint":false,
          "idempotentHint":true,
          "openWorldHint":false
        },
        "_meta":{"ai.frontman/tool-metadata":{"visibleToAgent":true,"access":"read"}}
      }],
      "nextCursor":"opaque",
      "ttlMs":2,
      "cacheScope":"public"
    }`

    let invalid = [
      `{"resultType":"complete","tools":[{"name":"search","inputSchema":{"type":"object"},"title":123}],"ttlMs":2,"cacheScope":"public"}`,
      `{"resultType":"complete","tools":[{"name":"search","inputSchema":{"type":"object"},"icons":[{"src":"x","theme":"system"}]}],"ttlMs":2,"cacheScope":"public"}`,
      `{"resultType":"complete","tools":[{"name":"search","inputSchema":{"type":"object"},"annotations":{"readOnlyHint":"yes"}}],"ttlMs":2,"cacheScope":"public"}`,
      `{"resultType":"complete","tools":[{"name":"search","inputSchema":{"type":"object"},"_meta":{"ai.frontman/tool-metadata":{"executionMode":"invalid"}}}],"ttlMs":2,"cacheScope":"public"}`,
    ]

    t
    ->expect(parseJson(MCP.toolsListResultWireSchema, json))
    ->Expect.toEqual(JSON.parseOrThrow(json))
    invalid->Array.forEach(
      json => t->expect(parses(MCP.toolsListResultWireSchema, json))->Expect.toBe(false),
    )
  })

  test("preserves input schema composition, references, dialect and extension keywords", t => {
    let inputs = [
      `{"type":"object","allOf":[{"properties":{"q":{"type":"string"}}},{"required":["q"]}]}`,
      `{"type":"object","$defs":{"query":{"type":"string"}},"properties":{"q":{"$ref":"#/$defs/query"}}}`,
      `{"type":"object","$schema":"https://json-schema.org/draft/2020-12/schema","unevaluatedProperties":false}`,
      `{"type":"object","x-frontman":{"nested":[0,false,null]}}`,
    ]
    let roundTrips = [
      json => typedRoundTrip(MCP.toolJsonSchema, json),
      json => typedRoundTrip(FrontmanProtocol__Relay.remoteToolSchema, json),
    ]
    inputs->Array.forEach(
      input => {
        let json = `{"name":"search","inputSchema":${input},"_meta":{"ai.frontman/tool-metadata":{"visibleToAgent":true,"access":"read"}}}`
        roundTrips->Array.forEach(
          roundTrip => t->expect(roundTrip(json))->Expect.toEqual(JSON.parseOrThrow(json)),
        )
      },
    )
  })

  test("requires an explicit object input root in MCP and modern relay", t => {
    let invalid = [
      `{}`,
      `{"allOf":[{"type":"object"}]}`,
      `{"type":"string"}`,
      `{"type":["object","null"]}`,
      `null`,
      `true`,
      `[]`,
      `0`,
      `"object"`,
    ]
    invalid->Array.forEach(
      input => {
        let json = `{"name":"search","inputSchema":${input},"_meta":{"ai.frontman/tool-metadata":{"visibleToAgent":true,"access":"read"}}}`
        t->expect(parses(MCP.toolInputSchema, input))->Expect.toBe(false)
        t->expect(parses(MCP.toolJsonSchema, json))->Expect.toBe(false)
        t->expect(parses(FrontmanProtocol__Relay.remoteToolSchema, json))->Expect.toBe(false)
      },
    )
  })

  test("preserves object output schema documents describing arbitrary JSON values", t => {
    let valid = [
      `{}`,
      `{"type":"object"}`,
      `{"type":"array","items":{"type":"string"}}`,
      `{"type":"string"}`,
      `{"type":"number"}`,
      `{"type":"boolean"}`,
      `{"type":"null"}`,
      `{"anyOf":[{"type":"null"},{"type":"string"}],"x-frontman":true}`,
    ]
    let invalid = [`null`, `true`, `[]`, `0`, `"object"`]
    let roundTrips = [
      json => typedRoundTrip(MCP.toolJsonSchema, json),
      json => typedRoundTrip(FrontmanProtocol__Relay.remoteToolSchema, json),
    ]
    roundTrips->Array.forEach(
      roundTrip => {
        valid->Array.forEach(
          output => {
            let json = `{"name":"search","inputSchema":{"type":"object"},"outputSchema":${output},"_meta":{"ai.frontman/tool-metadata":{"visibleToAgent":true,"access":"read"}}}`
            t->expect(roundTrip(json))->Expect.toEqual(JSON.parseOrThrow(json))
          },
        )
        invalid->Array.forEach(
          output => {
            let json = `{"name":"search","inputSchema":{"type":"object"},"outputSchema":${output},"_meta":{"ai.frontman/tool-metadata":{"visibleToAgent":true,"access":"read"}}}`
            t->expect(() => roundTrip(json))->Expect.toThrow
          },
        )
      },
    )
  })

  test("round-trips official content annotations", t => {
    let json = `{
      "resultType":"complete",
      "content":[{
        "type":"text",
        "text":"hello",
        "annotations":{"audience":["user","assistant"],"priority":0.5,"lastModified":"2025-01-12T15:00:58Z","_meta":{"vendor":"annotation"}},
        "_meta":{"trace":"1"}
      },{
        "type":"resource_link",
        "name":"file",
        "title":"File",
        "uri":"file:///tmp/a.txt",
        "description":"A file",
        "mimeType":"text/plain",
        "size":3000000000,
        "annotations":{"audience":["assistant"],"priority":1,"_meta":{"vendor":"resource-annotation"}},
        "_meta":{"trace":"2"}
      }]
    }`
    let invalid = `{"resultType":"complete","content":[{"type":"text","text":"hello","annotations":{"priority":2}}]}`

    t
    ->expect(typedRoundTrip(MCP.callToolResultSchema, json))
    ->Expect.toEqual(JSON.parseOrThrow(json))
    t->expect(parses(MCP.callToolResultSchema, invalid))->Expect.toBe(false)
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
