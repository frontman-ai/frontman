module BodyDecoder = FrontmanCore__MCP__BodyDecoder
module BodyReader = FrontmanCore__MCP__BodyReader

type boundaryError =
  | MissingBody
  | BodyAlreadyUsed
  | ReaderError(BodyReader.readError)
  | DecoderError(BodyDecoder.decodeError)

@get
external body: WebAPI.Request.t => Null.t<WebAPI.FileTypes.readableStream<Uint8Array.t>> = "body"

let decode = async (request: WebAPI.Request.t): result<JSON.t, boundaryError> => {
  switch request.bodyUsed {
  | true => Error(BodyAlreadyUsed)
  | false =>
    switch request->body->Null.toOption {
    | None => Error(MissingBody)
    | Some(body) =>
      switch await BodyReader.read(~headers=request.headers, ~body) {
      | Error(error) => Error(ReaderError(error))
      | Ok(bytes) =>
        switch BodyDecoder.decode(bytes) {
        | Error(error) => Error(DecoderError(error))
        | Ok(json) => Ok(json)
        }
      }
    }
  }
}
