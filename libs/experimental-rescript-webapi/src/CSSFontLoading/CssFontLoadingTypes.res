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

@editor.completeFrom(FontFace)
type rec fontFace = {
  mutable family: string,
  mutable style: string,
  mutable weight: string,
  mutable stretch: string,
  mutable unicodeRange: string,
  mutable featureSettings: string,
  mutable display: fontDisplay,
  mutable ascentOverride: string,
  mutable descentOverride: string,
  mutable lineGapOverride: string,
  status: fontFaceLoadStatus,
  loaded: promise<fontFace>,
}

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
