@val
external nodeListToElements: WebAPI.DOMAPI.nodeList => array<WebAPI.DOMAPI.element> = "Array.from"

let effectiveRole = (element: WebAPI.DOMAPI.element): string =>
  switch FrontmanBindings.Bindings__DomAccessibilityApi.getRole(element)->Null.toOption {
  | Some(role) if role !== "" => role
  | Some(_) | None => element.tagName->String.toLowerCase
  }

let getOptionalRole = (element: WebAPI.DOMAPI.element): option<string> =>
  switch FrontmanBindings.Bindings__DomAccessibilityApi.getRole(element)->Null.toOption {
  | Some("") | None => None
  | role => role
  }

let getOptionalAccessibleName = (element: WebAPI.DOMAPI.element): option<string> =>
  switch FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(element) {
  | "" => None
  | name => Some(name)
  }

let interactiveRoleSet =
  [
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
  ->Array.map(role => (role, true))
  ->Dict.fromArray

type detectionMethod =
  | Semantic
  | CursorPointer
  | Tabindex

let detectionMethodToString = method =>
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

let isEffectivelyHidden = (element: WebAPI.DOMAPI.element): bool => {
  let rect = element->WebAPI.Element.getBoundingClientRect
  FrontmanBindings.Bindings__DomAccessibilityApi.isInaccessible(element) ||
  rect.width <= 0.0 ||
  rect.height <= 0.0
}

let getVisibleText = (element: WebAPI.DOMAPI.element): string =>
  switch element->WebAPI.Element.asHTMLElement->WebAPI.HTMLElement.innerText {
  | "" => (element :> WebAPI.DOMAPI.node)->WebAPI.Node.textContent->Null.toOption->Option.getOr("")
  | text => text
  }

let truncateText = (text: string): option<string> =>
  switch text->String.trim {
  | "" => None
  | text if text->String.length > 80 => Some(text->String.slice(~start=0, ~end=80) ++ "...")
  | text => Some(text)
  }

let detectInteractivity = (
  ~contentWindow: WebAPI.DOMAPI.window,
  ~element: WebAPI.DOMAPI.element,
  ~role: string,
): option<detectionMethod> =>
  switch true {
  | _ if role !== "" && interactiveRoleSet->Dict.get(role)->Option.isSome => Some(Semantic)
  | _ if WebAPI.Window.getComputedStyle(contentWindow, ~elt=element).cursor === "pointer" =>
    Some(CursorPointer)
  | _ if element->WebAPI.Element.hasAttribute("tabindex") =>
    switch element
    ->WebAPI.Element.getAttribute("tabindex")
    ->Null.toOption
    ->Option.flatMap(value => value->Int.fromString(~radix=10)) {
    | Some(value) if value >= 0 => Some(Tabindex)
    | Some(_) | None => None
    }
  | _ => None
  }

let passesFilters = (
  ~role: string,
  ~name: string,
  ~roleFilter: option<string>,
  ~nameFilter: option<string>,
): bool => {
  let roleMatches = roleFilter->Option.mapOr(true, filter => role === filter->String.toLowerCase)
  let nameMatches =
    nameFilter->Option.mapOr(true, filter =>
      name->String.toLowerCase->String.includes(filter->String.toLowerCase)
    )
  roleMatches && nameMatches
}

let resolveInteractiveElement = (
  ~contentWindow: WebAPI.DOMAPI.window,
  element: WebAPI.DOMAPI.element,
): option<resolvedElement> =>
  switch isEffectivelyHidden(element) {
  | true => None
  | false =>
    let rawRole =
      FrontmanBindings.Bindings__DomAccessibilityApi.getRole(element)
      ->Null.toOption
      ->Option.getOr("")
    switch detectInteractivity(~contentWindow, ~element, ~role=rawRole) {
    | None => None
    | Some(detectionMethod) =>
      Some({
        element,
        role: effectiveRole(element),
        name: FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(element),
        tag: element.tagName->String.toLowerCase,
        detectionMethod,
        visibleText: element->getVisibleText->truncateText,
      })
    }
  }

let queryInteractiveElements = (
  ~document: WebAPI.DOMAPI.document,
  ~contentWindow: WebAPI.DOMAPI.window,
  ~roleFilter: option<string>,
  ~nameFilter: option<string>,
  ~limit: option<int>,
): array<resolvedElement> => {
  let elements = document->WebAPI.Document.querySelectorAll("*")->nodeListToElements
  let results = []
  let index = ref(0)
  let belowLimit = () => limit->Option.mapOr(true, limit => results->Array.length < limit)
  while index.contents < elements->Array.length && belowLimit() {
    let element = elements->Array.getUnsafe(index.contents)
    index := index.contents + 1
    switch resolveInteractiveElement(~contentWindow, element) {
    | Some(result)
      if passesFilters(~role=result.role, ~name=result.name, ~roleFilter, ~nameFilter) =>
      results->Array.push(result)->ignore
    | Some(_) | None => ()
    }
  }
  results
}

let collectInteractiveElements = (
  ~document: WebAPI.DOMAPI.document,
  ~contentWindow: WebAPI.DOMAPI.window,
  ~roleFilter: option<string>=?,
  ~nameFilter: option<string>=?,
  ~maxElements: int,
): array<resolvedElement> =>
  queryInteractiveElements(
    ~document,
    ~contentWindow,
    ~roleFilter,
    ~nameFilter,
    ~limit=Some(maxElements),
  )

let resolveByRoleAndName = (
  ~document: WebAPI.DOMAPI.document,
  ~contentWindow: WebAPI.DOMAPI.window,
  ~role: string,
  ~name: string,
  ~index: int,
): (option<WebAPI.DOMAPI.element>, int) => {
  let matches = queryInteractiveElements(
    ~document,
    ~contentWindow,
    ~roleFilter=Some(role),
    ~nameFilter=Some(name),
    ~limit=None,
  )
  (matches->Array.get(index)->Option.map(match => match.element), matches->Array.length)
}

let childMatchesText = (element: WebAPI.DOMAPI.element, lowerText: string): bool => {
  let children = element.children
  let found = ref(false)
  let index = ref(0)
  while index.contents < children.length && !found.contents {
    let child = children->WebAPI.HTMLCollection.item(index.contents)
    switch isEffectivelyHidden(child) {
    | true => ()
    | false => found := child->getVisibleText->String.toLowerCase->String.includes(lowerText)
    }
    index := index.contents + 1
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
  ->Array.filter(element =>
    switch isEffectivelyHidden(element) {
    | true => false
    | false =>
      element->getVisibleText->String.toLowerCase->String.includes(lowerQuery) &&
        !childMatchesText(element, lowerQuery)
    }
  )
}

let resolveByText = (~document: WebAPI.DOMAPI.document, ~text: string, ~index: int): (
  option<WebAPI.DOMAPI.element>,
  int,
) => {
  let matches = findMatchingElements(~root=document.body->WebAPI.HTMLElement.asElement, ~query=text)
  (matches->Array.get(index), matches->Array.length)
}

let generateSelector = (
  ~element: WebAPI.DOMAPI.element,
  ~document: option<WebAPI.DOMAPI.document>,
): option<string> =>
  switch Client__ElementInspector.findSelector(~element, ~document) {
  | Ok(selector) => Some(selector)
  | Error(_) => None
  }

let describeElement = (element: WebAPI.DOMAPI.element): string => {
  let label = effectiveRole(element)
  switch FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(element) {
  | "" => label
  | name => `${label} '${name}'`
  }
}
