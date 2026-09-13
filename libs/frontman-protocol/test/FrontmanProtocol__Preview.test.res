open Vitest

describe("lockstep preview protocol", _t => {
  test("page context round-trips schema serialization and rejects malformed responses", t => {
    module Preview = FrontmanProtocol.Preview
    let page: Preview.pageContext = {
      url: "https://preview.example/path?q=1#section",
      title: "Preview",
      viewportWidth: 390,
      viewportHeight: 844,
      devicePixelRatio: 2.0,
      scrollY: 120,
      colorScheme: #dark,
      astroClientRouting: Disabled,
    }
    let json = S.decodeOrThrow(page, ~from=Preview.pageContextSchema, ~to=S.json)
    t
    ->expect(S.parseOrThrow(json, ~to=Preview.pageContextSchema))
    ->Expect.toEqual(page)
    t
    ->expect(
      () =>
        S.parseOrThrow(
          JSON.parseOrThrow(`{"url":"x","colorScheme":"invalid"}`),
          ~to=Preview.pageContextSchema,
        )->ignore,
    )
    ->Expect.toThrow
  })
})
