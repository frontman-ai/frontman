type boundingBox = {
  x: float,
  y: float,
  width: float,
  height: float,
}

type t = {
  selector: result<option<string>, string>,
  cssClasses: option<string>,
  nearbyText: option<string>,
  boundingBox: boundingBox,
  html: string,
  nodeCount: int,
  truncated: bool,
}

let textTruncateLen = 80

let simplifiedAttributes = [
  "id",
  "class",
  "role",
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

let childElements = (element: WebAPI.DOMAPI.element, ~pierceShadowDom: bool): array<
  WebAPI.DOMAPI.element,
> => {
  let result: array<WebAPI.DOMAPI.element> = []
  let children = element.children
  for i in 0 to children.length - 1 {
    result->Array.push(children->WebAPI.HTMLCollection.item(i))->ignore
  }

  switch pierceShadowDom {
  | true =>
    switch element.shadowRoot->Null.toOption {
    | Some(shadowRoot) =>
      let nodes = shadowRoot.childNodes
      for i in 0 to nodes.length - 1 {
        let node = WebAPI.NodeListOf.item(nodes, i)
        switch node.nodeType === 1 {
        | true => result->Array.push(node->WebAPI.Node.asElement)->ignore
        | false => ()
        }
      }
    | None => ()
    }
  | false => ()
  }
  result
}

let truncate = (text: string, ~maxLen: int): string =>
  switch text->String.length > maxLen {
  | true => text->String.slice(~start=0, ~end=maxLen) ++ "..."
  | false => text
  }

let errorMessage = (exn: exn): string =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")

let selectorFor = (~element: WebAPI.DOMAPI.element, ~document: WebAPI.DOMAPI.document): result<
  string,
  string,
> =>
  try {
    Ok(
      FrontmanBindings.Bindings__Finder.finder(
        ~element,
        ~options={
          root: document.documentElement->WebAPI.HTMLElement.asElement,
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

let cssClasses = (element: WebAPI.DOMAPI.element): option<string> =>
  element
  ->WebAPI.Element.getAttribute("class")
  ->Null.toOption
  ->Option.flatMap(classes => {
    let trimmed = classes->String.trim
    switch trimmed {
    | "" => None
    | classes => Some(classes)
    }
  })

let nearbyText = (element: WebAPI.DOMAPI.element): option<string> => {
  let text =
    element
    ->WebAPI.Element.asNode
    ->WebAPI.Node.textContent
    ->Null.toOption
    ->Option.getOr("")
    ->String.trim
  let text = text->truncate(~maxLen=200)
  switch text {
  | "" => None
  | text => Some(text)
  }
}

let boundingBox = (element: WebAPI.DOMAPI.element): boundingBox => {
  let rect = element->WebAPI.Element.getBoundingClientRect
  {x: rect.left, y: rect.top, width: rect.width, height: rect.height}
}

let buildAttributes = (
  element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
): string => {
  let parts: array<string> = []

  element
  ->WebAPI.Element.getAttributeNames
  ->Array.forEach(attributeName => {
    let included =
      simplifiedAttributeSet->Dict.get(attributeName)->Option.isSome ||
        attributeName->String.startsWith("aria-")
    switch included {
    | true =>
      switch element->WebAPI.Element.getAttribute(attributeName)->Null.toOption {
      | Some(value) =>
        parts->Array.push(` ${attributeName}="${value->truncate(~maxLen=57)}"`)->ignore
      | None => ()
      }
    | false => ()
    }
  })

  switch selectorFor(~element, ~document) {
  | Ok(selector) => parts->Array.push(` selector="${selector}"`)->ignore
  | Error(_) => ()
  }

  switch Client__ComponentName.getForElement(
    element,
    ~window=?document.defaultView->Null.toOption,
  ) {
  | Some(name) => parts->Array.push(` component="${name}"`)->ignore
  | None => ()
  }

  parts->Array.join("")
}

let directText = (element: WebAPI.DOMAPI.element): string => {
  let nodes = element->WebAPI.Element.asNode
  let nodes = nodes.childNodes
  let text = ref("")
  for i in 0 to nodes.length - 1 {
    let node = WebAPI.NodeListOf.item(nodes, i)
    switch node.nodeType === 3 {
    | true =>
      let content = node.nodeValue->Null.toOption->Option.getOr("")->String.trim
      switch content {
      | "" => ()
      | content =>
        let separator = switch text.contents {
        | "" => ""
        | _ => " "
        }
        text := text.contents ++ separator ++ content
      }
    | false => ()
    }
  }
  text.contents
}

let indent = (depth: int): string => "  "->String.repeat(depth)

type walkState = {
  mutable output: string,
  mutable nodeCount: int,
  mutable truncated: bool,
  maxNodes: int,
}

let rec walk = (
  ~element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
  ~depth: int,
  ~maxDepth: int,
  ~pierceShadowDom: bool,
  ~state: walkState,
): unit => {
  switch state.nodeCount >= state.maxNodes {
  | true => state.truncated = true
  | false =>
    state.nodeCount = state.nodeCount + 1
    let tag = element.tagName->String.toLowerCase
    let pad = indent(depth)

    switch tag {
    | "script" | "style" | "svg" => state.output = state.output ++ pad ++ `<!-- ${tag} -->\n`
    | _ =>
      let attributes = buildAttributes(element, ~document)
      let children = childElements(element, ~pierceShadowDom)
      let childCount = children->Array.length
      let text = directText(element)
      let hasShadowRoot = pierceShadowDom && element.shadowRoot->Null.toOption->Option.isSome

      switch (childCount, text, hasShadowRoot) {
      | (0, text, false) if text !== "" =>
        state.output =
          state.output ++
          pad ++
          `<${tag}${attributes}>"${text->truncate(~maxLen=textTruncateLen)}"</${tag}>\n`
      | (0, _, false) => state.output = state.output ++ pad ++ `<${tag}${attributes} />\n`
      | _ if depth >= maxDepth =>
        let summary = switch childCount {
        | 0 => ""
        | count => `<!-- ...${count->Int.toString} children -->`
        }
        let text = text->truncate(~maxLen=textTruncateLen)
        let content = switch text {
        | "" => summary
        | text => `"${text}" ${summary}`
        }
        state.output = state.output ++ pad ++ `<${tag}${attributes}>${content}</${tag}>\n`
      | _ =>
        state.output = state.output ++ pad ++ `<${tag}${attributes}>\n`
        switch hasShadowRoot {
        | true =>
          state.output = state.output ++ indent(depth + 1) ++ "<!-- #shadow-root (open) -->\n"
        | false => ()
        }
        switch text {
        | "" => ()
        | text =>
          state.output =
            state.output ++ indent(depth + 1) ++ `"${text->truncate(~maxLen=textTruncateLen)}"\n`
        }
        children->Array.forEach(child =>
          walk(~element=child, ~document, ~depth=depth + 1, ~maxDepth, ~pierceShadowDom, ~state)
        )
        state.output = state.output ++ pad ++ `</${tag}>\n`
      }
    }
  }
}

let renderNode = (
  ~element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
  ~maxDepth: int,
  ~maxNodes: int,
  ~pierceShadowDom: bool,
): walkState => {
  let state = {output: "", nodeCount: 0, truncated: false, maxNodes}
  walk(~element, ~document, ~depth=0, ~maxDepth, ~pierceShadowDom, ~state)
  state
}

let inspect = (
  ~element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
  ~maxDepth: int,
  ~maxNodes: int,
  ~pierceShadowDom: bool,
): t => {
  let selected = renderNode(~element, ~document, ~maxDepth, ~maxNodes, ~pierceShadowDom)
  let parentContext = switch element.parentElement->Null.toOption {
  | Some(parent) =>
    let rendered = renderNode(
      ~element=parent->WebAPI.HTMLElement.asElement,
      ~document,
      ~maxDepth=0,
      ~maxNodes=1,
      ~pierceShadowDom=false,
    )
    `Parent: ${rendered.output->String.trim}\n`
  | None => "Parent: none\n"
  }
  let truncation = switch selected.truncated {
  | true => `\n<!-- context truncated at ${maxNodes->Int.toString} nodes -->`
  | false => ""
  }

  {
    selector: selectorFor(~element, ~document)->Result.map(selector => Some(selector)),
    cssClasses: cssClasses(element),
    nearbyText: nearbyText(element),
    boundingBox: boundingBox(element),
    html: parentContext ++ "Selected:\n" ++ selected.output->String.trim ++ truncation,
    nodeCount: selected.nodeCount,
    truncated: selected.truncated,
  }
}
