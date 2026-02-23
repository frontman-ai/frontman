// Frontman Dev Toolbar App
//
// Clicking the Frontman icon in the Astro dev toolbar navigates to /<basePath>/
// where the full Frontman UI is served by the middleware.

module Bindings = FrontmanBindings.Astro

// The toolbar app definition
let app: Bindings.toolbarAppConfig = {
  init: (_canvas, app, _server) => {
    app->Bindings.onToggled(({state}) => {
      switch state {
      | true =>
        // Read basePath from the meta tag injected by the integration
        let basePath = {
          let meta =
            WebAPI.Global.document
            ->WebAPI.Document.querySelector(`meta[name="frontman-base-path"]`)
            ->Null.toOption
          switch meta {
          | Some(el) =>
            el->WebAPI.Element.getAttribute("content")->Null.toOption->Option.getOr("frontman")
          | None => "frontman"
          }
        }

        // Navigate to the Frontman UI
        WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.assign(`/${basePath}/`)

        // Immediately toggle off so the icon doesn't stay "active"
        app->Bindings.toggleState({state: false})
      | false => ()
      }
    })
  },
}

// Export as default for Astro to pick up
let default = Bindings.defineToolbarApp(app)
