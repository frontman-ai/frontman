open DOMAPI
open Prelude

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly)
*/
@new
external make: (~init: string=?) => domMatrixReadOnly = "DOMMatrixReadOnly"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly)
*/
@new
external make2: (~init: array<float>=?) => domMatrixReadOnly = "DOMMatrixReadOnly"

@scope("DOMMatrixReadOnly")
external fromMatrix: (~other: domMatrixInit=?) => domMatrixReadOnly = "fromMatrix"

@scope("DOMMatrixReadOnly")
external fromFloat32Array: array<float> => domMatrixReadOnly = "fromFloat32Array"

@scope("DOMMatrixReadOnly")
external fromFloat64Array: float64Array => domMatrixReadOnly = "fromFloat64Array"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly/translate)
*/
@send
external translate: (domMatrixReadOnly, ~tx: float=?, ~ty: float=?, ~tz: float=?) => domMatrix =
  "translate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly/scale)
*/
@send
external scale: (
  domMatrixReadOnly,
  ~scaleX: float=?,
  ~scaleY: float=?,
  ~scaleZ: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => domMatrix = "scale"

@send
external scale3d: (
  domMatrixReadOnly,
  ~scale: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => domMatrix = "scale3d"

@send
external rotate: (domMatrixReadOnly, ~rotX: float=?, ~rotY: float=?, ~rotZ: float=?) => domMatrix =
  "rotate"

@send
external rotateFromVector: (domMatrixReadOnly, ~x: float=?, ~y: float=?) => domMatrix =
  "rotateFromVector"

@send
external rotateAxisAngle: (
  domMatrixReadOnly,
  ~x: float=?,
  ~y: float=?,
  ~z: float=?,
  ~angle: float=?,
) => domMatrix = "rotateAxisAngle"

@send
external skewX: (domMatrixReadOnly, ~sx: float=?) => domMatrix = "skewX"

@send
external skewY: (domMatrixReadOnly, ~sy: float=?) => domMatrix = "skewY"

@send
external multiply: (domMatrixReadOnly, ~other: domMatrixInit=?) => domMatrix = "multiply"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly/flipX)
*/
@send
external flipX: domMatrixReadOnly => domMatrix = "flipX"

@send
external flipY: domMatrixReadOnly => domMatrix = "flipY"

@send
external inverse: domMatrixReadOnly => domMatrix = "inverse"

@send
external transformPoint: (domMatrixReadOnly, ~point: domPointInit=?) => domPoint = "transformPoint"

@send
external toFloat32Array: domMatrixReadOnly => array<float> = "toFloat32Array"

@send
external toFloat64Array: domMatrixReadOnly => float64Array = "toFloat64Array"

@send
external toJSON: domMatrixReadOnly => Dict.t<string> = "toJSON"
