module GetDom = FrontmanAiFrontmanProtocol.FrontmanProtocol__GetDom
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module ClientRouting = FrontmanAstroBrowser__ClientRouting
module Persistence = FrontmanAstroBrowser__Persistence
module Navigation = FrontmanAstroBrowser__Navigation

@schema
type output = {
  ...GetDom.output,
  @s.describe("Astro current-page routing opt-in, not navigation completion.") @live
  astro_client_routing: ClientRouting.t,
  @s.describe(
    "Latest observed navigation from the preview's dev recorder. Unavailable means no recorder; not_observed means no navigation recorded. astro:page-load is observed page lifecycle completion; astro:after-swap is not completion. hash-change is a same-document URL change, not an Astro page transition. This does not prove animation completion or preserved state."
  )
  @live
  astro_navigation: Navigation.t,
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
        description ++ "\n\nAstro results include current-page client-routing opt-in, persistence keys on inspected elements, and marked ancestors in astro_persistence in both modes. Ancestor lookup does not cross shadow roots. astro_navigation reports the latest observed source URL, destination URL, and lifecycle phase, or unavailable/not_observed status. Only astro:page-load records page lifecycle completion; astro:after-swap is not completion, and hash-change is only a same-document URL change. Routing opt-in and persistence markers are not proof of completed navigation or preserved state. Exercise navigation and inspect again to verify behavior; lifecycle completion does not prove animation completion or preserved state."
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
                astro_navigation: Navigation.read(preview.win),
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
