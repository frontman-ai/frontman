// Shared helpers for element discovery and resolution in browser tools.
// Used by GetInteractiveElements, InteractWithElement, GetDom, and SearchText tools.

// Convert a NodeList to an array of elements. NodeList has no toArray binding
// in @rescript/webapi, so we use a small typed external for Array.from.
@val
external nodeListToElements: WebAPI.DOMAPI.nodeList => array<WebAPI.DOMAPI.element> = "Array.from"

// Extract the message from a JS exception, or return "Unknown error".
let exnMessage = (exn: exn): string =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")

// ============================================================================
// Preview frame access
// ============================================================================

// Re-export from protocol for consumers that import from ElementResolver
type previewContext = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.previewContext

// Get preview iframe context if available. Used by forFramework to inject
// into framework-specific browser tool factories.
let getPreviewDoc = (): option<previewContext> => {
  let state = StateStore.getState(Client__State__Store.store)
  let previewFrame = Client__State__StateReducer.Selectors.previewFrame(state)
  switch (previewFrame.contentDocument, previewFrame.contentWindow) {
  | (Some(doc), Some(win)) => Some({doc, win})
  | _ => None
  }
}

// Eliminates repeated getState -> previewFrame -> switch contentDocument boilerplate.
// Calls `fn` with the preview iframe's document and window when available,
// or `onUnavailable` when the preview frame isn't ready.
let withPreviewDoc = (~onUnavailable: unit => 'a, fn: previewContext => 'a): 'a =>
  switch getPreviewDoc() {
  | Some(ctx) => fn(ctx)
  | None => onUnavailable()
  }

// ============================================================================
// Selector resolution (CSS + XPath)
// ============================================================================

type selectorKind =
  | CssSelector(string)
  | XPathExpression(string)

// Detect whether a selector string is XPath or CSS.
// XPath expressions start with "/" or "(" (for grouped expressions).
let classifySelector = (selector: string): selectorKind =>
  switch selector->String.startsWith("/") || selector->String.startsWith("(") {
  | true => XPathExpression(selector)
  | false => CssSelector(selector)
  }

// Resolve elements by CSS selector or XPath expression.
// Returns the element at the given index and the total match count.
let resolveBySelector = (~doc: WebAPI.DOMAPI.document, ~selector: string, ~index: int=0): (
  option<WebAPI.DOMAPI.element>,
  int,
) => {
  switch classifySelector(selector) {
  | CssSelector(css) =>
    let elements = doc->WebAPI.Document.querySelectorAll(css)->nodeListToElements
    (elements->Array.get(index), elements->Array.length)
  | XPathExpression(xpath) =>
    // ORDERED_NODE_SNAPSHOT_TYPE = 7
    let result =
      doc->WebAPI.Document.evaluate(
        ~expression=xpath,
        ~contextNode=(doc :> WebAPI.DOMAPI.node),
        ~type_=7,
      )
    let count = result.snapshotLength
    // snapshotItem returns node; use typed asElement cast
    // (XPath snapshot queries on DOM return element nodes)
    let element = switch index >= 0 && index < count {
    | true =>
      let node = result->WebAPI.XPathResult.snapshotItem(index)
      Some(node->WebAPI.Node.asElement)
    | false => None
    }
    (element, count)
  }
}

// Resolve an optional selector to a root element, falling back to document body.
// Used by tools that accept an optional scope selector (e.g. SearchText).
let resolveRootOrBody = (~doc: WebAPI.DOMAPI.document, ~selector: option<string>): result<
  WebAPI.DOMAPI.element,
  string,
> =>
  switch selector {
  | Some(sel) =>
    let (element, _count) = resolveBySelector(~doc, ~selector=sel)
    switch element {
    | Some(el) => Ok(el)
    | None => Error(`No element found for selector: ${sel}`)
    }
  | None => Ok(doc.body->WebAPI.HTMLElement.asElement)
  }

// ============================================================================
// Shadow DOM traversal helpers
// ============================================================================

// Get child elements from an element, optionally including shadow root children.
// Shadow root children are appended after the element's direct children.
let getChildElements = (el: WebAPI.DOMAPI.element, ~pierceShadowDom: bool): array<
  WebAPI.DOMAPI.element,
