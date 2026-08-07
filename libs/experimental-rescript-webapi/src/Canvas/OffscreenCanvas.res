@new
external make: (~width: int, ~height: int) => CanvasTypes.offscreenCanvas = "OffscreenCanvas"

include EventTarget.Impl({type t = CanvasTypes.offscreenCanvas})

@send
external getContext2D: (
  CanvasTypes.offscreenCanvas,
  @as("2d") _,
  ~options: JSON.t=?,
) => CanvasTypes.offscreenCanvasRenderingContext2D = "getContext"

@send
external getContextWebGL: (
  CanvasTypes.offscreenCanvas,
  @as("webgl") _,
  ~options: CanvasTypes.webGLContextAttributes=?,
) => CanvasTypes.webGLRenderingContext = "getContext"

@send
external getContextWebGL2: (
  CanvasTypes.offscreenCanvas,
  @as("webgl2") _,
  ~options: CanvasTypes.webGLContextAttributes=?,
) => CanvasTypes.webGL2RenderingContext = "getContext"

@send
external getContextBitmapRenderer: (
  CanvasTypes.offscreenCanvas,
  @as("bitmaprenderer") _,
  ~options: CanvasTypes.imageBitmapRenderingContextSettings=?,
) => CanvasTypes.imageBitmapRenderingContext = "getContext"

@send
external transferToImageBitmap: CanvasTypes.offscreenCanvas => CanvasTypes.imageBitmap =
  "transferToImageBitmap"

@send
external convertToBlob: (
  CanvasTypes.offscreenCanvas,
  ~options: CanvasTypes.imageEncodeOptions=?,
) => promise<Blob.t> = "convertToBlob"
