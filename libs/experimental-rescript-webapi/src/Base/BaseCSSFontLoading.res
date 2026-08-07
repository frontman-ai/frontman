type fontFaceLoadStatus =
  | @as("error") Error
  | @as("loaded") Loaded
  | @as("loading") Loading
  | @as("unloaded") Unloaded

type fontFaceSetLoadStatus =
  | @as("loaded") Loaded
  | @as("loading") Loading

@editor.completeFrom(BaseCSSFontLoading.FontFaceSet)
type rec fontFaceSet = private {
  ...BaseEvent.eventTarget,
  ready: promise<fontFaceSet>,
  status: fontFaceSetLoadStatus,
}
