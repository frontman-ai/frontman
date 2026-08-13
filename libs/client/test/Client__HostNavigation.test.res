open Vitest

module HostNavigation = Client__HostNavigation

describe("useTopWindow", () => {
  test("returns false when already top-level", t => {
    let currentWindow = Obj.magic({"id": "current"})

    t
    ->expect(HostNavigation.useTopWindow(~currentWindow, ~topWindow=currentWindow))
    ->Expect.toBe(false)
  })

  test("returns true when embedded", t => {
    let currentWindow = Obj.magic({"id": "current"})
    let topWindow = Obj.magic({"id": "top"})

    t
    ->expect(HostNavigation.useTopWindow(~currentWindow, ~topWindow))
    ->Expect.toBe(true)
  })
})

describe("returnUrl", () => {
  test("uses the host page URL when embedded and available", t => {
    t
    ->expect(
      HostNavigation.returnUrl(
        ~currentUrl="https://site.example/frontman",
        ~topUrl=Some("https://playground.wordpress.net/?site=demo"),
        ~useTopWindow=true,
      ),
    )
    ->Expect.toBe("https://playground.wordpress.net/?site=demo")
  })

  test("falls back to the current page URL when the host page URL is unavailable", t => {
    t
    ->expect(
      HostNavigation.returnUrl(
        ~currentUrl="https://site.example/frontman",
        ~topUrl=None,
        ~useTopWindow=true,
      ),
    )
    ->Expect.toBe("https://site.example/frontman")
  })
})

describe("loginNavigation", () => {
  test("opens login in a new window when embedded", t => {
    let currentWindow = Obj.magic({"id": "current"})
    let topWindow = Obj.magic({"id": "top"})

    t
    ->expect(HostNavigation.loginNavigation(~currentWindow, ~topWindow))
    ->Expect.toBe(HostNavigation.NewWindow)
  })

  test("uses the current window when already top-level", t => {
    let currentWindow = Obj.magic({"id": "current"})

    t
    ->expect(HostNavigation.loginNavigation(~currentWindow, ~topWindow=currentWindow))
    ->Expect.toBe(HostNavigation.CurrentWindow)
  })
})

describe("login popup result", () => {
  test("reports a popup handle as opened", t => {
    let popup = Obj.magic({"id": "popup"})

    t->expect(HostNavigation.popupOpened(Nullable.make(popup)))->Expect.toBe(true)
  })

  test("reports a missing popup handle as blocked", t => {
    t->expect(HostNavigation.popupOpened(Nullable.null))->Expect.toBe(false)
  })
})
