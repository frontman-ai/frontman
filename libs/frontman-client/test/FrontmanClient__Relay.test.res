open Vitest

module Relay = FrontmanClient__Relay

@module("vitest") @scope("vi") external stubGlobal: (string, 'a) => unit = "stubGlobal"
@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"
afterEach(unstubAllGlobals)

testAsync("only replays an authenticated nonce rejection once", async t => {
  for i in 0 to 1 {
    let code = ["frontman_invalid_nonce", "frontman_forbidden"]->Array.get(i)->Option.getOrThrow
    let calls = ref(0)
    let relay = Relay.make(
      ~baseUrl="https://example.test",
      ~requestHeaders=dict{"X-WP-Nonce": "old"},
    )
    relay.state := Relay.Connected({tools: [], serverInfo: {name: "wordpress", version: "5"}})
    stubGlobal("fetch", async (_, _: WebAPI.FetchTypes.requestInit) => {
      calls := calls.contents + 1
      WebAPI.Response.fromString(
        `{"code":"${code}","error":"Rejected"}`,
        ~init={
          status: 403,
          headers: WebAPI.HeadersInit.fromDict(dict{"X-WP-Nonce": "fresh"}),
        },
      )
    })
    let result = await relay->Relay.executeTool(~name="wp_update_block")
    t->expect(result)->Expect.toEqual(Error(`HTTP 403 [${code}]: Rejected`))
    t->expect(calls.contents)->Expect.toBe([2, 1]->Array.get(i)->Option.getOrThrow)
  }
})

describe("Relay.connect", _t => {
  test("accepts only the current relay protocol version", t => {
    let json = JSON.parseOrThrow(`{"tools":[],"serverInfo":{"name":"test","version":"1"},"protocolVersion":"1.0"}`)
    t
    ->expect(() => json->S.parseOrThrow(~to=FrontmanClient__Relay__Types.toolsResponseSchema))
    ->Expect.toThrow
  })

  test("normalizes WordPress relay v1 responses", t => {
    let json = JSON.parseOrThrow(`{
      "tools":[{
        "name":"wp_list_posts",
        "description":"List posts",
        "access":"read",
        "inputSchema":{"type":"object"},
        "visibleToAgent":true
      }],
      "serverInfo":{"name":"frontman-wordpress","version":"4.0.0"},
      "protocolVersion":"1.0"
    }`)
    let response = json->Relay.parseToolsResponse->Result.getOrThrow

    t->expect(response.protocolVersion)->Expect.toBe("2.0")
    t
    ->expect(response.tools->Array.get(0)->Option.map(json => JSON.stringify(json)))
    ->Expect.toEqual(
      Some(
        JSON.stringify(
          JSON.parseOrThrow(`{
            "name":"wp_list_posts",
            "description":"List posts",
            "inputSchema":{"type":"object"},
            "_meta":{"ai.frontman/tool-metadata":{"access":"read","visibleToAgent":true}}
          }`),
        ),
      ),
    )
  })

  test("requires relay v2 tool metadata shape", t => {
    let legacy = JSON.parseOrThrow(`{
      "tools":[{"name":"hidden","inputSchema":{"type":"object"},"access":"read","visibleToAgent":false}],
      "serverInfo":{"name":"test","version":"1"},
      "protocolVersion":"2.0"
    }`)
    let current = JSON.parseOrThrow(`{
      "tools":[{"name":"hidden","inputSchema":{"type":"object"},"_meta":{"ai.frontman/tool-metadata":{"access":"read","visibleToAgent":false}}}],
      "serverInfo":{"name":"test","version":"1"},
      "protocolVersion":"2.0"
    }`)

    t
    ->expect(() => legacy->S.parseOrThrow(~to=FrontmanClient__Relay__Types.toolsResponseSchema))
    ->Expect.toThrow
    current->S.parseOrThrow(~to=FrontmanClient__Relay__Types.toolsResponseSchema)->ignore
  })
})

test("preserves relayed MCP tool metadata and parses legacy results", t => {
  let relay = Relay.make(~baseUrl="http://localhost")
  let tool = JSON.parseOrThrow(`{
    "name":"tool",
    "title":"Tool",
    "description":"tool",
    "icons":[{"src":"data:image/png;base64,AA==","theme":"light"}],
    "inputSchema":{"type":"object"},
    "outputSchema":{"type":"object"},
    "annotations":{"title":"Tool annotation","readOnlyHint":true},
    "_meta":{"ai.frontman/tool-metadata":{"visibleToAgent":true,"access":"read"},"vendor/example":{"x":1}}
  }`)
  relay.state :=
    Relay.Connected({
      tools: [tool],
      serverInfo: {name: "test", version: "1"},
    })

  t
  ->expect(relay->Relay.getToolsJson->Array.get(0)->Option.map(json => JSON.stringify(json)))
  ->Expect.toEqual(Some(JSON.stringify(tool)))
  t->expect(relay->Relay.hasTool("tool"))->Expect.toBe(true)
  JSON.parseOrThrow(`{"content":[]}`)
  ->S.parseOrThrow(~to=FrontmanClient__MCP__Types.callToolResultSchema)
  ->ignore
})
