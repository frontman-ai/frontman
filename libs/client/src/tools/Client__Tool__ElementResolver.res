// Shared helpers for element discovery and resolution in browser tools.
// Used by GetInteractiveElements and InteractWithElement tools.

// Convert a NodeList to an array of elements. NodeList has no toArray binding
// in @rescript/webapi, so we use a small typed external for Array.from.
@val external nodeListToElements: WebAPI.DOMAPI.nodeList => array<WebAPI.DOMAPI.element> = "Array.from"

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
let getCursor = (win: WebAPI.DOMAPI.window, el: WebAPI.DOMAPI.element): string =>
  try {
    WebAPI.Window.getComputedStyle(win, ~elt=el).cursor
  } catch {
  | _ => ""
  }

// Check if an element has zero dimensions (invisible)
let hasZeroDimensions = (el: WebAPI.DOMAPI.element): bool => {
  let rect = el->WebAPI.Element.getBoundingClientRect
  rect.width <= 0.0 || rect.height <= 0.0
}

// Truncate text to a reasonable length for LLM context
let truncateText = (text: string, ~maxLen: int=80): option<string> => {
  let trimmed = text->String.trim
  switch trimmed {
  | "" => None
  | t if t->String.length > maxLen => Some(t->String.slice(~start=0, ~end=maxLen) ++ "...")
  | t => Some(t)
  }
}

// Get visible text content from an element (innerText preferred, falls back to textContent).
// Cast to htmlElement for innerText access; textContent is on node.
let getVisibleText = (el: WebAPI.DOMAPI.element): string =>
  try {
    let htmlEl: WebAPI.DOMAPI.htmlElement = el->Obj.magic
    switch WebAPI.HTMLElement.innerText(htmlEl) {
    | "" =>
      (el :> WebAPI.DOMAPI.node)->WebAPI.Node.textContent->Null.toOption->Option.getOr("")
    | text => text
    }
  } catch {
  | _ => ""
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
    tabVal >= 0 ? Some(Tabindex) : None
  | _ => None
  }

// Check whether an element passes the optional role and name filters.
let passesFilters = (~role: string, ~name: string, ~roleFilter: option<string>, ~nameFilter: option<string>): bool => {
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
  ~maxElements: int=50,
): array<resolvedElement> => {
  let allElements = document->WebAPI.Document.querySelectorAll("*")->nodeListToElements
  let results: array<resolvedElement> = []

  let i = ref(0)
  while i.contents < allElements->Array.length && results->Array.length < maxElements {
    let el = allElements->Array.getUnsafe(i.contents)
    i := i.contents + 1

    if !Bindings__DomAccessibilityApi.isInaccessible(el) && !hasZeroDimensions(el) {
      let rawRole = Bindings__DomAccessibilityApi.getRole(el)->Null.toOption->Option.getOr("")
      let tag = el.tagName->String.toLowerCase
      // Use tag name as fallback when ARIA role is empty (e.g. cursor:pointer divs).
      // This "effective role" is used consistently for filtering, resolution, and output
      // so the agent can target elements by the same role value shown in discovery.
      let role = rawRole === "" ? tag : rawRole

      switch detectInteractivity(~contentWindow, ~el, ~rawRole) {
      | None => ()
      | Some(detectionMethod) =>
        let name = Bindings__DomAccessibilityApi.computeAccessibleName(el)
        if passesFilters(~role, ~name, ~roleFilter, ~nameFilter) {
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
  ~index: int=0,
): (option<WebAPI.DOMAPI.element>, int) => {
  let lowerRole = role->String.toLowerCase
  let lowerName = name->String.toLowerCase

  let matches =
    document
    ->WebAPI.Document.querySelectorAll("*")
    ->nodeListToElements
    ->Array.filter(el => {
      if Bindings__DomAccessibilityApi.isInaccessible(el) || hasZeroDimensions(el) {
        false
      } else {
        let rawRole =
          Bindings__DomAccessibilityApi.getRole(el)
          ->Null.toOption
          ->Option.getOr("")
          ->String.toLowerCase
        let tag = el.tagName->String.toLowerCase
        let elRole = rawRole === "" ? tag : rawRole
        elRole === lowerRole &&
          Bindings__DomAccessibilityApi.computeAccessibleName(el)
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
    if !Bindings__DomAccessibilityApi.isInaccessible(child) && !hasZeroDimensions(child) {
      if getVisibleText(child)->String.toLowerCase->String.includes(lowerText) {
        found := true
      }
    }
    j := j.contents + 1
  }
  found.contents
}

// Resolve an element by visible text content.
// Walks all elements, matches by innerText substring.
let resolveByText = (
  ~document: WebAPI.DOMAPI.document,
  ~text: string,
  ~index: int=0,
): (option<WebAPI.DOMAPI.element>, int) => {
  let lowerText = text->String.toLowerCase

  let matches =
    document
    ->WebAPI.Document.querySelectorAll("*")
    ->nodeListToElements
    ->Array.filter(el => {
      if Bindings__DomAccessibilityApi.isInaccessible(el) || hasZeroDimensions(el) {
        false
      } else {
        let visText = getVisibleText(el)->String.toLowerCase
        // Match text, but prefer leaf-ish elements: skip if a child also matches
        // (to avoid matching a parent div when a child button has the text)
        visText->String.includes(lowerText) && !childMatchesText(el, lowerText)
      }
    })

  (matches->Array.get(index), matches->Array.length)
}

// Generate a CSS selector for an element using @medv/finder.
// Returns None if selector generation fails.
let generateSelector = (
  ~element: WebAPI.DOMAPI.element,
  ~document: option<WebAPI.DOMAPI.document>,
): option<string> => {
  try {
    let selector = Bindings__Finder.finder(
      ~element,
      ~options={
        root: document
        ->Option.map(doc => doc.documentElement->Obj.magic)
        ->Option.getOr(element),
        idName: (~name as _) => true,
        className: (~name as _) => true,
        tagName: (~name as _) => true,
        attr: (~name as _, ~value as _) => false,
      },
    )
    Some(selector)
  } catch {
  | _ => None
  }
}

// Describe an element for output to the agent.
// Format: "role 'name'" or "tag 'name'" or "tag" if no name.
let describeElement = (el: WebAPI.DOMAPI.element): string => {
  let role =
    Bindings__DomAccessibilityApi.getRole(el)->Null.toOption->Option.getOr("")
  let name = Bindings__DomAccessibilityApi.computeAccessibleName(el)
  let tag = el.tagName->String.toLowerCase
  let label = role === "" ? tag : role

  switch name {
  | "" => label
  | n => `${label} '${n}'`
  }
}
