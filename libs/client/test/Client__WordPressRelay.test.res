open Vitest

module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay

@module("vitest") @scope("vi") external stubGlobal: (string, 'a) => unit = "stubGlobal"
@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"
afterEach(unstubAllGlobals)

testAsync("nonce recovery is bounded and only enabled by the WordPress integration", async t => {
  for i in 0 to 2 {
    let code =
      ["frontman_invalid_nonce", "frontman_forbidden", "frontman_invalid_nonce"]
      ->Array.get(i)
      ->Option.getOrThrow
    let calls = ref(0)
    let baseUrl = "https://example.test"
    let config = switch i {
    | 2 => Relay.makeConfig(~baseUrl, ~requestHeaders=dict{"X-WP-Nonce": "old"})
    | _ => Client__WordPressRelay.makeConfig(~baseUrl, ~nonce=Some("old"))
    }
    stubGlobal("fetch", async (url: string, _: WebAPI.FetchTypes.requestInit) => {
      switch url->String.endsWith("/tools") {
      | true =>
        WebAPI.Response.fromString(`{"tools":[],"serverInfo":{"name":"test","version":"5"},"protocolVersion":"2.0"}`)
      | false =>
        calls := calls.contents + 1
        WebAPI.Response.fromString(
          `{"code":"${code}","error":"Rejected"}`,
          ~init={
            status: 403,
            headers: WebAPI.HeadersInit.fromDict(dict{"X-WP-Nonce": "fresh"}),
          },
        )
      }
    })
    let relay =
      (await Relay.connect(config, ~signal=WebAPI.AbortController.make().signal))->Result.getOrThrow
    let result = await relay->Relay.executeTool(~name="wp_update_block")
    t->expect(result)->Expect.toEqual(Error(`HTTP 403 [${code}]: Rejected`))
    t->expect(calls.contents)->Expect.toBe([2, 1, 1]->Array.get(i)->Option.getOrThrow)
  }
})
