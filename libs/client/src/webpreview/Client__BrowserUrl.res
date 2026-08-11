module Log = FrontmanLogs.Logs.Make({
  let component = #BrowserUrl
})

let _getBasePath: unit => string = {
  let cached = ref(None)
  () =>
    switch cached.contents {
    | Some(bp) => bp
    | None =>
      let bp = try {
        Client__RuntimeConfig.read().basePath
      } catch {
      | _ =>
        Log.warning("RuntimeConfig.basePath unavailable, falling back to \"frontman\"")
        "frontman"
      }
      cached := Some(bp)
      bp
    }
}

let removeTrailingSlash = s =>
  switch s->String.endsWith("/") && String.length(s) > 1 {
  | true => s->String.slice(~start=0, ~end=String.length(s) - 1)
  | false => s
  }

let _escapeRegex = s => s->String.replaceRegExp(/[.*+?^${}()|[\\]\\\\]/g, "\\$&")

let hasSuffix = pathname => {
  let sfx = _getBasePath()->_escapeRegex
  let re = RegExp.fromString(`(\\/${sfx})+\\/?$`)
  re->RegExp.test(pathname)
}

let stripSuffix = pathname => {
  switch hasSuffix(pathname) {
  | false => pathname
  | true =>
    let sfx = _getBasePath()->_escapeRegex
    let re = RegExp.fromString(`(\\/${sfx})+\\/?$`)
    switch pathname->String.replaceRegExp(re, "") {
    | "" => "/"
    | p =>
      switch p->String.endsWith("/") {
      | true => p
      | false => p ++ "/"
      }
    }
  }
}

let getInitialUrl = () => {
  let currentUrl =
    WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
  let previewPath = WebAPI.Global.location.pathname->stripSuffix
  let default = `${currentUrl.protocol}//${currentUrl.host}${previewPath}`

  WebAPI.Global.document
  ->WebAPI.Document.querySelector("#frontman-entrypoint-url")
  ->Null.flatMap(element => {
    element->WebAPI.Element.asNode->WebAPI.Node.textContent
  })
  ->Null.toOption
  ->Option.map(entrypointUrl => {
    let browserProtocol = currentUrl.protocol
    try {
      let parsed = WebAPI.URL.make(~url=entrypointUrl)
      switch parsed.protocol == browserProtocol {
      | true => entrypointUrl
      | false =>
        `${browserProtocol}//${parsed.host}${parsed.pathname}${parsed.search}${parsed.hash}`
      }
    } catch {
    | _ => entrypointUrl
    }
  })
  ->Option.getOr(default)
}

let resolveUrlWithBase = (~url: string, ~base: string): option<string> => {
  try {
    Some(WebAPI.URL.make(~url, ~base).href)
  } catch {
  | _ => None
  }
}

let isSameOriginWithBase = (~baseUrl: string, ~targetUrl: string): bool => {
  try {
    let base = WebAPI.URL.make(~url=baseUrl)
    let target = WebAPI.URL.make(~url=targetUrl, ~base=baseUrl)
    base.protocol == target.protocol && base.host == target.host
  } catch {
  | _ => false
  }
}

let syncBrowserUrl = (~previewUrl) => {
  let basePath = _getBasePath()
  let pathname = WebAPI.URL.make(~url=previewUrl).pathname->removeTrailingSlash
  let newPath = switch pathname {
  | "" | "/" => `/${basePath}/`
  | p => `${p}/${basePath}/`
  }
  switch WebAPI.Global.location.pathname == newPath {
  | true => ()
  | false =>
    WebAPI.Global.history->WebAPI.History.replaceState(
      ~data=JSON.Encode.null,
      ~unused="",
      ~url=newPath,
    )
  }
}
