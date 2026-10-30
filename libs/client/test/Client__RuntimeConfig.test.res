open Vitest

@module("react-dom/client")
external createRoot: WebAPI.DomTypes.element => ReactDOM.Client.Root.t = "createRoot"
@module("react-dom") external flushSync: (unit => unit) => unit = "flushSync"

let _setRuntime: JSON.t => unit = %raw(`function(value) { window.__frontmanRuntime = value }`)
let _clearRuntime: unit => unit = %raw(`function() { delete window.__frontmanRuntime }`)

afterEach(() => {
  _clearRuntime()
  WebAPI.DomGlobal.document
  ->WebAPI.Document.querySelector("#frontman-runtime-config")
  ->Null.toOption
  ->Option.forEach(WebAPI.Element.remove)
})

let setNativeRuntimeAttribute = (~name, ~value) => {
  let element = WebAPI.DomGlobal.document->WebAPI.Document.createElement("div")
  element->WebAPI.Element.setAttribute(~qualifiedName="id", ~value="frontman-runtime-config")
  element->WebAPI.Element.setAttribute(~qualifiedName=name, ~value)
  WebAPI.DomGlobal.document.body
  ->WebAPI.HTMLElement.appendChild(element->WebAPI.Element.asNode)
  ->ignore
}

let setNativeLoginUrl = loginUrl =>
  setNativeRuntimeAttribute(~name="data-wordpress-login-url", ~value=loginUrl)

let setOldBootstrapRuntime = framework =>
  _setRuntime(
    JSON.Encode.object(
      dict{
        "framework": JSON.Encode.string(framework),
        "basePath": JSON.Encode.string("frontman"),
        "relayBaseUrl": JSON.Encode.string("https://example.test/site/index.php"),
        "wpNonce": JSON.Encode.string("nonce-123"),
        "wordpressPluginsUrl": JSON.Encode.string("https://example.test/site/wp-admin/plugins.php"),
      },
    ),
  )

