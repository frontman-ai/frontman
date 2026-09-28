open Vitest

let makeWindow = () => {
  let window = WebAPI.EventTarget.make()
  let properties: Dict.t<Obj.t> = Obj.magic(window)
  properties->Dict.set("parent", Obj.magic(window))
  Object.set(globalThis, "window", window)
  (Obj.magic(window): WebAPI.DomTypes.window)
}

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
