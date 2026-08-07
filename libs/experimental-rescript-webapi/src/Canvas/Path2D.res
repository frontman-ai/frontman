type domMatrix2DInit = DomTypes.domMatrix2DInit

@new
external make: unit => CanvasTypes.path2D = "Path2D"

@new
external fromPath2D: CanvasTypes.path2D => CanvasTypes.path2D = "Path2D"

@new
external fromString: string => CanvasTypes.path2D = "Path2D"

@send
external closePath: CanvasTypes.path2D => unit = "closePath"

@send
external moveTo: (CanvasTypes.path2D, ~x: float, ~y: float) => unit = "moveTo"

@send
external lineTo: (CanvasTypes.path2D, ~x: float, ~y: float) => unit = "lineTo"

@send
external quadraticCurveTo: (
  CanvasTypes.path2D,
  ~cpx: float,
  ~cpy: float,
  ~x: float,
  ~y: float,
) => unit = "quadraticCurveTo"

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

@send
external arcTo: (
  CanvasTypes.path2D,
  ~x1: float,
  ~y1: float,
  ~x2: float,
  ~y2: float,
  ~radius: float,
) => unit = "arcTo"

@send
external rect: (CanvasTypes.path2D, ~x: float, ~y: float, ~w: float, ~h: float) => unit = "rect"

@send
external roundRect: (
  CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
  ~radii_: array<float>=?,
) => unit = "roundRect"

@send
external roundRect2: (
  CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
  ~radii_: array<float>=?,
) => unit = "roundRect"

@send
external roundRect3: (
  CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
  ~radii_: array<float>=?,
) => unit = "roundRect"

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

@send
external addPath: (
  CanvasTypes.path2D,
  ~path: CanvasTypes.path2D,
  ~transform: domMatrix2DInit=?,
) => unit = "addPath"
