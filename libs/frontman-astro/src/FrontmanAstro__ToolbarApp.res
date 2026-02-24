// Frontman Dev Toolbar App
//
// Clicking the Frontman icon in the Astro dev toolbar navigates to
// {currentPage}/<basePath> using suffix-based routing, so the preview
// loads the page the user was already on.
//
// NOTE: The URL construction logic here (trailing-slash strip, suffix
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
        // Strip trailing slash to normalize, matching BrowserUrl.syncBrowserUrl.
        let pathname =
          WebAPI.Global.location.pathname->String.replaceRegExp(%re("/\/$/"), "")
        // If already inside /<basePath>, stay put. Otherwise append it.
        let alreadyInFrontman =
          pathname == `/${basePath}` || pathname->String.endsWith(`/${basePath}`)
        let url = switch alreadyInFrontman {
        | true => pathname
        | false =>
          switch pathname {
          | "" => `/${basePath}`
          | p => `${p}/${basePath}`
          }
        }
        WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.assign(url)
        app->toggleState({state: false})
      | false => ()
      }
    })
  },
}

let default = defineToolbarApp(app)
