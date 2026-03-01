// Client tool that inspects DOM structure in the web preview.
// Supports CSS selectors and XPath expressions for targeting subtrees.
// Enforces size limits and guides the agent toward progressive disclosure:
// start narrow, drill down, never dump the full page.

S.enableJson()
module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.getDom
let visibleToAgent = true
let description = `Inspect a specific section of the DOM in the web preview.

**Always target the smallest subtree you need.** Do NOT request "body" or "html" unless you need a high-level page overview.

Workflow:
1. Start with a specific selector targeting the area of interest (e.g. "#main-content", ".hero-section", "nav")
2. If you need broader context, use "body" with maxDepth: 3 to get a page skeleton, then drill into specific subtrees
3. Use full mode only when you need exact markup for a small, specific component

Modes:
- **simplified** (default): Pruned indented representation showing tag names, key attributes (id, class, role, aria-*, href, src, etc.), and short text snippets. Script/style/SVG stripped. Capped at 200 nodes.
- **full**: Raw outerHTML. Capped at 15KB. Use only when you need exact markup for a specific component.

If the subtree is too large, the tool will **reject the request** and return a list of the element's direct children so you can pick a narrower target. This is by design — it prevents wasting your context window on huge DOM dumps.

Examples:
- Inspect a section: {"selector": "#main-content"}
- Inspect by role: {"selector": "[role='navigation']"}
- Full HTML of a small component: {"selector": ".hero-section", "mode": "full"}
- XPath: {"selector": "//form[@id='checkout']"}
- Page skeleton (use sparingly): {"selector": "body", "maxDepth": 3}`