describe("Client__RuntimeConfig", _t => {
  test("reads the WordPress page-context-v1 capability without adding it to ACP metadata", t => {
    setOldBootstrapRuntime("wordpress")
    setNativeRuntimeAttribute(~name="data-preview-bridge", ~value="page-context-v1")
    let config = Client__RuntimeConfig.read()
    t->expect(config.previewBridge)->Expect.toEqual(Some(Client__RuntimeConfig.PageContextV1))
    t
    ->expect(Client__RuntimeConfig.toMeta(config))
    ->Expect.toEqual(JSON.Encode.object(dict{"framework": JSON.Encode.string("wordpress")}))
  })

  test("WordPress integrations without a marker do not advertise bridge support", t => {
    setOldBootstrapRuntime("wordpress")
    t->expect(Client__RuntimeConfig.read().previewBridge)->Expect.toEqual(None)
    setNativeLoginUrl("https://example.test/wp-login.php")
    t->expect(Client__RuntimeConfig.read().previewBridge)->Expect.toEqual(None)
  })

  ["", "page-context-v2", "unknown"]->Array.forEach(marker =>
    test(
      `ignores unsupported preview bridge marker "${marker}"`,
      t => {
        setOldBootstrapRuntime("wordpress")
        setNativeRuntimeAttribute(~name="data-preview-bridge", ~value=marker)
        t->expect(Client__RuntimeConfig.read().previewBridge)->Expect.toEqual(None)
      },
    )
  )

  test("other frameworks ignore the WordPress preview bridge marker", t => {
    setNativeRuntimeAttribute(~name="data-preview-bridge", ~value="page-context-v1")
    ["nextjs", "vite", "astro"]->Array.forEach(
      framework => {
        setOldBootstrapRuntime(framework)
        t->expect(Client__RuntimeConfig.read().previewBridge)->Expect.toEqual(None)
      },
    )
  })

  test("old WordPress bootstrap obtains the native login URL without leaking metadata", t => {
    let loginUrl = "https://example.test/site/wp-login.php?redirect_to=https%3A%2F%2Fexample.test%2Fsite%2Findex.php%2Ffrontman&reauth=1"
    setOldBootstrapRuntime("wordpress")
    setNativeLoginUrl(loginUrl)
    let config = Client__RuntimeConfig.read()
    t->expect(config.wordpressLoginUrl)->Expect.toBe(Some(loginUrl))
    t->expect(config.wpNonce)->Expect.toBe(Some("nonce-123"))
    let original = StateStore.getState(Client__State__Store.store)
    Client__State.Actions.wordPressAuthenticationRequired(config.wordpressLoginUrl)
    let container = WebAPI.DomGlobal.document->WebAPI.Document.createElement("div")
    let root = createRoot(container)
    flushSync(() => root->ReactDOM.Client.Root.render(<Client__WordPressLoginBanner />))
    let href =
      container
      ->WebAPI.Element.querySelector("a")
      ->Null.toOption
      ->Option.flatMap(element => element->WebAPI.Element.getAttribute("href")->Null.toOption)
    flushSync(() => root->ReactDOM.Client.Root.unmount())
    StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
      Client__State__Store.store,
      original,
    )
    t->expect(href)->Expect.toBe(Some(loginUrl))
    t
    ->expect(Client__RuntimeConfig.toMeta(config))
    ->Expect.toEqual(JSON.Encode.object(dict{"framework": JSON.Encode.string("wordpress")}))
  })

  test("old WordPress bootstrap permits missing native login URL", t => {
    setOldBootstrapRuntime("wordpress")
    t->expect(Client__RuntimeConfig.read().wordpressLoginUrl)->Expect.toBe(None)
    setNativeLoginUrl("")
    t->expect(Client__RuntimeConfig.read().wordpressLoginUrl)->Expect.toBe(None)
  })

  test("other frameworks ignore the native WordPress login URL", t => {
    setNativeLoginUrl("https://example.test/wp-login.php")
    ["nextjs", "vite", "astro"]->Array.forEach(
      framework => {
        setOldBootstrapRuntime(framework)
        t->expect(Client__RuntimeConfig.read().wordpressLoginUrl)->Expect.toBe(None)
      },
    )
  })

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
    ->Expect.toEqual(Client__State__Types.WordPressPlugin)
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
    t->expect(config.wordpressLoginUrl)->Expect.toBe(None)
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

  test("read preserves WordPress runtime values over native DOM values", t => {
    setNativeLoginUrl("https://example.test/ignored/wp-login.php")
    _setRuntime(
      JSON.Encode.object(
        Dict.fromArray([
          ("framework", JSON.Encode.string("wordpress")),
          ("basePath", JSON.Encode.string("frontman")),
          ("relayBaseUrl", JSON.Encode.string("https://example.com/index.php")),
          ("wpNonce", JSON.Encode.string("nonce-123")),
          (
            "wordpressLoginUrl",
            JSON.Encode.string("https://example.com/wp-login.php?redirect_to=frontman"),
          ),
          ("wordpressPluginsUrl", JSON.Encode.string("https://example.com/wp-admin/plugins.php")),
        ]),
      ),
    )

    let config = Client__RuntimeConfig.read()

    t->expect(config.framework)->Expect.toBe(Client__RuntimeConfig.Wordpress)
    t->expect(config.relayBaseUrl)->Expect.toBe(Some("https://example.com/index.php"))
    t->expect(config.wpNonce)->Expect.toBe(Some("nonce-123"))
    t
    ->expect(config.wordpressLoginUrl)
    ->Expect.toBe(Some("https://example.com/wp-login.php?redirect_to=frontman"))
    t
    ->expect(config.wordpressPluginsUrl)
    ->Expect.toBe(Some("https://example.com/wp-admin/plugins.php"))
  })

  test("toMeta does not leak wpNonce into ACP metadata", t => {
    let meta = Client__RuntimeConfig.toMeta({
      framework: Client__RuntimeConfig.Wordpress,
      previewBridge: None,
      basePath: "frontman",
      relayBaseUrl: Some("https://example.com/index.php"),
      wpNonce: Some("nonce-123"),
      wordpressLoginUrl: Some("https://example.com/wp-login.php?redirect_to=frontman"),
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
