open Vitest

@val external structuredClone: 'a => 'a = "structuredClone"

describe("lockstep preview protocol", _t => {
  test("rejects malformed or unsupported remote page metadata", t => {
    [
      `{"url":"https://child.test/","title":42,"viewportWidth":800,"viewportHeight":600,"devicePixelRatio":1,"scrollY":0,"colorScheme":"dark","astroClientRouting":"enabled"}`,
      `{"url":"https://child.test/","title":"Child","viewportWidth":800,"viewportHeight":600,"devicePixelRatio":1,"scrollY":0,"colorScheme":"unknown","astroClientRouting":"enabled"}`,
    ]->Array.forEach(
      json => {
        let rejected = try {
          S.decodeOrThrow(
            json,
            ~from=S.jsonString,
            ~to=FrontmanProtocol.Preview.pageContextSchema,
          )->ignore
          false
        } catch {
        | _ => true
        }
        t->expect(rejected)->Expect.toBe(true)
      },
    )
  })
  test("error DTO survives structured clone", t => {
    let error: FrontmanProtocol.Preview.error = {
      code: "preview_unavailable",
      message: "Preview bridge is unavailable",
    }

    t->expect(structuredClone(error))->Expect.toEqual(error)
  })
})