@schema
type input = {
  @s.describe("CSS selector or XPath expression targeting a DOM subtree. Target the smallest subtree you need. CSS examples: '#main-content', '.hero-section', '[role=\"navigation\"]'. XPath examples: '//form', '//div[@id=\"app\"]'")
  selector: string,
  @s.describe("Output mode: 'simplified' (default) returns a pruned text representation, 'full' returns raw outerHTML (capped at 15KB, use only for small components).")
  mode: option<[#full | #simplified]>,
  @s.describe("Maximum tree depth in simplified mode. Defaults to 5. Nodes beyond this depth are summarized as '...N children'.")
  maxDepth: option<int>,
  @s.describe("Maximum number of element nodes to include. Defaults to 200. If the subtree exceeds this, the request is rejected with a hint showing the element's direct children so you can narrow your selector.")
  maxNodes: option<int>,
  @s.describe("Whether to traverse into shadow DOM roots. Defaults to false.")
  pierceShadowDom: option<bool>,
}

@schema
type output = {
  @s.describe("Whether the DOM query succeeded")
  success: bool,
  @s.describe("The DOM content: pruned text in simplified mode, raw HTML in full mode. Absent when the subtree is too large.")
  html: option<string>,
  @s.describe("Number of element nodes in the returned subtree")
  nodeCount: option<int>,
  @s.describe("Size of the returned content in bytes")
  byteSize: option<int>,
  @s.describe("Guidance for the next query: lists direct children when a request is rejected, or suggests narrower selectors.")
  hint: option<string>,
  @s.describe("Error message if the query failed")
  error: option<string>,
}

// ============================================================================
// Constants
// ============================================================================

let maxOutputBytes = 30_000 // ~8-15k tokens — enough for a meaningful subtree
let fullModeMaxBytes = 15_000 // Full mode is raw HTML, much denser — stricter cap
let defaultMaxDepth = 5
let defaultMaxNodes = 200
let hardMaxNodes = 500 // Clamp even if agent passes higher
let textTruncateLen = 80

// Truncate a string to maxLen characters, appending "..." if truncated.
let truncate = (text: string, ~maxLen: int): string =>
  switch text->String.length > maxLen {
  | true => text->String.slice(~start=0, ~end=maxLen) ++ "..."
  | false => text
  }

// Attributes to keep in simplified mode
let simplifiedAttributes = [
  "id",
  "class",
  "role",
  "aria-label",
  "aria-labelledby",
  "aria-describedby",
  "aria-hidden",
  "aria-expanded",
  "aria-selected",
  "aria-checked",
  "aria-disabled",
  "aria-live",
  "aria-controls",
  "data-testid",
  "data-test-id",
  "href",
  "src",
  "type",
  "name",
  "for",
  "action",
  "method",
  "value",
  "placeholder",
  "alt",
  "title",
]

let simplifiedAttributeSet = simplifiedAttributes->Array.map(a => (a, true))->Dict.fromArray

// Tags whose text content should be stripped entirely in simplified mode
let contentStrippedTags = ["script", "style", "svg"]->Array.map(t => (t, true))->Dict.fromArray

// ============================================================================
// Pre-flight helpers
// ============================================================================

// Count descendant elements of a target element (quick pre-flight check).
let countDescendants = (el: WebAPI.DOMAPI.element): int =>
  el->WebAPI.Element.querySelectorAll("*")->Client__Tool__ElementResolver.nodeListToElements->Array.length

// Build a "table of contents" of an element's direct children.
// Returns something like: "<header>, <main id=\"content\">, <footer class=\"site-footer\">"
// This gives the agent concrete selectors to drill into.
let describeDirectChildren = (el: WebAPI.DOMAPI.element): string => {
  let children = el.children
  let descriptions: array<string> = []
  let count = children.length
  let maxToShow = 15

  for i in 0 to Math.Int.min(count, maxToShow) - 1 {
    let child = children->WebAPI.HTMLCollection.item(i)
    let tag = child.tagName->String.toLowerCase
    let id = child->WebAPI.Element.getAttribute("id")->Null.toOption
    let cls = child->WebAPI.Element.getAttribute("class")->Null.toOption
    let role = child->WebAPI.Element.getAttribute("role")->Null.toOption

    let desc = switch (id, role, cls) {
    | (Some(id), _, _) => `<${tag} id="${id}">`
    | (_, Some(r), _) => `<${tag} role="${r}">`
    | (_, _, Some(c)) =>
      let shortClass = c->truncate(~maxLen=27)
      `<${tag} class="${shortClass}">`
    | _ => `<${tag}>`
    }
    descriptions->Array.push(desc)->ignore
  }

  if count > maxToShow {
    descriptions->Array.push(`...and ${Int.toString(count - maxToShow)} more`)->ignore
  }

  descriptions->Array.join(", ")
}

// Build a hint message for when a subtree is too large.
let buildTooLargeHint = (
  ~el: WebAPI.DOMAPI.element,
  ~descendantCount: int,
  ~maxNodes: int,
): string => {
  let tag = el.tagName->String.toLowerCase
  let childrenDesc = describeDirectChildren(el)
  let childCount = el.children.length

  `Subtree too large: <${tag}> has ${Int.toString(descendantCount)} descendant elements (limit: ${Int.toString(maxNodes)}). ` ++
  `It has ${Int.toString(childCount)} direct children: ${childrenDesc}. ` ++
  `Target a specific child instead.`
}

// ============================================================================
// Simplified DOM walker
// ============================================================================

type walkState = {
  mutable output: string,
  mutable nodeCount: int,
  mutable stopped: bool,
  maxNodes: int,
}

// Build the attribute string for an element in simplified mode.
let buildSimplifiedAttrs = (el: WebAPI.DOMAPI.element): string => {
  let attrNames = el->WebAPI.Element.getAttributeNames
  let parts: array<string> = []

  attrNames->Array.forEach(attrName => {
    let included =
      simplifiedAttributeSet->Dict.get(attrName)->Option.isSome ||
        attrName->String.startsWith("aria-")
    if included {
      switch el->WebAPI.Element.getAttribute(attrName)->Null.toOption {
      | None => ()
      | Some(value) =>
        let displayValue = value->truncate(~maxLen=57)
        parts->Array.push(` ${attrName}="${displayValue}"`)->ignore
      }
    }
  })

  parts->Array.join("")
}

// Get direct text content of an element (text nodes only, not children's text).
let getDirectText = (el: WebAPI.DOMAPI.element): string => {
  let childNodes = (el :> WebAPI.DOMAPI.node).childNodes
  let text = ref("")
  for i in 0 to childNodes.length - 1 {
    let node = WebAPI.NodeListOf.item(childNodes, i)
    // nodeType === 3 is TEXT_NODE
    if node.nodeType === 3 {
      let content = node.nodeValue->Null.toOption->Option.getOr("")->String.trim
      if content !== "" {
        text := text.contents ++ (text.contents !== "" ? " " : "") ++ content
      }
    }
  }
  text.contents
}

let indent = (depth: int): string => {
  let spaces = ref("")
  for _ in 1 to depth * 2 {
    spaces := spaces.contents ++ " "
  }
  spaces.contents
}

// Recursive DOM walker for simplified mode.
// Respects both maxDepth and maxNodes. Stops cleanly at either limit.
let rec walkSimplified = (
  ~el: WebAPI.DOMAPI.element,
  ~depth: int,
  ~maxDepth: int,
  ~pierceShadowDom: bool,
  ~state: walkState,
): unit => {
  if state.stopped || state.nodeCount >= state.maxNodes {
    state.stopped = true
    ()
  } else {
    state.nodeCount = state.nodeCount + 1
    let tag = el.tagName->String.toLowerCase
    let pad = indent(depth)

    // For content-stripped tags, just show the tag without content
    switch contentStrippedTags->Dict.get(tag) {
    | Some(_) =>
      state.output = state.output ++ pad ++ `<!-- ${tag} -->\n`
    | None =>
      let attrs = buildSimplifiedAttrs(el)
      let children = Client__Tool__ElementResolver.getChildElements(el, ~pierceShadowDom)
      let childCount = children->Array.length
      let directText = getDirectText(el)
      let hasShadow = pierceShadowDom && Client__Tool__ElementResolver.hasShadowRoot(el)

      switch (childCount, directText, hasShadow) {
      // Leaf element with text — inline it
      | (0, text, false) if text !== "" =>
        let truncated = text->truncate(~maxLen=textTruncateLen)
        state.output = state.output ++ pad ++ `<${tag}${attrs}>"${truncated}"</${tag}>\n`

      // Leaf element, no text
      | (0, _, false) =>
        state.output = state.output ++ pad ++ `<${tag}${attrs} />\n`

      // Element with children — recurse or summarize
      | _ =>
        if depth >= maxDepth {
          // Beyond max depth: summarize
          let summary = switch childCount {
          | 0 => ""
          | n => `<!-- ...${Int.toString(n)} children -->`
          }
          switch directText {
          | "" => state.output = state.output ++ pad ++ `<${tag}${attrs}>${summary}</${tag}>\n`
          | text =>
            let truncated = text->truncate(~maxLen=textTruncateLen)
            state.output =
              state.output ++ pad ++ `<${tag}${attrs}>"${truncated}" ${summary}</${tag}>\n`
          }
        } else {
          state.output = state.output ++ pad ++ `<${tag}${attrs}>\n`

          if hasShadow {
            state.output = state.output ++ indent(depth + 1) ++ "<!-- #shadow-root (open) -->\n"
          }

          if directText !== "" {
            let truncated = directText->truncate(~maxLen=textTruncateLen)
            state.output = state.output ++ indent(depth + 1) ++ `"${truncated}"\n`
          }

          children->Array.forEach(child => {
            if !state.stopped {
              walkSimplified(
                ~el=child,
                ~depth=depth + 1,
                ~maxDepth,
                ~pierceShadowDom,
                ~state,
              )
            }
          })

          state.output = state.output ++ pad ++ `</${tag}>\n`
        }
      }
    }
  }
}

// ============================================================================
// Result helpers
// ============================================================================

let errorResult = (~error: string, ~hint: option<string>=?, ~nodeCount: option<int>=?): result<output, _> =>
  Ok({
    success: false,
    html: None,
    nodeCount,
    byteSize: None,
    hint,
    error: Some(error),
  })

let successResult = (~html: string, ~nodeCount: option<int>=?, ~hint: option<string>=?): result<output, _> => {
  Ok({
    success: true,
    html: Some(html),
    nodeCount,
    byteSize: Some(html->String.length),
    hint,
    error: None,
  })
}

// ============================================================================
// Tool execution
// ============================================================================

let execute = async (input: input): toolResult<output> => {
  Client__Tool__ElementResolver.withPreviewDoc(
    ~onUnavailable=() =>
      errorResult(~error="Preview frame not available"),
    ({doc, win: _}) => {
      try {
        let (element, _matchCount) = Client__Tool__ElementResolver.resolveBySelector(
          ~doc,
          ~selector=input.selector,
        )

        switch element {
        | None =>
          errorResult(~error=`No element found for selector: ${input.selector}`)

        | Some(el) =>
          let mode = input.mode->Option.getOr(#simplified)
          let pierceShadowDom = input.pierceShadowDom->Option.getOr(false)
          let maxNodes = input.maxNodes
            ->Option.getOr(defaultMaxNodes)
            ->Math.Int.min(hardMaxNodes)
            ->Math.Int.max(1)

          // Pre-flight: count descendants to decide if we should proceed
          let descendantCount = countDescendants(el)

          switch mode {
          | #full =>
            // Pre-flight for full mode: check outerHTML size
            if descendantCount > maxNodes {
              errorResult(
                ~error=`Subtree too large for full mode (${Int.toString(descendantCount)} elements, limit: ${Int.toString(maxNodes)}).`,
                ~hint=buildTooLargeHint(~el, ~descendantCount, ~maxNodes),
                ~nodeCount=descendantCount,
              )
            } else {
              let raw = el.outerHTML
              let byteSize = raw->String.length
              if byteSize > fullModeMaxBytes {
                // HTML fits node count but is too large in bytes — reject, don't truncate
                errorResult(
                  ~error=`HTML too large: ${Int.toString(byteSize)} bytes (limit: ${Int.toString(fullModeMaxBytes)}). Use simplified mode for an overview, or target a smaller component.`,
                  ~hint=buildTooLargeHint(~el, ~descendantCount, ~maxNodes),
                  ~nodeCount=descendantCount,
                )
              } else {
                successResult(~html=raw, ~nodeCount=descendantCount)
              }
            }

          | #simplified =>
            if descendantCount > maxNodes {
              // Too many elements — fail fast with a useful hint
              errorResult(
                ~error=`Subtree too large: ${Int.toString(descendantCount)} elements (limit: ${Int.toString(maxNodes)}).`,
                ~hint=buildTooLargeHint(~el, ~descendantCount, ~maxNodes),
                ~nodeCount=descendantCount,
              )
            } else {
              let maxDepth = input.maxDepth->Option.getOr(defaultMaxDepth)
              let state: walkState = {
                output: "",
                nodeCount: 0,
                stopped: false,
                maxNodes,
              }

              walkSimplified(~el, ~depth=0, ~maxDepth, ~pierceShadowDom, ~state)

              // Byte size guard — shouldn't normally trigger given the node cap,
              // but protects against elements with very long attribute values
              if state.output->String.length > maxOutputBytes {
                errorResult(
                  ~error=`Output too large (${Int.toString(state.output->String.length)} bytes, limit: ${Int.toString(maxOutputBytes)}). Reduce maxDepth or narrow your selector.`,
                  ~hint=buildTooLargeHint(~el, ~descendantCount, ~maxNodes),
                  ~nodeCount=state.nodeCount,
                )
              } else {
                let hint = switch state.stopped {
                | true => Some(`Walker stopped at ${Int.toString(state.nodeCount)} nodes (limit: ${Int.toString(maxNodes)}). Some elements were omitted. Narrow your selector for complete results.`)
                | false => None
                }
                successResult(
                  ~html=state.output,
                  ~nodeCount=state.nodeCount,
                  ~hint?,
                )
              }
            }
          }
        }
      } catch {
      | exn =>
        errorResult(~error=Client__Tool__ElementResolver.exnMessage(exn))
      }
    },
  )
}
