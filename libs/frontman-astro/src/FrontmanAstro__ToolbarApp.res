// Frontman Dev Toolbar App
//
// Clicking the Frontman icon in the Astro dev toolbar navigates to
// {currentPage}/<basePath>/ using suffix-based routing, so the preview
// loads the page the user was already on. The trailing slash is always
// included to match Astro's trailingSlash: "always" default and avoid
// redirect loops or 404s from the trailing-slash middleware.
//
// NOTE: The URL construction logic here (trailing-slash ensure, suffix
// append, already-at-path check) is intentionally duplicated from
// Client__BrowserUrl.syncBrowserUrl in libs/client. The two files
// cannot share code because frontman-core is server-only and the client
// bundle cannot depend on it. Keep the two implementations aligned —
// if you change one, update the other.

open FrontmanBindings.Astro

let defaultBasePath = "frontman"

// Read basePath from the <meta name="frontman-base-path"> tag injected
// by FrontmanAstro__Integration. Falls back to defaultBasePath.
let _getBasePath = () => {
  WebAPI.Global.document
  ->WebAPI.Document.querySelector(`meta[name="frontman-base-path"]`)
  ->Null.flatMap(el => el->WebAPI.Element.getAttribute("content"))
  ->Null.toOption
  ->Option.getOr(defaultBasePath)
}

let app: toolbarAppConfig = {
  init: (_canvas, app, _server) => {
    app->onToggled(({state}) => {
      switch state {
      | true =>
        let basePath = _getBasePath()
        // Normalize: ensure pathname always ends with a trailing slash so the
        // constructed URL matches Astro's trailingSlash: "always" expectation.
        let rawPathname = WebAPI.Global.location.pathname
        let pathname = switch rawPathname->String.endsWith("/") {
        | true => rawPathname
        | false => rawPathname ++ "/"
        }
        // If already inside /<basePath>/, stay put. Otherwise append it.
        let alreadyInFrontman =
          pathname == `/${basePath}/` || pathname->String.endsWith(`/${basePath}/`)
        let url = switch alreadyInFrontman {
        | true => pathname
        | false => `${pathname}${basePath}/`
        }
        WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.assign(url)
        app->toggleState({state: false})
      | false => ()
      }
    })
  },
}

let default = defineToolbarApp(app)
