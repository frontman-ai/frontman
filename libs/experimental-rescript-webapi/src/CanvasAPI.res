@@warning("-30")

open Prelude
open EventAPI

type offscreenRenderingContextId =
  | @as("2d") V2d
  | @as("bitmaprenderer") Bitmaprenderer
  | @as("webgl") Webgl
  | @as("webgl2") Webgl2
  | @as("webgpu") Webgpu

type globalCompositeOperation =
  | @as("color") Color
  | @as("color-burn") ColorBurn
  | @as("color-dodge") ColorDodge
  | @as("copy") Copy
  | @as("darken") Darken
  | @as("destination-atop") DestinationAtop
  | @as("destination-in") DestinationIn
  | @as("destination-out") DestinationOut
  | @as("destination-over") DestinationOver
  | @as("difference") Difference
  | @as("exclusion") Exclusion
  | @as("hard-light") HardLight
  | @as("hue") Hue
  | @as("lighten") Lighten
  | @as("lighter") Lighter
  | @as("luminosity") Luminosity
  | @as("multiply") Multiply
  | @as("overlay") Overlay
  | @as("saturation") Saturation
  | @as("screen") Screen
  | @as("soft-light") SoftLight
  | @as("source-atop") SourceAtop
  | @as("source-in") SourceIn
  | @as("source-out") SourceOut
  | @as("source-over") SourceOver
  | @as("xor") Xor

type imageSmoothingQuality =
  | @as("high") High
  | @as("low") Low
  | @as("medium") Medium

type canvasLineCap =
  | @as("butt") Butt
  | @as("round") Round
  | @as("square") Square

type canvasLineJoin =
  | @as("bevel") Bevel
  | @as("miter") Miter
  | @as("round") Round

type canvasTextAlign =
  | @as("center") Center
  | @as("end") End
  | @as("left") Left
  | @as("right") Right
  | @as("start") Start

type canvasTextBaseline =
  | @as("alphabetic") Alphabetic
  | @as("bottom") Bottom
  | @as("hanging") Hanging
  | @as("ideographic") Ideographic
  | @as("middle") Middle
  | @as("top") Top

type canvasDirection =
  | @as("inherit") Inherit
  | @as("ltr") Ltr
  | @as("rtl") Rtl

type canvasFontKerning =
  | @as("auto") Auto
  | @as("none") None
  | @as("normal") Normal

type canvasFontStretch =
  | @as("condensed") Condensed
  | @as("expanded") Expanded
  | @as("extra-condensed") ExtraCondensed
  | @as("extra-expanded") ExtraExpanded
  | @as("normal") Normal
  | @as("semi-condensed") SemiCondensed
  | @as("semi-expanded") SemiExpanded
  | @as("ultra-condensed") UltraCondensed
  | @as("ultra-expanded") UltraExpanded

type canvasFontVariantCaps =
  | @as("all-petite-caps") AllPetiteCaps
  | @as("all-small-caps") AllSmallCaps
  | @as("normal") Normal
  | @as("petite-caps") PetiteCaps
  | @as("small-caps") SmallCaps
  | @as("titling-caps") TitlingCaps
  | @as("unicase") Unicase

type canvasTextRendering =
  | @as("auto") Auto
  | @as("geometricPrecision") GeometricPrecision
  | @as("optimizeLegibility") OptimizeLegibility
  | @as("optimizeSpeed") OptimizeSpeed

type predefinedColorSpace =
  | @as("display-p3") DisplayP3
  | @as("srgb") Srgb

type canvasFillRule =
  | @as("evenodd") Evenodd
  | @as("nonzero") Nonzero

type webGLPowerPreference =
  | @as("default") Default
  | @as("high-performance") HighPerformance
  | @as("low-power") LowPower

@editor.completeFrom(FillStyle) type fillStyle

