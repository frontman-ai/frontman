open Vitest

@val external structuredClone: 'a => 'a = "structuredClone"

let handle = (request: Types.message<unit>) =>
  switch request {
  | FrontmanProtocol.Preview.Ready => ()
  | _ => JsError.throwWithMessage("Unexpected preview message")
  }

describe("lockstep preview messages", _t => {
  test("Ready proves the Frontman handler is installed", t => {
    t->expect(handle(FrontmanProtocol.Preview.Ready))->Expect.toEqual()
  })

  test("error DTO survives structured clone", t => {
    let error: FrontmanProtocol.Preview.error = {
      code: "preview_unavailable",
      message: "Preview bridge is unavailable",
    }

    t->expect(structuredClone(error))->Expect.toEqual(error)
  })
})
