open Vitest

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module MCP = Tool.MCP

@schema
type resultProjection = {
  content: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.t>,
  structuredContent: FrontmanAstroBrowser__Tool__GetAstroAudit.output,
  resultType: string,
  isError: option<bool>,
}

external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

let makeTool = (~getPreviewDoc) => FrontmanAstroBrowser__Tool__GetAstroAudit.make(~getPreviewDoc)

let unpackName = (toolModule: module(Tool.BrowserTool)): string => {
  module T = unpack(toolModule)
  T.name
}

let unpackExecute = (toolModule: module(Tool.BrowserTool)) => {
  module T = unpack(toolModule)
  (input, ~taskId, ~toolCallId) =>
    T.execute(Obj.magic(input), ~taskId, ~toolCallId, ~signal=WebAPI.AbortController.make().signal)
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
      result->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json->S.noValidation(true))
    let projection = json->S.parseOrThrow(~to=resultProjectionSchema)
    t->expect(projection.resultType)->Expect.toBe("complete")
    t->expect(projection.isError)->Expect.toBe(None)
    t->expect(projection.structuredContent.audits)->Expect.toEqual([])
    t
    ->expect(projection.structuredContent.message)
    ->Expect.toBe(Some("Preview iframe is not available"))
    t->expect(projection.content->Array.length)->Expect.toBe(1)
  })

  test("input and output schemas satisfy MCP tool schema boundaries", _t => {
    let inputJson =
      FrontmanAstroBrowser__Tool__GetAstroAudit.inputSchema
      ->S.toJSONSchema
      ->jsonSchemaAsJson
    let outputJson =
      FrontmanAstroBrowser__Tool__GetAstroAudit.outputSchema
      ->S.toJSONSchema
      ->jsonSchemaAsJson

    inputJson->S.parseOrThrow(~to=MCP.ToolSchema.inputSchema)->ignore
    outputJson->S.parseOrThrow(~to=MCP.ToolSchema.outputSchema)->ignore
    JSON.parseOrThrow(`{}`)
    ->S.parseOrThrow(~to=FrontmanAstroBrowser__Tool__GetAstroAudit.inputSchema)
    ->ignore
    JSON.parseOrThrow(`{"audits":[{"code":"a11y-test","category":"a11y","title":"Title","message":"Message","description":"Description","element":{"tagName":"button","selector":"button.primary","textSnippet":"Save"}}]}`)
    ->S.parseOrThrow(~to=FrontmanAstroBrowser__Tool__GetAstroAudit.outputSchema)
    ->ignore
  })
})
