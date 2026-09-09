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
        description ++ "\n\nResults also include Astro current-page client routing opt-in (enabled or disabled). Routing opt-in does not indicate completed navigation. An unavailable preview returns a tool error, not disabled routing.\n\nAstro persistence keys appear as data-astro-transition-persist attributes on inspected elements. astro_persistence describes marked DOM ancestors outside the selected element, nearest first, in both modes. It follows parentElement only and does not cross shadow roots. Attribute values may be shortened with '...'. Ancestor context is capped at 50 parent steps, 10 boundaries, and 4 KB with explicit truncation. These are markers, not proof that nodes, component state, or props survived navigation; exercise navigation to verify behavior."
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
