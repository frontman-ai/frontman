module PathContext = FrontmanCore__PathContext
module DOMElementToComponentSource = FrontmanBindings.DOMElementToComponentSource
module RequestBody = FrontmanCore__MCP__RequestBody
module BodyReader = FrontmanCore__MCP__BodyReader
module BodyDecoder = FrontmanCore__MCP__BodyDecoder

@schema
type resolveSourceLocationRequest = {
  componentName: string,
  file: string,
  line: int,
  column: int,
}

@schema
type resolveSourceLocationResponse = {
  @live
  componentName: string,
  @live
  file: string,
  @live
  line: int,
  @live
  column: int,
}

@schema
type errorResponse = {
  @live
  error: string,
  @live @s.matches(S.option(S.string))
  details: option<string>,
}

let handleResolveSourceLocation = async (
  ~sourceRoot: string,
  req: WebAPI.FetchAPI.request,
): WebAPI.FetchAPI.response => {
  let request = switch await RequestBody.decode(req) {
  | Error(RequestBody.BodyAlreadyUsed) =>
    failwith("Source-location request body was already consumed")
  | Error(RequestBody.ReaderError(BodyReader.BodyTooLarge))
  | Error(RequestBody.DecoderError(BodyDecoder.BodyTooLarge)) =>
    Error(#bodyTooLarge)
  | Error(RequestBody.ReaderError(BodyReader.BodyTimedOut)) => Error(#bodyTimedOut)
  | Error(
      RequestBody.MissingBody
      | RequestBody.ReaderError(BodyReader.InvalidContentLength | BodyReader.BodyTooFragmented)
      | RequestBody.DecoderError(
        BodyDecoder.InvalidUtf8 | BodyDecoder.JsonTooDeep | BodyDecoder.InvalidJson,
      ),
    ) =>
    Error(#invalidBody)
  | Ok(body) =>
    try {
      Ok(body->S.parseOrThrow(~to=resolveSourceLocationRequestSchema))
    } catch {
    | S.Exn(_) => Error(#invalidRequest)
    }
  }

  switch request {
  | Error(#bodyTooLarge) => WebAPI.Response.fromNull(~init={status: 413})
  | Error(#bodyTimedOut) => WebAPI.Response.fromNull(~init={status: 408})
  | Error(#invalidBody | #invalidRequest) =>
    let json =
      {error: "Invalid request", details: None}->S.decodeOrThrow(
        ~from=errorResponseSchema,
        ~to=S.json,
      )
    WebAPI.Response.jsonR(~data=json, ~init={status: 400})

  | Ok(request) =>
    try {
      let sourceLocation: DOMElementToComponentSource.sourceLocation = {
        componentName: request.componentName,
        file: request.file,
        line: request.line,
        column: request.column,
        componentProps: None,
        parent: None,
      }

      let resolved = await DOMElementToComponentSource.resolveSourceLocationInServer(sourceLocation)

      let relativeFile = PathContext.toRelativePath(~sourceRoot, ~absolutePath=resolved.file)

      let responseJson: resolveSourceLocationResponse = {
        componentName: resolved.componentName,
        file: relativeFile,
        line: resolved.line,
        column: resolved.column,
      }

      let json =
        responseJson->S.decodeOrThrow(~from=resolveSourceLocationResponseSchema, ~to=S.json)
      let headers = WebAPI.HeadersInit.fromDict(
        Dict.fromArray([("Content-Type", "application/json")]),
      )
      WebAPI.Response.jsonR(~data=json, ~init={headers: headers})
    } catch {
    | exn =>
      exn->ignore
      let json = {
        error: "Failed to resolve source location",
        details: None,
      }->S.decodeOrThrow(~from=errorResponseSchema, ~to=S.json->S.noValidation(true))
      WebAPI.Response.jsonR(~data=json, ~init={status: 500})
    }
  }
}
