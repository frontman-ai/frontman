open Vitest

@val external structuredClone: 'a => 'a = "structuredClone"

describe("lockstep preview protocol", _t => {
  test("error DTO survives structured clone", t => {
    let error: FrontmanProtocol.Preview.error = {
      code: "preview_unavailable",
      message: "Preview bridge is unavailable",
    }

    t->expect(structuredClone(error))->Expect.toEqual(error)
  })
})
