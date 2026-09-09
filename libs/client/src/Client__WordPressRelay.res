module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay

@new external makeHeaders: option<WebAPI.HeadersInit.t> => WebAPI.FetchTypes.headers = "Headers"

let make = (~baseUrl, ~nonce: option<string>) => {
  let nonce = ref(nonce)
  let fetch = async (url, init: WebAPI.FetchTypes.requestInit) => {
    let headers = makeHeaders(init.headers)
    nonce.contents->Option.forEach(value => headers->WebAPI.Headers.set(~name="X-WP-Nonce", ~value))
    let init = {
      ...init,
      headers: WebAPI.HeadersInit.fromHeaders(headers),
      mode: WebAPI.FetchTypes.SameOrigin,
      redirect: WebAPI.FetchTypes.Error,
      cache: WebAPI.FetchTypes.NoStore,
    }
    let response = await WebAPI.Fetch.fetch(url, ~init)
    switch (response.status, response.headers->WebAPI.Headers.get("X-WP-Nonce")->Null.toOption) {
    | (403, Some(replacement)) if replacement->String.trim != "" =>
      let failure = await Relay.readHttpError(response->WebAPI.Response.clone)
      switch failure.code {
      | Some("frontman_missing_nonce" | "frontman_invalid_nonce") =>
        nonce := Some(replacement)
        headers->WebAPI.Headers.set(~name="X-WP-Nonce", ~value=replacement)
        await WebAPI.Fetch.fetch(url, ~init)
      | _ => response
      }
    | _ => response
    }
  }
  Relay.make(~baseUrl, ~fetch)
}
