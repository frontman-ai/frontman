module GetDom = FrontmanAiFrontmanProtocol.FrontmanProtocol__GetDom
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module ClientRouting = FrontmanAstroBrowser__ClientRouting

@schema
type output = {
  ...GetDom.output,
  @s.describe("Astro current-page routing opt-in, not navigation completion.") @live
  astro_client_routing: ClientRouting.t,
}

@live
let make = (
  ~getPreviewDoc: unit => option<Tool.previewContext>,
  ~inspect: (GetDom.input, Tool.previewContext) => result<GetDom.output, string>,
  ~description: string,
): module(Tool.BrowserTool) => {
  module(
    {
      let name = Tool.ToolNames.getDom
      let access = Tool.Read
      let visibleToAgent = true
      let executionMode = Tool.Synchronous
      let description =
        description ++ "\n\nResults also include Astro current-page client routing opt-in (enabled or disabled). Routing opt-in does not indicate completed navigation. An unavailable preview returns a tool error, not disabled routing."
      type input = GetDom.input
      let inputSchema = GetDom.inputSchema
      let outputJsonSchema = Some(outputSchema->S.toJSONSchema)
      let execute = async (input, ~taskId as _, ~toolCallId as _) =>
        switch getPreviewDoc() {
        | None => Tool.MCP.CallToolResult.makeError("Preview frame not available")
        | Some(preview) =>
          switch inspect(input, preview) {
          | Error(message) => Tool.MCP.CallToolResult.makeError(message)
          | Ok(result) =>
            Tool.structuredResult(
              {
                url: result.url,
                html: result.html,
                nodeCount: result.nodeCount,
                byteSize: result.byteSize,
                hint: result.hint,
                astro_client_routing: ClientRouting.read(Some(preview.doc)),
              },
              outputSchema,
            )
          }
        }
    }
  )
}
