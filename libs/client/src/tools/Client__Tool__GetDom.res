module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview
module Log = FrontmanLogs.Logs.Make({
  let component = #MCP
})

let name = Tool.ToolNames.getDom
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = `Inspect a specific section of the DOM in the web preview.

**Always target the smallest subtree you need.** Do NOT request "body" or "html" unless you need a high-level page overview.

Workflow:
1. Start with a specific selector targeting the area of interest (e.g. "#main-content", ".hero-section", "nav")
2. If you need broader context, use "body" with maxDepth: 3 to get a page skeleton, then drill into specific subtrees
3. Use full mode only when you need exact markup for a small, specific component

Modes:
- **simplified** (default): Line-oriented parent, selected, and child descriptors with selectors when resolvable, key attributes, accessibility role/name, child counts, and escaped text. Script/style/SVG and form-control values stripped. Capped at 200 nodes and 30KB.
- **full**: Raw markup. Capped at 15KB. Use only when you need exact markup for a specific component.

Simplified mode stops at the node or output limit and returns selectors so you can continue with a narrower target. Full mode rejects oversized subtrees.

Examples:
- Inspect a section: {"selector": "#main-content"}
- Inspect by role: {"selector": "[role='navigation']"}
- Full HTML of a small component: {"selector": ".hero-section", "mode": "full"}
- XPath: {"selector": "//form[@id='checkout']"}
- Page skeleton (use sparingly): {"selector": "body", "maxDepth": 3}`

type input = Preview.getDomInput

type output = Preview.getDomOutput

let inputSchema = Preview.getDomInputSchema
let outputSchema = Preview.getDomOutputSchema
let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

let structuredResult = output => Tool.structuredResult(output, outputSchema)

let bridgeUnavailableError = () => {
  let base = "Preview bridge runtime not available"
  try {
    switch Client__RuntimeConfig.read().framework {
    | Nextjs =>
      base ++ ". Update @frontman-ai/nextjs, then run `npx frontman-nextjs install` or add `import '@frontman-ai/nextjs/preview-loader'` to instrumentation-client.ts and restart your dev server."
    | Vite => base ++ ". Update @frontman-ai/vite and restart your dev server."
    | Astro => base ++ ". Update @frontman-ai/astro and restart your dev server."
    | Wordpress => base ++ ". Update the Frontman WordPress plugin."
    }
  } catch {
  | _ => base
  }
}

let runtimeStatusToString = status =>
  switch status {
  | Runtime.Connecting => "connecting"
  | Runtime.Open => "open"
  | Runtime.Disconnected(reason) => `disconnected: ${reason}`
  | Runtime.Closed(reason) => `closed: ${reason}`
  }

let execute = async (
  input: input,
  ~taskId: string,
  ~toolCallId as _toolCallId: string,
): Tool.MCP.CallToolResult.t => {
  switch Client__PreviewRuntimeRegistry.get() {
  | None => {
      let ctx = {
        "taskId": taskId,
        "selector": input.selector,
        "runtime": Client__PreviewRuntimeRegistry.describe(),
      }
      Console.error2("Preview bridge runtime not available for get_dom", ctx)
      Log.error(~ctx, "Preview bridge runtime not available for get_dom")
      structuredResult(Preview.getDomError(~error=bridgeUnavailableError()))
    }
  | Some(runtime) =>
    try {
      let output = await Client__PreviewRuntime.getDom(runtime, input)
      structuredResult(output)
    } catch {
    | exn =>
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Preview bridge request failed")
      let ctx = {
        "taskId": taskId,
        "selector": input.selector,
        "status": Client__PreviewRuntime.status(runtime)->runtimeStatusToString,
        "runtime": Client__PreviewRuntimeRegistry.describe(),
      }
      Console.error2("Preview bridge get_dom request failed", ctx)
      Log.error(~ctx, ~error=JsExn.fromException(exn), "Preview bridge get_dom request failed")
      structuredResult(Preview.getDomError(~error=message))
    }
  }
}
