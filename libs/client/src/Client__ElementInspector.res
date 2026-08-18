type t = {
  selector: result<option<string>, string>,
  cssClasses: option<string>,
  nearbyText: option<string>,
  boundingBox: Client__Annotation__Types.boundingBox,
  html: string,
  nodeCount: int,
  truncated: bool,
  byteTruncated: bool,
}

type textEncoder

type walkState = {
  lines: array<string>,
  mutable nodeCount: int,
  mutable truncated: bool,
  mutable byteTruncated: bool,
  mutable byteSize: int,
  maxNodes: int,
  maxBytes: int,
  encoder: textEncoder,
}

type childRelation =
  | LightChild(int)
  | ShadowChild(int)

type walkChild = {
  element: WebAPI.DOMAPI.element,
  relation: childRelation,
}

let maxOutputBytes = 30_000

let keyAttributes = ["id", "class", "data-testid", "href", "src", "type", "placeholder", "alt"]

@new external makeTextEncoder: unit => textEncoder = "TextEncoder"
@send external encode: (textEncoder, string) => Uint8Array.t = "encode"
@get external byteLength: Uint8Array.t => int = "byteLength"

let utf8ByteSize = (text: string): int => makeTextEncoder()->encode(text)->byteLength

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

let childElements = (~element: WebAPI.DOMAPI.element, ~pierceShadowDom: bool): array<walkChild> => {
  let lightChildren =
    element.children
    ->WebAPI.HTMLCollection.toArray
    ->Array.mapWithIndex((child, index) => {
      element: child,
      relation: LightChild(index + 1),
    })
  switch (pierceShadowDom, element.shadowRoot->Null.toOption) {
  | (true, Some(shadowRoot)) => {
      let shadowChildren = shadowRoot->WebAPI.ShadowRoot.children->WebAPI.HTMLCollection.toArray
      Array.concat(
        lightChildren,
        shadowChildren->Array.mapWithIndex((child, index) => {
          element: child,
          relation: ShadowChild(index + 1),
        }),
      )
    }
  | (false, Some(_)) | (false, None) | (true, None) => lightChildren
  }
}

let directText = (element: WebAPI.DOMAPI.element): string => {
  let node = element->WebAPI.Element.asNode
  node.childNodes
  ->WebAPI.NodeList.toArray
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

let contextText = (element: WebAPI.DOMAPI.element): string =>
  switch element.tagName->String.toLowerCase {
  | "input" | "script" | "style" | "svg" | "textarea" => ""
  | _ => directText(element)
  }

let pushField = (fields: array<string>, name: string, value: string): unit =>
  fields->Array.push(`${name}=${value->truncate(~maxLen=80)->quote}`)->ignore

let stripUrlSecrets = (value: string): string => {
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

let appendLine = (state: walkState, line: string): bool => {
  let separatorBytes = switch state.lines->Array.length {
  | 0 => 0
  | _ => 1
  }
  let lineBytes = state.encoder->encode(line)->byteLength
  switch state.byteSize + separatorBytes + lineBytes > state.maxBytes {
  | true => {
      state.truncated = true
      state.byteTruncated = true
      false
    }
  | false => {
      state.lines->Array.push(line)->ignore
      state.byteSize = state.byteSize + separatorBytes + lineBytes
      true
    }
  }
}

let describe = (
  ~relation: string,
  ~element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
  ~selector: option<string>,
  ~pierceShadowDom: bool,
): (string, array<walkChild>) => {
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
  switch selector {
  | Some(selector) => fields->Array.push(`selector=${selector->quote}`)->ignore
  | None => ()
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
  switch contextText(element) {
  | "" => ()
  | text => pushField(fields, "text", text)
  }
  let children = childElements(~element, ~pierceShadowDom)
  fields->Array.push(`children=${children->Array.length->Int.toString}`)->ignore
  (fields->Array.join(" "), children)
}

let rec walk = (
  ~element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
  ~selector: option<string>,
  ~depth: int,
  ~maxDepth: int,
  ~pierceShadowDom: bool,
  ~insideShadowDom: bool,
  ~state: walkState,
): unit =>
  switch state.truncated || state.nodeCount >= state.maxNodes {
  | true => state.truncated = true
  | false =>
    let (description, children) = describe(
      ~relation=switch depth {
      | 0 => "selected"
      | _ => "child"
      },
      ~element,
      ~document,
      ~selector,
      ~pierceShadowDom,
    )
    let appended = appendLine(state, "  "->String.repeat(depth) ++ description)
    switch appended {
    | true => state.nodeCount = state.nodeCount + 1
    | false => ()
    }
    switch appended && depth < maxDepth {
    | true =>
      children->Array.forEach(child => {
        let childSelector = selector->Option.map(selector =>
          switch (child.relation, insideShadowDom) {
          | (ShadowChild(index), _) => `${selector} >>> ${index->Int.toString}`
          | (LightChild(index), true) => `${selector}/${index->Int.toString}`
          | (LightChild(index), false) => `${selector} > :nth-child(${index->Int.toString})`
          }
        )
        walk(
          ~element=child.element,
          ~document,
          ~selector=childSelector,
          ~depth=depth + 1,
          ~maxDepth,
          ~pierceShadowDom,
          ~insideShadowDom=switch child.relation {
          | ShadowChild(_) => true
          | LightChild(_) => insideShadowDom
          },
          ~state,
        )
      })
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
  ~pierceShadowDom=false,
  ~selectedSelector: option<string>=?,
): t => {
  let selector = switch selectedSelector {
  | Some(selector) => Ok(selector)
  | None => findSelector(~element, ~document=Some(document))
  }
  let selectedSelector = switch selector {
  | Ok(selector) => Some(selector)
  | Error(_) => None
  }
  let parent = switch element.parentElement->Null.toOption {
  | Some(parent) =>
    let (description, _) = describe(
      ~relation="parent",
      ~element=parent->WebAPI.HTMLElement.asElement,
      ~document,
      ~selector=None,
      ~pierceShadowDom=false,
    )
    description
  | None => "parent none"
  }
  let state = {
    lines: [],
    nodeCount: 0,
    truncated: false,
    byteTruncated: false,
    byteSize: 0,
    maxNodes,
    maxBytes: maxOutputBytes,
    encoder: makeTextEncoder(),
  }
  appendLine(state, parent)->ignore
  walk(
    ~element,
    ~document,
    ~selector=selectedSelector,
    ~depth=0,
    ~maxDepth,
    ~pierceShadowDom,
    ~insideShadowDom=selectedSelector->Option.mapOr(false, selector =>
      selector->String.includes(" >>> ")
    ),
    ~state,
  )
  switch state.truncated {
  | true => appendLine(state, `truncated nodes=${state.nodeCount->Int.toString}`)->ignore
  | false => ()
  }
  let rect = element->WebAPI.Element.getBoundingClientRect
  {
    selector: selector->Result.map(selector => Some(selector)),
    cssClasses: element->WebAPI.Element.getAttribute("class")->optionalTrimmed,
    nearbyText: switch contextText(element) {
    | "" => None
    | text => Some(text->truncate(~maxLen=200))
    },
    boundingBox: {x: rect.left, y: rect.top, width: rect.width, height: rect.height},
    html: state.lines->Array.join("\n"),
    nodeCount: state.nodeCount,
    truncated: state.truncated,
    byteTruncated: state.byteTruncated,
  }
}
