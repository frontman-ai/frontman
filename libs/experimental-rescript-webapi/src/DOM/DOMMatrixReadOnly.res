/**
`make()`

Creates a new identity `DOMMatrixReadOnly`.

```res
let matrix = DOMMatrixReadOnly.make()
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly)
*/
@new
external make: unit => DomTypes.domMatrixReadOnly = "DOMMatrixReadOnly"

/**
`fromString(string)`

Creates a new `DOMMatrixReadOnly` from a transform string.

```res
let matrix = DOMMatrixReadOnly.fromString("matrix(1, 0, 0, 1, 0, 0)")
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly)
*/
@new
external fromString: string => DomTypes.domMatrixReadOnly = "DOMMatrixReadOnly"

/**
`fromArray(array<float>)`

Creates a new `DOMMatrixReadOnly` from an array of matrix component values.

```res
let matrix = DOMMatrixReadOnly.fromArray([1., 0., 0., 1., 0., 0.])
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly)
*/
@new
external fromArray: array<float> => DomTypes.domMatrixReadOnly = "DOMMatrixReadOnly"

@scope("DOMMatrixReadOnly")
external fromMatrix: (~other: DomTypes.domMatrixInit=?) => DomTypes.domMatrixReadOnly = "fromMatrix"

@scope("DOMMatrixReadOnly")
external fromFloat32Array: array<float> => DomTypes.domMatrixReadOnly = "fromFloat32Array"

@scope("DOMMatrixReadOnly")
external fromFloat64Array: Float64Array.t => DomTypes.domMatrixReadOnly = "fromFloat64Array"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly/translate)
*/
@send
external translate: (
  DomTypes.domMatrixReadOnly,
  ~tx: float=?,
  ~ty: float=?,
  ~tz: float=?,
) => DomTypes.domMatrix = "translate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly/scale)
*/
@send
external scale: (
  DomTypes.domMatrixReadOnly,
  ~scaleX: float=?,
  ~scaleY: float=?,
  ~scaleZ: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => DomTypes.domMatrix = "scale"

@send
external scale3d: (
  DomTypes.domMatrixReadOnly,
  ~scale: float=?,
  ~originX: float=?,
  ~originY: float=?,
  ~originZ: float=?,
) => DomTypes.domMatrix = "scale3d"

@send
external rotate: (
  DomTypes.domMatrixReadOnly,
  ~rotX: float=?,
  ~rotY: float=?,
  ~rotZ: float=?,
) => DomTypes.domMatrix = "rotate"

@send
external rotateFromVector: (
  DomTypes.domMatrixReadOnly,
  ~x: float=?,
  ~y: float=?,
) => DomTypes.domMatrix = "rotateFromVector"

@send
external rotateAxisAngle: (
  DomTypes.domMatrixReadOnly,
  ~x: float=?,
  ~y: float=?,
  ~z: float=?,
  ~angle: float=?,
) => DomTypes.domMatrix = "rotateAxisAngle"

@send
external skewX: (DomTypes.domMatrixReadOnly, ~sx: float=?) => DomTypes.domMatrix = "skewX"

@send
external skewY: (DomTypes.domMatrixReadOnly, ~sy: float=?) => DomTypes.domMatrix = "skewY"

@send
external multiply: (
  DomTypes.domMatrixReadOnly,
  ~other: DomTypes.domMatrixInit=?,
) => DomTypes.domMatrix = "multiply"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMMatrixReadOnly/flipX)
*/
@send
external flipX: DomTypes.domMatrixReadOnly => DomTypes.domMatrix = "flipX"

@send
external flipY: DomTypes.domMatrixReadOnly => DomTypes.domMatrix = "flipY"

@send
external inverse: DomTypes.domMatrixReadOnly => DomTypes.domMatrix = "inverse"

@send
external transformPoint: (
  DomTypes.domMatrixReadOnly,
  ~point: DomTypes.domPointInit=?,
) => DomTypes.domPoint = "transformPoint"

@send
external toFloat32Array: DomTypes.domMatrixReadOnly => array<float> = "toFloat32Array"

@send
external toFloat64Array: DomTypes.domMatrixReadOnly => Float64Array.t = "toFloat64Array"

@send
external toJSON: DomTypes.domMatrixReadOnly => Dict.t<string> = "toJSON"
