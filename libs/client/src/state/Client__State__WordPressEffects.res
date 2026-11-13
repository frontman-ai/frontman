open Client__State__Protocol

module Types = Client__State__Types
module Log = FrontmanLogs.Logs.Make({
  let component = #StateReducer
})
let requireEmbeddedAuthentication = Client__State__RequestAuth.requireEmbeddedAuthentication

let completeWordPressRequest = (dispatch, token, requestId, result, ~credentialRisk) => {
  let result = switch (Client__EmbeddedAuth.loadToken() == token, result) {
  | (false, _) => Error(WordPressRequestFailed("Frontman sign-in changed. Check again."))
  | (true, Error(WordPressAuthRequired)) =>
    requireEmbeddedAuthentication(dispatch)
    result
  | (true, _) => result
  }
  dispatch(WordPressConnectionCompletion({requestId, result, credentialRisk}))
}

let runWordPressRequest = async (dispatch, apiBaseUrl, requestId, operation) => {
  let token = Client__EmbeddedAuth.loadToken()
  let credentialRisk = ref(false)
  let result = try {
    switch (
      token->Option.filter(token => token->String.trim != ""),
      Client__EmbeddedAuth.jsonHeaders(),
    ) {
    | (None, _) | (_, None) => Error(WordPressAuthRequired)
    | (Some(_), Some(headers)) =>
      let account = async (path, body, schema) => {
        switch Client__EmbeddedAuth.loadToken() == token {
        | false => Error(WordPressRequestFailed("Frontman sign-in changed. Check again."))
        | true =>
          let response = await WebAPI.Fetch.fetch(
            `${apiBaseUrl}/api/wordpress/connections${path}`,
            ~init={
              method: body->Option.isSome ? "POST" : "GET",
              headers,
              ?body,
              redirect: WebAPI.FetchTypes.Error,
              cache: WebAPI.FetchTypes.NoStore,
              signal: Null.make(WebAPI.AbortSignal.timeout(30000)),
            },
          )
          switch (response.status, response.ok) {
          | (401, _) => Error(WordPressAuthRequired)
          | (_, false) =>
            Error(WordPressRequestFailed("Could not check or save the connection. Try again."))
          | (_, true) =>
            let json = await response->WebAPI.Response.json
            Ok(json->S.decodeOrThrow(~from=S.json, ~to=schema))
          }
        }
      }
      let runtime = Client__RuntimeConfig.read()
      let relay = Client__WordPressRelay.makeConfig(
        ~baseUrl=Client__RelayBaseUrl.current(),
        ~nonce=runtime.wpNonce,
        ~onAuthenticationRequired=() =>
          dispatch(WordPressAuthenticationRequired(runtime.wordpressLoginUrl)),
      )
      let path = switch operation {
      | CheckConnection => "status"
      | ApproveConnection => "connect"
      | UpdateAccess(enabled) => enabled ? "enable" : "disable"
      }
      credentialRisk := operation == ApproveConnection
      let response = await relay.fetch(
        `${relay.baseUrl}/frontman/mcp/${path}`,
        {
          method: operation == CheckConnection ? "GET" : "POST",
          signal: Null.make(WebAPI.AbortSignal.timeout(30000)),
        },
      )
      switch (response.ok, operation) {
      | (false, _) =>
        let json = await response->WebAPI.Response.json
        let error = json->S.decodeOrThrow(~from=S.json, ~to=Types.wordPressConnectionErrorSchema)
        credentialRisk := credentialRisk.contents && Types.wordPressCredentialRisk(error)
        Error(WordPressRequestFailed(error.error))
      | (true, UpdateAccess(_)) =>
        let json = await response->WebAPI.Response.json
        let saved = json->S.decodeOrThrow(~from=S.json, ~to=Types.wordPressAccessStatusSchema)
        Ok({connected: true, enabled: saved.enabled})
      | (true, CheckConnection) =>
        let json = await response->WebAPI.Response.json
        let local = json->S.decodeOrThrow(~from=S.json, ~to=Types.wordPressLocalStatusSchema)
        let query = WebAPI.URLSearchParams.make()
        query->WebAPI.URLSearchParams.set(~name="catalog_url", ~value=local.catalog_url)
        let saved = await account(
          `/status?${query->WebAPI.URLSearchParams.toString}`,
          None,
          Types.wordPressSavedStatusSchema,
        )
        saved->Result.map(saved => {connected: saved.connected, enabled: local.enabled})
      | (true, ApproveConnection) =>
        let body = await response->WebAPI.Response.text
        let saved = await account(
          "",
          Some(WebAPI.BodyInit.fromString(body)),
          Types.wordPressConnectionResponseSchema,
        )
        saved->Result.map(_ => {connected: true, enabled: true})
      }
    }
  } catch {
  | exn =>
    Log.error(~error=JsExn.fromException(exn), "WordPress connection request failed")
    Error(WordPressRequestFailed("Could not confirm WordPress access. Check again."))
  }
  completeWordPressRequest(
    dispatch,
    token,
    requestId,
    result,
    ~credentialRisk=credentialRisk.contents,
  )
}
