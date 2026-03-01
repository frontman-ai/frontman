// Unified Source Detection - cascading strategy for multiple frameworks
// Tries React fiber detection first (works for React apps and Astro islands),
// then Vue component instance detection, then falls back to Astro annotations.

let getElementSourceLocation = async (
  ~element: WebAPI.DOMAPI.element,
  ~window: WebAPI.DOMAPI.window,
): option<Client__Types.SourceLocation.t> => {
  // 1. Try React fiber detection (works for React apps AND Astro islands)
  let reactResult = await Client__DOMElementToComponentSource.getElementSourceLocation(~element)

  switch reactResult {
  | Some(_) => reactResult
  | None =>
    // 2. Try Vue 3 component instance detection
    let vueResult = Client__Vue__SourceDetection.getElementSourceLocation(~element)

    switch vueResult {
    | Some(_) => vueResult
    | None =>
      // 3. Fall back to Astro annotations
      Client__AstroSourceDetection.getElementSourceLocation(~element, ~window)
    }
  }
}
