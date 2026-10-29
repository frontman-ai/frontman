module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool

let name = Tool.ToolNames.previewStatus
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.ReadWrite
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = "Check whether the storefront preview is ready for DOM inspection. Returns ready:true when a valid, same-origin preview document is loaded."

@schema
type input = {}

@schema
type output = {
  @live ready: bool,
  @live url: string,
  @live message: string,
}

let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

@live
let execute = async (
  _input: input,
  ~taskId as _: string,
  ~toolCallId as _: string,
  ~signal as _=?,
): Tool.MCP.CallToolResult.t => {
  let state = StateStore.getState(Client__State__Store.store)
  let base = Client__State.Selectors.previewUrl(state)
  let respond = (~ready, ~url, message) =>
    Tool.structuredResult({ready, url, message}, outputSchema)
  switch Client__Tool__PreviewContext.get() {
  | Some({doc}) if Client__Tool__NavigatePreview.validateDestination(doc.url) == Ok() &&
      Client__BrowserUrl.isSameOriginWithBase(~baseUrl=base, ~targetUrl=doc.url) =>
    respond(~ready=true, ~url=doc.url, "Preview document is available.")
  | Some(_) | None =>
    respond(
      ~ready=false,
      ~url=base,
      "Preview is unavailable or unsupported. It may still be loading, blocked, or missing the frontend bridge. Use navigate_preview with a known same-origin storefront URL such as /shop/ to recover without refreshing Frontman.",
    )
  }
}
