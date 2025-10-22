open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPoint)
*/
@new
external make: (~x: float=?, ~y: float=?, ~z: float=?, ~w: float=?) => domPoint = "DOMPoint"

external asDOMPointReadOnly: domPoint => domPointReadOnly = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/fromPoint_static)
*/
@scope("DOMPoint")
external fromPoint: (~other: domPointInit=?) => domPointReadOnly = "fromPoint"

@send
external matrixTransform: (domPoint, ~matrix: domMatrixInit=?) => domPoint = "matrixTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/toJSON)
*/
@send
external toJSON: domPoint => Dict.t<string> = "toJSON"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPoint/fromPoint_static)
*/
@scope("DOMPoint")
external fromPointD: (~other: domPointInit=?) => domPoint = "fromPoint"
