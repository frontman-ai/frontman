type readResult<'t> = {
  done: bool,
  value: Nullable.t<'t>,
}

@send
external readChunk: WebAPI.FileTypes.readableStreamReader<'t> => promise<readResult<'t>> = "read"

type textDecoder

@new external makeTextDecoder: unit => textDecoder = "TextDecoder"
@new external makeTextDecoderWithEncoding: string => textDecoder = "TextDecoder"

@send external decode: (textDecoder, Uint8Array.t) => string = "decode"
@send external decodeWithOptions: (textDecoder, Uint8Array.t, {"stream": bool}) => string = "decode"

type textEncoder

@new external makeTextEncoder: unit => textEncoder = "TextEncoder"
@send external encode: (textEncoder, string) => Uint8Array.t = "encode"
@get external byteLength: Uint8Array.t => int = "byteLength"

let utf8ByteSize = (text: string): int => makeTextEncoder()->encode(text)->byteLength

type readableStreamController

@send external enqueue: (readableStreamController, Uint8Array.t) => unit = "enqueue"
@send external close: readableStreamController => unit = "close"

type underlyingSource = {
  start?: readableStreamController => unit,
  pull?: readableStreamController => promise<unit>,
  cancel?: string => promise<unit>,
}

@module("stream/web") @new
external makeReadableStream: underlyingSource => WebAPI.ReadableStream.t<Uint8Array.t> =
  "ReadableStream"
