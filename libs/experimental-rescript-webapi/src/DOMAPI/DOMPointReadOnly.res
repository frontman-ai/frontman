open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly)
*/
@new
external make: (~x: float=?, ~y: float=?, ~z: float=?, ~w: float=?) => domPointReadOnly =
  "DOMPointReadOnly"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/fromPoint_static)
*/
@scope("DOMPointReadOnly")
external fromPoint: (~other: domPointInit=?) => domPointReadOnly = "fromPoint"

@send
external matrixTransform: (domPointReadOnly, ~matrix: domMatrixInit=?) => domPoint =
  "matrixTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/toJSON)
*/
@send
external toJSON: domPointReadOnly => Dict.t<string> = "toJSON"
