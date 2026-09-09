module GetDom = FrontmanAiFrontmanProtocol.FrontmanProtocol__GetDom
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module ClientRouting = FrontmanAstroBrowser__ClientRouting

@schema
type output = {
  ...GetDom.output,
  @s.describe("Astro current-page routing opt-in, not navigation completion.") @live
  astro_client_routing: ClientRouting.t,
}

let make = (
  ~getPreviewDoc: unit => option<Tool.previewContext>,
  ~inspect: (GetDom.input, option<Tool.previewContext>) => GetDom.output,
  ~description: string,
): module(Tool.BrowserTool) => {
  module(
    {
      let name = Tool.ToolNames.getDom
      let access = Tool.Read
      let visibleToAgent = true
      let executionMode = Tool.Synchronous
      let description =
        description ++ "\n\nResults also include Astro current-page client routing opt-in (enabled, disabled, or unavailable). Routing opt-in does not indicate completed navigation."
      type input = GetDom.input
      let inputSchema = GetDom.inputSchema
      let outputJsonSchema = Some(outputSchema->S.toJSONSchema)
      let execute = async (input, ~taskId as _, ~toolCallId as _) => {
        let preview = getPreviewDoc()
        let result = inspect(input, preview)
        Tool.structuredResult(
          {
            url: result.url,
            success: result.success,
            html: result.html,
            nodeCount: result.nodeCount,
            byteSize: result.byteSize,
            hint: result.hint,
            error: result.error,
            astro_client_routing: ClientRouting.read(preview->Option.map(({doc}) => doc)),
          },
          outputSchema,
        )
      }
    }
  )
}
