module GetDom = FrontmanAiFrontmanProtocol.FrontmanProtocol__GetDom
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module ClientRouting = FrontmanAstroBrowser__ClientRouting
module Persistence = FrontmanAstroBrowser__Persistence

@schema
type output = {
  ...GetDom.output,
  @s.describe("Astro current-page routing opt-in, not navigation completion.") @live
  astro_client_routing: ClientRouting.t,
  @s.describe("Current DOM persistence markers, not observed survival across navigation.") @live
  astro_persistence: Persistence.t,
}

@live
let make = (
  ~getPreviewDoc: unit => option<Tool.previewContext>,
  ~inspect: (
    GetDom.input,
    Tool.previewContext,
  ) => result<(GetDom.output, WebAPI.DomTypes.element), string>,
  ~describeAncestor: (WebAPI.DomTypes.element, Tool.previewContext) => string,
  ~description: string,
): module(Tool.BrowserTool) => {
  module(
    {
      let name = Tool.ToolNames.getDom
      let access = Tool.Read
      let visibleToAgent = true
      let executionMode = Tool.Synchronous
      let description =
        description ++ "\n\nAstro results include current-page client-routing opt-in, persistence keys on inspected elements, and marked ancestors in astro_persistence in both modes. Ancestor lookup does not cross shadow roots. Routing opt-in and persistence markers are not proof of completed navigation or preserved state. Exercise navigation to verify behavior."
      type input = GetDom.input
      let inputSchema = GetDom.inputSchema
      let outputJsonSchema = Some(outputSchema->S.toJSONSchema)
      let execute = async (input, ~taskId as _, ~toolCallId as _) =>
        switch getPreviewDoc() {
        | None => Tool.MCP.CallToolResult.makeError("Preview frame not available")
        | Some(preview) =>
          switch inspect(input, preview) {
          | Error(message) => Tool.MCP.CallToolResult.makeError(message)
          | Ok((result, element)) =>
            Tool.structuredResult(
              {
                url: result.url,
                html: result.html,
                nodeCount: result.nodeCount,
                byteSize: result.byteSize,
                hint: result.hint,
                astro_client_routing: ClientRouting.read(Some(preview.doc)),
                astro_persistence: Persistence.read(element, ~describeAncestor=element =>
                  describeAncestor(element, preview)
                ),
              },
              outputSchema,
            )
          }
        }
    }
  )
}
