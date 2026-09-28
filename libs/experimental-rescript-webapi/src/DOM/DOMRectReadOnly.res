/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly)
*/
@new
external make: (
  ~x: float=?,
  ~y: float=?,
  ~width: float=?,
  ~height: float=?,
) => DomTypes.domRectReadOnly = "DOMRectReadOnly"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/fromRect_static)
*/
@scope("DOMRectReadOnly")
external fromRect: (~other: DomTypes.domRectInit=?) => DomTypes.domRectReadOnly = "fromRect"

@send
external toJSON: DomTypes.domRectReadOnly => Dict.t<string> = "toJSON"
