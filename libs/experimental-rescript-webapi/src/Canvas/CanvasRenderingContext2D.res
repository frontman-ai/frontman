/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/save)
*/
@send
external save: DomTypes.canvasRenderingContext2D => unit = "save"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/restore)
*/
@send
external restore: DomTypes.canvasRenderingContext2D => unit = "restore"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/reset)
*/
@send
external reset: DomTypes.canvasRenderingContext2D => unit = "reset"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isContextLost)
*/
@send
external isContextLost: DomTypes.canvasRenderingContext2D => bool = "isContextLost"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/scale)
*/
@send
external scale: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => unit = "scale"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/rotate)
*/
@send
external rotate: (DomTypes.canvasRenderingContext2D, float) => unit = "rotate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/translate)
*/
@send
external translate: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => unit = "translate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/transform)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/getTransform)
*/
@send
external getTransform: DomTypes.canvasRenderingContext2D => DomTypes.domMatrix = "getTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/setTransform)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/setTransform)
*/
@send
external setTransform2: (
  DomTypes.canvasRenderingContext2D,
  ~transform: DomTypes.domMatrix2DInit=?,
) => unit = "setTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/resetTransform)
*/
@send
external resetTransform: DomTypes.canvasRenderingContext2D => unit = "resetTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createLinearGradient)
*/
@send
external createLinearGradient: (
  DomTypes.canvasRenderingContext2D,
  ~x0: float,
  ~y0: float,
  ~x1: float,
  ~y1: float,
) => CanvasTypes.canvasGradient = "createLinearGradient"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createRadialGradient)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createConicGradient)
*/
@send
external createConicGradient: (
  DomTypes.canvasRenderingContext2D,
  ~startAngle: float,
  ~x: float,
  ~y: float,
) => CanvasTypes.canvasGradient = "createConicGradient"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlImageElement,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern2: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.svgImageElement,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern3: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlVideoElement,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern4: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlCanvasElement,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern5: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.imageBitmap,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern6: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.offscreenCanvas,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern7: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.videoFrame,
  ~repetition: string,
) => CanvasTypes.canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/clearRect)
*/
@send
external clearRect: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
) => unit = "clearRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fillRect)
*/
@send
external fillRect: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
) => unit = "fillRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/strokeRect)
*/
@send
external strokeRect: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
) => unit = "strokeRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/beginPath)
*/
@send
external beginPath: DomTypes.canvasRenderingContext2D => unit = "beginPath"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fill)
*/
@send
external fill: (
  DomTypes.canvasRenderingContext2D,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => unit = "fill"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fill)
*/
@send
external fill2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => unit = "fill"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/stroke)
*/
@send
external stroke: DomTypes.canvasRenderingContext2D => unit = "stroke"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/stroke)
*/
@send
external stroke2: (DomTypes.canvasRenderingContext2D, CanvasTypes.path2D) => unit = "stroke"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/clip)
*/
@send
external clip: (
  DomTypes.canvasRenderingContext2D,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => unit = "clip"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/clip)
*/
@send
external clip2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => unit = "clip"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isPointInPath)
*/
@send
external isPointInPath: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => bool = "isPointInPath"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isPointInPath)
*/
@send
external isPointInPath2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~x: float,
  ~y: float,
  ~fillRule: CanvasTypes.canvasFillRule=?,
) => bool = "isPointInPath"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isPointInStroke)
*/
@send
external isPointInStroke: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => bool =
  "isPointInStroke"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isPointInStroke)
*/
@send
external isPointInStroke2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~x: float,
  ~y: float,
) => bool = "isPointInStroke"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawFocusIfNeeded)
*/
@send
external drawFocusIfNeeded: (DomTypes.canvasRenderingContext2D, DomTypes.element) => unit =
  "drawFocusIfNeeded"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawFocusIfNeeded)
*/
@send
external drawFocusIfNeeded2: (
  DomTypes.canvasRenderingContext2D,
  ~path: CanvasTypes.path2D,
  ~element: DomTypes.element,
) => unit = "drawFocusIfNeeded"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fillText)
*/
@send
external fillText: (
  DomTypes.canvasRenderingContext2D,
  ~text: string,
  ~x: float,
  ~y: float,
  ~maxWidth: float=?,
) => unit = "fillText"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/strokeText)
*/
@send
external strokeText: (
  DomTypes.canvasRenderingContext2D,
  ~text: string,
  ~x: float,
  ~y: float,
  ~maxWidth: float=?,
) => unit = "strokeText"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/measureText)
*/
@send
external measureText: (DomTypes.canvasRenderingContext2D, string) => CanvasTypes.textMetrics =
  "measureText"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImage: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlImageElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithSvg: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.svgImageElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithVideo: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlVideoElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithCanvas: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlCanvasElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithImageBitmap: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.imageBitmap,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithOffscreenCanvas: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.offscreenCanvas,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithVideoFrame: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.videoFrame,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlImageElement,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithSvgDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.svgImageElement,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithVideoDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlVideoElement,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithCanvasDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.htmlCanvasElement,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithImageBitmapDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.imageBitmap,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithOffscreenCanvasDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: CanvasTypes.offscreenCanvas,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithVideoFrameDimensions: (
  DomTypes.canvasRenderingContext2D,
  ~image: DomTypes.videoFrame,
  ~dx: float,
  ~dy: float,
  ~dw: float,
  ~dh: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createImageData)
*/
@send
external createImageData: (
  DomTypes.canvasRenderingContext2D,
  ~sw: int,
  ~sh: int,
  ~settings: DomTypes.imageDataSettings=?,
) => DomTypes.imageData = "createImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createImageData)
*/
@send
external createImageData2: (
  DomTypes.canvasRenderingContext2D,
  DomTypes.imageData,
) => DomTypes.imageData = "createImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/getImageData)
*/
@send
external getImageData: (
  DomTypes.canvasRenderingContext2D,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~settings: DomTypes.imageDataSettings=?,
) => DomTypes.imageData = "getImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/putImageData)
*/
@send
external putImageData: (
  DomTypes.canvasRenderingContext2D,
  ~imagedata: DomTypes.imageData,
  ~dx: int,
  ~dy: int,
) => unit = "putImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/putImageData)
*/
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/setLineDash)
*/
@send
external setLineDash: (DomTypes.canvasRenderingContext2D, array<float>) => unit = "setLineDash"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/getLineDash)
*/
@send
external getLineDash: DomTypes.canvasRenderingContext2D => array<float> = "getLineDash"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/closePath)
*/
@send
external closePath: DomTypes.canvasRenderingContext2D => unit = "closePath"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/moveTo)
*/
@send
external moveTo: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => unit = "moveTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineTo)
*/
@send
external lineTo: (DomTypes.canvasRenderingContext2D, ~x: float, ~y: float) => unit = "lineTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/quadraticCurveTo)
*/
@send
external quadraticCurveTo: (
  DomTypes.canvasRenderingContext2D,
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
  DomTypes.canvasRenderingContext2D,
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
  DomTypes.canvasRenderingContext2D,
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
external rect: (
  DomTypes.canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
) => unit = "rect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/roundRect)
*/
@send
external roundRect: (
  DomTypes.canvasRenderingContext2D,
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
  DomTypes.canvasRenderingContext2D,
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
  DomTypes.canvasRenderingContext2D,
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
  DomTypes.canvasRenderingContext2D,
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

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/getContextAttributes)
*/
@send
external getContextAttributes: DomTypes.canvasRenderingContext2D => CanvasTypes.canvasRenderingContext2DSettings =
  "getContextAttributes"