/**
[See OffscreenCanvas on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas)
*/
@editor.completeFrom(OffscreenCanvas)
type offscreenCanvas = {
  ...eventTarget,
  /**
    These attributes return the dimensions of the OffscreenCanvas object's bitmap.

They can be set, to replace the bitmap with a new, transparent black bitmap of the specified dimensions (effectively resizing it).
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas/width)
    */
  mutable width: int,
  /**
    These attributes return the dimensions of the OffscreenCanvas object's bitmap.

They can be set, to replace the bitmap with a new, transparent black bitmap of the specified dimensions (effectively resizing it).
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvas/height)
    */
  mutable height: int,
}

/**
[See ImageBitmap on MDN](https://developer.mozilla.org/docs/Web/API/ImageBitmap)
*/
@editor.completeFrom(ImageBitmap)
type imageBitmap = {
  /**
    Returns the intrinsic width of the image, in CSS pixels.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageBitmap/width)
    */
  width: int,
  /**
    Returns the intrinsic height of the image, in CSS pixels.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageBitmap/height)
    */
  height: int,
}

/**
[See OffscreenCanvasRenderingContext2D on MDN](https://developer.mozilla.org/docs/Web/API/OffscreenCanvasRenderingContext2D)
*/
type offscreenCanvasRenderingContext2D = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/canvas)
    */
  canvas: offscreenCanvas,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/globalAlpha)
    */
  mutable globalAlpha: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/globalCompositeOperation)
    */
  mutable globalCompositeOperation: globalCompositeOperation,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/imageSmoothingEnabled)
    */
  mutable imageSmoothingEnabled: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/imageSmoothingQuality)
    */
  mutable imageSmoothingQuality: imageSmoothingQuality,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/strokeStyle)
    */
  mutable strokeStyle: fillStyle,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fillStyle)
    */
  mutable fillStyle: fillStyle,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/shadowOffsetX)
    */
  mutable shadowOffsetX: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/shadowOffsetY)
    */
  mutable shadowOffsetY: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/shadowBlur)
    */
  mutable shadowBlur: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/shadowColor)
    */
  mutable shadowColor: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/filter)
    */
  mutable filter: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineWidth)
    */
  mutable lineWidth: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineCap)
    */
  mutable lineCap: canvasLineCap,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineJoin)
    */
  mutable lineJoin: canvasLineJoin,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/miterLimit)
    */
  mutable miterLimit: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/lineDashOffset)
    */
  mutable lineDashOffset: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/font)
    */
  mutable font: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/textAlign)
    */
  mutable textAlign: canvasTextAlign,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/textBaseline)
    */
  mutable textBaseline: canvasTextBaseline,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/direction)
    */
  mutable direction: canvasDirection,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/letterSpacing)
    */
  mutable letterSpacing: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fontKerning)
    */
  mutable fontKerning: canvasFontKerning,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fontStretch)
    */
  mutable fontStretch: canvasFontStretch,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/fontVariantCaps)
    */
  mutable fontVariantCaps: canvasFontVariantCaps,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/textRendering)
    */
  mutable textRendering: canvasTextRendering,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CanvasRenderingContext2D/wordSpacing)
    */
  mutable wordSpacing: string,
}

/**
[See ImageBitmapRenderingContext on MDN](https://developer.mozilla.org/docs/Web/API/ImageBitmapRenderingContext)
*/
@editor.completeFrom(ImageBitmapRenderingContext)
type imageBitmapRenderingContext = {
  /**
    Returns the canvas element that the context is bound to.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ImageBitmapRenderingContext/canvas)
    */
  canvas: unknown,
}

/**
Provides an interface to the OpenGL ES 2.0 graphics rendering context for the drawing surface of an HTML <canvas> element.
[See WebGLRenderingContext on MDN](https://developer.mozilla.org/docs/Web/API/WebGLRenderingContext)
*/
type webGLRenderingContext = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGLRenderingContext/canvas)
    */
  canvas: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGLRenderingContext/drawingBufferWidth)
    */
  drawingBufferWidth: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGLRenderingContext/drawingBufferHeight)
    */
  drawingBufferHeight: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGLRenderingContext/drawingBufferColorSpace)
    */
  mutable drawingBufferColorSpace: predefinedColorSpace,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGL2RenderingContext/unpackColorSpace)
    */
  mutable unpackColorSpace: predefinedColorSpace,
}

