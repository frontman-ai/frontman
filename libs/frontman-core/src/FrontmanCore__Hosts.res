/** The production API server host (without protocol). */
let apiHost = "api.frontman.sh"

@@live
let devApiHost = "frontman.local:4000"

/** The production client bundle URL. */
let clientJs = "https://app.frontman.sh/frontman.es.js"

/** The production client CSS URL. */
let clientCss = "https://app.frontman.sh/frontman.css"

/** The local dev client entry point (used when developing frontman itself). */
let devClientJs = "http://localhost:5173/src/Main.res.mjs"

let clientUrl = (~baseUrl, ~clientName, ~host, ~isDev, ~sentryDsn, ~preserveExisting) => {
  let baseUrl =
    baseUrl
    ->Option.orElse(FrontmanBindings.Process.env->Dict.get("FRONTMAN_CLIENT_URL"))
    ->Option.getOr(
      switch isDev {
      | true => devClientJs
      | false => clientJs
      },
    )
  let url = WebAPI.URL.make(~url=baseUrl)
  let setIfMissing = (name, value) =>
    switch (preserveExisting, url.searchParams->WebAPI.URLSearchParams.has(~name)) {
    | (true, true) => ()
    | _ => url.searchParams->WebAPI.URLSearchParams.set(~name, ~value)
    }

  setIfMissing("clientName", clientName)
  setIfMissing("host", host)
  sentryDsn->Option.forEach(dsn => setIfMissing("sentryDsn", dsn))
  url.href
}
