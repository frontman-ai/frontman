open Vitest

@val external structuredClone: 'a => 'a = "structuredClone"

describe("lockstep preview protocol", _t => {
  test("page context survives clone and schema serialization; rejects malformed responses", t => {
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
    ->expect(S.parseOrThrow(structuredClone(json), ~to=Preview.pageContextSchema))
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

  test("error DTO survives structured clone", t => {
    let error: FrontmanProtocol.Preview.error = {
      code: "preview_unavailable",
      message: "Preview bridge is unavailable",
    }

    t->expect(structuredClone(error))->Expect.toEqual(error)
  })

  test("get_dom request and response DTOs survive structured clone", t => {
    let input: FrontmanProtocol.Preview.getDomInput = {
      selector: "#app",
      mode: Some(#simplified),
      maxDepth: Some(2),
      maxNodes: Some(20),
      pierceShadowDom: Some(false),
    }
    let output: FrontmanProtocol.Preview.getDomOutput = Ok({
      url: "https://preview.example/",
      html: "selected tag=div id=\"app\" children=0",
      nodeCount: 1,
      byteSize: 38,
      hint: None,
    })

    t->expect(structuredClone(input))->Expect.toEqual(input)
    t->expect(structuredClone(output))->Expect.toEqual(output)
  })
})
