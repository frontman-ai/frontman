open Vitest

let _setRuntime: JSON.t => unit = %raw(`function(value) { window.__frontmanRuntime = value }`)
let _clearRuntime: unit => unit = %raw(`function() { delete window.__frontmanRuntime }`)

afterEach(() => {
  _clearRuntime()
})

describe("Client__RuntimeConfig", _t => {
  test("file changes are supported by project-backed frameworks", t => {
    t
    ->expect(Client__RuntimeConfig.supportsFileChanges(Client__RuntimeConfig.Nextjs))
    ->Expect.toBe(true)
    t
    ->expect(Client__RuntimeConfig.supportsFileChanges(Client__RuntimeConfig.Vite))
    ->Expect.toBe(true)
    t
    ->expect(Client__RuntimeConfig.supportsFileChanges(Client__RuntimeConfig.Astro))
    ->Expect.toBe(true)
  })

  test("file changes are unsupported by WordPress", t => {
    t
    ->expect(Client__RuntimeConfig.supportsFileChanges(Client__RuntimeConfig.Wordpress))
    ->Expect.toBe(false)
  })

  test("maps frameworks to their update registries", t => {
    let npmTarget = Client__RuntimeConfig.frameworkUpdateTarget(Client__RuntimeConfig.Nextjs)
    let wordpressTarget = Client__RuntimeConfig.frameworkUpdateTarget(
      Client__RuntimeConfig.Wordpress,
    )

    t->expect(npmTarget)->Expect.toEqual(Client__State__Types.NpmPackage("@frontman-ai/nextjs"))
    t
    ->expect(wordpressTarget)
    ->Expect.toEqual(Client__State__Types.WordPressPlugin("frontman-agentic-ai-editor"))
    t
    ->expect(Client__UpdateBanner.updateActionForTarget(npmTarget, ~wordpressPluginsUrl=None))
    ->Expect.toEqual(Client__UpdateBanner.AgentUpdate("@frontman-ai/nextjs"))
    t
    ->expect(
      Client__UpdateBanner.updateActionForTarget(
        wordpressTarget,
        ~wordpressPluginsUrl=Some("https://example.com/wp-admin/plugins.php"),
      ),
    )
    ->Expect.toEqual(
      Client__UpdateBanner.WordPressUpdate("https://example.com/wp-admin/plugins.php"),
    )
  })

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
    t->expect(config.relayBaseUrl)->Expect.toBe(None)
    t->expect(config.wpNonce)->Expect.toBe(None)
    t->expect(config.wordpressPluginsUrl)->Expect.toBe(None)
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

  test("read preserves WordPress runtime values", t => {
    _setRuntime(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("wordpress")),
          ("basePath", JSON.Encode.string("frontman")),
          ("relayBaseUrl", JSON.Encode.string("https://example.com/index.php")),
          ("wpNonce", JSON.Encode.string("nonce-123")),
          ("wordpressPluginsUrl", JSON.Encode.string("https://example.com/wp-admin/plugins.php")),
        ]),
      ),
    )

    let config = Client__RuntimeConfig.read()

    t->expect(config.framework)->Expect.toBe(Client__RuntimeConfig.Wordpress)
    t->expect(config.relayBaseUrl)->Expect.toBe(Some("https://example.com/index.php"))
    t->expect(config.wpNonce)->Expect.toBe(Some("nonce-123"))
    t
    ->expect(config.wordpressPluginsUrl)
    ->Expect.toBe(Some("https://example.com/wp-admin/plugins.php"))
  })

  test("toMeta does not leak wpNonce into ACP metadata", t => {
    let meta = Client__RuntimeConfig.toMeta({
      framework: Client__RuntimeConfig.Wordpress,
      basePath: "frontman",
      relayBaseUrl: Some("https://example.com/index.php"),
      wpNonce: Some("nonce-123"),
      wordpressPluginsUrl: Some("https://example.com/wp-admin/plugins.php"),
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
