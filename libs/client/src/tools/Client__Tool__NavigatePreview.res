module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool

let name = "navigate_preview"
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.ReadWrite
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = `Navigate or recover the storefront preview without refreshing Frontman.
Pass a same-origin storefront URL (for example /shop/) to replace the iframe, even when preview tools are unavailable.
Omit url to check readiness after navigation. An accepted request is NOT destination readiness.
WordPress admin, Customizer, and login pages are unsupported; use WordPress tools for configuration.
If unavailable, retry status after loading or navigate to a known supported storefront URL.`

@schema
type input = {url: option<string>}

@schema
type output = {
  accepted: bool,
  ready: bool,
  url: string,
  message: string,
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
      Error("WordPress admin, Customizer, and login destinations are unsupported in the storefront preview. Use WordPress tools for configuration, or navigate_preview to a storefront URL such as /shop/.")
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
  let respond = (~accepted, ~ready=false, ~url=base, message) =>
    Tool.structuredResult({accepted, ready, url, message}, outputSchema)
  switch input.url {
  | None =>
    switch Client__Tool__PreviewContext.get() {
    | Some({doc}) if validateDestination(doc.url) == Ok() &&
        Client__BrowserUrl.isSameOriginWithBase(~baseUrl=base, ~targetUrl=doc.url) =>
      respond(~accepted=false, ~ready=true, ~url=doc.url, "Preview document is available.")
    | Some(_) | None =>
      respond(
        ~accepted=false,
        "Preview is unavailable or unsupported. It may still be loading, blocked, or missing the frontend bridge. Use navigate_preview with a known same-origin storefront URL such as /shop/ to recover without refreshing Frontman.",
      )
    }
  | Some(url) =>
    switch Client__BrowserUrl.resolveUrlWithBase(~url, ~base) {
    | None => respond(~accepted=false, "Invalid preview URL.")
    | Some(url) =>
      switch Client__BrowserUrl.isSameOriginWithBase(~baseUrl=base, ~targetUrl=url) {
      | false => respond(~accepted=false, "Preview navigation must stay on the same origin.")
      | true =>
        switch validateDestination(url) {
        | Error(message) => respond(~accepted=false, message)
        | Ok() =>
          Client__State.Actions.setCurrentPreviewUrl(~url)
          respond(
            ~accepted=true,
            ~url,
            "Navigation requested, not yet ready. Call navigate_preview without url to check destination readiness before using DOM tools.",
          )
        }
      }
    }
  }
}
