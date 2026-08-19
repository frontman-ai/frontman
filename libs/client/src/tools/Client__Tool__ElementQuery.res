let effectiveRole = (element: WebAPI.DOMAPI.element): string =>
  switch FrontmanBindings.Bindings__DomAccessibilityApi.getRole(element)->Null.toOption {
  | Some(role) if role !== "" => role
  | Some(_) | None => element.tagName->String.toLowerCase
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

@get
external innerText: WebAPI.DOMAPI.element => Nullable.t<string> = "innerText"

let getVisibleText = (element: WebAPI.DOMAPI.element): string => {
  let textContent =
    (element :> WebAPI.DOMAPI.node)->WebAPI.Node.textContent->Null.toOption->Option.getOr("")
  element->innerText->Nullable.toOption->Option.getOr(textContent)
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
  | _ if interactiveRoleSet->Dict.get(role->String.toLowerCase)->Option.isSome => Some(Semantic)
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
  let elements = document->WebAPI.Document.querySelectorAll("*")->WebAPI.NodeList.toArray
  let results = []
  let index = ref(0)
  let belowLimit = () => limit->Option.mapOr(true, limit => results->Array.length < limit)
  while index.contents < elements->Array.length && belowLimit() {
    let element = elements->Array.getUnsafe(index.contents)
    index := index.contents + 1
    switch resolveInteractiveElement(~contentWindow, element) {
    | None => ()
    | Some(result) =>
      let roleMatches =
        roleFilter->Option.mapOr(true, filter =>
          result.role->String.toLowerCase === filter->String.toLowerCase
        )
      let nameMatches =
        nameFilter->Option.mapOr(true, filter =>
          result.name->String.toLowerCase->String.includes(filter->String.toLowerCase)
        )
      switch roleMatches && nameMatches {
      | true => results->Array.push(result)->ignore
      | false => ()
      }
    }
  }
  results
}

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
  element.children
  ->WebAPI.HTMLCollection.toArray
  ->Array.some(child =>
    switch isEffectivelyHidden(child) {
    | true => false
    | false => child->getVisibleText->String.toLowerCase->String.includes(lowerText)
    }
  )
}

let findMatchingElements = (~root: WebAPI.DOMAPI.element, ~query: string): array<
  WebAPI.DOMAPI.element,
> => {
  let lowerQuery = query->String.toLowerCase
  root
  ->WebAPI.Element.querySelectorAll("*")
  ->WebAPI.NodeList.toArray
  ->Array.filter(element =>
    switch isEffectivelyHidden(element) {
    | true => false
    | false =>
      element->getVisibleText->String.toLowerCase->String.includes(lowerQuery) &&
        !childMatchesText(element, lowerQuery)
    }
  )
}
