module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview
module WebStreams = FrontmanBindings.WebStreams

let fullModeMaxBytes = 15_000
let maxOutputBytes = 30_000
let defaultMaxDepth = 1
let defaultMaxNodes = 200
let hardMaxNodes = 500
let shadowPathSeparator = " >>> "
let keyAttributes = ["id", "class", "data-testid", "href", "src", "type", "placeholder", "alt"]

let utf8ByteSize = WebStreams.utf8ByteSize
let quote = value => JSON.stringifyAny(value)->Option.getOr(`""`)
let truncate = (text: string, ~maxLen: int): string =>
  switch text->String.length > maxLen {
  | true => text->String.slice(~start=0, ~end=maxLen) ++ "..."
  | false => text
  }

let errorMessage = exn =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")

type selectorKind = CssSelector(string) | XPathExpression(string)
let classifySelector = selector =>
  switch selector->String.startsWith("/") || selector->String.startsWith("(") {
  | true => XPathExpression(selector)
  | false => CssSelector(selector)
  }

let parseShadowIndexes = segment =>
  segment
  ->String.split("/")
  ->Array.map(value =>
    switch value->String.trim->Int.fromString {
    | Some(index) if index > 0 => index
    | _ => JsError.throwWithMessage(`Invalid shadow path segment: ${segment}`)
    }
  )

let resolveShadowSegment = (root: WebAPI.DomTypes.shadowRoot, segment: string) => {
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

let resolveCssSelector = (~doc, ~selector) =>
  try {
    doc->WebAPI.Document.querySelectorAll(selector)->WebAPI.NodeList.toArray
  } catch {
  | JsExn(_) =>
    let segments = selector->String.split(shadowPathSeparator)
    switch segments->Array.length > 1 {
    | false => doc->WebAPI.Document.querySelectorAll(selector)->WebAPI.NodeList.toArray
    | true =>
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
    }
  }

let resolveXPath = (~doc, ~xpath) => {
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
    switch node->FrontmanBindings.Bindings__WebAPI.elementFromNode {
    | Some(element) => elements->Array.push(element)->ignore
    | None => ()
    }
    index := index.contents + 1
  }
  elements
}

let resolveBySelector = (~doc, ~selector) => {
  let elements = switch classifySelector(selector) {
  | CssSelector(css) => resolveCssSelector(~doc, ~selector=css)
  | XPathExpression(xpath) => resolveXPath(~doc, ~xpath)
  }
  (elements->Array.get(0), elements->Array.length)
}

let stripUrlSecrets = value => {
  let value = value->String.trim
  try {
    let protocolRelative = value->String.startsWith("//")
    let url = switch protocolRelative {
    | true => WebAPI.URL.make(~url=value, ~base="https://redaction.invalid")
    | false => WebAPI.URL.make(~url=value)
    }
    switch url.protocol->String.toLowerCase {
    | "blob:" | "data:" => "[redacted]"
    | _ => {
        url.username = ""
        url.password = ""
        url.search = ""
        url.hash = ""
        switch protocolRelative {
        | true => `//${url.host}${url.pathname}`
        | false => url.href
        }
      }
    }
  } catch {
  | _ =>
    value
    ->String.split("?")
    ->Array.get(0)
    ->Option.getOrThrow
    ->String.split("#")
    ->Array.get(0)
    ->Option.getOrThrow
  }
}

