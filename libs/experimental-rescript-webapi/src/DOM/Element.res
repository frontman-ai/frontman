module Impl = (
  T: {
    type t
  },
) => {
  include Node.Impl({type t = T.t})

  external asElement: T.t => DomTypes.element = "%identity"
  external asHTMLElement: T.t => DomTypes.htmlElement = "%identity"
  external asRescriptElement: T.t => 'a = "%identity"

  @get
  external parentElement: T.t => Null.t<DomTypes.element> = "parentElement"

  @send
  external after: (T.t, DomTypes.node) => unit = "after"

  @send
  external after2: (T.t, string) => unit = "after"

  @send
  external animate: (T.t, ~keyframes: unknown, ~options: float=?) => DomTypes.animation = "animate"

  @send
  external animate2: (
    T.t,
    ~keyframes: unknown,
    ~options: DomTypes.keyframeAnimationOptions=?,
  ) => DomTypes.animation = "animate"

  @send
  external append: (T.t, DomTypes.node) => unit = "append"

  @send
  external append2: (T.t, string) => unit = "append"

  @send
  external attachShadow: (T.t, DomTypes.shadowRootInit) => DomTypes.shadowRoot = "attachShadow"

  @send
  external before: (T.t, DomTypes.node) => unit = "before"

  @send
  external before2: (T.t, string) => unit = "before"

  @send
  external checkVisibility: (T.t, ~options: DomTypes.checkVisibilityOptions=?) => bool =
    "checkVisibility"

  @send
  external closest: (T.t, string) => 'e = "closest"

  @send
  external computedStyleMap: T.t => DomTypes.stylePropertyMapReadOnly = "computedStyleMap"

  @send
  external getAnimations: (
    T.t,
    ~options: DomTypes.getAnimationsOptions=?,
  ) => array<DomTypes.animation> = "getAnimations"

  @send
  external getAttribute: (T.t, string) => null<string> = "getAttribute"

  @send
  external getAttributeNames: T.t => array<string> = "getAttributeNames"

  @send
  external getAttributeNode: (T.t, string) => DomTypes.attr = "getAttributeNode"

  @send
  external getAttributeNodeNS: (T.t, ~namespace: string, ~localName: string) => DomTypes.attr =
    "getAttributeNodeNS"

  @send
  external getAttributeNS: (T.t, ~namespace: string, ~localName: string) => string =
    "getAttributeNS"

  @send
  external getBoundingClientRect: T.t => DomTypes.domRect = "getBoundingClientRect"

  @send
  external getClientRects: T.t => DomTypes.domRectList = "getClientRects"

  @send
  external getElementsByClassName: (T.t, string) => DomTypes.htmlCollection<DomTypes.element> =
    "getElementsByClassName"

  @send
  external getElementsByTagName: (T.t, string) => DomTypes.htmlCollection<DomTypes.element> =
    "getElementsByTagName"

  @send
  external getElementsByTagNameNS: (
    DomTypes.element,
    ~namespace: string,
    ~localName: string,
  ) => DomTypes.htmlCollection<DomTypes.element> = "getElementsByTagNameNS"

  @send
  external getHTML: (T.t, ~options: DomTypes.getHTMLOptions=?) => string = "getHTML"

  @send
  external hasAttribute: (T.t, string) => bool = "hasAttribute"

  @send
  external hasAttributeNS: (T.t, ~namespace: string, ~localName: string) => bool = "hasAttributeNS"

  @send
  external hasAttributes: T.t => bool = "hasAttributes"

  @send
  external hasPointerCapture: (T.t, int) => bool = "hasPointerCapture"

  @send
  external insertAdjacentElement: (
    T.t,
    ~where: DomTypes.insertPosition,
    ~element: DomTypes.element,
  ) => DomTypes.element = "insertAdjacentElement"

  @send
  external insertAdjacentHTML: (T.t, ~position: DomTypes.insertPosition, ~string: string) => unit =
    "insertAdjacentHTML"

  @send
  external insertAdjacentText: (T.t, ~where: DomTypes.insertPosition, ~data: string) => unit =
    "insertAdjacentText"

  @send
  external matches: (T.t, string) => bool = "matches"

  @send
  external prepend: (T.t, DomTypes.node) => unit = "prepend"

  @send
  external prepend2: (T.t, string) => unit = "prepend"

  @send
  external querySelector: (T.t, string) => Null.t<DomTypes.element> = "querySelector"

  @send
  external querySelectorAll: (T.t, string) => DomTypes.nodeList<DomTypes.element> =
    "querySelectorAll"

  @send
  external releasePointerCapture: (T.t, int) => unit = "releasePointerCapture"

  @send
  external remove: T.t => unit = "remove"

  @send
  external removeAttribute: (T.t, string) => unit = "removeAttribute"

  @send
  external removeAttributeNode: (T.t, DomTypes.attr) => DomTypes.attr = "removeAttributeNode"

  @send
  external removeAttributeNS: (T.t, ~namespace: string, ~localName: string) => unit =
    "removeAttributeNS"

  @send
  external replaceChildren: (T.t, DomTypes.node) => unit = "replaceChildren"

  @send
  external replaceChildren2: (T.t, string) => unit = "replaceChildren"

  @send
  external replaceWith: (T.t, DomTypes.node) => unit = "replaceWith"

  @send
  external replaceWith2: (T.t, string) => unit = "replaceWith"

  @send
  external requestFullscreen: (T.t, ~options: DomTypes.fullscreenOptions=?) => promise<unit> =
    "requestFullscreen"

  @send
  external requestPointerLock: (T.t, ~options: DomTypes.pointerLockOptions=?) => promise<unit> =
    "requestPointerLock"

  @send
  external scroll: (T.t, ~options: DomTypes.scrollToOptions=?) => unit = "scroll"

  @send
  external scroll2: (T.t, ~x: float, ~y: float) => unit = "scroll"

  @send
  external scrollBy: (T.t, ~options: DomTypes.scrollToOptions=?) => unit = "scrollBy"

  @send
  external scrollBy2: (T.t, ~x: float, ~y: float) => unit = "scrollBy"

  @send
  external scrollIntoView: T.t => unit = "scrollIntoView"

  @send
  external scrollIntoViewAlignToTop: (T.t, @as(json`true`) _) => unit = "scrollIntoView"

  @send
  external scrollIntoViewWithOptions: (T.t, DomTypes.scrollIntoViewOptions) => unit =
    "scrollIntoView"

  @send
  external scrollTo: (T.t, ~options: DomTypes.scrollToOptions=?) => unit = "scrollTo"

  @send
  external scrollTo2: (T.t, ~x: float, ~y: float) => unit = "scrollTo"

  @send
  external setAttribute: (T.t, ~qualifiedName: string, ~value: string) => unit = "setAttribute"

  @send
  external setAttributeNode: (T.t, DomTypes.attr) => DomTypes.attr = "setAttributeNode"

  @send
  external setAttributeNodeNS: (T.t, DomTypes.attr) => DomTypes.attr = "setAttributeNodeNS"

  @send
  external setAttributeNS: (
    DomTypes.element,
    ~namespace: string,
    ~qualifiedName: string,
    ~value: string,
  ) => unit = "setAttributeNS"

  @send
  external setHTMLUnsafe: (T.t, string) => unit = "setHTMLUnsafe"

  @send
  external setPointerCapture: (T.t, int) => unit = "setPointerCapture"

  @send
  external toggleAttribute: (T.t, ~qualifiedName: string, ~force: bool=?) => bool =
    "toggleAttribute"
}

include Impl({type t = DomTypes.element})

let isInstanceOf = (_: 't): bool => %raw(`param instanceof Element`)
