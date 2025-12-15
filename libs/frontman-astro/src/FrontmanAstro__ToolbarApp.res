// Frontman Dev Toolbar App

module Bindings = FrontmanAstro__AstroBindings

// Type for the annotations API exposed on window
type annotation = {
  file: string,
  loc: string,
}

type annotationsApi = {
  get: WebAPI.DOMAPI.element => option<annotation>,
  has: WebAPI.DOMAPI.element => bool,
  size: unit => int,
}

// External binding to window.__frontman_annotations__
@val @scope("window")
external annotations: option<annotationsApi> = "__frontman_annotations__"

// The toolbar app definition
let app: Bindings.toolbarAppConfig = {
  init: (_canvas, _app, _server) => {
    switch annotations {
    | Some(api) if api.size() > 0 =>
      Console.log(`[Frontman] SUCCESS - Captured ${api.size()->Int.toString} elements`)

      // Test retrieval on first h1 or body child
      let testEl =
        WebAPI.Global.document->WebAPI.Document.querySelector("h1")->Null.toOption
      switch testEl {
      | Some(el) =>
        switch api.get(el) {
        | Some(data) =>
          Console.log(`[Frontman] Test element: H1 -> ${data.file}:${data.loc}`)
        | None =>
          Console.log("[Frontman] Test element H1 has no annotation (might be in layout)")
        }
      | None => ()
      }
    | Some(_) =>
      Console.log("[Frontman] WARNING - Annotations API exists but captured 0 elements")
    | None =>
      Console.log("[Frontman] FAILED - window.__frontman_annotations__ not found")
    }
  },
}

// Export as default for Astro to pick up
let default = Bindings.defineToolbarApp(app)
