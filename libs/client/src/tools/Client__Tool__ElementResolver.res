@val
external nodeListToElements: WebAPI.DOMAPI.nodeList => array<WebAPI.DOMAPI.element> = "Array.from"

let exnMessage = (exn: exn): string =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")

type previewContext = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.previewContext

let getPreviewDoc = (): option<previewContext> => {
  let state = StateStore.getState(Client__State__Store.store)
  let previewFrame = Client__State__StateReducer.Selectors.previewFrame(state)
  switch (previewFrame.contentDocument, previewFrame.contentWindow) {
  | (Some(doc), Some(win)) => Some({doc, win})
  | _ => None
  }
}

let withPreviewDoc = (~onUnavailable: unit => 'a, fn: previewContext => 'a): 'a =>
  switch getPreviewDoc() {
  | Some(ctx) => fn(ctx)
  | None => onUnavailable()
  }

type selectorKind =
  | CssSelector(string)
  | XPathExpression(string)

let classifySelector = (selector: string): selectorKind =>
  switch selector->String.startsWith("/") || selector->String.startsWith("(") {
  | true => XPathExpression(selector)
  | false => CssSelector(selector)
  }

let resolveBySelector = (~doc: WebAPI.DOMAPI.document, ~selector: string, ~index: int=0): (
  option<WebAPI.DOMAPI.element>,
  int,
) => {
  switch classifySelector(selector) {
  | CssSelector(css) =>
    let elements = doc->WebAPI.Document.querySelectorAll(css)->nodeListToElements
    (elements->Array.get(index), elements->Array.length)
  | XPathExpression(xpath) =>
    let result =
      doc->WebAPI.Document.evaluate(
        ~expression=xpath,
        ~contextNode=(doc :> WebAPI.DOMAPI.node),
        ~type_=7,
      )
    let count = result.snapshotLength
    let element = switch index >= 0 && index < count {
    | true =>
      let node = result->WebAPI.XPathResult.snapshotItem(index)
      Some(node->WebAPI.Node.asElement)
    | false => None
    }
    (element, count)
  }
}

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

let hasShadowRoot = (el: WebAPI.DOMAPI.element): bool => el.shadowRoot->Null.toOption->Option.isSome

let effectiveRole = (el: WebAPI.DOMAPI.element): string => {
  let rawRole =
    FrontmanBindings.Bindings__DomAccessibilityApi.getRole(el)->Null.toOption->Option.getOr("")
  let tag = el.tagName->String.toLowerCase
  switch rawRole {
  | "" => tag
  | role => role
  }
}

let getOptionalRole = (el: WebAPI.DOMAPI.element): option<string> =>
  switch FrontmanBindings.Bindings__DomAccessibilityApi.getRole(el)->Null.toOption {
  | Some("") | None => None
  | some => some
  }

let getOptionalAccessibleName = (el: WebAPI.DOMAPI.element): option<string> =>
  switch FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(el) {
  | "" => None
  | n => Some(n)
  }

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

let getCursor = (win: WebAPI.DOMAPI.window, el: WebAPI.DOMAPI.element): string =>
  try {
    WebAPI.Window.getComputedStyle(win, ~elt=el).cursor
  } catch {
  | JsExn(_) => ""
  }

let hasZeroDimensions = (el: WebAPI.DOMAPI.element): bool => {
  let rect = el->WebAPI.Element.getBoundingClientRect
  rect.width <= 0.0 || rect.height <= 0.0
}

let isEffectivelyHidden = (el: WebAPI.DOMAPI.element): bool =>
  FrontmanBindings.Bindings__DomAccessibilityApi.isInaccessible(el) || hasZeroDimensions(el)

let truncateText = (text: string): option<string> => {
  let maxLen = 80
  let trimmed = text->String.trim
  switch trimmed {
  | "" => None
  | t if t->String.length > maxLen => Some(t->String.slice(~start=0, ~end=maxLen) ++ "...")
  | t => Some(t)
  }
}

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

let detectInteractivity = (
  ~contentWindow: WebAPI.DOMAPI.window,
  ~el: WebAPI.DOMAPI.element,
  ~rawRole: string,
): option<detectionMethod> =>
  switch true {
  | _ if rawRole !== "" && interactiveRoleSet->Dict.get(rawRole)->Option.isSome => Some(Semantic)
  | _ if getCursor(contentWindow, el) === "pointer" => Some(CursorPointer)
  | _ if el->WebAPI.Element.hasAttribute("tabindex") =>
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

let childMatchesText = (el: WebAPI.DOMAPI.element, lowerText: string): bool => {
  let children = el.children
  let found = ref(false)
  let j = ref(0)
  while j.contents < children.length && !found.contents {
    let child = children->WebAPI.HTMLCollection.item(j.contents)
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
      visText->String.includes(lowerQuery) && !childMatchesText(el, lowerQuery)
    }
  })
}

let resolveByText = (~document: WebAPI.DOMAPI.document, ~text: string, ~index: int): (
  option<WebAPI.DOMAPI.element>,
  int,
) => {
  let bodyEl = document.body->WebAPI.HTMLElement.asElement
  let matches = findMatchingElements(~root=bodyEl, ~query=text)
  (matches->Array.get(index), matches->Array.length)
}

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

let describeElement = (el: WebAPI.DOMAPI.element): string => {
  let label = effectiveRole(el)
  let name = FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(el)

  switch name {
  | "" => label
  | n => `${label} '${n}'`
  }
}
