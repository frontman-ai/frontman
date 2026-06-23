open Vitest

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let makeTool = (~getPreviewDoc) => FrontmanAstroBrowser__Tool__GetAstroAudit.make(~getPreviewDoc)

let unpackName = (toolModule: module(Tool.BrowserTool)): string => {
  module T = unpack(toolModule)
  T.name
}

let unpackExecute = (toolModule: module(Tool.BrowserTool)) => {
  module T = unpack(toolModule)
  (input, ~taskId, ~toolCallId) => T.execute(Obj.magic(input), ~taskId, ~toolCallId)
}

describe("FrontmanAstroBrowser__Tool__GetAstroAudit", _t => {
  test("tool name is get_astro_audit", t => {
    let tool = makeTool(~getPreviewDoc=() => None)
    t->expect(unpackName(tool))->Expect.toBe("get_astro_audit")
  })

  testAsync("returns message when preview is unavailable", async t => {
    let tool = makeTool(~getPreviewDoc=() => None)
    let execute = unpackExecute(tool)
    let result = await execute(
      ({}: FrontmanAstroBrowser__Tool__GetAstroAudit.input),
      ~taskId="t1",
      ~toolCallId="tc1",
    )
    let json =
      result
      ->S.decodeOrThrow(~from=Tool.MCP.callToolResultSchema, ~to=S.json->S.noValidation(true))
      ->JSON.stringify
    t->expect(json->String.includes("Preview iframe is not available"))->Expect.toBe(true)
  })
})
