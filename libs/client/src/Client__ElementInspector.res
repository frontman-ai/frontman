type t = {
  selector: result<option<string>, string>,
  cssClasses: option<string>,
  nearbyText: option<string>,
  boundingBox: Client__Annotation__Types.boundingBox,
  html: string,
  nodeCount: int,
  truncated: bool,
}

type walkState = {
  lines: array<string>,
  mutable nodeCount: int,
  mutable truncated: bool,
  maxNodes: int,
}

let keyAttributes = ["id", "class", "data-testid", "href", "src", "type", "placeholder", "alt"]

@scope("Array") @val
external collectionToArray: 'collection => array<'item> = "from"

let quote = value => JSON.stringifyAny(value)->Option.getOr(`""`)

let truncate = (text: string, ~maxLen: int): string =>
  switch text->String.length > maxLen {
  | true => text->String.slice(~start=0, ~end=maxLen) ++ "..."
  | false => text
  }

let errorMessage = (exn: exn): string =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")

let findSelector = (
  ~element: WebAPI.DOMAPI.element,
  ~document: option<WebAPI.DOMAPI.document>,
): result<string, string> =>
  try {
    let root = switch document {
    | Some(document) => document.documentElement->WebAPI.HTMLElement.asElement
    | None => element
    }
    Ok(
      FrontmanBindings.Bindings__Finder.finder(
        ~element,
        ~options={
          root,
          idName: (~name as _) => true,
          className: (~name as _) => true,
          tagName: (~name as _) => true,
          attr: (~name as _, ~value as _) => false,
        },
      ),
    )
  } catch {
  | exn => Error(errorMessage(exn))
  }

let childElements = (element: WebAPI.DOMAPI.element, ~pierceShadowDom: bool): array<
  WebAPI.DOMAPI.element,
> => {
  let result: array<WebAPI.DOMAPI.element> = collectionToArray(element.children)
  switch (pierceShadowDom, element.shadowRoot->Null.toOption) {
  | (true, Some(shadowRoot)) =>
    shadowRoot.childNodes
    ->collectionToArray
    ->Array.filterMap((node: WebAPI.DOMAPI.node) =>
      switch node.nodeType === 1 {
      | true => Some(node->WebAPI.Node.asElement)
      | false => None
      }
    )
    ->Array.forEach(element => result->Array.push(element)->ignore)
  | _ => ()
  }
  result
}

let directText = (element: WebAPI.DOMAPI.element): string => {
  let node = element->WebAPI.Element.asNode
  node.childNodes
  ->collectionToArray
  ->Array.filterMap((node: WebAPI.DOMAPI.node) =>
    switch node.nodeType === 3 {
    | false => None
    | true =>
      switch node.nodeValue->Null.toOption->Option.getOr("")->String.trim {
      | "" => None
      | text => Some(text)
      }
    }
  )
  ->Array.join(" ")
}

let pushField = (fields: array<string>, name: string, value: string): unit =>
  fields->Array.push(`${name}=${value->truncate(~maxLen=80)->quote}`)->ignore

let describe = (
  ~relation: string,
  ~element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
  ~pierceShadowDom: bool,
): (string, array<WebAPI.DOMAPI.element>) => {
  let fields = [relation]
  pushField(fields, "tag", element.tagName->String.toLowerCase)
  keyAttributes->Array.forEach(name =>
    switch element->WebAPI.Element.getAttribute(name)->Null.toOption {
    | Some(value) => pushField(fields, name, value)
    | None => ()
    }
  )
  switch findSelector(~element, ~document=Some(document)) {
  | Ok(selector) => pushField(fields, "selector", selector)
  | Error(_) => ()
  }
  switch Client__ComponentName.getForElement(
    element,
    ~window=?document.defaultView->Null.toOption,
  ) {
  | Some(component) => pushField(fields, "component", component)
  | None => ()
  }
  switch FrontmanBindings.Bindings__DomAccessibilityApi.getRole(element)->Null.toOption {
  | Some(role) => pushField(fields, "role", role)
  | None => ()
  }
  switch FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(element) {
  | "" => ()
  | name => pushField(fields, "name", name)
  }
  switch element.tagName->String.toLowerCase {
  | "script" | "style" | "svg" => ()
  | _ =>
    switch directText(element) {
    | "" => ()
    | text => pushField(fields, "text", text)
    }
  }
  let children = childElements(element, ~pierceShadowDom)
  fields->Array.push(`children=${children->Array.length->Int.toString}`)->ignore
  switch pierceShadowDom && element.shadowRoot->Null.toOption->Option.isSome {
  | true => fields->Array.push("shadow=true")->ignore
  | false => ()
  }
  (fields->Array.join(" "), children)
}

let rec walk = (
  ~element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
  ~depth: int,
  ~maxDepth: int,
  ~pierceShadowDom: bool,
  ~state: walkState,
): unit =>
  switch state.nodeCount >= state.maxNodes {
  | true => state.truncated = true
  | false =>
    state.nodeCount = state.nodeCount + 1
    let (description, children) = describe(
      ~relation=switch depth {
      | 0 => "selected"
      | _ => "child"
      },
      ~element,
      ~document,
      ~pierceShadowDom,
    )
    state.lines->Array.push("  "->String.repeat(depth) ++ description)->ignore
    switch depth < maxDepth {
    | true =>
      children->Array.forEach(child =>
        walk(~element=child, ~document, ~depth=depth + 1, ~maxDepth, ~pierceShadowDom, ~state)
      )
    | false => ()
    }
  }

let optionalTrimmed = (value: Null.t<string>): option<string> =>
  switch value->Null.toOption->Option.map(String.trim) {
  | Some("") | None => None
  | value => value
  }

let inspect = (
  ~element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
  ~maxDepth: int,
  ~maxNodes: int,
  ~pierceShadowDom: bool,
): t => {
  let state = {lines: [], nodeCount: 0, truncated: false, maxNodes}
  walk(~element, ~document, ~depth=0, ~maxDepth, ~pierceShadowDom, ~state)
  let parent = switch element.parentElement->Null.toOption {
  | Some(parent) =>
    let (description, _) = describe(
      ~relation="parent",
      ~element=parent->WebAPI.HTMLElement.asElement,
      ~document,
      ~pierceShadowDom=false,
    )
    description
  | None => "parent none"
  }
  switch state.truncated {
  | true => state.lines->Array.push(`truncated nodes=${state.nodeCount->Int.toString}`)->ignore
  | false => ()
  }
  let rect = element->WebAPI.Element.getBoundingClientRect
  {
    selector: findSelector(~element, ~document=Some(document))->Result.map(selector => Some(
      selector,
    )),
    cssClasses: element->WebAPI.Element.getAttribute("class")->optionalTrimmed,
    nearbyText: element
    ->WebAPI.Element.asNode
    ->WebAPI.Node.textContent
    ->optionalTrimmed
    ->Option.map(text => text->truncate(~maxLen=200)),
    boundingBox: {x: rect.left, y: rect.top, width: rect.width, height: rect.height},
    html: [parent, ...state.lines]->Array.join("\n"),
    nodeCount: state.nodeCount,
    truncated: state.truncated,
  }
}
