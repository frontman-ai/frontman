module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module GetDom = FrontmanAiFrontmanProtocol.FrontmanProtocol__GetDom
module Log = FrontmanLogs.Logs.Make({
  let component = #MCP
})

let name = Tool.ToolNames.getDom
let access = Tool.Read
let visibleToAgent = true
let executionMode = Tool.Synchronous
let description = `Inspect a specific section of the DOM in the web preview.

**Always target the smallest subtree you need.** Do NOT request "body" or "html" unless you need a high-level page overview.

Workflow:
1. Start with a specific selector targeting the area of interest (e.g. "#main-content", ".hero-section", "nav")
2. If you need broader context, use "body" with maxDepth: 3 to get a page skeleton, then drill into specific subtrees
3. Use full mode only when you need exact markup for a small, specific component

Modes:
- **simplified** (default): Line-oriented parent, selected, and child descriptors with selectors when resolvable, key attributes, accessibility role/name, component names, child counts, and escaped text. Script/style/SVG and form-control values stripped. Capped at 200 nodes and 30KB.
- **full**: Raw outerHTML. Capped at 15KB. Use only when you need exact markup for a specific component.

Results include the current preview URL.

Simplified mode stops at the node or output limit and returns selectors so you can continue with a narrower target. Full mode rejects oversized subtrees.

Examples:
- Inspect a section: {"selector": "#main-content"}
- Inspect by role: {"selector": "[role='navigation']"}
- Full HTML of a small component: {"selector": ".hero-section", "mode": "full"}
- XPath: {"selector": "//form[@id='checkout']"}
- Page skeleton (use sparingly): {"selector": "body", "maxDepth": 3}`

type input = GetDom.input
let inputSchema = GetDom.inputSchema
type output = GetDom.output
let outputSchema = GetDom.outputSchema

let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

let inspect = (input: input, {doc}: Tool.previewContext, ~additionalAttributes) =>
  FrontmanAiFrontmanCore.FrontmanCore__DomSnapshot.inspect(
    input,
    ~document=doc,
    ~additionalAttributes,
    ~componentForElement=Client__ElementInspector.componentForDocument(doc),
  )

let execute = async (
  input: input,
  ~taskId: string,
  ~toolCallId as _toolCallId: string,
): Tool.MCP.CallToolResult.t => {
  let state = StateStore.getState(Client__State__Store.store)
  let runtime =
    state.tasks
    ->Dict.get(taskId)
    ->Option.flatMap(task =>
      Client__PreviewRuntimeRegistry.get(~clientId=Client__Task__Types.Task.getClientId(task))
    )
  switch runtime {
  | None => {
      let ctx = {
        "taskId": taskId,
        "selector": input.selector,
        "runtime": Client__PreviewRuntimeRegistry.describe(),
      }
      Log.error(~ctx, "Preview bridge runtime not available for get_dom")
      Tool.MCP.CallToolResult.makeError("Preview bridge runtime not available")
    }
  | Some(runtime) =>
    try {
      switch await Client__PreviewRuntime.getDom(runtime, input) {
      | Ok(output) => Tool.structuredResult(output, outputSchema)
      | Error(message) => Tool.MCP.CallToolResult.makeError(message)
      }
    } catch {
    | exn =>
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Preview bridge request failed")
      Log.error(
        ~ctx={"taskId": taskId, "selector": input.selector},
        ~error=JsExn.fromException(exn),
        "Preview bridge get_dom request failed",
      )
      Tool.MCP.CallToolResult.makeError(message)
    }
  }
}
