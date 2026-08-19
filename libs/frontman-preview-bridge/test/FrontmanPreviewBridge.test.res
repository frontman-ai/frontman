open Vitest

let installationKey =
  Symbol.getFor("@frontman-ai/frontman-preview-bridge/installation")->Option.getOrThrow

let makeWindow = () => {
  Object.setSymbol(globalThis, installationKey, undefined)
  let window = WebAPI.EventTarget.make()
  let properties: Dict.t<Obj.t> = Obj.magic(window)
  properties->Dict.set("parent", Obj.magic(window))
  Object.set(globalThis, "window", window)
  (Obj.magic(window): WebAPI.DomTypes.window)
}

describe("preview bridge installation", _t => {
  test("creates one connecting runtime for matching configuration", t => {
    makeWindow()->ignore
    let config: FrontmanPreviewBridge.config = {
      parentOrigin: "https://parent.example.com",
      channel: "preview-task-id",
    }

    let first = FrontmanPreviewBridge.install(config)
    let second = FrontmanPreviewBridge.install(config)

    t->expect(first === second)->Expect.toBe(true)

    FrontmanPreviewBridge.dispose(first)
  })

  test("rejects conflicting duplicate configuration", t => {
    makeWindow()->ignore
    let installation = FrontmanPreviewBridge.install({
      parentOrigin: "https://parent.example.com",
      channel: "preview-task-id",
    })

    t
    ->expect(
      () =>
        FrontmanPreviewBridge.install({
          parentOrigin: "https://parent.example.com",
          channel: "other-task-id",
        })->ignore,
    )
    ->Expect.toThrow
    t
    ->expect(
      () =>
        FrontmanPreviewBridge.install({
          parentOrigin: "https://other-parent.example.com",
          channel: "preview-task-id",
        })->ignore,
    )
    ->Expect.toThrow

    FrontmanPreviewBridge.dispose(installation)
  })

  test("rejects an occupied installation slot", t => {
    makeWindow()->ignore
    Object.setSymbol(globalThis, installationKey, {"marker": "other-application"})

    t
    ->expect(
      () =>
        FrontmanPreviewBridge.install({
          parentOrigin: "https://parent.example.com",
          channel: "preview-task-id",
        })->ignore,
    )
    ->Expect.toThrow
  })

  test("disposal is terminal and idempotent", t => {
    makeWindow()->ignore
    let config: FrontmanPreviewBridge.config = {
      parentOrigin: "https://parent.example.com",
      channel: "preview-task-id",
    }
    let installation = FrontmanPreviewBridge.install(config)

    FrontmanPreviewBridge.dispose(installation)
    FrontmanPreviewBridge.dispose(installation)

    t->expect(FrontmanPreviewBridge.install(config) === installation)->Expect.toBe(true)
  })
})
