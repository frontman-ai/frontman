module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module GetDom = FrontmanAiFrontmanProtocol.FrontmanProtocol__GetDom

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

let fullModeMaxBytes = 15_000
let defaultMaxDepth = 1
let defaultMaxNodes = 200
let hardMaxNodes = 500

let countElements = (el: WebAPI.DomTypes.element): int =>
  (el->WebAPI.Element.querySelectorAll("*")).length + 1

let buildTooLargeHint = (
  ~el: WebAPI.DomTypes.element,
  ~document: WebAPI.DomTypes.document,
  ~additionalAttributes: array<string>,
): string => {
  let overview = Client__ElementInspector.inspect(
    ~element=el,
    ~document,
    ~maxDepth=1,
    ~maxNodes=16,
    ~additionalAttributes,
  )
  `Target a child selector from this overview instead:\n${overview.html}`
}

let inspect = (input: input, {doc, win}: Tool.previewContext, ~additionalAttributes=[]): result<
  (output, WebAPI.DomTypes.element),
  string,
> => {
  let (element, _matchCount) = Client__Tool__SelectorResolver.resolveBySelector(
    ~doc,
    ~selector=input.selector,
  )
  switch element {
  | None => Error(`No element found for selector: ${input.selector}`)
  | Some(el) =>
    let maxNodes =
      input.maxNodes
      ->Option.getOr(defaultMaxNodes)
      ->Math.Int.min(hardMaxNodes)
      ->Math.Int.max(1)
    let content = switch input.mode->Option.getOr(#simplified) {
    | #full =>
      let elementCount = countElements(el)
      switch elementCount > maxNodes {
      | true =>
        Error(
          `Subtree too large for full mode (${Int.toString(
              elementCount,
            )} elements, limit: ${Int.toString(maxNodes)}).\n` ++
          buildTooLargeHint(~el, ~document=doc, ~additionalAttributes),
        )
      | false =>
        let raw = el.outerHTML
        let byteSize = Client__ElementInspector.utf8ByteSize(raw)
        switch byteSize > fullModeMaxBytes {
        | true =>
          Error(
            `HTML too large: ${Int.toString(byteSize)} bytes (limit: ${Int.toString(
                fullModeMaxBytes,
              )}). Use simplified mode for an overview, or target a smaller component.\n` ++
            buildTooLargeHint(~el, ~document=doc, ~additionalAttributes),
          )
        | false => Ok((raw, elementCount, None))
        }
      }
    | #simplified =>
      let maxDepth = input.maxDepth->Option.getOr(defaultMaxDepth)
      let pierceShadowDom = input.pierceShadowDom->Option.getOr(false)
      let selectedSelector = switch Client__Tool__SelectorResolver.classifySelector(
        input.selector,
      ) {
      | CssSelector(_) => Some(input.selector)
      | XPathExpression(_) => None
      }
      let inspection = Client__ElementInspector.inspect(
        ~element=el,
        ~document=doc,
        ~maxDepth,
        ~maxNodes,
        ~pierceShadowDom,
        ~selectedSelector?,
        ~additionalAttributes,
      )
      let hint = switch inspection.truncated {
      | true =>
        Some(
          `Output stopped at the ${maxNodes->Int.toString}-node or ${Client__ElementInspector.maxOutputBytes->Int.toString}-byte limit. Narrow your selector for complete results.`,
        )
      | false => None
      }
      Ok((inspection.html, inspection.nodeCount, hint))
    }
    content->Result.map(((html, nodeCount, hint)) => (
      {
        GetDom.url: (win->WebAPI.Window.location).href,
        html,
        nodeCount,
        byteSize: Client__ElementInspector.utf8ByteSize(html),
        hint,
      },
      el,
    ))
  }
}

let execute = async (
  input: input,
  ~taskId as _taskId: string,
  ~toolCallId as _toolCallId: string,
): Tool.MCP.CallToolResult.t =>
  switch Client__Tool__PreviewContext.get() {
  | None => Tool.MCP.CallToolResult.makeError("Preview frame not available")
  | Some(preview) =>
    switch inspect(input, preview) {
    | Ok((output, _element)) => Tool.structuredResult(output, outputSchema)
    | Error(message) => Tool.MCP.CallToolResult.makeError(message)
    }
  }
