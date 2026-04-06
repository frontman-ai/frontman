open Vitest

module Registry = FrontmanAiAstroBrowser.FrontmanAstroBrowser__Registry
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let unpackName = (toolModule: module(Tool.BrowserTool)): string => {
  module T = unpack(toolModule)
  T.name
}

describe("FrontmanAstroBrowser__Registry", _t => {
  test("browserTools returns one tool", t => {
    let tools = Registry.browserTools(~getPreviewDoc=() => None)
    t->expect(tools->Array.length)->Expect.toBe(1)
  })

  test("first tool is get_astro_audit", t => {
    let tools = Registry.browserTools(~getPreviewDoc=() => None)
    let name = tools->Array.getUnsafe(0)->unpackName
    t->expect(name)->Expect.toBe("get_astro_audit")
  })
})
