// Unified Source Detection - cascading strategy for multiple frameworks
// Tries React fiber detection first (works for React apps and Astro islands),
// then falls back to Astro annotations for pure Astro elements.

let getElementSourceLocation = async (
  ~element: WebAPI.DOMAPI.element,
  ~window: WebAPI.DOMAPI.window,
): option<Client__Types.SourceLocation.t> => {
  // 1. Try React fiber detection (works for React apps AND Astro islands)
  let reactResult = await Bindings__DOMElementToComponentSource.getElementSourceLocation(~element)

  switch reactResult {
  | Some(_) => reactResult
  | None =>
    // 2. Fall back to Astro annotations
    Bindings__AstroSourceDetection.getElementSourceLocation(~element, ~window)
  }
}
