@@warning("-30")

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

@editor.completeFrom(OffscreenCanvas)
type offscreenCanvas = {
  ...EventTypes.eventTarget,
  mutable width: int,
  mutable height: int,
}

@editor.completeFrom(ImageBitmap)
type imageBitmap = private {
  width: int,
  height: int,
}

type offscreenCanvasRenderingContext2D = {
  canvas: offscreenCanvas,
  mutable globalAlpha: float,
  mutable globalCompositeOperation: globalCompositeOperation,
  mutable imageSmoothingEnabled: bool,
  mutable imageSmoothingQuality: imageSmoothingQuality,
  mutable strokeStyle: fillStyle,
  mutable fillStyle: fillStyle,
  mutable shadowOffsetX: float,
  mutable shadowOffsetY: float,
  mutable shadowBlur: float,
  mutable shadowColor: string,
  mutable filter: string,
  mutable lineWidth: float,
  mutable lineCap: canvasLineCap,
  mutable lineJoin: canvasLineJoin,
  mutable miterLimit: float,
  mutable lineDashOffset: float,
  mutable font: string,
  mutable textAlign: canvasTextAlign,
  mutable textBaseline: canvasTextBaseline,
  mutable direction: canvasDirection,
  mutable letterSpacing: string,
  mutable fontKerning: canvasFontKerning,
  mutable fontStretch: canvasFontStretch,
  mutable fontVariantCaps: canvasFontVariantCaps,
  mutable textRendering: canvasTextRendering,
  mutable wordSpacing: string,
}

@editor.completeFrom(ImageBitmapRenderingContext)
type imageBitmapRenderingContext = private {
  canvas: unknown,
}

type webGLRenderingContext = {
  canvas: unknown,
  drawingBufferWidth: float,
  drawingBufferHeight: float,
  mutable drawingBufferColorSpace: predefinedColorSpace,
  mutable unpackColorSpace: predefinedColorSpace,
}

type webGL2RenderingContext = {
  canvas: unknown,
  drawingBufferWidth: float,
  drawingBufferHeight: float,
  mutable drawingBufferColorSpace: predefinedColorSpace,
  mutable unpackColorSpace: predefinedColorSpace,
}

@editor.completeFrom(CanvasGradient)
type canvasGradient = private {}

@editor.completeFrom(CanvasPattern)
type canvasPattern = private {}

@editor.completeFrom(Path2D)
type path2D = private {}

type textMetrics = {
  width: float,
  actualBoundingBoxLeft: float,
  actualBoundingBoxRight: float,
  fontBoundingBoxAscent: float,
  fontBoundingBoxDescent: float,
  actualBoundingBoxAscent: float,
  actualBoundingBoxDescent: float,
  emHeightAscent: float,
  emHeightDescent: float,
  hangingBaseline: float,
  alphabeticBaseline: float,
  ideographicBaseline: float,
}

type offscreenRenderingContext = unknown

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
