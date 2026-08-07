@send
external save: DomTypes.canvasRenderingContext2D => unit = "save"

@send
external restore: DomTypes.canvasRenderingContext2D => unit = "restore"

@send
external reset: DomTypes.canvasRenderingContext2D => unit = "reset"

@send
external isContextLost: DomTypes.canvasRenderingContext2D => bool = "isContextLost"

@send
external scale: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => unit = "scale"

@send
external rotate: (DomTypes.canvasRenderingContext2D, float) => unit = "rotate"

@send
external translate: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => unit = "translate"

@send
external transform: (
  DomTypes.canvasRenderingContext2D,
  ~a: float,
  ~b: float,
  ~c: float,
  ~d: float,
  ~e: float,
  ~f: float,
) => unit = "transform"

@send
external getTransform: DomTypes.canvasRenderingContext2D => DomTypes.domMatrix = "getTransform"

@send
external setTransform: (
  DomTypes.canvasRenderingContext2D,
  ~a: float,
  ~b: float,
  ~c: float,
  ~d: float,
  ~e: float,
  ~f: float,
) => unit = "setTransform"

@send
external setTransform2: (
  DomTypes.canvasRenderingContext2D,
  ~transform: DomTypes.domMatrix2DInit=?,
) => unit = "setTransform"

@send
external resetTransform: DomTypes.canvasRenderingContext2D => unit = "resetTransform"

@send
external createLinearGradient: (
  DomTypes.canvasRenderingContext2D,
  ~x0: float,
  ~y0: float,
  ~x1: float,
  ~y1: float,
) => CanvasTypes.canvasGradient = "createLinearGradient"

@send
external createRadialGradient: (
  DomTypes.canvasRenderingContext2D,
  ~x0: float,
  ~y0: float,
  ~r0: float,
  ~x1: float,
  ~y1: float,
  ~r1: float,
) => CanvasTypes.canvasGradient = "createRadialGradient"

@send
external createConicGradient: (
  DomTypes.canvasRenderingContext2D,
  ~startAngle: float,
  ~x: float,
  ~y: float,
) => CanvasTypes.canvasGradient = "createConicGradient"

@send
external createPattern: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlImageElement,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

@send
external createPattern2: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.svgImageElement,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

@send
external createPattern3: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlVideoElement,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

@send
external createPattern4: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlCanvasElement,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

@send
external createPattern5: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.imageBitmap,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

@send
external createPattern6: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.offscreenCanvas,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

@send
external createPattern7: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.videoFrame,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

@send
external clearRect: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
) => unit = "clearRect"

@send
external fillRect: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
) => unit = "fillRect"

@send
external strokeRect: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
) => unit = "strokeRect"

@send
external beginPath: DomTypes.canvasRenderingContext2D => unit = "beginPath"

@send
external fill: (
  DomTypes.canvasRenderingContext2D,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => unit = "fill"

@send
external fill2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => unit = "fill"

@send
external stroke: DomTypes.canvasRenderingContext2D => unit = "stroke"

@send
external stroke2: (DomTypes.canvasRenderingContext2D, CanvasTypes.path2D) => unit = "stroke"

@send
external clip: (
  DomTypes.canvasRenderingContext2D,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => unit = "clip"

@send
external clip2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => unit = "clip"

@send
external isPointInPath: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => bool = "isPointInPath"

@send
external isPointInPath2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => bool = "isPointInPath"

@send
external isPointInStroke: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => bool =
  "isPointInStroke"

@send
external isPointInStroke2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~x: float,
  ~y: float,
) => bool = "isPointInStroke"

@send
external drawFocusIfNeeded: (DomTypes.canvasRenderingContext2D, DomTypes.element) => unit =
  "drawFocusIfNeeded"

@send
external drawFocusIfNeeded2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~element: DomTypes.element,
) => unit = "drawFocusIfNeeded"

@send
external fillText: (
  DomTypes.canvasRenderingContext2D,
  ~text: string,
  ~x: float,
  ~y: float,
  ~maxWidth: float=?,
) => unit = "fillText"

@send
external strokeText: (
  DomTypes.canvasRenderingContext2D,
  ~text: string,
  ~x: float,
  ~y: float,
  ~maxWidth: float=?,
) => unit = "strokeText"

@send
external measureText: (DomTypes.canvasRenderingContext2D, string) => CanvasTypes.textMetrics =
  "measureText"

@send
external drawImage: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlImageElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

@send
external drawImageWithSvg: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.svgImageElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

@send
external drawImageWithVideo: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlVideoElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

@send
external drawImageWithCanvas: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlCanvasElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

