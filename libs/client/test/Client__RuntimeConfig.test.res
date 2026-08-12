open Vitest

let _setRuntime: JSON.t => unit = %raw(`function(value) { window.__frontmanRuntime = value }`)
let _clearRuntime: unit => unit = %raw(`function() { delete window.__frontmanRuntime }`)

afterEach(() => {
  _clearRuntime()
})

describe("Client__RuntimeConfig", _t => {
  test("read works without wpNonce for non-WordPress integrations", t => {
    _setRuntime(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("nextjs")),
          ("basePath", JSON.Encode.string("frontman")),
          ("projectRoot", JSON.Encode.string("/test/project")),
        ]),
      ),
    )

    let config = Client__RuntimeConfig.read()

    t->expect(config.framework)->Expect.toBe(Client__RuntimeConfig.Nextjs)
    t->expect(config.basePath)->Expect.toBe("frontman")
    t->expect(config.routePrefix)->Expect.toBe("")
    t->expect(config.wpNonce)->Expect.toBe(None)
    t->expect(config.projectRoot)->Expect.toBe(Some("/test/project"))
    t->expect(config.traits)->Expect.toBe(None)
  })

  test("read forwards runtime traits to ACP metadata", t => {
    _setRuntime(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("nextjs")),
          (
            "traits",
            [JSON.Encode.string("react"), JSON.Encode.string("typescript")]->JSON.Encode.array,
          ),
        ]),
      ),
    )

    let config = Client__RuntimeConfig.read()

    t->expect(config.traits)->Expect.toEqual(Some(["react", "typescript"]))

    t
    ->expect(Client__RuntimeConfig.toMeta(config))
    ->Expect.toEqual(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("nextjs")),
          (
            "traits",
            [JSON.Encode.string("react"), JSON.Encode.string("typescript")]->JSON.Encode.array,
          ),
        ]),
      ),
    )
  })

  test("read preserves wpNonce for WordPress integrations", t => {
    _setRuntime(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("wordpress")),
          ("basePath", JSON.Encode.string("frontman")),
          ("routePrefix", JSON.Encode.string("/index.php")),
          ("wpNonce", JSON.Encode.string("nonce-123")),
        ]),
      ),
    )

    let config = Client__RuntimeConfig.read()

    t->expect(config.framework)->Expect.toBe(Client__RuntimeConfig.Wordpress)
    t->expect(config.routePrefix)->Expect.toBe("/index.php")
    t->expect(config.wpNonce)->Expect.toBe(Some("nonce-123"))
  })

  test("toMeta does not leak wpNonce into ACP metadata", t => {
    let meta = Client__RuntimeConfig.toMeta({
      framework: Client__RuntimeConfig.Wordpress,
      basePath: "frontman",
      routePrefix: "/index.php",
      wpNonce: Some("nonce-123"),
      projectRoot: None,
      traits: None,
    })

    t
    ->expect(meta)
    ->Expect.toEqual(
      JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("wordpress"))])),
    )
  })

  test("toMeta excludes provider keys", t => {
    _setRuntime(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("nextjs")),
          ("basePath", JSON.Encode.string("frontman")),
          ("fireworksKeyValue", JSON.Encode.string("fw-test-123")),
          ("nvidiaKeyValue", JSON.Encode.string("nvapi-test-123")),
        ]),
      ),
    )

    let meta = Client__RuntimeConfig.read()->Client__RuntimeConfig.toMeta

    t
    ->expect(meta)
    ->Expect.toEqual(
      JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("nextjs"))])),
    )
  })
})
