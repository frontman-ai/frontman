open DOMAPI
open CanvasAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/save)
*/
@send
external save: canvasRenderingContext2D => unit = "save"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/restore)
*/
@send
external restore: canvasRenderingContext2D => unit = "restore"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/reset)
*/
@send
external reset: canvasRenderingContext2D => unit = "reset"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isContextLost)
*/
@send
external isContextLost: canvasRenderingContext2D => bool = "isContextLost"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/scale)
*/
@send
external scale: (canvasRenderingContext2D, ~x: float, ~y: float) => unit = "scale"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/rotate)
*/
@send
external rotate: (canvasRenderingContext2D, float) => unit = "rotate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/translate)
*/
@send
external translate: (canvasRenderingContext2D, ~x: float, ~y: float) => unit = "translate"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/transform)
*/
@send
external transform: (
  canvasRenderingContext2D,
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
external getTransform: canvasRenderingContext2D => domMatrix = "getTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/setTransform)
*/
@send
external setTransform: (
  canvasRenderingContext2D,
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
external setTransform2: (canvasRenderingContext2D, ~transform: domMatrix2DInit=?) => unit =
  "setTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/resetTransform)
*/
@send
external resetTransform: canvasRenderingContext2D => unit = "resetTransform"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createLinearGradient)
*/
@send
external createLinearGradient: (
  canvasRenderingContext2D,
  ~x0: float,
  ~y0: float,
  ~x1: float,
  ~y1: float,
) => canvasGradient = "createLinearGradient"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createRadialGradient)
*/
@send
external createRadialGradient: (
  canvasRenderingContext2D,
  ~x0: float,
  ~y0: float,
  ~r0: float,
  ~x1: float,
  ~y1: float,
  ~r1: float,
) => canvasGradient = "createRadialGradient"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createConicGradient)
*/
@send
external createConicGradient: (
  canvasRenderingContext2D,
  ~startAngle: float,
  ~x: float,
  ~y: float,
) => canvasGradient = "createConicGradient"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern: (
  canvasRenderingContext2D,
  ~image: htmlImageElement,
  ~repetition: string,
) => canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern2: (
  canvasRenderingContext2D,
  ~image: svgImageElement,
  ~repetition: string,
) => canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern3: (
  canvasRenderingContext2D,
  ~image: htmlVideoElement,
  ~repetition: string,
) => canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern4: (
  canvasRenderingContext2D,
  ~image: htmlCanvasElement,
  ~repetition: string,
) => canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern5: (
  canvasRenderingContext2D,
  ~image: imageBitmap,
  ~repetition: string,
) => canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern6: (
  canvasRenderingContext2D,
  ~image: offscreenCanvas,
  ~repetition: string,
) => canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createPattern)
*/
@send
external createPattern7: (
  canvasRenderingContext2D,
  ~image: videoFrame,
  ~repetition: string,
) => canvasPattern = "createPattern"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/clearRect)
*/
@send
external clearRect: (canvasRenderingContext2D, ~x: float, ~y: float, ~w: float, ~h: float) => unit =
  "clearRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fillRect)
*/
@send
external fillRect: (canvasRenderingContext2D, ~x: float, ~y: float, ~w: float, ~h: float) => unit =
  "fillRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/strokeRect)
*/
@send
external strokeRect: (
  canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~w: float,
  ~h: float,
) => unit = "strokeRect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/beginPath)
*/
@send
external beginPath: canvasRenderingContext2D => unit = "beginPath"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fill)
*/
@send
external fill: (canvasRenderingContext2D, ~fillRule: canvasFillRule=?) => unit = "fill"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fill)
*/
@send
external fill2: (canvasRenderingContext2D, ~path: path2D, ~fillRule: canvasFillRule=?) => unit =
  "fill"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/stroke)
*/
@send
external stroke: canvasRenderingContext2D => unit = "stroke"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/stroke)
*/
@send
external stroke2: (canvasRenderingContext2D, path2D) => unit = "stroke"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/clip)
*/
@send
external clip: (canvasRenderingContext2D, ~fillRule: canvasFillRule=?) => unit = "clip"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/clip)
*/
@send
external clip2: (canvasRenderingContext2D, ~path: path2D, ~fillRule: canvasFillRule=?) => unit =
  "clip"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isPointInPath)
*/
@send
external isPointInPath: (
  canvasRenderingContext2D,
  ~x: float,
  ~y: float,
  ~fillRule: canvasFillRule=?,
) => bool = "isPointInPath"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isPointInPath)
*/
@send
external isPointInPath2: (
  canvasRenderingContext2D,
  ~path: path2D,
  ~x: float,
  ~y: float,
  ~fillRule: canvasFillRule=?,
) => bool = "isPointInPath"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isPointInStroke)
*/
@send
external isPointInStroke: (canvasRenderingContext2D, ~x: float, ~y: float) => bool =
  "isPointInStroke"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/isPointInStroke)
