@new
external fromHTMLImageElement: (
  ~image: DomTypes.htmlImageElement,
  ~init: DomTypes.videoFrameInit=?,
) => DomTypes.videoFrame = "VideoFrame"

@new
external fromSVGImageElement: (
  ~image: DomTypes.svgImageElement,
  ~init: DomTypes.videoFrameInit=?,
) => DomTypes.videoFrame = "VideoFrame"

@new
external fromHTMLVideoElement: (
  ~image: DomTypes.htmlVideoElement,
  ~init: DomTypes.videoFrameInit=?,
) => DomTypes.videoFrame = "VideoFrame"

@new
external fromHTMLCanvasElement: (
  ~image: DomTypes.htmlCanvasElement,
  ~init: DomTypes.videoFrameInit=?,
) => DomTypes.videoFrame = "VideoFrame"

@new
external fromImageBitmap: (
  ~image: CanvasTypes.imageBitmap,
  ~init: DomTypes.videoFrameInit=?,
) => DomTypes.videoFrame = "VideoFrame"

@new
external fromOffscreenCanvas: (
  ~image: CanvasTypes.offscreenCanvas,
  ~init: DomTypes.videoFrameInit=?,
) => DomTypes.videoFrame = "VideoFrame"

@new
external fromVideoFrame: (
  ~image: DomTypes.videoFrame,
  ~init: DomTypes.videoFrameInit=?,
) => DomTypes.videoFrame = "VideoFrame"

@new
external fromArrayBuffer: (
  ~data: ArrayBuffer.t,
  ~init: DomTypes.videoFrameBufferInit,
) => DomTypes.videoFrame = "VideoFrame"

@new
external fromTypedArray: (
  ~data: TypedArray.t<'t>,
  ~init: DomTypes.videoFrameBufferInit,
) => DomTypes.videoFrame = "VideoFrame"

@new
external fromDataView: (
  ~data: DataView.t,
  ~init: DomTypes.videoFrameBufferInit,
) => DomTypes.videoFrame = "VideoFrame"

@send
external allocationSize: (
  DomTypes.videoFrame,
  ~options: DomTypes.videoFrameCopyToOptions=?,
) => int = "allocationSize"

@send
external copyTo: (
  DomTypes.videoFrame,
  ~destination: ArrayBuffer.t,
  ~options: DomTypes.videoFrameCopyToOptions=?,
) => promise<array<DomTypes.planeLayout>> = "copyTo"

@send
external copyTo2: (
  DomTypes.videoFrame,
  ~destination: ArrayBufferTypedArrayOrDataView.t,
  ~options: DomTypes.videoFrameCopyToOptions=?,
) => promise<array<DomTypes.planeLayout>> = "copyTo"

@send
external copyTo3: (
  DomTypes.videoFrame,
  ~destination: DataView.t,
  ~options: DomTypes.videoFrameCopyToOptions=?,
) => promise<array<DomTypes.planeLayout>> = "copyTo"

@send
external clone: DomTypes.videoFrame => DomTypes.videoFrame = "clone"

@send
external close: DomTypes.videoFrame => unit = "close"
