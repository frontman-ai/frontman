open Vitest

describe("preview bootstrap rollout", _t => {
  let origin = "https://site.test"
  test("stays inactive for old clients and top-level pages", t => {
    ["", "application-frame"]->Array.forEach(
      name =>
        t
        ->expect(FrontmanPreviewBridge__Bootstrap.fromFrame(~name, ~origin, ~isTopLevel=false))
        ->Expect.toEqual(None),
    )
    t
    ->expect(
      FrontmanPreviewBridge__Bootstrap.fromFrame(
        ~name="frontman:https://site.test/?channel=task",
        ~origin,
        ~isTopLevel=true,
      ),
    )
    ->Expect.toEqual(None)
  })
  test("binds each frame to its own channel and the page origin", t => {
    ["first", "second"]->Array.forEach(
      channel =>
        t
        ->expect(
          FrontmanPreviewBridge__Bootstrap.fromFrame(
            ~name=`frontman:https://site.test/?channel=${channel}`,
            ~origin,
            ~isTopLevel=false,
          ),
        )
        ->Expect.toEqual(Some({FrontmanPreviewBridge.parentOrigin: origin, channel})),
    )
    ["https://attacker.test", "http://site.test", "https://site.test:8443"]->Array.forEach(
      parent =>
        t
        ->expect(
          FrontmanPreviewBridge__Bootstrap.fromFrame(
            ~name=`frontman:${parent}/?channel=task`,
            ~origin,
            ~isTopLevel=false,
          ),
        )
        ->Expect.toEqual(None),
    )
  })
  test("rejects malformed frame configuration", t => {
    [
      "frontman:invalid",
      "frontman:https://site.test/",
      "frontman:https://site.test/?channel=",
      "frontman:file:///?channel=task",
    ]->Array.forEach(
      name =>
        t
        ->expect(
          () =>
            FrontmanPreviewBridge__Bootstrap.fromFrame(~name, ~origin, ~isTopLevel=false)->ignore,
        )
        ->Expect.toThrow,
    )
  })
})
