open Vitest

let makeWindow = () => {
  let window = WebAPI.EventTarget.make()
  let properties: Dict.t<Obj.t> = Obj.magic(window)
  properties->Dict.set("parent", Obj.magic(window))
  Object.set(globalThis, "window", window)
  (Obj.magic(window): WebAPI.DomTypes.window)
}

describe("preview bridge installation", _t => {
  test("reads page context inside the child window", t => {
    let window: {..} = Obj.magic(makeWindow())
    Object.set(window, "location", WebAPI.URL.make(~url="https://site.test/article"))
    Object.set(
      window,
      "document",
      {
        "title": "Article",
        "querySelector": (_: string) => Null.null,
      },
    )
    Object.set(window, "innerWidth", 800)
    Object.set(window, "innerHeight", 600)
    Object.set(window, "devicePixelRatio", 2.0)
    Object.set(window, "scrollY", 42.0)
    Object.set(window, "matchMedia", (_: string) => {"matches": true})
    let page = FrontmanPreviewBridge__PageContext.read()
    t
    ->expect(page)
    ->Expect.toEqual({
      FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview.url: "https://site.test/article",
      title: "Article",
      viewportWidth: 800,
      viewportHeight: 600,
      devicePixelRatio: 2.0,
      scrollY: 42,
      colorScheme: #dark,
      astroClientRouting: Disabled,
    })
  })

  test("creates and disposes a runtime", _t => {
    makeWindow()->ignore
    let installation = FrontmanPreviewBridge.install({
      parentOrigin: "https://parent.example.com",
      channel: "preview-task-id",
    })
    FrontmanPreviewBridge.dispose(installation)
  })

  test("rejects invalid transport configuration", t => {
    makeWindow()->ignore
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
    makeWindow()->ignore
    let config: FrontmanPreviewBridge.config = {
      parentOrigin: "https://parent.example.com",
      channel: "preview-task-id",
    }
    let installation = FrontmanPreviewBridge.install(config)

    FrontmanPreviewBridge.dispose(installation)
    FrontmanPreviewBridge.dispose(installation)
  })
})
