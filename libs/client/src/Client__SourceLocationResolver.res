@schema
type resolverErrorResponse = {
  error: string,
  details: option<string>,
}

let resolve = async (sourceContext: Client__SourceContext.t): result<
  Client__Types.SourceLocation.t,
  string,
> => {
  let runtimeConfig = Client__RuntimeConfig.read()
  let baseUrl = runtimeConfig.mcpBaseUrl->Option.getOr(Client__MCPBaseUrl.current())
  let url = `${baseUrl}/frontman/resolve-source-location`
  let headers = Dict.fromArray([("Content-Type", "application/json")])
  runtimeConfig.wpNonce->Option.forEach(nonce => headers->Dict.set("X-WP-Nonce", nonce))
  let requestJson =
    sourceContext->S.decodeOrThrow(
      ~from=Client__SourceContext.schema,
      ~to=S.json->S.noValidation(true),
    )
  let requestBody = requestJson->JSON.stringifyAny->Option.getOrThrow

  try {
    let response = await WebAPI.Fetch.fetch(
      url,
      ~init={
        method: "POST",
        headers: WebAPI.HeadersInit.fromDict(headers),
        body: WebAPI.BodyInit.fromString(requestBody),
      },
    )

    switch response.ok {
    | false =>
      let json = await response->WebAPI.Response.json
      let errorResponse = json->S.parseOrThrow(~to=resolverErrorResponseSchema)
      let details = switch errorResponse.details {
      | Some(details) => `: ${details}`
      | None => ""
      }
      Error(`HTTP ${response.status->Int.toString}: ${errorResponse.error}${details}`)
    | true =>
      let json = await response->WebAPI.Response.json
      let resolvedContext = json->S.parseOrThrow(~to=Client__SourceContext.schema)
      switch Client__SourceContext.toSourceLocation(resolvedContext) {
      | Some(sourceLocation) => Ok(sourceLocation)
      | None => Error("Resolved source context is empty")
      }
    }
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to resolve source location: ${msg}`)
  }
}
