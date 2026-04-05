open Vitest

module Registry = FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry

describe("FrontmanAstroBrowser__Registry", _t => {
  test("browserTools is an empty array", t => {
    t->expect(Registry.browserTools->Array.length)->Expect.toBe(0)
  })
})
