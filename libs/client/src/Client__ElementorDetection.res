type t = {
  postId: option<int>,
  elementId: string,
  elementType: option<string>,
  widgetType: option<string>,
  @live
  documentType: option<string>,
  editHint: string,
}

let schema: S.t<t> = S.object(s => {
  postId: s.field("post_id", S.option(S.int)),
  elementId: s.field("element_id", S.string),
  elementType: s.field("element_type", S.option(S.string)),
  widgetType: s.field("widget_type", S.option(S.string)),
  documentType: s.field("document_type", S.option(S.string)),
  editHint: s.field("edit_hint", S.string),
})

let _attr = (element: WebAPI.DOMAPI.element, name: string): option<string> =>
  element
  ->WebAPI.Element.getAttribute(name)
  ->Null.toOption
  ->Option.flatMap(value => {
    let trimmed = value->String.trim
    trimmed == "" ? None : Some(trimmed)
  })

let _normalizeWidgetType = (value: string): string =>
  value->String.split(".")->Array.get(0)->Option.getOr(value)

let _parseClassPostId = (className: string): option<int> =>
  className
  ->String.split(" ")
  ->Array.filterMap(cls => {
    let fromElementor = switch cls->String.startsWith("elementor-page-") {
    | true => Some(cls->String.slice(~start=15, ~end=cls->String.length))
    | false => None
    }

    let rawId = switch fromElementor {
    | Some(id) => Some(id)
    | None =>
      switch cls->String.startsWith("page-id-") {
      | true => Some(cls->String.slice(~start=8, ~end=cls->String.length))
      | false => None
      }
    }

    rawId->Option.flatMap(id => Int.fromString(id, ~radix=10))
  })
  ->Array.get(0)

let _postIdFromRoot = (element: WebAPI.DOMAPI.element): option<int> =>
  _attr(element, "data-elementor-id")->Option.flatMap(id => Int.fromString(id, ~radix=10))

let _postIdFromDocument = (document: WebAPI.DOMAPI.document): option<int> => {
  let rootPostId =
    document
    ->WebAPI.Document.querySelector("[data-elementor-id]")
    ->Null.toOption
    ->Option.flatMap(_postIdFromRoot)

  switch rootPostId {
  | Some(_) => rootPostId
  | None =>
    document
    ->WebAPI.Document.querySelector("body")
    ->Null.toOption
    ->Option.flatMap(body => _attr(body, "class"))
    ->Option.flatMap(_parseClassPostId)
  }
}

let _closestElementorRoot = (element: WebAPI.DOMAPI.element): option<WebAPI.DOMAPI.element> =>
  element->WebAPI.Element.closest("[data-elementor-id]")->Null.toOption

let _closestElementorElement = (element: WebAPI.DOMAPI.element): option<WebAPI.DOMAPI.element> =>
  element->WebAPI.Element.closest(".elementor-element[data-id]")->Null.toOption

let _makeHint = (~postId: option<int>, ~elementId: string): string => {
  let target = switch postId {
  | Some(id) => `post_id=${id->Int.toString}, element_id=${elementId}`
  | None => `element_id=${elementId}`
  }
  `Elementor target (${target}). Prefer wp_elementor_update_element for granular edits; inspect first so the tool can use Elementor element props to choose settings vs HTML-fragment updates.`
}

let getElementorContext = (
  ~element: WebAPI.DOMAPI.element,
  ~document: WebAPI.DOMAPI.document,
): option<t> =>
  switch _closestElementorElement(element) {
  | None => None
  | Some(elementorElement) =>
    switch _attr(elementorElement, "data-id") {
    | None => None
    | Some(elementId) => {
        let postId = switch _closestElementorRoot(element) {
        | Some(root) => _postIdFromRoot(root)
        | None => _postIdFromDocument(document)
        }

        let elementType = _attr(elementorElement, "data-element_type")
        let widgetType =
          _attr(elementorElement, "data-widget_type")->Option.map(_normalizeWidgetType)
        let documentType = switch _closestElementorRoot(element) {
        | Some(root) => _attr(root, "data-elementor-type")
        | None => None
        }
        Some({
          postId,
          elementId,
          elementType,
          widgetType,
          documentType,
          editHint: _makeHint(~postId, ~elementId),
        })
      }
    }
  }

let uri = (context: t): string =>
  switch context.postId {
  | Some(postId) => `elementor://post/${postId->Int.toString}/element/${context.elementId}`
  | None => `elementor://element/${context.elementId}`
  }

let summary = (context: t, ~tagName: string): string => {
  let detail = switch (context.elementType, context.widgetType) {
  | (Some("widget"), Some(widgetType)) => `widget ${widgetType}`
  | (Some(elementType), _) => elementType
  | _ => tagName
  }

  `Annotated Elementor element: <${tagName}> ${detail} (${context.editHint})`
}
