open DOMAPI
open Prelude

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrix)
*/
@new
external make: (~init: string=?) => domMatrix = "DOMMatrix"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrix)
*/
@new
external make2: (~init: array<float>=?) => domMatrix = "DOMMatrix"

external asDOMMatrixReadOnly: domMatrix => domMatrixReadOnly = "%identity"
@scope("DOMMatrix")
external fromMatrix: (~other: domMatrixInit=?) => domMatrixReadOnly = "fromMatrix"

@scope("DOMMatrix")
external fromFloat32Array: array<float> => domMatrixReadOnly = "fromFloat32Array"

@scope("DOMMatrix")
external fromFloat64Array: float64Array => domMatrixReadOnly = "fromFloat64Array"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly/translate)
*/
@send
external translate: (domMatrix, ~tx: float=?, ~ty: float=?, ~tz: float=?) => domMatrix = "translate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly/scale)
*/
@send
external scale: (
  domMatrix,
  ~scaleX: float=?,
  ~scaleY: float=?,
  ~scaleZ: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => domMatrix = "scale"

@send
external scale3d: (
  domMatrix,
  ~scale: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => domMatrix = "scale3d"

@send
external rotate: (domMatrix, ~rotX: float=?, ~rotY: float=?, ~rotZ: float=?) => domMatrix = "rotate"

@send
external rotateFromVector: (domMatrix, ~x: float=?, ~y: float=?) => domMatrix = "rotateFromVector"

@send
external rotateAxisAngle: (
  domMatrix,
  ~x: float=?,
  ~y: float=?,
  ~z: float=?,
  ~angle: float=?,
) => domMatrix = "rotateAxisAngle"

@send
external skewX: (domMatrix, ~sx: float=?) => domMatrix = "skewX"

@send
external skewY: (domMatrix, ~sy: float=?) => domMatrix = "skewY"

@send
external multiply: (domMatrix, ~other: domMatrixInit=?) => domMatrix = "multiply"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly/flipX)
*/
@send
external flipX: domMatrix => domMatrix = "flipX"

@send
external flipY: domMatrix => domMatrix = "flipY"

@send
external inverse: domMatrix => domMatrix = "inverse"

@send
external transformPoint: (domMatrix, ~point: domPointInit=?) => domPoint = "transformPoint"

@send
external toFloat32Array: domMatrix => array<float> = "toFloat32Array"

@send
external toFloat64Array: domMatrix => float64Array = "toFloat64Array"

@send
external toJSON: domMatrix => Dict.t<string> = "toJSON"

@scope("DOMMatrix")
external fromMatrixD: (~other: domMatrixInit=?) => domMatrix = "fromMatrix"

@scope("DOMMatrix")
external fromFloat32ArrayD: array<float> => domMatrix = "fromFloat32Array"

@scope("DOMMatrix")
external fromFloat64ArrayD: float64Array => domMatrix = "fromFloat64Array"

@send
external multiplySelf: (domMatrix, ~other: domMatrixInit=?) => domMatrix = "multiplySelf"

@send
external preMultiplySelf: (domMatrix, ~other: domMatrixInit=?) => domMatrix = "preMultiplySelf"

@send
external translateSelf: (domMatrix, ~tx: float=?, ~ty: float=?, ~tz: float=?) => domMatrix =
  "translateSelf"

@send
external scaleSelf: (
  domMatrix,
  ~scaleX: float=?,
  ~scaleY: float=?,
  ~scaleZ: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => domMatrix = "scaleSelf"

@send
external scale3dSelf: (
  domMatrix,
  ~scale: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => domMatrix = "scale3dSelf"

@send
external rotateSelf: (domMatrix, ~rotX: float=?, ~rotY: float=?, ~rotZ: float=?) => domMatrix =
  "rotateSelf"

@send
external rotateFromVectorSelf: (domMatrix, ~x: float=?, ~y: float=?) => domMatrix =
  "rotateFromVectorSelf"

@send
external rotateAxisAngleSelf: (
  domMatrix,
  ~x: float=?,
  ~y: float=?,
  ~z: float=?,
  ~angle: float=?,
) => domMatrix = "rotateAxisAngleSelf"

@send
external skewXSelf: (domMatrix, ~sx: float=?) => domMatrix = "skewXSelf"

@send
external skewYSelf: (domMatrix, ~sy: float=?) => domMatrix = "skewYSelf"

@send
external invertSelf: domMatrix => domMatrix = "invertSelf"

@send
external setMatrixValue: (domMatrix, string) => domMatrix = "setMatrixValue"
