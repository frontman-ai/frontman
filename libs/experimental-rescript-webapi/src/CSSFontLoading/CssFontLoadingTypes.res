@@warning("-30")

type fontDisplay =
  | @as("auto") Auto
  | @as("block") Block
  | @as("fallback") Fallback
  | @as("optional") Optional
  | @as("swap") Swap

type fontFaceLoadStatus = BaseCSSFontLoading.fontFaceLoadStatus =
  | @as("error") Error
  | @as("loaded") Loaded
  | @as("loading") Loading
  | @as("unloaded") Unloaded

type fontFaceSetLoadStatus = BaseCSSFontLoading.fontFaceSetLoadStatus =
  | @as("loaded") Loaded
  | @as("loading") Loading

/**
[See FontFace on MDN](https://developer.mozilla.org/docs/Web/API/FontFace)
TODO: mark as private once mutating fields of private records is allowed
*/
@editor.completeFrom(FontFace)
type rec fontFace = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/family)
    */
  mutable family: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/style)
    */
  mutable style: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/weight)
    */
  mutable weight: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/stretch)
    */
  mutable stretch: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/unicodeRange)
    */
  mutable unicodeRange: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/featureSettings)
    */
  mutable featureSettings: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/display)
    */
  mutable display: fontDisplay,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/ascentOverride)
    */
  mutable ascentOverride: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/descentOverride)
    */
  mutable descentOverride: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/lineGapOverride)
    */
  mutable lineGapOverride: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/status)
    */
  status: fontFaceLoadStatus,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFace/loaded)
    */
  loaded: promise<fontFace>,
}

/**
[See FontFaceSet on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet)
*/
@editor.completeFrom(FontFaceSet)
type fontFaceSet = BaseCSSFontLoading.fontFaceSet

type fontFaceDescriptors = {
  mutable style?: string,
  mutable weight?: string,
  mutable stretch?: string,
  mutable unicodeRange?: string,
  mutable featureSettings?: string,
  mutable display?: fontDisplay,
  mutable ascentOverride?: string,
  mutable descentOverride?: string,
  mutable lineGapOverride?: string,
}
