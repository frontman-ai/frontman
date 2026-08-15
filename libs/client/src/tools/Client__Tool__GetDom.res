module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool

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
- **simplified** (default): Line-oriented parent, selected, and child descriptors with selectors when resolvable, key attributes, accessibility role/name, component names, child counts, and escaped text. Script/style/SVG content stripped. Capped at 200 nodes.
- **full**: Raw outerHTML. Capped at 15KB. Use only when you need exact markup for a specific component.

Simplified mode stops at the node limit and returns selectors so you can continue with a narrower target. Full mode rejects oversized subtrees.

Examples:
- Inspect a section: {"selector": "#main-content"}
- Inspect by role: {"selector": "[role='navigation']"}
- Full HTML of a small component: {"selector": ".hero-section", "mode": "full"}
- XPath: {"selector": "//form[@id='checkout']"}
- Page skeleton (use sparingly): {"selector": "body", "maxDepth": 3}`

@schema
type input = {
  @s.describe(
    "CSS selector or XPath expression targeting a DOM subtree. Target the smallest subtree you need. CSS examples: '#main-content', '.hero-section', '[role=\"navigation\"]'. XPath examples: '//form', '//div[@id=\"app\"]'"
  )
  selector: string,
  @s.describe(
    "Output mode: 'simplified' (default) returns line-oriented element descriptors, 'full' returns raw outerHTML (capped at 15KB, use only for small components)."
  )
  mode: option<[#full | #simplified]>,
  @s.describe(
    "Maximum target subtree depth in simplified mode. Defaults to 1. Descriptors report child counts at the depth boundary. Call get_dom again with a returned selector to inspect another part of the tree."
  )
  maxDepth: option<int>,
  @s.describe(
    "Maximum number of element nodes to include. Defaults to 200. Simplified mode stops at this limit and returns a narrowing hint; full mode rejects larger subtrees."
  )
  maxNodes: option<int>,
  @s.describe("Whether to traverse into shadow DOM roots. Defaults to false.")
  pierceShadowDom: option<bool>,
}

@schema
type output = {
  @s.describe("Whether the DOM query succeeded") @live
  success: bool,
  @s.describe(
    "The DOM content: line-oriented element descriptors in simplified mode, raw HTML in full mode. Absent when the subtree is too large."
  )
  @live
  html: option<string>,
  @s.describe("Number of element nodes in the returned subtree") @live
  nodeCount: option<int>,
  @s.describe("Size of the returned content in bytes") @live
  byteSize: option<int>,
  @s.describe(
    "Guidance for the next query: lists direct children when a request is rejected, or suggests narrower selectors."
  )
  @live
  hint: option<string>,
  @s.describe("Error message if the query failed") @live
  error: option<string>,
}

let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

let maxOutputBytes = 30_000
let fullModeMaxBytes = 15_000
let defaultMaxDepth = 1
let defaultMaxNodes = 200
let hardMaxNodes = 500

let countElements = (el: WebAPI.DOMAPI.element): int =>
  (el->WebAPI.Element.querySelectorAll("*")).length + 1

let buildTooLargeHint = (
  ~el: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
  ~elementCount: int,
  ~maxNodes: int,
): string => {
  let overview = Client__ElementInspector.inspect(
    ~element=el,
    ~document,
    ~maxDepth=1,
    ~maxNodes=16,
    ~pierceShadowDom=false,
  )
  `Subtree has ${elementCount->Int.toString} elements (limit: ${maxNodes->Int.toString}). ` ++
  `Target a child selector from this overview instead:\n${overview.html}`
}

let errorResult = (
  ~error: string,
  ~hint: option<string>=?,
  ~nodeCount: option<int>=?,
): Tool.MCP.CallToolResult.t =>
  Tool.structuredResult(
    {
      success: false,
      html: None,
      nodeCount,
      byteSize: None,
      hint,
      error: Some(error),
    },
    outputSchema,
  )

let successResult = (
  ~html: string,
  ~nodeCount: int,
  ~hint: option<string>=?,
): Tool.MCP.CallToolResult.t =>
  Tool.structuredResult(
    {
      success: true,
      html: Some(html),
      nodeCount: Some(nodeCount),
      byteSize: Some(html->String.length),
      hint,
      error: None,
    },
    outputSchema,
  )

let execute = async (
  input: input,
  ~taskId as _taskId: string,
  ~toolCallId as _toolCallId: string,
): Tool.MCP.CallToolResult.t => {
  Client__Tool__ElementResolver.withPreviewDoc(
    ~onUnavailable=() => errorResult(~error="Preview frame not available"),
    ({doc, win: _}) => {
      try {
        let (element, _matchCount) = Client__Tool__ElementResolver.resolveBySelector(
          ~doc,
          ~selector=input.selector,
        )

        switch element {
        | None => errorResult(~error=`No element found for selector: ${input.selector}`)

        | Some(el) =>
          let pierceShadowDom = input.pierceShadowDom->Option.getOr(false)
          let maxNodes =
            input.maxNodes
            ->Option.getOr(defaultMaxNodes)
            ->Math.Int.min(hardMaxNodes)
            ->Math.Int.max(1)

          switch input.mode->Option.getOr(#simplified) {
          | #full =>
            let elementCount = countElements(el)
            if elementCount > maxNodes {
              errorResult(
                ~error=`Subtree too large for full mode (${Int.toString(
                    elementCount,
                  )} elements, limit: ${Int.toString(maxNodes)}).`,
                ~hint=buildTooLargeHint(~el, ~document=doc, ~elementCount, ~maxNodes),
                ~nodeCount=elementCount,
              )
            } else {
              let raw = el.outerHTML
              let byteSize = raw->String.length
              if byteSize > fullModeMaxBytes {
                errorResult(
                  ~error=`HTML too large: ${Int.toString(byteSize)} bytes (limit: ${Int.toString(
                      fullModeMaxBytes,
                    )}). Use simplified mode for an overview, or target a smaller component.`,
                  ~hint=buildTooLargeHint(~el, ~document=doc, ~elementCount, ~maxNodes),
                  ~nodeCount=elementCount,
                )
              } else {
                successResult(~html=raw, ~nodeCount=elementCount)
              }
            }

          | #simplified =>
            let maxDepth = input.maxDepth->Option.getOr(defaultMaxDepth)
            let inspection = Client__ElementInspector.inspect(
              ~element=el,
              ~document=doc,
              ~maxDepth,
              ~maxNodes,
              ~pierceShadowDom,
            )

            if inspection.html->String.length > maxOutputBytes {
              let elementCount = countElements(el)
              errorResult(
                ~error=`Output too large (${Int.toString(
                    inspection.html->String.length,
                  )} bytes, limit: ${Int.toString(
                    maxOutputBytes,
                  )}). Reduce maxDepth or narrow your selector.`,
                ~hint=buildTooLargeHint(~el, ~document=doc, ~elementCount, ~maxNodes),
                ~nodeCount=inspection.nodeCount,
              )
            } else {
              let hint = switch inspection.truncated {
              | true =>
                Some(
                  `Walker stopped at ${Int.toString(
                      inspection.nodeCount,
                    )} nodes (limit: ${Int.toString(
                      maxNodes,
                    )}). Some elements were omitted. Narrow your selector for complete results.`,
                )
              | false => None
              }
              successResult(~html=inspection.html, ~nodeCount=inspection.nodeCount, ~hint?)
            }
          }
        }
      } catch {
      | exn => errorResult(~error=Client__Tool__ElementResolver.exnMessage(exn))
      }
    },
  )
}
