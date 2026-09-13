module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module GetDom = Client__Tool__GetDom

@schema
type page = {
  url: string,
  html: string,
  astro_client_routing: option<string>,
  astro_persistence: option<FrontmanAiAstroBrowser.FrontmanAstroBrowser__Persistence.t>,
  astro_navigation: option<FrontmanAiAstroBrowser.FrontmanAstroBrowser__Navigation.t>,
}
@schema
type textContent = {text: string}
@schema
type response = {
  isError: option<bool>,
  structuredContent: option<page>,
  content: array<textContent>,
}

let execute = async (framework, input: GetDom.input, ~taskId: string) => {
  module T = unpack(
    Client__ToolRegistry.forFramework(framework).tools
    ->Array.find(tool => {
      module T = unpack(tool)
      T.name == GetDom.name
    })
    ->Option.getOrThrow
  )
  let input =
    input->S.decodeOrThrow(~from=GetDom.inputSchema, ~to=S.json)->S.parseOrThrow(~to=T.inputSchema)
  let result = await T.execute(input, ~taskId, ~toolCallId="call")
  result
  ->S.decodeOrThrow(~from=Tool.MCP.CallToolResult.schema, ~to=S.json)
  ->S.parseOrThrow(~to=responseSchema)
}
