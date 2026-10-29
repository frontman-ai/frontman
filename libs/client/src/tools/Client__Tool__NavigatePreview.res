module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool

let name = "navigate_preview"
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.ReadWrite
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = `Navigate the preview to a same-origin URL without refreshing Frontman.
Pass a non-empty URL (for example /shop/) to replace the iframe, even when preview tools are unavailable.
Use preview_status to check destination readiness after navigating. An accepted request is NOT destination readiness.
WordPress admin, Customizer, and login pages are unsupported; use WordPress tools for configuration.`

@schema
type input = {url: option<string>}

@schema
type output = {
  @live accepted: bool,
  @live url: string,
  @live message: string,
}

let outputJsonSchema = Some(outputSchema->S.toJSONSchema)

@val external decodeURIComponent: string => string = "decodeURIComponent"

let validateDestination = url => {
  let pathname = WebAPI.URL.make(~url).pathname
  let decoded = try {
    Ok(decodeURIComponent(pathname))
  } catch {
  | exn =>
    switch exn->JsExn.fromException->Option.flatMap(JsExn.name) {
    | Some("URIError") => Error("Invalid preview URL: malformed path encoding.")
    | _ => throw(exn)
    }
  }
  decoded->Result.flatMap(path => {
    let unsupported =
      Client__RuntimeConfig.read().framework == Wordpress &&
      (path->String.toLowerCase->String.split("/")->Array.some(segment =>
        segment == "wp-admin" || segment == "wp-login.php"
      ))
    switch unsupported {
    | true =>
      Error("WordPress admin, Customizer, and login destinations are unsupported in the preview. Use WordPress tools for configuration, or navigate_preview to a supported URL such as /shop/.")
    | false => Ok()
    }
  })
}

@live
let execute = async (
  input: input,
  ~taskId as _: string,
  ~toolCallId as _: string,
  ~signal as _=?,
): Tool.MCP.CallToolResult.t => {
  let state = StateStore.getState(Client__State__Store.store)
  let base = Client__State.Selectors.previewUrl(state)
  let respond = (~accepted, ~url=base, message) =>
    Tool.structuredResult({accepted, url, message}, outputSchema)
  let resolveNavigationUrl = url => {
    let trimmed = url->String.trim
    if String.length(trimmed) == 0 {
      Error("Provide a non-empty URL to navigate, or call preview_status to check readiness.")
    } else {
      Client__BrowserUrl.resolveUrlWithBase(~url=trimmed, ~base)
      ->Option.mapOr(
        Error("Invalid preview URL."),
        url =>
          if Client__BrowserUrl.isSameOriginWithBase(~baseUrl=base, ~targetUrl=url) {
            validateDestination(url)->Result.map(() => url)
          } else {
            Error("Preview navigation must stay on the same origin.")
          },
      )
    }
  }
  switch input.url {
  | None =>
    respond(~accepted=false, "Provide a URL to navigate, or call preview_status to check readiness.")
  | Some(url) =>
    switch url->resolveNavigationUrl {
    | Error(message) => respond(~accepted=false, message)
    | Ok(url) =>
      Client__State.Actions.setCurrentPreviewUrl(~url)
      respond(
        ~accepted=true,
        ~url,
        "Navigation requested. Call preview_status to check destination readiness.",
      )
    }
  }
}