> => {
  let children = el.children
  let result: array<WebAPI.DOMAPI.element> = []
  for i in 0 to children.length - 1 {
    result->Array.push(children->WebAPI.HTMLCollection.item(i))->ignore
  }
  switch pierceShadowDom {
  | false => ()
  | true =>
    switch el.shadowRoot->Null.toOption {
    | Some(shadowRoot) =>
      // Walk childNodes and pick element nodes (nodeType === 1)
      let childNodes = shadowRoot.childNodes
      for i in 0 to childNodes.length - 1 {
        let node = WebAPI.NodeListOf.item(childNodes, i)
        switch WebAPI.Node.nodeType(node) === 1 {
        | true => result->Array.push(node->WebAPI.Node.asElement)->ignore
        | false => ()
        }
      }
    | None => ()
    }
  }
  result
}

// Check whether an element has a shadow root (for annotation in DOM output)
let hasShadowRoot = (el: WebAPI.DOMAPI.element): bool => el.shadowRoot->Null.toOption->Option.isSome

// Compute the effective role for an element: ARIA role if present, tag name otherwise.
// Used consistently for filtering, resolution, and output so the agent can target
// elements by the same role value shown in discovery.
let effectiveRole = (el: WebAPI.DOMAPI.element): string => {
  let rawRole =
    FrontmanBindings.Bindings__DomAccessibilityApi.getRole(el)->Null.toOption->Option.getOr("")
  let tag = el.tagName->String.toLowerCase
  switch rawRole {
  | "" => tag
  | role => role
  }
}

// Extract optional ARIA role, returning None for empty strings or absent roles.
let getOptionalRole = (el: WebAPI.DOMAPI.element): option<string> =>
  switch FrontmanBindings.Bindings__DomAccessibilityApi.getRole(el)->Null.toOption {
  | Some("") | None => None
  | some => some
  }

// Extract optional accessible name, returning None for empty strings.
let getOptionalAccessibleName = (el: WebAPI.DOMAPI.element): option<string> =>
  switch FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(el) {
  | "" => None
  | n => Some(n)
  }

// Interactive ARIA roles — elements with these roles are inherently interactive
let interactiveRoles = [
  "button",
  "link",
  "menuitem",
  "menuitemcheckbox",
  "menuitemradio",
  "tab",
  "checkbox",
  "radio",
  "switch",
  "option",
  "combobox",
  "textbox",
  "searchbox",
  "slider",
  "spinbutton",
  "treeitem",
]

let interactiveRoleSet = interactiveRoles->Array.map(r => (r, true))->Dict.fromArray

type detectionMethod =
  | Semantic
  | CursorPointer
  | Tabindex

let detectionMethodToString = (method: detectionMethod): string =>
  switch method {
  | Semantic => "semantic"
  | CursorPointer => "cursor_pointer"
  | Tabindex => "tabindex"
  }

type resolvedElement = {
  element: WebAPI.DOMAPI.element,
  role: string,
  name: string,
  tag: string,
  detectionMethod: detectionMethod,
  visibleText: option<string>,
}

// Get cursor style for an element. Uses the iframe's window for getComputedStyle.
// May throw on cross-origin or detached elements — returns "" on failure.
let getCursor = (win: WebAPI.DOMAPI.window, el: WebAPI.DOMAPI.element): string =>
  try {
    WebAPI.Window.getComputedStyle(win, ~elt=el).cursor
  } catch {
  | JsExn(_) => ""
  }

// Check if an element has zero dimensions (invisible)
let hasZeroDimensions = (el: WebAPI.DOMAPI.element): bool => {
  let rect = el->WebAPI.Element.getBoundingClientRect
  rect.width <= 0.0 || rect.height <= 0.0
}

// Check if an element is effectively hidden — either inaccessible (aria-hidden,
// display:none, etc.) or has zero dimensions. Single predicate for the visibility
// guard used across all tool element walks.
let isEffectivelyHidden = (el: WebAPI.DOMAPI.element): bool =>
  FrontmanBindings.Bindings__DomAccessibilityApi.isInaccessible(el) || hasZeroDimensions(el)

