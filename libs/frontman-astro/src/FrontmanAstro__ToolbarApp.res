open FrontmanBindings.Astro

let defaultBasePath = "frontman"

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
        let rawPathname = WebAPI.Global.location.pathname
        let pathname = switch rawPathname->String.endsWith("/") {
        | true => rawPathname
        | false => rawPathname ++ "/"
        }
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

@@live
let default = defineToolbarApp(app)
