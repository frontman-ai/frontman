/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly)
*/
@new
external make: (~x: float=?, ~y: float=?, ~z: float=?, ~w: float=?) => DomTypes.domPointReadOnly =
  "DOMPointReadOnly"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/fromPoint_static)
*/
@scope("DOMPointReadOnly")
external fromPoint: (~other: DomTypes.domPointInit=?) => DomTypes.domPointReadOnly = "fromPoint"

@send
external matrixTransform: (
  DomTypes.domPointReadOnly,
  ~matrix: DomTypes.domMatrixInit=?,
) => DomTypes.domPoint = "matrixTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMPointReadOnly/toJSON)
*/
@send
external toJSON: DomTypes.domPointReadOnly => Dict.t<string> = "toJSON"