/**
[See WebGL2RenderingContext on MDN](https://developer.mozilla.org/docs/Web/API/WebGL2RenderingContext)
*/
type webGL2RenderingContext = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGLRenderingContext/canvas)
    */
  canvas: unknown,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGLRenderingContext/drawingBufferWidth)
    */
  drawingBufferWidth: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGLRenderingContext/drawingBufferHeight)
    */
  drawingBufferHeight: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGLRenderingContext/drawingBufferColorSpace)
    */
  mutable drawingBufferColorSpace: predefinedColorSpace,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebGL2RenderingContext/unpackColorSpace)
    */
  mutable unpackColorSpace: predefinedColorSpace,
}

/**
An opaque object describing a gradient. It is returned by the methods CanvasRenderingContext2D.createLinearGradient() or CanvasRenderingContext2D.createRadialGradient().
[See CanvasGradient on MDN](https://developer.mozilla.org/docs/Web/API/CanvasGradient)
*/
@editor.completeFrom(CanvasGradient)
type canvasGradient = {}

/**
An opaque object describing a pattern, based on an image, a canvas, or a video, created by the CanvasRenderingContext2D.createPattern() method.
[See CanvasPattern on MDN](https://developer.mozilla.org/docs/Web/API/CanvasPattern)
*/
@editor.completeFrom(CanvasPattern)
type canvasPattern = {}

/**
This Canvas 2D API interface is used to declare a path that can then be used on a CanvasRenderingContext2D object. The path methods of the CanvasRenderingContext2D interface are also present on this interface, which gives you the convenience of being able to retain and replay your path whenever desired.
[See Path2D on MDN](https://developer.mozilla.org/docs/Web/API/Path2D)
*/
@editor.completeFrom(Path2D)
type path2D = {}

/**
The dimensions of a piece of text in the canvas, as created by the CanvasRenderingContext2D.measureText() method.
[See TextMetrics on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics)
*/
type textMetrics = {
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/width)
    */
  width: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/actualBoundingBoxLeft)
    */
  actualBoundingBoxLeft: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/actualBoundingBoxRight)
    */
  actualBoundingBoxRight: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/fontBoundingBoxAscent)
    */
  fontBoundingBoxAscent: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/fontBoundingBoxDescent)
    */
  fontBoundingBoxDescent: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/actualBoundingBoxAscent)
    */
  actualBoundingBoxAscent: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/actualBoundingBoxDescent)
    */
  actualBoundingBoxDescent: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/emHeightAscent)
    */
  emHeightAscent: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/emHeightDescent)
    */
  emHeightDescent: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/hangingBaseline)
    */
  hangingBaseline: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/alphabeticBaseline)
    */
  alphabeticBaseline: float,
  /**
    Returns the measurement described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/TextMetrics/ideographicBaseline)
    */
  ideographicBaseline: float,
}

type offscreenRenderingContext = any

type imageEncodeOptions = {
  @as("type") mutable type_?: string,
  mutable quality?: float,
}

type canvasRenderingContext2DSettings = {
  mutable alpha?: bool,
  mutable desynchronized?: bool,
  mutable colorSpace?: predefinedColorSpace,
  mutable willReadFrequently?: bool,
}

type webGLContextAttributes = {
  mutable alpha?: bool,
  mutable depth?: bool,
  mutable stencil?: bool,
  mutable antialias?: bool,
  mutable premultipliedAlpha?: bool,
  mutable preserveDrawingBuffer?: bool,
  mutable powerPreference?: webGLPowerPreference,
  mutable failIfMajorPerformanceCaveat?: bool,
  mutable desynchronized?: bool,
}

type imageBitmapRenderingContextSettings = {mutable alpha?: bool}
