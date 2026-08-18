@val
external nodeListToElements: WebAPI.DOMAPI.nodeList => array<WebAPI.DOMAPI.element> = "Array.from"

@val
external collectionToElements: 'collection => array<WebAPI.DOMAPI.element> = "Array.from"

@get
external shadowElementChildren: WebAPI.DOMAPI.shadowRoot => WebAPI.DOMAPI.nodeList = "children"

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

let resolveShadowSegment = (root: WebAPI.DOMAPI.shadowRoot, segment: string): option<
  WebAPI.DOMAPI.element,
> => {
  let children = ref(root->shadowElementChildren->nodeListToElements)
  let selected = ref(None)
  segment
  ->parseShadowIndexes
  ->Array.forEach(index =>
    switch children.contents->Array.get(index - 1) {
    | Some(element) => {
        selected := Some(element)
        children := element.children->collectionToElements
      }
    | None => {
        selected := None
        children := []
      }
    }
  )
  selected.contents
}

let resolveShadowPath = (~doc: WebAPI.DOMAPI.document, ~segments: array<string>): array<
  WebAPI.DOMAPI.element,
> =>
  segments
  ->Array.slice(~start=1, ~end=segments->Array.length)
  ->Array.reduce(
    doc->WebAPI.Document.querySelectorAll(segments->Array.getUnsafe(0))->nodeListToElements,
    (hosts, segment) =>
      hosts->Array.filterMap(host =>
        host.shadowRoot
        ->Null.toOption
        ->Option.flatMap(root => resolveShadowSegment(root, segment->String.trim))
      ),
  )

let resolveCssSelector = (~doc: WebAPI.DOMAPI.document, ~selector: string): array<
  WebAPI.DOMAPI.element,
> =>
  try {
    doc->WebAPI.Document.querySelectorAll(selector)->nodeListToElements
  } catch {
  | JsExn(_) =>
    let segments = selector->String.split(shadowPathSeparator)
    switch segments->Array.length > 1 {
    | true => resolveShadowPath(~doc, ~segments)
    | false => doc->WebAPI.Document.querySelectorAll(selector)->nodeListToElements
    }
  }

let resolveXPath = (~doc: WebAPI.DOMAPI.document, ~xpath: string): array<WebAPI.DOMAPI.element> => {
  let snapshot =
    doc->WebAPI.Document.evaluate(
      ~expression=xpath,
      ~contextNode=(doc :> WebAPI.DOMAPI.node),
      ~type_=7,
    )
  let elements = []
  let index = ref(0)
  while index.contents < snapshot.snapshotLength {
    let node = snapshot->WebAPI.XPathResult.snapshotItem(index.contents)
    switch node.nodeType === 1 {
    | true => elements->Array.push(node->WebAPI.Node.asElement)->ignore
    | false => ()
    }
    index := index.contents + 1
  }
  elements
}

let resolveBySelector = (~doc: WebAPI.DOMAPI.document, ~selector: string, ~index: int=0): (
  option<WebAPI.DOMAPI.element>,
  int,
) => {
  let elements = switch classifySelector(selector) {
  | CssSelector(css) => resolveCssSelector(~doc, ~selector=css)
  | XPathExpression(xpath) => resolveXPath(~doc, ~xpath)
  }
  (elements->Array.get(index), elements->Array.length)
}

let resolveRootOrBody = (~doc: WebAPI.DOMAPI.document, ~selector: option<string>): result<
  WebAPI.DOMAPI.element,
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
