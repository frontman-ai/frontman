open Vitest

let structuredClone = value => WebAPI.DomGlobal.structuredClone(value)

let setBodyHtml = html => {
  let body =
    WebAPI.Window.current
    ->WebAPI.Window.document
    ->WebAPI.Document.body
    ->Null.toOption
    ->Option.getOrThrow(~message="Test document requires a body")
  body.innerHTML = html
}

describe("page context", _t => {
  test("reads fresh Astro routing markers from the child document", t => {
    let document = WebAPI.Window.current->WebAPI.Window.document
    document.head.innerHTML = `<meta name="astro-view-transitions-enabled">`
    t
    ->expect(FrontmanPreviewBridge__PageContext.read().astroClientRouting)
    ->Expect.toEqual(FrontmanAiFrontmanProtocol.FrontmanProtocol__AstroClientRouting.Enabled)
    document.head.innerHTML = ""
    t
    ->expect(FrontmanPreviewBridge__PageContext.read().astroClientRouting)
    ->Expect.toEqual(FrontmanAiFrontmanProtocol.FrontmanProtocol__AstroClientRouting.Disabled)
  })

  test("reads the child document and reports unsupported media queries explicitly", t => {
    let page = FrontmanPreviewBridge__PageContext.read()
    let window = WebAPI.Window.current
    t->expect(page.url)->Expect.toBe((window->WebAPI.Window.location).href)
    t->expect(page.viewportWidth)->Expect.toBe(window->WebAPI.Window.innerWidth)
    t->expect(page.viewportHeight)->Expect.toBe(window->WebAPI.Window.innerHeight)
    t->expect(page.devicePixelRatio)->Expect.toBe(window->WebAPI.Window.devicePixelRatio)
    t->expect(page.colorScheme)->Expect.toEqual(#unsupported)
    t->expect(structuredClone(page))->Expect.toEqual(page)
  })
})

describe("DOM snapshot", _t => {
  test("returns a bounded clone-safe snapshot", t => {
    setBodyHtml(`<main id="app"><button aria-label="Save changes">Save</button></main>`)

    let output = FrontmanPreviewBridge__DomSnapshot.execute({
      selector: "#app",
      mode: Some(#simplified),
      maxDepth: Some(1),
      maxNodes: Some(20),
      pierceShadowDom: Some(false),
    })

    let snapshot = output->Result.getOrThrow
    t->expect(snapshot.html->String.includes("selected"))->Expect.toBe(true)
    t->expect(snapshot.html->String.includes("button"))->Expect.toBe(true)
    t->expect(snapshot.nodeCount)->Expect.toBe(2)
    t->expect(snapshot.url)->Expect.toBe((WebAPI.Window.current->WebAPI.Window.location).href)
    t->expect(structuredClone(output))->Expect.toEqual(output)
  })

  test("returns a structured error for oversized full output", t => {
    setBodyHtml(`<section id="large"><div></div><div></div><div></div></section>`)

    let output = FrontmanPreviewBridge__DomSnapshot.execute({
      selector: "#large",
      mode: Some(#full),
      maxDepth: None,
      maxNodes: Some(2),
      pierceShadowDom: None,
    })

    switch output {
    | Error(message) =>
      t
      ->expect(message->String.includes("Subtree too large for full mode (4 elements"))
      ->Expect.toBe(true)
    | Ok(_) => JsError.throwWithMessage("Expected an oversized subtree error")
    }
    t->expect(structuredClone(output))->Expect.toEqual(output)
  })
})

describe("preview bridge installation", _t => {
  test("creates and disposes a runtime", _t => {
    let installation = FrontmanPreviewBridge.install({
      parentOrigin: "https://parent.example.com",
      channel: "preview-task-id",
    })
    FrontmanPreviewBridge.dispose(installation)
  })

  test("rejects invalid transport configuration", t => {
    t
    ->expect(
      () =>
        FrontmanPreviewBridge.install({
          parentOrigin: "*",
          channel: "preview-task-id",
        })->ignore,
    )
    ->Expect.toThrow
    t
    ->expect(
      () =>
        FrontmanPreviewBridge.install({
          parentOrigin: "https://parent.example.com",
          channel: "",
        })->ignore,
    )
    ->Expect.toThrow
  })

  test("disposal is idempotent", _t => {
    let config: FrontmanPreviewBridge.config = {
      parentOrigin: "https://parent.example.com",
      channel: "preview-task-id",
    }
    let installation = FrontmanPreviewBridge.install(config)

    FrontmanPreviewBridge.dispose(installation)
    FrontmanPreviewBridge.dispose(installation)
  })
})
