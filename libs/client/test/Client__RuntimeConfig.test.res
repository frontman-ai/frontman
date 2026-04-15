open Vitest

let _setRuntime: JSON.t => unit = %raw(`function(value) { window.__frontmanRuntime = value }`)
let _clearRuntime: unit => unit = %raw(`function() { delete window.__frontmanRuntime }`)

afterEach(_t => {
  _clearRuntime()
})

describe("Client__RuntimeConfig", _t => {
  test("read works without wpNonce for non-WordPress integrations", t => {
    _setRuntime(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("nextjs")),
          ("basePath", JSON.Encode.string("frontman")),
        ]),
      ),
    )

    let config = Client__RuntimeConfig.read()

    t->expect(config.framework)->Expect.toBe(Client__RuntimeConfig.Nextjs)
    t->expect(config.basePath)->Expect.toBe("frontman")
    t->expect(config.wpNonce)->Expect.toBe(None)
  })

  test("read preserves wpNonce for WordPress integrations", t => {
    _setRuntime(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("wordpress")),
          ("basePath", JSON.Encode.string("frontman")),
          ("wpNonce", JSON.Encode.string("nonce-123")),
        ]),
      ),
    )

    let config = Client__RuntimeConfig.read()

    t->expect(config.framework)->Expect.toBe(Client__RuntimeConfig.Wordpress)
    t->expect(config.wpNonce)->Expect.toBe(Some("nonce-123"))
  })

  test("toMeta does not leak wpNonce into ACP metadata", t => {
    let meta = Client__RuntimeConfig.toMeta({
      framework: Client__RuntimeConfig.Wordpress,
      basePath: "frontman",
      wpNonce: Some("nonce-123"),
      openrouterKeyValue: None,
      anthropicKeyValue: None,
      projectRoot: None,
      sourceRoot: None,
    })

    t
    ->expect(meta)
    ->Expect.toEqual(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("wordpress")),
          ("basePath", JSON.Encode.string("frontman")),
        ]),
      ),
    )
  })
})