// Truncate text to a reasonable length for LLM context
let truncateText = (text: string): option<string> => {
  let maxLen = 80
  let trimmed = text->String.trim
  switch trimmed {
  | "" => None
  | t if t->String.length > maxLen => Some(t->String.slice(~start=0, ~end=maxLen) ++ "...")
  | t => Some(t)
  }
}

// Get visible text content from an element (innerText preferred, falls back to textContent).
// May throw on cross-origin or detached elements — returns "" on failure.
let getVisibleText = (el: WebAPI.DOMAPI.element): string =>
  try {
    let htmlEl = el->WebAPI.Element.asHTMLElement
    switch WebAPI.HTMLElement.innerText(htmlEl) {
    | "" => (el :> WebAPI.DOMAPI.node)->WebAPI.Node.textContent->Null.toOption->Option.getOr("")
    | text => text
    }
  } catch {
  | JsExn(_) => ""
  }

// Determine how an element was detected as interactive, if at all.
let detectInteractivity = (
  ~contentWindow: WebAPI.DOMAPI.window,
  ~el: WebAPI.DOMAPI.element,
  ~rawRole: string,
): option<detectionMethod> =>
  switch true {
  | _ if rawRole !== "" && interactiveRoleSet->Dict.get(rawRole)->Option.isSome => Some(Semantic)
  | _ if getCursor(contentWindow, el) === "pointer" => Some(CursorPointer)
  | _ if el->WebAPI.Element.hasAttribute("tabindex") =>
    // Only treat tabindex >= 0 as interactive. tabindex="-1" means
    // "programmatically focusable but not in the tab order" and is
    // used on non-interactive containers (modals, scroll targets, etc.)
    let tabVal =
      el
      ->WebAPI.Element.getAttribute("tabindex")
      ->Null.toOption
      ->Option.getOr("-1")
      ->Int.fromString(~radix=10)
      ->Option.getOr(-1)
    switch tabVal >= 0 {
    | true => Some(Tabindex)
    | false => None
    }
  | _ => None
  }

// Check whether an element passes the optional role and name filters.
let passesFilters = (
  ~role: string,
  ~name: string,
  ~roleFilter: option<string>,
  ~nameFilter: option<string>,
): bool => {
  let passesRole = switch roleFilter {
  | None => true
  | Some(r) => role === r->String.toLowerCase
  }
  let passesName = switch nameFilter {
  | None => true
  | Some(n) => name->String.toLowerCase->String.includes(n->String.toLowerCase)
  }
  passesRole && passesName
}

// Collect interactive elements from a document.
// Walks the DOM and identifies elements that are interactive via:
// 1. Semantic ARIA role (implicit or explicit)
// 2. cursor:pointer CSS
// 3. tabindex attribute
//
// Uses a while loop (not Array.filter) so we can stop at maxElements
// without scanning the entire DOM.
let collectInteractiveElements = (
  ~document: WebAPI.DOMAPI.document,
  ~contentWindow: WebAPI.DOMAPI.window,
  ~roleFilter: option<string>=?,
  ~nameFilter: option<string>=?,
  ~maxElements: int,
): array<resolvedElement> => {
  let allElements = document->WebAPI.Document.querySelectorAll("*")->nodeListToElements
  let results: array<resolvedElement> = []

  let i = ref(0)
  while i.contents < allElements->Array.length && results->Array.length < maxElements {
    let el = allElements->Array.getUnsafe(i.contents)
    i := i.contents + 1

    switch isEffectivelyHidden(el) {
    | true => ()
    | false =>
      let rawRole =
        FrontmanBindings.Bindings__DomAccessibilityApi.getRole(el)->Null.toOption->Option.getOr("")
      let tag = el.tagName->String.toLowerCase
      let role = switch rawRole {
      | "" => tag
      | r => r
      }

      switch detectInteractivity(~contentWindow, ~el, ~rawRole) {
      | None => ()
      | Some(detectionMethod) =>
        let name = FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(el)
        switch passesFilters(~role, ~name, ~roleFilter, ~nameFilter) {
        | false => ()
        | true =>
          results
          ->Array.push({
            element: el,
            role,
            name,
            tag,
            detectionMethod,
            visibleText: getVisibleText(el)->truncateText,
          })
          ->ignore
        }
      }
    }
  }

  results
}

