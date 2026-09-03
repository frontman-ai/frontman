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

  test("get_dom request and response DTOs survive structured clone", t => {
    let input: FrontmanProtocol.Preview.getDomInput = {
      selector: "#app",
      mode: Some(#simplified),
      maxDepth: Some(2),
      maxNodes: Some(20),
      pierceShadowDom: Some(false),
    }
    let output: FrontmanProtocol.Preview.getDomOutput = {
      success: true,
      html: Some("selected tag=div id=\"app\" children=0"),
      nodeCount: Some(1),
      byteSize: Some(38),
      hint: None,
      error: None,
    }

    t->expect(structuredClone(input))->Expect.toEqual(input)
    t->expect(structuredClone(output))->Expect.toEqual(output)
  })
})
