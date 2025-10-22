open DOMAPI
open CanvasAPI
open MediaCaptureAndStreamsAPI

include HTMLElement.Impl({type t = htmlCanvasElement})

/**
Returns an object that provides methods and properties for drawing and manipulating images and graphics on a canvas element in a document. A context object includes information about colors, line widths, fonts, and other graphic parameters that can be drawn on a canvas.
Creates a CanvasRenderingContext2D object representing a two-dimensional rendering context.

[Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/getContext#2d)
*/
@send
external getContext_2D: (
  htmlCanvasElement,
  @as("2d") _,
  ~options: canvasRenderingContext2DSettings=?,
) => canvasRenderingContext2D = "getContext"

/**
Returns an object that provides methods and properties for drawing and manipulating images and graphics on a canvas element in a document. A context object includes information about colors, line widths, fonts, and other graphic parameters that can be drawn on a canvas.
@param contextId The identifier (ID) of the type of canvas to create. Internet Explorer 9 and Internet Explorer 10 support only a 2-D context using canvas.getContext("2d"); IE11 Preview also supports 3-D or WebGL context using canvas.getContext("experimental-webgl");
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement/getContext)
*/
@send
external getContext_WebGL: (
  htmlCanvasElement,
  @as("webgl") _,
  ~options: webGLContextAttributes=?,
) => webGLRenderingContext = "getContext"

/**
Returns an object that provides methods and properties for drawing and manipulating images and graphics on a canvas element in a document. A context object includes information about colors, line widths, fonts, and other graphic parameters that can be drawn on a canvas.
@param contextId The identifier (ID) of the type of canvas to create. Internet Explorer 9 and Internet Explorer 10 support only a 2-D context using canvas.getContext("2d"); IE11 Preview also supports 3-D or WebGL context using canvas.getContext("experimental-webgl");
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement/getContext)
*/
@send
external getContext_WebGL2: (
  htmlCanvasElement,
  @as("webgl2") _,
  ~options: webGLContextAttributes=?,
) => webGL2RenderingContext = "getContext"

/**
Returns an object that provides methods and properties for drawing and manipulating images and graphics on a canvas element in a document. A context object includes information about colors, line widths, fonts, and other graphic parameters that can be drawn on a canvas.
@param contextId The identifier (ID) of the type of canvas to create. Internet Explorer 9 and Internet Explorer 10 support only a 2-D context using canvas.getContext("2d"); IE11 Preview also supports 3-D or WebGL context using canvas.getContext("experimental-webgl");
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement/getContext)
*/
@send
external getContext_BitmapRenderer: (
  htmlCanvasElement,
  @as("bitmaprenderer") _,
  ~options: imageBitmapRenderingContextSettings=?,
) => imageBitmapRenderingContext = "getContext"

/**
Returns the content of the current canvas as an image that you can use as a source for another canvas or an HTML element.
@param type The standard MIME type for the image format to return. If you do not specify this parameter, the default value is a PNG format image.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement/toDataURL)
*/
@send
external toDataURL: (htmlCanvasElement, ~type_: string=?, ~quality: JSON.t=?) => string =
  "toDataURL"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement/toBlob)
*/
@send
external toBlob: (
  htmlCanvasElement,
  ~callback: blobCallback,
  ~type_: string=?,
  ~quality: JSON.t=?,
) => unit = "toBlob"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement/transferControlToOffscreen)
*/
@send
external transferControlToOffscreen: htmlCanvasElement => offscreenCanvas =
  "transferControlToOffscreen"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCanvasElement/captureStream)
*/
@send
external captureStream: (htmlCanvasElement, ~frameRequestRate: float=?) => mediaStream =
  "captureStream"