@send
external drawImageWithImageBitmap: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.imageBitmap,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

@send
external drawImageWithOffscreenCanvas: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.offscreenCanvas,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

@send
external drawImageWithVideoFrame: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.videoFrame,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

@send
external drawImageWithDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlImageElement,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithSvgDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.svgImageElement,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithVideoDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlVideoElement,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithCanvasDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlCanvasElement,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithImageBitmapDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.imageBitmap,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithOffscreenCanvasDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.offscreenCanvas,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithVideoFrameDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.videoFrame,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithSubRectangle: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlImageElement,
  ~sx: float,
  ~sy: float,
  ~sw: float,
  ~sh: float,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithSvgSubRectangle: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.svgImageElement,
  ~sx: float,
  ~sy: float,
  ~sw: float,
  ~sh: float,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithVideoSubRectangle: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlVideoElement,
  ~sx: float,
  ~sy: float,
  ~sw: float,
  ~sh: float,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithCanvasSubRectangle: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlCanvasElement,
  ~sx: float,
  ~sy: float,
  ~sw: float,
  ~sh: float,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithImageBitmapSubRectangle: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.imageBitmap,
  ~sx: float,
  ~sy: float,
  ~sw: float,
  ~sh: float,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithOffscreenCanvasSubRectangle: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.offscreenCanvas,
  ~sx: float,
  ~sy: float,
  ~sw: float,
  ~sh: float,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external drawImageWithVideoFrameSubRectangle: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.videoFrame,
  ~sx: float,
  ~sy: float,
  ~sw: float,
  ~sh: float,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

@send
external createImageData: (
  DomTypes.canvasRenderingContext2D,
  ~sw: int,
  ~sh: int,
  ~settings: DomTypes.imageDataSettings=?,
) => DomTypes.imageData = "createImageData"

@send
external createImageData2: (
  DomTypes.canvasRenderingContext2D,
  DomTypes.imageData,
) => DomTypes.imageData = "createImageData"

@send
external getImageData: (
  DomTypes.canvasRenderingContext2D,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~settings: DomTypes.imageDataSettings=?,
) => DomTypes.imageData = "getImageData"

@send
external putImageData: (
  DomTypes.canvasRenderingContext2D,
  ~imagedata: DomTypes.imageData,
  ~dx: int,
  ~dy: int,
) => unit = "putImageData"

@send
external putImageData2: (
  DomTypes.canvasRenderingContext2D,
  ~imagedata: DomTypes.imageData,
  ~dx: int,
  ~dy: int,
  ~dirtyX: int,
  ~dirtyY: int,
  ~dirtyWidth: int,
  ~dirtyHeight: int,
) => unit = "putImageData"

@send
external setLineDash: (DomTypes.canvasRenderingContext2D, array<float>) => unit = "setLineDash"

@send
external getLineDash: DomTypes.canvasRenderingContext2D => array<float> = "getLineDash"

@send
external closePath: DomTypes.canvasRenderingContext2D => unit = "closePath"

@send
external moveTo: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => unit = "moveTo"

@send
external lineTo: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => unit = "lineTo"

@send
external quadraticCurveTo: (
  DomTypes.canvasRenderingContext2D,
  ~cpx: float,
  ~cpy: float,
  ~x: float,
  ~y: float,
) => unit = "quadraticCurveTo"

@send
external bezierCurveTo: (
  DomTypes.canvasRenderingContext2D,
  ~cp1x: float,
  ~cp1y: float,
  ~cp2x: float,
  ~cp2y: float,
  ~x: float,
  ~y: float,
) => unit = "bezierCurveTo"

@send
external arcTo: (
  DomTypes.canvasRenderingContext2D,
  ~x1: float,
  ~y1: float,
  ~x2: float,
  ~y2: float,
  ~radius: float,
) => unit = "arcTo"

@send
external rect: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
) => unit = "rect"

@send
external roundRect: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
  ~radii_: array<float>=?,
) => unit = "roundRect"

@send
external roundRect2: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
  ~radii_: array<float>=?,
) => unit = "roundRect"

@send
external roundRect3: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
  ~radii_: array<float>=?,
) => unit = "roundRect"

@send
external arc: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~radius: float,
  ~startAngle: float,
  ~endAngle: float,
  ~counterclockwise: bool=?,
) => unit = "arc"

@send
external ellipse: (
  DomTypes.canvasRenderingContext2D,
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
external getContextAttributes: DomTypes.canvasRenderingContext2D => CanvasTypes.canvasRenderingContext2DSettings =
  "getContextAttributes"