*/
@send
external isPointInStroke2: (canvasRenderingContext2D, ~path: path2D, ~x: float, ~y: float) => bool =
  "isPointInStroke"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawFocusIfNeeded)
*/
@send
external drawFocusIfNeeded: (canvasRenderingContext2D, element) => unit = "drawFocusIfNeeded"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawFocusIfNeeded)
*/
@send
external drawFocusIfNeeded2: (canvasRenderingContext2D, ~path: path2D, ~element: element) => unit =
  "drawFocusIfNeeded"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fillText)
*/
@send
external fillText: (
  canvasRenderingContext2D,
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
  canvasRenderingContext2D,
  ~text: string,
  ~x: float,
  ~y: float,
  ~maxWidth: float=?,
) => unit = "strokeText"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/measureText)
*/
@send
external measureText: (canvasRenderingContext2D, string) => textMetrics = "measureText"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImage: (
  canvasRenderingContext2D,
  ~image: htmlImageElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithSvg: (
  canvasRenderingContext2D,
  ~image: svgImageElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithVideo: (
  canvasRenderingContext2D,
  ~image: htmlVideoElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithCanvas: (
  canvasRenderingContext2D,
  ~image: htmlCanvasElement,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithImageBitmap: (
  canvasRenderingContext2D,
  ~image: imageBitmap,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithOffscreenCanvas: (
  canvasRenderingContext2D,
  ~image: offscreenCanvas,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithVideoFrame: (
  canvasRenderingContext2D,
  ~image: videoFrame,
  ~dx: float,
  ~dy: float,
) => unit = "drawImage"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/drawImage)
*/
@send
external drawImageWithDimensions: (
  canvasRenderingContext2D,
  ~image: htmlImageElement,
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
  canvasRenderingContext2D,
  ~image: svgImageElement,
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
  canvasRenderingContext2D,
  ~image: htmlVideoElement,
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
  canvasRenderingContext2D,
  ~image: htmlCanvasElement,
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
  canvasRenderingContext2D,
  ~image: imageBitmap,
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
  canvasRenderingContext2D,
  ~image: offscreenCanvas,
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
  canvasRenderingContext2D,
  ~image: videoFrame,
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
  canvasRenderingContext2D,
  ~image: htmlImageElement,
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
  canvasRenderingContext2D,
  ~image: svgImageElement,
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
  canvasRenderingContext2D,
  ~image: htmlVideoElement,
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
  canvasRenderingContext2D,
  ~image: htmlCanvasElement,
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
  canvasRenderingContext2D,
  ~image: imageBitmap,
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
  canvasRenderingContext2D,
  ~image: offscreenCanvas,
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
  canvasRenderingContext2D,
  ~image: videoFrame,
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
  canvasRenderingContext2D,
  ~sw: int,
  ~sh: int,
  ~settings: imageDataSettings=?,
) => imageData = "createImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/createImageData)
*/
@send
external createImageData2: (canvasRenderingContext2D, imageData) => imageData = "createImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/getImageData)
*/
@send
external getImageData: (
  canvasRenderingContext2D,
  ~sx: int,
  ~sy: int,
  ~sw: int,
  ~sh: int,
  ~settings: imageDataSettings=?,
) => imageData = "getImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/putImageData)
*/
@send
external putImageData: (
  canvasRenderingContext2D,
  ~imagedata: imageData,
  ~dx: int,
  ~dy: int,
) => unit = "putImageData"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/putImageData)
*/
@send
external putImageData2: (
  canvasRenderingContext2D,
  ~imagedata: imageData,
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
external setLineDash: (canvasRenderingContext2D, array<float>) => unit = "setLineDash"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/getLineDash)
*/
@send
external getLineDash: canvasRenderingContext2D => array<float> = "getLineDash"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/closePath)
*/
@send
external closePath: canvasRenderingContext2D => unit = "closePath"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/moveTo)
*/
@send
external moveTo: (canvasRenderingContext2D, ~x: float, ~y: float) => unit = "moveTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineTo)
*/
@send
external lineTo: (canvasRenderingContext2D, ~x: float, ~y: float) => unit = "lineTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/quadraticCurveTo)
*/
@send
external quadraticCurveTo: (
  canvasRenderingContext2D,
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
  canvasRenderingContext2D,
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
  canvasRenderingContext2D,
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
external rect: (canvasRenderingContext2D, ~x: float, ~y: float, ~w: float, ~h: float) => unit =
  "rect"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/roundRect)
*/
@send
external roundRect: (
  canvasRenderingContext2D,
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
  canvasRenderingContext2D,
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
  canvasRenderingContext2D,
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
  canvasRenderingContext2D,
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
  canvasRenderingContext2D,
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
external getContextAttributes: canvasRenderingContext2D => canvasRenderingContext2DSettings =
  "getContextAttributes"
