open DOMAPI

module Impl = (
  T: {
    type t
  },
) => {
  include Element.Impl({type t = T.t})

  external asHTMLElement: T.t => htmlElement = "%identity"
  external style: T.t => cssStyleDeclaration = "style"
  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/attachInternals)
*/
  @send
  external attachInternals: T.t => elementInternals = "attachInternals"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/blur)
*/
  @send
  external blur: T.t => unit = "blur"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/click)
*/
  @send
  external click: T.t => unit = "click"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/focus)
*/
  @send
  external focus: (T.t, ~options: focusOptions=?) => unit = "focus"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/hidePopover)
*/
  @send
  external hidePopover: T.t => unit = "hidePopover"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/showPopover)
*/
  @send
  external showPopover: T.t => unit = "showPopover"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLElement/togglePopover)
*/
  @send
  external togglePopover: (T.t, ~force: bool=?) => bool = "togglePopover"
}

include Impl({type t = htmlElement})
