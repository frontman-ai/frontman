open CanvasAPI
open FileAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas)
*/
@new
external make: (~width: int, ~height: int) => offscreenCanvas = "OffscreenCanvas"

include EventTarget.Impl({type t = offscreenCanvas})

/**
Returns an object that exposes an API for drawing on the OffscreenCanvas object. contextId specifies the desired API: "2d", "bitmaprenderer", "webgl", or "webgl2". options is handled by that API.

This specification defines the "2d" context below, which is similar but distinct from the "2d" context that is created from a canvas element. The WebGL specifications define the "webgl" and "webgl2" contexts. [WEBGL]

Returns null if the canvas has already been initialized with another context type (e.g., trying to get a "2d" context after getting a "webgl" context).
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas/getContext)
*/
@send
external getContext_2D: (
  offscreenCanvas,
  @as("2d") _,
  ~options: JSON.t=?,
) => offscreenCanvasRenderingContext2D = "getContext"

/**
Returns an object that exposes an API for drawing on the OffscreenCanvas object. contextId specifies the desired API: "2d", "bitmaprenderer", "webgl", or "webgl2". options is handled by that API.

This specification defines the "2d" context below, which is similar but distinct from the "2d" context that is created from a canvas element. The WebGL specifications define the "webgl" and "webgl2" contexts. [WEBGL]

Returns null if the canvas has already been initialized with another context type (e.g., trying to get a "2d" context after getting a "webgl" context).
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas/getContext)
*/
@send
external getContext_WebGL: (
  offscreenCanvas,
  @as("webgl") _,
  ~options: webGLContextAttributes=?,
) => webGLRenderingContext = "getContext"

/**
Returns an object that exposes an API for drawing on the OffscreenCanvas object. contextId specifies the desired API: "2d", "bitmaprenderer", "webgl", or "webgl2". options is handled by that API.

This specification defines the "2d" context below, which is similar but distinct from the "2d" context that is created from a canvas element. The WebGL specifications define the "webgl" and "webgl2" contexts. [WEBGL]

Returns null if the canvas has already been initialized with another context type (e.g., trying to get a "2d" context after getting a "webgl" context).
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas/getContext)
*/
@send
external getContext_WebGL2: (
  offscreenCanvas,
  @as("webgl2") _,
  ~options: webGLContextAttributes=?,
) => webGL2RenderingContext = "getContext"

/**
Returns an object that exposes an API for drawing on the OffscreenCanvas object. contextId specifies the desired API: "2d", "bitmaprenderer", "webgl", or "webgl2". options is handled by that API.

This specification defines the "2d" context below, which is similar but distinct from the "2d" context that is created from a canvas element. The WebGL specifications define the "webgl" and "webgl2" contexts. [WEBGL]

Returns null if the canvas has already been initialized with another context type (e.g., trying to get a "2d" context after getting a "webgl" context).
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas/getContext)
*/
@send
external getContext_BitmapRenderer: (
  offscreenCanvas,
  @as("bitmaprenderer") _,
  ~options: imageBitmapRenderingContextSettings=?,
) => imageBitmapRenderingContext = "getContext"

/**
Returns a newly created ImageBitmap object with the image in the OffscreenCanvas object. The image in the OffscreenCanvas object is replaced with a new blank image.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas/transferToImageBitmap)
*/
@send
external transferToImageBitmap: offscreenCanvas => imageBitmap = "transferToImageBitmap"

/**
Returns a promise that will fulfill with a new Blob object representing a file containing the image in the OffscreenCanvas object.

The argument, if provided, is a dictionary that controls the encoding options of the image file to be created. The type field specifies the file format and has a default value of "image/png"; that type is also used if the requested type isn't supported. If the image format supports variable quality (such as "image/jpeg"), then the quality field is a number in the range 0.0 to 1.0 inclusive indicating the desired quality level for the resulting image.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas/convertToBlob)
*/
@send
external convertToBlob: (offscreenCanvas, ~options: imageEncodeOptions=?) => promise<blob> =
  "convertToBlob"
