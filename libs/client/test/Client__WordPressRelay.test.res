open Vitest

module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay

@module("vitest") @scope("vi") external stubGlobal: (string, 'a) => unit = "stubGlobal"
@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"
afterEach(unstubAllGlobals)

@set external setClone: (WebAPI.Response.t, unit => WebAPI.Response.t) => unit = "clone"
@set external setJson: (WebAPI.Response.t, unit => promise<JSON.t>) => unit = "json"

testAsync("aborting while parsing the cloned 401 suppresses the login callback", async t => {
  let controller = WebAPI.AbortController.make()
  let notifications = ref(0)
  let body = `{"code":"frontman_not_authenticated","error":"Log in"}`
  let response = WebAPI.Response.fromString(body, ~init={status: 401})
  let clone = response->WebAPI.Response.clone
  clone->setJson(async () => {
    controller->WebAPI.AbortController.abort
    JSON.Encode.object(
      dict{
        "code": JSON.Encode.string("frontman_not_authenticated"),
        "error": JSON.Encode.string("Log in"),
      },
    )
  })
  response->setClone(() => clone)
  stubGlobal("fetch", async (_url: string, _init: WebAPI.FetchTypes.requestInit) => response)
  let config = Client__WordPressRelay.makeConfig(
    ~baseUrl="https://example.test",
    ~nonce=None,
    ~onAuthenticationRequired=() => notifications := notifications.contents + 1,
  )
  let actual = await config.fetch(
    "https://example.test/frontman/tools/call",
    {signal: Null.make(controller.signal)},
  )
  t->expect(notifications.contents)->Expect.toBe(0)
  t->expect(actual == response)->Expect.toBe(true)
  t->expect(await actual->WebAPI.Response.text)->Expect.toBe(body)
})

testAsync("only the exact WordPress HTTP 401 signals login and preserves the response", async t => {
  let cases = [
    (401, `{"code":"frontman_not_authenticated","error":"Log in"}`, 1),
    (401, `{"code":"unknown","error":"Other"}`, 0),
    (401, "not JSON", 0),
    (403, `{"code":"frontman_not_authenticated","error":"Forbidden"}`, 0),
    (403, `{"code":"frontman_forbidden","error":"Forbidden"}`, 0),
  ]
  for i in 0 to cases->Array.length - 1 {
    let (status, body, expected) = cases->Array.get(i)->Option.getOrThrow
    let notifications = ref(0)
    let calls = ref(0)
    let response = WebAPI.Response.fromString(body, ~init={status: status})
    stubGlobal("fetch", async (_url: string, _init: WebAPI.FetchTypes.requestInit) => {
      calls := calls.contents + 1
      response
    })
    let config = Client__WordPressRelay.makeConfig(
      ~baseUrl="https://example.test",
      ~nonce=Some("old"),
      ~onAuthenticationRequired=() => notifications := notifications.contents + 1,
    )
    let actual = await config.fetch("https://example.test/frontman/tools/call", {})
    t->expect(actual == response)->Expect.toBe(true)
    t->expect(await actual->WebAPI.Response.text)->Expect.toBe(body)
    t->expect(notifications.contents)->Expect.toBe(expected)
    t->expect(calls.contents)->Expect.toBe(1)
  }
})

testAsync("nonce retry updates headers once and also inspects its HTTP 401", async t => {
  for statusIndex in 0 to 1 {
    let notifications = ref(0)
    let nonces = ref([])
    let body = `{"code":"frontman_not_authenticated","error":"Log in"}`
    let finalResponse = WebAPI.Response.fromString(
      body,
      ~init={status: statusIndex == 0 ? 200 : 401},
    )
    stubGlobal("fetch", async (_url: string, init: WebAPI.FetchTypes.requestInit) => {
      let headers = Client__WordPressRelay.makeHeaders(init.headers)
      nonces :=
        nonces.contents->Array.concat([headers->WebAPI.Headers.get("X-WP-Nonce")->Null.toOption])
      switch nonces.contents->Array.length {
      | 1 =>
        WebAPI.Response.fromString(
          `{"code":"frontman_invalid_nonce","error":"Nonce"}`,
          ~init={status: 403, headers: WebAPI.HeadersInit.fromDict(dict{"X-WP-Nonce": "fresh"})},
        )
      | _ => finalResponse
      }
    })
    let config = Client__WordPressRelay.makeConfig(
      ~baseUrl="https://example.test",
      ~nonce=Some("old"),
      ~onAuthenticationRequired=() => notifications := notifications.contents + 1,
    )
    let actual = await config.fetch("https://example.test/frontman/tools/call", {})
    t->expect(actual == finalResponse)->Expect.toBe(true)
    t->expect(await actual->WebAPI.Response.text)->Expect.toBe(body)
    t->expect(nonces.contents)->Expect.toEqual([Some("old"), Some("fresh")])
    t->expect(notifications.contents)->Expect.toBe(statusIndex)
  }
})

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
