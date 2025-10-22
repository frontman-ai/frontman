open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly)
*/
@new
external make: (~x: float=?, ~y: float=?, ~width: float=?, ~height: float=?) => domRectReadOnly =
  "DOMRectReadOnly"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMRectReadOnly/fromRect_static)
*/
@scope("DOMRectReadOnly")
external fromRect: (~other: domRectInit=?) => domRectReadOnly = "fromRect"

@send
external toJSON: domRectReadOnly => Dict.t<string> = "toJSON"
