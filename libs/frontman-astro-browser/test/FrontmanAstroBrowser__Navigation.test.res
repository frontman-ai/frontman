open Vitest

module Navigation = FrontmanAstroBrowser__Navigation

@set
external setState: (WebAPI.DomTypes.window, option<JSON.t>) => unit =
  "__frontman_astro_navigation__"

let host = WebAPI.DomGlobal.window
afterEach(() => setState(host, None))

describe("Astro navigation inspection", () => {
  test("serializes unavailable, empty, and observed recorder states", t => {
    let cases = [
      (None, `"unavailable"`),
      (Some(`{}`), `"not_observed"`),
      (
        Some(`{"lastNavigation":{"from":"https://preview.test/a","to":"https://preview.test/b","phase":"astro:page-load"}}`),
        `{"status":"observed","from":"https://preview.test/a","to":"https://preview.test/b","phase":"astro:page-load"}`,
      ),
    ]
    cases->Array.forEach(
      ((state, expected)) => {
        setState(
          host,
          state->Option.map(value => S.decodeOrThrow(value, ~from=S.jsonString, ~to=S.json)),
        )
        let actual = Navigation.read(host)->S.decodeOrThrow(~from=Navigation.schema, ~to=S.json)
        t->expect(actual)->Expect.toEqual(S.decodeOrThrow(expected, ~from=S.jsonString, ~to=S.json))
      },
    )
  })

  test("rejects malformed records instead of reporting no navigation", t => {
    [
      `{"lastNavigation":{"from":"/a","to":"/b","phase":"completed"}}`,
      `{"lastNavigation":{"from":"/a","phase":"astro:page-load"}}`,
    ]->Array.forEach(
      value => {
        setState(host, Some(S.decodeOrThrow(value, ~from=S.jsonString, ~to=S.json)))
        t->expect(() => Navigation.read(host)->ignore)->Expect.toThrow
      },
    )
  })
})
