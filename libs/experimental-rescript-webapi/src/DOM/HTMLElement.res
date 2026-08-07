type t = DomTypes.htmlElement

module Impl = (
  T: {
    type t
  },
) => {
  include Element.Impl({type t = T.t})

  external asHTMLElement: T.t => t = "%identity"

  @get
  external style: T.t => DomTypes.cssStyleDeclaration = "style"

  @get
  external innerText: T.t => string = "innerText"

  @send
  external attachInternals: T.t => DomTypes.elementInternals = "attachInternals"

  @send
  external blur: T.t => unit = "blur"

  @send
  external click: T.t => unit = "click"

  @send
  external focus: (T.t, ~options: DomTypes.focusOptions=?) => unit = "focus"

  @send
  external hidePopover: T.t => unit = "hidePopover"

  @send
  external showPopover: T.t => unit = "showPopover"

  @send
  external togglePopover: (T.t, ~force: bool=?) => bool = "togglePopover"
}

include Impl({type t = t})
