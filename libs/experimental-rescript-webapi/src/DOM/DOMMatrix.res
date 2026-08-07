@new
external make: unit => DomTypes.domMatrix = "DOMMatrix"

@new
external fromString: string => DomTypes.domMatrix = "DOMMatrix"

@new
external fromArray: array<float> => DomTypes.domMatrix = "DOMMatrix"

external asDOMMatrixReadOnly: DomTypes.domMatrix => DomTypes.domMatrixReadOnly = "%identity"
@scope("DOMMatrix")
external fromMatrix: (~other: DomTypes.domMatrixInit=?) => DomTypes.domMatrixReadOnly = "fromMatrix"

@scope("DOMMatrix")
external fromFloat32Array: array<float> => DomTypes.domMatrixReadOnly = "fromFloat32Array"

@scope("DOMMatrix")
external fromFloat64Array: Float64Array.t => DomTypes.domMatrixReadOnly = "fromFloat64Array"

@send
external translate: (
  DomTypes.domMatrix,
  ~tx: float=?,
  ~ty: float=?,
  ~tz: float=?,
) => DomTypes.domMatrix = "translate"

@send
external scale: (
  DomTypes.domMatrix,
  ~scaleX: float=?,
  ~scaleY: float=?,
  ~scaleZ: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => DomTypes.domMatrix = "scale"

@send
external scale3d: (
  DomTypes.domMatrix,
  ~scale: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => DomTypes.domMatrix = "scale3d"

@send
external rotate: (
  DomTypes.domMatrix,
  ~rotX: float=?,
  ~rotY: float=?,
  ~rotZ: float=?,
) => DomTypes.domMatrix = "rotate"

@send
external rotateFromVector: (DomTypes.domMatrix, ~x: float=?, ~y: float=?) => DomTypes.domMatrix =
  "rotateFromVector"

@send
external rotateAxisAngle: (
  DomTypes.domMatrix,
  ~x: float=?,
  ~y: float=?,
  ~z: float=?,
  ~angle: float=?,
) => DomTypes.domMatrix = "rotateAxisAngle"

@send
external skewX: (DomTypes.domMatrix, ~sx: float=?) => DomTypes.domMatrix = "skewX"

@send
external skewY: (DomTypes.domMatrix, ~sy: float=?) => DomTypes.domMatrix = "skewY"

@send
external multiply: (DomTypes.domMatrix, ~other: DomTypes.domMatrixInit=?) => DomTypes.domMatrix =
  "multiply"

@send
external flipX: DomTypes.domMatrix => DomTypes.domMatrix = "flipX"

@send
external flipY: DomTypes.domMatrix => DomTypes.domMatrix = "flipY"

@send
external inverse: DomTypes.domMatrix => DomTypes.domMatrix = "inverse"

@send
external transformPoint: (
  DomTypes.domMatrix,
  ~point: DomTypes.domPointInit=?,
) => DomTypes.domPoint = "transformPoint"

@send
external toFloat32Array: DomTypes.domMatrix => array<float> = "toFloat32Array"

@send
external toFloat64Array: DomTypes.domMatrix => Float64Array.t = "toFloat64Array"

@send
external toJSON: DomTypes.domMatrix => Dict.t<string> = "toJSON"

@scope("DOMMatrix")
external fromMatrixD: (~other: DomTypes.domMatrixInit=?) => DomTypes.domMatrix = "fromMatrix"

@scope("DOMMatrix")
external fromFloat32ArrayD: array<float> => DomTypes.domMatrix = "fromFloat32Array"

@scope("DOMMatrix")
external fromFloat64ArrayD: Float64Array.t => DomTypes.domMatrix = "fromFloat64Array"

@send
external multiplySelf: (
  DomTypes.domMatrix,
  ~other: DomTypes.domMatrixInit=?,
) => DomTypes.domMatrix = "multiplySelf"

@send
external preMultiplySelf: (
  DomTypes.domMatrix,
  ~other: DomTypes.domMatrixInit=?,
) => DomTypes.domMatrix = "preMultiplySelf"

@send
external translateSelf: (
  DomTypes.domMatrix,
  ~tx: float=?,
  ~ty: float=?,
  ~tz: float=?,
) => DomTypes.domMatrix = "translateSelf"

@send
external scaleSelf: (
  DomTypes.domMatrix,
  ~scaleX: float=?,
  ~scaleY: float=?,
  ~scaleZ: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => DomTypes.domMatrix = "scaleSelf"

@send
external scale3dSelf: (
  DomTypes.domMatrix,
  ~scale: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => DomTypes.domMatrix = "scale3dSelf"

@send
external rotateSelf: (
  DomTypes.domMatrix,
  ~rotX: float=?,
  ~rotY: float=?,
  ~rotZ: float=?,
) => DomTypes.domMatrix = "rotateSelf"

@send
external rotateFromVectorSelf: (
  DomTypes.domMatrix,
  ~x: float=?,
  ~y: float=?,
) => DomTypes.domMatrix = "rotateFromVectorSelf"

@send
external rotateAxisAngleSelf: (
  DomTypes.domMatrix,
  ~x: float=?,
  ~y: float=?,
  ~z: float=?,
  ~angle: float=?,
) => DomTypes.domMatrix = "rotateAxisAngleSelf"

@send
external skewXSelf: (DomTypes.domMatrix, ~sx: float=?) => DomTypes.domMatrix = "skewXSelf"

@send
external skewYSelf: (DomTypes.domMatrix, ~sy: float=?) => DomTypes.domMatrix = "skewYSelf"

@send
external invertSelf: DomTypes.domMatrix => DomTypes.domMatrix = "invertSelf"

@send
external setMatrixValue: (DomTypes.domMatrix, string) => DomTypes.domMatrix = "setMatrixValue"
