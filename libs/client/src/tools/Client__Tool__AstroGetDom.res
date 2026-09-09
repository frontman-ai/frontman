module GetDom = Client__Tool__GetDom
module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
module ClientRouting = FrontmanAiAstroBrowser.FrontmanAstroBrowser__ClientRouting

let name = GetDom.name
let access = GetDom.access
let visibleToAgent = GetDom.visibleToAgent
let executionMode = GetDom.executionMode
let description =
  GetDom.description ++ "\n\nResults also include Astro current-page client routing opt-in (enabled, disabled, or unavailable). Routing opt-in does not indicate completed navigation."

type input = GetDom.input
let inputSchema = GetDom.inputSchema

@schema
type output = {
  ...GetDom.output,
  @s.describe("Astro current-page routing opt-in, not navigation completion.") @live
  astro_client_routing: ClientRouting.t,
}

let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

let execute = async (
  input: input,
  ~taskId as _taskId: string,
  ~toolCallId as _toolCallId: string,
): Tool.MCP.CallToolResult.t => {
  let preview = Client__Tool__PreviewContext.get()
  let result = GetDom.inspect(input, preview)
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
