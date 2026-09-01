module MediaTypes = FrontmanCore__MCP__MediaTypes
module RequestBody = FrontmanCore__MCP__RequestBody
module BodyReader = FrontmanCore__MCP__BodyReader
module BodyDecoder = FrontmanCore__MCP__BodyDecoder
module DecodedRequest = FrontmanCore__MCP__DecodedRequest
module ErrorResponse = FrontmanCore__MCP__ErrorResponse
module ToolRegistry = FrontmanCore__ToolRegistry
module RawHeaders = FrontmanCore__MCP__RawHeaders
module HttpSecurity = FrontmanCore__MCP__HttpSecurity

type accepted = {
  origin: string,
  request: DecodedRequest.accepted,
}

type t =
  | Accepted(accepted)
  | Completed(WebAPI.Response.t)
  | Rejected(WebAPI.Response.t)

let emptyResponse = (status: int) => WebAPI.Response.fromNull(~init={status: status})

let mediaErrorResponse = error =>
  switch error {
  | MediaTypes.UnsupportedMediaType => emptyResponse(415)
  | MediaTypes.NotAcceptable => emptyResponse(406)
  }

let bodyErrorResponse = error =>
  switch error {
  | RequestBody.BodyAlreadyUsed => failwith("MCP request body was already consumed")
  | RequestBody.ReaderError(BodyReader.BodyTooLarge)
  | RequestBody.DecoderError(BodyDecoder.BodyTooLarge) =>
    emptyResponse(413)
  | RequestBody.ReaderError(BodyReader.BodyTimedOut) => emptyResponse(408)
  | RequestBody.MissingBody
  | RequestBody.ReaderError(BodyReader.InvalidContentLength)
  | RequestBody.ReaderError(BodyReader.BodyTooFragmented)
  | RequestBody.DecoderError(BodyDecoder.InvalidUtf8)
  | RequestBody.DecoderError(BodyDecoder.JsonTooDeep)
  | RequestBody.DecoderError(BodyDecoder.InvalidJson) =>
    ErrorResponse.parseError()
  }

let validateAfterSecurity = async (
  ~request: WebAPI.Request.t,
  ~origin: string,
  ~rawHeaders: option<RawHeaders.t>,
  ~registry: ToolRegistry.t,
  ~requiredClientCapabilities: option<DecodedRequest.requiredClientCapabilities>=None,
  ~serverIdentity: option<DecodedRequest.serverIdentity>,
): t => {
  switch MediaTypes.validate(request.headers) {
  | Error(error) => Rejected(mediaErrorResponse(error)->HttpSecurity.withOrigin(~origin))
  | Ok() =>
    switch await RequestBody.decode(request) {
    | Error(error) => Rejected(bodyErrorResponse(error)->HttpSecurity.withOrigin(~origin))
    | Ok(json) =>
      switch DecodedRequest.validate(
        ~headers=request.headers,
        ~rawHeaders,
        ~json,
        ~registry,
        ~requiredClientCapabilities,
        ~serverIdentity,
      ) {
      | DecodedRequest.Accepted(request) => Accepted({origin, request})
      | DecodedRequest.Completed(response) => Completed(response->HttpSecurity.withOrigin(~origin))
      | DecodedRequest.Rejected(response) => Rejected(response->HttpSecurity.withOrigin(~origin))
      }
    }
  }
}

@@live
let validate = async (
  ~request: WebAPI.Request.t,
  ~security: HttpSecurity.policy,
  ~rawHeaders: option<RawHeaders.t>=None,
  ~registry: ToolRegistry.t,
  ~requiredClientCapabilities: option<DecodedRequest.requiredClientCapabilities>=None,
  ~serverIdentity: option<DecodedRequest.serverIdentity>=None,
): t => {
  switch await HttpSecurity.validate(~request, ~policy=security) {
  | HttpSecurity.Rejected(response) => Rejected(response)
  | HttpSecurity.Allowed(origin) =>
    await validateAfterSecurity(
      ~request,
      ~origin,
      ~rawHeaders,
      ~registry,
      ~requiredClientCapabilities,
      ~serverIdentity,
    )
  }
}
