type fontFaceLoadStatus =
  | @as("error") Error
  | @as("loaded") Loaded
  | @as("loading") Loading
  | @as("unloaded") Unloaded

type fontFaceSetLoadStatus =
  | @as("loaded") Loaded
  | @as("loading") Loading

/**
[See FontFaceSet on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet)
*/
@editor.completeFrom(BaseCSSFontLoading.FontFaceSet)
type rec fontFaceSet = private {
  ...BaseEvent.eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/ready)
    */
  ready: promise<fontFaceSet>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FontFaceSet/status)
    */
  status: fontFaceSetLoadStatus,
}
