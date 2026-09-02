open Vitest

@val external structuredClone: 'a => 'a = "structuredClone"

@set external setInnerHTML: (WebAPI.DomTypes.element, string) => unit = "innerHTML"

let setBodyHtml = html => {
  let body =
    WebAPI.Window.current
    ->WebAPI.Window.document
    ->WebAPI.Document.body
    ->Null.toOption
    ->Option.getOrThrow(~message="Test document requires a body")
  body->WebAPI.HTMLElement.asElement->setInnerHTML(html)
}

let makeWindow = () => {
  let window = WebAPI.EventTarget.make()
  let properties: Dict.t<Obj.t> = Obj.magic(window)
  properties->Dict.set("parent", Obj.magic(window))
  Object.set(globalThis, "window", window)
  (Obj.magic(window): WebAPI.DomTypes.window)
}

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

    t->expect(output.success)->Expect.toBe(true)
    t->expect(output.html->Option.getOrThrow->String.includes("selected"))->Expect.toBe(true)
    t->expect(output.html->Option.getOrThrow->String.includes("button"))->Expect.toBe(true)
    t->expect(output.nodeCount)->Expect.toEqual(Some(2))
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

    t->expect(output.success)->Expect.toBe(false)
    t->expect(output.html)->Expect.toEqual(None)
    t->expect(output.nodeCount)->Expect.toEqual(Some(4))
    t
    ->expect(output.error->Option.getOrThrow->String.includes("Subtree too large"))
    ->Expect.toBe(true)
    t->expect(structuredClone(output))->Expect.toEqual(output)
  })
})

describe("preview bridge installation", _t => {
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
