open Vitest

module Registry = FrontmanAstroBrowser__Registry
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let unpackName = (toolModule: module(Tool.BrowserTool)): string => {
  module T = unpack(toolModule)
  T.name
}

let inspectTool = (toolModule: module(Tool.BrowserTool)) => {
  module T = unpack(toolModule)
  (T.name, T.access, T.visibleToAgent, T.executionMode, T.description, T.outputJsonSchema)
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

  test("audit tool exposes read-only standardizable policy and output schema", t => {
    let tool = Registry.browserTools(~getPreviewDoc=() => None)->Array.getUnsafe(0)->inspectTool
    let (name, access, visibleToAgent, executionMode, description, outputJsonSchema) = tool

    t->expect(name)->Expect.toBe("get_astro_audit")
    t->expect(access)->Expect.toBe(Tool.Read)
    t->expect(visibleToAgent)->Expect.toBe(true)
    t->expect(executionMode)->Expect.toBe(Tool.Synchronous)
    t->expect(description->String.length > 0)->Expect.toBe(true)
    t->expect(Option.isSome(outputJsonSchema))->Expect.toBe(true)
  })
})
