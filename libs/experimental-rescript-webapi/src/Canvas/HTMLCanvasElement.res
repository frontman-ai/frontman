include HTMLElement.Impl({type t = DomTypes.htmlCanvasElement})

@send
external getContext2D: (
  DomTypes.htmlCanvasElement,
  @as("2d") _,
  ~options: CanvasTypes.canvasRenderingContext2DSettings=?,
) => DomTypes.canvasRenderingContext2D = "getContext"

let getContext_2D = canvas => getContext2D(canvas)

@send
external getContextWebGL: (
  DomTypes.htmlCanvasElement,
  @as("webgl") _,
  ~options: CanvasTypes.webGLContextAttributes=?,
) => CanvasTypes.webGLRenderingContext = "getContext"

@send
external getContextWebGL2: (
  DomTypes.htmlCanvasElement,
  @as("webgl2") _,
  ~options: CanvasTypes.webGLContextAttributes=?,
) => CanvasTypes.webGL2RenderingContext = "getContext"

@send
external getContextBitmapRenderer: (
  DomTypes.htmlCanvasElement,
  @as("bitmaprenderer") _,
  ~options: CanvasTypes.imageBitmapRenderingContextSettings=?,
) => CanvasTypes.imageBitmapRenderingContext = "getContext"

@send
external toDataURL: (DomTypes.htmlCanvasElement, ~type_: string=?, ~quality: JSON.t=?) => string =
  "toDataURL"

@send
external toBlob: (
  DomTypes.htmlCanvasElement,
  ~callback: FileTypes.blob => unit,
  ~type_: string=?,
  ~quality: JSON.t=?,
) => unit = "toBlob"

@send
external transferControlToOffscreen: DomTypes.htmlCanvasElement => CanvasTypes.offscreenCanvas =
  "transferControlToOffscreen"

@send
external captureStream: (
  DomTypes.htmlCanvasElement,
  ~frameRequestRate: float=?,
) => MediaCaptureAndStreamsTypes.mediaStream = "captureStream"
