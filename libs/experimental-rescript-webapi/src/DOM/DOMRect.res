/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRect)
*/
@new
external make: (~x: float=?, ~y: float=?, ~width: float=?, ~height: float=?) => DomTypes.domRect =
  "DOMRect"

external asDOMRectReadOnly: DomTypes.domRect => DomTypes.domRectReadOnly = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/fromRect_static)
*/
@scope("DOMRect")
external fromRect: (~other: DomTypes.domRectInit=?) => DomTypes.domRectReadOnly = "fromRect"

@send
external toJSON: DomTypes.domRect => Dict.t<string> = "toJSON"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRect/fromRect_static)
*/
@scope("DOMRect")
external fromRectD: (~other: DomTypes.domRectInit=?) => DomTypes.domRect = "fromRect"
