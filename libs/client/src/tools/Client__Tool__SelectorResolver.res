let shadowPathSeparator = " >>> "

type selectorKind =
  | CssSelector(string)
  | XPathExpression(string)

let classifySelector = (selector: string): selectorKind =>
  switch selector->String.startsWith("/") || selector->String.startsWith("(") {
  | true => XPathExpression(selector)
  | false => CssSelector(selector)
  }

let parseShadowIndexes = (segment: string): array<int> =>
  segment
  ->String.split("/")
  ->Array.map(value =>
    switch value->String.trim->Int.fromString {
    | Some(index) if index > 0 => index
    | _ => JsError.throwWithMessage(`Invalid shadow path segment: ${segment}`)
    }
  )

let resolveShadowSegment = (root: WebAPI.DomTypes.shadowRoot, segment: string): option<
  WebAPI.DomTypes.element,
> => {
  let children = ref(root->WebAPI.ShadowRoot.children->WebAPI.HTMLCollection.toArray)
  let selected = ref(None)
  segment
  ->parseShadowIndexes
  ->Array.forEach(index =>
    switch children.contents->Array.get(index - 1) {
    | Some(element) => {
        selected := Some(element)
        children := element.children->WebAPI.HTMLCollection.toArray
      }
    | None => {
        selected := None
        children := []
      }
    }
  )
  selected.contents
}

let resolveShadowPath = (~doc: WebAPI.DomTypes.document, ~segments: array<string>): array<
  WebAPI.DomTypes.element,
> =>
  segments
  ->Array.slice(~start=1, ~end=segments->Array.length)
  ->Array.reduce(
    doc
    ->WebAPI.Document.querySelectorAll(segments->Array.getUnsafe(0))
    ->WebAPI.NodeList.toArray,
    (hosts, segment) =>
      hosts->Array.filterMap(host =>
        host.shadowRoot
        ->Null.toOption
        ->Option.flatMap(root => resolveShadowSegment(root, segment->String.trim))
      ),
  )

let resolveCssSelector = (~doc: WebAPI.DomTypes.document, ~selector: string): array<
  WebAPI.DomTypes.element,
> =>
  try {
    doc->WebAPI.Document.querySelectorAll(selector)->WebAPI.NodeList.toArray
  } catch {
  | JsExn(_) =>
    let segments = selector->String.split(shadowPathSeparator)
    switch segments->Array.length > 1 {
    | true => resolveShadowPath(~doc, ~segments)
    | false => doc->WebAPI.Document.querySelectorAll(selector)->WebAPI.NodeList.toArray
    }
  }

let resolveXPath = (~doc: WebAPI.DomTypes.document, ~xpath: string): array<
  WebAPI.DomTypes.element,
> => {
  let snapshot =
    doc->WebAPI.Document.evaluate(
      ~expression=xpath,
      ~contextNode=(doc :> WebAPI.DomTypes.node),
      ~type_=7,
    )
  let elements = []
  let index = ref(0)
  while index.contents < snapshot.snapshotLength {
    let node = snapshot->WebAPI.XPathResult.snapshotItem(index.contents)
    switch node.nodeType === 1 {
    | true =>
      node
      ->FrontmanBindings.Bindings__WebAPI.elementFromNode
      ->Option.forEach(element => elements->Array.push(element)->ignore)
    | false => ()
    }
    index := index.contents + 1
  }
  elements
}

let resolveBySelector = (~doc: WebAPI.DomTypes.document, ~selector: string, ~index: int=0): (
  option<WebAPI.DomTypes.element>,
  int,
) => {
  let elements = try {
    switch classifySelector(selector) {
    | CssSelector(css) => resolveCssSelector(~doc, ~selector=css)
    | XPathExpression(xpath) => resolveXPath(~doc, ~xpath)
    }
  } catch {
  | JsExn(_) => []
  }
  (elements->Array.get(index), elements->Array.length)
}

let resolveRootOrBody = (~doc: WebAPI.DomTypes.document, ~selector: option<string>): result<
  WebAPI.DomTypes.element,
  string,
> =>
  switch selector {
  | Some(selector) =>
    switch resolveBySelector(~doc, ~selector) {
    | (Some(element), _) => Ok(element)
    | (None, _) => Error(`No element found for selector: ${selector}`)
    }
  | None => Ok(doc.body->WebAPI.HTMLElement.asElement)
  }
