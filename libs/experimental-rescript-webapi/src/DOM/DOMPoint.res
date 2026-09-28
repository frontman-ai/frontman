/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPoint)
*/
@new
external make: (~x: float=?, ~y: float=?, ~z: float=?, ~w: float=?) => DomTypes.domPoint =
  "DOMPoint"

external asDOMPointReadOnly: DomTypes.domPoint => DomTypes.domPointReadOnly = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/fromPoint_static)
*/
@scope("DOMPoint")
external fromPoint: (~other: DomTypes.domPointInit=?) => DomTypes.domPointReadOnly = "fromPoint"

@send
external matrixTransform: (
  DomTypes.domPoint,
  ~matrix: DomTypes.domMatrixInit=?,
) => DomTypes.domPoint = "matrixTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/toJSON)
*/
@send
external toJSON: DomTypes.domPoint => Dict.t<string> = "toJSON"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPoint/fromPoint_static)
*/
@scope("DOMPoint")
external fromPointD: (~other: DomTypes.domPointInit=?) => DomTypes.domPoint = "fromPoint"