let directText = (element: WebAPI.DomTypes.element) =>
  (element->WebAPI.Element.asNode).childNodes
  ->WebAPI.NodeList.toArray
  ->Array.filterMap((node: WebAPI.DomTypes.node) =>
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

let contextText = (element: WebAPI.DomTypes.element) =>
  switch element.tagName->String.toLowerCase {
  | "input" | "script" | "style" | "svg" | "textarea" => ""
  | _ => directText(element)
  }

type childRelation =
  | LightChild(int)
  | ShadowChild(int)

type walkChild = {
  element: WebAPI.DomTypes.element,
  relation: childRelation,
}

let childElements = (~element: WebAPI.DomTypes.element, ~pierceShadowDom): array<walkChild> => {
  let light =
    element.children
    ->WebAPI.HTMLCollection.toArray
    ->Array.mapWithIndex((child, index) => {element: child, relation: LightChild(index + 1)})
  switch (pierceShadowDom, element.shadowRoot->Null.toOption) {
  | (true, Some(shadowRoot)) =>
    light->Array.concat(
      shadowRoot
      ->WebAPI.ShadowRoot.children
      ->WebAPI.HTMLCollection.toArray
      ->Array.mapWithIndex((child, index) => {element: child, relation: ShadowChild(index + 1)}),
    )
  | _ => light
  }
}

let pushField = (fields, name, value) =>
  fields->Array.push(`${name}=${value->truncate(~maxLen=80)->quote}`)->ignore

let rec selectorForElement = (
  ~element: WebAPI.DomTypes.element,
  ~document: WebAPI.DomTypes.document,
) => {
  let tag = element.tagName->String.toLowerCase
  switch element->WebAPI.Element.getAttribute("id")->Null.toOption {
  | Some(id) if id !== "" => Some(`[id=${id->quote}]`)
  | Some(_) | None =>
    switch document->WebAPI.Document.querySelectorAll(tag)->WebAPI.NodeList.toArray->Array.length {
    | 1 => Some(tag)
    | _ =>
      switch element.parentElement->Null.toOption {
      | None => Some(tag)
      | Some(parent) =>
        let parent = parent->WebAPI.HTMLElement.asElement
        let siblings = parent.children->WebAPI.HTMLCollection.toArray
        let index = siblings->Array.findIndex(sibling => sibling == element)
        switch selectorForElement(~element=parent, ~document) {
        | Some(parentSelector) if index >= 0 =>
          Some(`${parentSelector} > :nth-child(${(index + 1)->Int.toString})`)
        | _ => None
        }
      }
    }
  }
}

let describe = (~relation, ~element: WebAPI.DomTypes.element, ~selector, ~pierceShadowDom) => {
  let fields = [relation]
  pushField(fields, "tag", element.tagName->String.toLowerCase)
  keyAttributes->Array.forEach(name =>
    switch element->WebAPI.Element.getAttribute(name)->Null.toOption {
    | Some(value) =>
      pushField(
        fields,
        name,
        switch name {
        | "href" | "src" => stripUrlSecrets(value)
        | _ => value
        },
      )
    | None => ()
    }
  )
  selector->Option.forEach(selector => fields->Array.push(`selector=${selector->quote}`)->ignore)
  FrontmanBindings.Bindings__DomAccessibilityApi.getRole(element)
  ->Null.toOption
  ->Option.forEach(role => pushField(fields, "role", role))
  switch FrontmanBindings.Bindings__DomAccessibilityApi.computeAccessibleName(element) {
  | "" => ()
  | name => pushField(fields, "name", name)
  }
  switch contextText(element) {
  | "" => ()
  | text => pushField(fields, "text", text)
  }
  let children = childElements(~element, ~pierceShadowDom)
  fields->Array.push(`children=${children->Array.length->Int.toString}`)->ignore
  (fields->Array.join(" "), children)
}

type walkState = {
  lines: array<string>,
  mutable nodeCount: int,
  mutable byteSize: int,
  mutable truncated: bool,
  maxNodes: int,
  maxBytes: int,
  encoder: WebStreams.textEncoder,
}

let appendLine = (state, line) => {
  let separatorBytes = state.lines->Array.length === 0 ? 0 : 1
  let lineBytes = state.encoder->WebStreams.encode(line)->WebStreams.byteLength
  switch state.byteSize + separatorBytes + lineBytes > state.maxBytes {
  | true => {
      state.truncated = true
      false
    }
  | false => {
      state.lines->Array.push(line)->ignore
      state.byteSize = state.byteSize + separatorBytes + lineBytes
      true
    }
  }
}

let rec walk = (
  ~element,
  ~selector,
  ~depth,
  ~maxDepth,
  ~pierceShadowDom,
  ~insideShadowDom,
  ~state,
) =>
  switch state.truncated || state.nodeCount >= state.maxNodes {
  | true => state.truncated = true
  | false =>
    let (line, children) = describe(
      ~relation=depth === 0 ? "selected" : "child",
      ~element,
      ~selector,
      ~pierceShadowDom,
    )
    switch appendLine(state, "  "->String.repeat(depth) ++ line) {
    | false => ()
    | true => {
        state.nodeCount = state.nodeCount + 1
        switch depth < maxDepth {
        | false => ()
        | true =>
          children->Array.forEach(child =>
            walk(
              ~element=child.element,
              ~selector=selector->Option.map(selector =>
                switch (child.relation, insideShadowDom) {
                | (ShadowChild(index), _) => `${selector} >>> ${index->Int.toString}`
                | (LightChild(index), true) => `${selector}/${index->Int.toString}`
                | (LightChild(index), false) => `${selector} > :nth-child(${index->Int.toString})`
                }
              ),
              ~depth=depth + 1,
              ~maxDepth,
              ~pierceShadowDom,
              ~insideShadowDom=switch child.relation {
              | ShadowChild(_) => true
              | LightChild(_) => insideShadowDom
              },
              ~state,
            )
          )
        }
      }
    }
  }

let inspect = (
  ~element: WebAPI.DomTypes.element,
  ~document: WebAPI.DomTypes.document,
  ~selector,
  ~maxDepth,
  ~maxNodes,
  ~pierceShadowDom,
) => {
  let state = {
    lines: [],
    nodeCount: 0,
    byteSize: 0,
    truncated: false,
    maxNodes,
    maxBytes: maxOutputBytes - 32,
    encoder: WebStreams.makeTextEncoder(),
  }
  switch element.parentElement->Null.toOption {
  | Some(parent) =>
    let parent = parent->WebAPI.HTMLElement.asElement
    let (line, _) = describe(
      ~relation="parent",
      ~element=parent,
      ~selector=selectorForElement(~element=parent, ~document),
      ~pierceShadowDom=false,
    )
    appendLine(state, line)->ignore
  | None => appendLine(state, "parent none")->ignore
  }
  walk(
    ~element,
    ~selector,
    ~depth=0,
    ~maxDepth,
    ~pierceShadowDom,
    ~insideShadowDom=selector->Option.mapOr(false, selector => selector->String.includes(" >>> ")),
    ~state,
  )
  switch state.truncated {
  | true => state.lines->Array.push(`truncated nodes=${state.nodeCount->Int.toString}`)->ignore
  | false => ()
  }
  (state.lines->Array.join("\n"), state.nodeCount, state.truncated)
}

let countElements = (el: WebAPI.DomTypes.element) =>
  (el->WebAPI.Element.querySelectorAll("*")).length + 1

let success = (~html, ~nodeCount, ~hint: option<string>=?): Preview.getDomOutput => {
  success: true,
  html: Some(html),
  nodeCount: Some(nodeCount),
  byteSize: Some(utf8ByteSize(html)),
  hint,
  error: None,
}

let tooLargeHint = (~el: WebAPI.DomTypes.element, ~document, ~elementCount, ~maxNodes) => {
  let (overview, _, _) = inspect(
    ~element=el,
    ~document,
    ~selector=None,
    ~maxDepth=1,
    ~maxNodes=16,
    ~pierceShadowDom=false,
  )
  `Subtree has ${elementCount->Int.toString} elements (limit: ${maxNodes->Int.toString}). ` ++
  `Target a child selector from this overview instead:\n${overview}`
}

let executeWithDocument = (input: Preview.getDomInput, ~document: WebAPI.DomTypes.document) =>
  try {
    switch resolveBySelector(~doc=document, ~selector=input.selector) {
    | (None, _) => Preview.getDomError(~error=`No element found for selector: ${input.selector}`)
    | (Some(el), _) =>
      let maxNodes =
        input.maxNodes->Option.getOr(defaultMaxNodes)->Math.Int.min(hardMaxNodes)->Math.Int.max(1)
      switch input.mode->Option.getOr(#simplified) {
      | #full =>
        let elementCount = countElements(el)
        if elementCount > maxNodes {
          Preview.getDomError(
            ~error=`Subtree too large for full mode (${elementCount->Int.toString} elements, limit: ${maxNodes->Int.toString}).`,
            ~hint=tooLargeHint(~el, ~document, ~elementCount, ~maxNodes),
            ~nodeCount=elementCount,
          )
        } else {
          let raw = el.outerHTML
          let byteSize = utf8ByteSize(raw)
          if byteSize > fullModeMaxBytes {
            Preview.getDomError(
              ~error=`HTML too large: ${byteSize->Int.toString} bytes (limit: ${fullModeMaxBytes->Int.toString}). Use simplified mode for an overview, or target a smaller component.`,
              ~hint=tooLargeHint(~el, ~document, ~elementCount, ~maxNodes),
              ~nodeCount=elementCount,
            )
          } else {
            success(~html=raw, ~nodeCount=elementCount)
          }
        }
      | #simplified =>
        let (html, nodeCount, truncated) = inspect(
          ~element=el,
          ~document,
          ~selector=switch classifySelector(input.selector) {
          | CssSelector(_) => Some(input.selector)
          | XPathExpression(_) => None
          },
          ~maxDepth=input.maxDepth->Option.getOr(defaultMaxDepth),
          ~maxNodes,
          ~pierceShadowDom=input.pierceShadowDom->Option.getOr(false),
        )
        success(
          ~html,
          ~nodeCount,
          ~hint=?switch truncated {
          | true =>
            Some(
              `Output stopped at the ${maxNodes->Int.toString}-node or ${maxOutputBytes->Int.toString}-byte limit. Narrow your selector for complete results.`,
            )
          | false => None
          },
        )
      }
    }
  } catch {
  | exn => Preview.getDomError(~error=errorMessage(exn))
  }

let execute = input =>
  executeWithDocument(input, ~document=WebAPI.Window.current->WebAPI.Window.document)