// Resolve an element by role + name (both required).
// Walks all elements, matches by computed role and accessible name.
let resolveByRoleAndName = (
  ~document: WebAPI.DOMAPI.document,
  ~role: string,
  ~name: string,
  ~index: int,
): (option<WebAPI.DOMAPI.element>, int) => {
  let lowerRole = role->String.toLowerCase
  let lowerName = name->String.toLowerCase

  let matches =
    document
    ->WebAPI.Document.querySelectorAll("*")
    ->nodeListToElements
    ->Array.filter(el => {
      switch isEffectivelyHidden(el) {
      | true => false
      | false =>
        let elRole = effectiveRole(el)->String.toLowerCase
        elRole === lowerRole &&
          FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(el)
          ->String.toLowerCase
          ->String.includes(lowerName)
      }
    })

  (matches->Array.get(index), matches->Array.length)
}

// Check whether any direct child of `el` contains `lowerText` in its visible text.
// Used to prefer leaf-ish elements over parent containers.
let childMatchesText = (el: WebAPI.DOMAPI.element, lowerText: string): bool => {
  let children = el.children
  let found = ref(false)
  let j = ref(0)
  while j.contents < children.length && !found.contents {
    let child = children->WebAPI.HTMLCollection.item(j.contents)
    // Only consider visible, accessible children — skip <style>, <script>,
    // aria-hidden="true", etc. to avoid false positives from hidden text content.
    switch isEffectivelyHidden(child) {
    | true => ()
    | false =>
      switch getVisibleText(child)->String.toLowerCase->String.includes(lowerText) {
      | true => found := true
      | false => ()
      }
    }
    j := j.contents + 1
  }
  found.contents
}

// Find all visible, accessible elements under `root` whose visible text
// contains `query` (case-insensitive). Prefers leaf-ish elements: skips
// an element if any direct child also contains the same text.
let findMatchingElements = (~root: WebAPI.DOMAPI.element, ~query: string): array<
  WebAPI.DOMAPI.element,
> => {
  let lowerQuery = query->String.toLowerCase

  root
  ->WebAPI.Element.querySelectorAll("*")
  ->nodeListToElements
  ->Array.filter(el => {
    switch isEffectivelyHidden(el) {
    | true => false
    | false =>
      let visText = getVisibleText(el)->String.toLowerCase
      // Match text, but prefer leaf-ish elements: skip if a child also matches
      // (to avoid matching a parent div when a child button has the text)
      visText->String.includes(lowerQuery) && !childMatchesText(el, lowerQuery)
    }
  })
}

// Resolve an element by visible text content.
// Walks all elements, matches by innerText substring.
let resolveByText = (~document: WebAPI.DOMAPI.document, ~text: string, ~index: int): (
  option<WebAPI.DOMAPI.element>,
  int,
) => {
  let bodyEl = document.body->WebAPI.HTMLElement.asElement
  let matches = findMatchingElements(~root=bodyEl, ~query=text)
  (matches->Array.get(index), matches->Array.length)
}

// Generate a CSS selector for an element using @medv/finder.
// Returns None if selector generation fails (e.g. detached elements).
let generateSelector = (
  ~element: WebAPI.DOMAPI.element,
  ~document: option<WebAPI.DOMAPI.document>,
): option<string> => {
  try {
    let root = switch document {
    | Some(doc) => doc.documentElement->WebAPI.HTMLElement.asElement
    | None => element
    }
    let selector = FrontmanBindings.Bindings__Finder.finder(
      ~element,
      ~options={
        root,
        idName: (~name as _) => true,
        className: (~name as _) => true,
        tagName: (~name as _) => true,
        attr: (~name as _, ~value as _) => false,
      },
    )
    Some(selector)
  } catch {
  | JsExn(_) => None
  }
}

// Describe an element for output to the agent.
// Format: "role 'name'" or "tag 'name'" or "tag" if no name.
let describeElement = (el: WebAPI.DOMAPI.element): string => {
  let label = effectiveRole(el)
  let name = FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(el)

  switch name {
  | "" => label
  | n => `${label} '${n}'`
  }
}
