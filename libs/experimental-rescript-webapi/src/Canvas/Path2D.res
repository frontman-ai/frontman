type domMatrix2DInit = DomTypes.domMatrix2DInit

/**
`make()`

Creates a new empty `Path2D`.

```res
let path = Path2D.make()
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Path2D)
*/
@new
external make: unit => CanvasTypes.path2D = "Path2D"

/**
`fromPath2D(path2D)`

Creates a new `Path2D` by copying another `Path2D`.

```res
let copiedPath = Path2D.fromPath2D(existingPath)
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Path2D)
*/
@new
external fromPath2D: CanvasTypes.path2D => CanvasTypes.path2D = "Path2D"

/**
`fromString(string)`

Creates a new `Path2D` from SVG path data text.

```res
let path = Path2D.fromString("M0 0 L10 10")
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Path2D)
*/
@new
external fromString: string => CanvasTypes.path2D = "Path2D"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/closePath)
*/
@send
external closePath: CanvasTypes.path2D => unit = "closePath"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/moveTo)
*/
@send
external moveTo: (CanvasTypes.path2D, ~x: float, ~y: float) => unit = "moveTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineTo)
*/
@send
external lineTo: (CanvasTypes.path2D, ~x: float, ~y: float) => unit = "lineTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/quadraticCurveTo)
*/
@send
external quadraticCurveTo: (
  CanvasTypes.path2D,
  ~cpx: float,
  ~cpy: float,
  ~x: float,
  ~y: float,
) => unit = "quadraticCurveTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/bezierCurveTo)
*/
@send
external bezierCurveTo: (
  CanvasTypes.path2D,
  ~cp1x: float,
  ~cp1y: float,
  ~cp2x: float,
  ~cp2y: float,
  ~x: float,
  ~y: float,
) => unit = "bezierCurveTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/arcTo)
*/
@send
external arcTo: (
  CanvasTypes.path2D,
  ~x1: float,
  ~y1: float,
  ~x2: float,
  ~y2: float,
  ~radius: float,
) => unit = "arcTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/rect)
*/
@send
external rect: (CanvasTypes.path2D, ~x: float, ~y: float, ~w: float, ~h: float) => unit = "rect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/roundRect)
*/
@send
external roundRect: (
  CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
  ~radii_: array<float>=?,
) => unit = "roundRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/roundRect)
*/
@send
external roundRect2: (
  CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
  ~radii_: array<float>=?,
) => unit = "roundRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/roundRect)
*/
@send
external roundRect3: (
  CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
  ~radii_: array<float>=?,
) => unit = "roundRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/arc)
*/
@send
external arc: (
  CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~radius: float,
  ~startAngle: float,
  ~endAngle: float,
  ~counterclockwise: bool=?,
) => unit = "arc"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/ellipse)
*/
@send
external ellipse: (
  CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~radiusX: float,
  ~radiusY: float,
  ~rotation: float,
  ~startAngle: float,
  ~endAngle: float,
  ~counterclockwise: bool=?,
) => unit = "ellipse"

/**
Adds to the path the path given by the argument.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Path2D/addPath)
*/
@send
external addPath: (
  CanvasTypes.path2D,
  ~path: CanvasTypes.path2D,
  ~transform: domMatrix2DInit=?,
) => unit = "addPath"
