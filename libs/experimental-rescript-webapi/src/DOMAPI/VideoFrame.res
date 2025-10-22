open DOMAPI
open Prelude
open CanvasAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make: (~image: htmlImageElement, ~init: videoFrameInit=?) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make2: (~image: svgImageElement, ~init: videoFrameInit=?) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make3: (~image: htmlVideoElement, ~init: videoFrameInit=?) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make4: (~image: htmlCanvasElement, ~init: videoFrameInit=?) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make5: (~image: imageBitmap, ~init: videoFrameInit=?) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make6: (~image: offscreenCanvas, ~init: videoFrameInit=?) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make7: (~image: videoFrame, ~init: videoFrameInit=?) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make8: (~data: ArrayBuffer.t, ~init: videoFrameBufferInit) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make9: (~data: sharedArrayBuffer, ~init: videoFrameBufferInit) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame)
*/
@new
external make10: (~data: DataView.t, ~init: videoFrameBufferInit) => videoFrame = "VideoFrame"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/allocationSize)
*/
@send
external allocationSize: (videoFrame, ~options: videoFrameCopyToOptions=?) => int = "allocationSize"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/copyTo)
*/
@send
external copyTo: (
  videoFrame,
  ~destination: ArrayBuffer.t,
  ~options: videoFrameCopyToOptions=?,
) => promise<array<planeLayout>> = "copyTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/copyTo)
*/
@send
external copyTo2: (
  videoFrame,
  ~destination: sharedArrayBuffer,
  ~options: videoFrameCopyToOptions=?,
) => promise<array<planeLayout>> = "copyTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/copyTo)
*/
@send
external copyTo3: (
  videoFrame,
  ~destination: DataView.t,
  ~options: videoFrameCopyToOptions=?,
) => promise<array<planeLayout>> = "copyTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/clone)
*/
@send
external clone: videoFrame => videoFrame = "clone"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/VideoFrame/close)
*/
@send
external close: videoFrame => unit = "close"
