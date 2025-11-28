// Browser WebAPI bindings not available in experimental-rescript-webapi
// Minimal bindings for stream reading and text encoding/decoding

// ReadableStreamDefaultReader.read() result
type readResult<'t> = {
  done: bool,
  value: Nullable.t<'t>,
}

// Binding for reader.read()
@send
external readChunk: WebAPI.FileAPI.readableStreamReader<'t> => promise<readResult<'t>> = "read"

// TextDecoder bindings
type textDecoder

@new external makeTextDecoder: unit => textDecoder = "TextDecoder"
@new external makeTextDecoderWithEncoding: string => textDecoder = "TextDecoder"

@send external decode: (textDecoder, Uint8Array.t) => string = "decode"
@send external decodeWithOptions: (textDecoder, Uint8Array.t, {"stream": bool}) => string = "decode"

// TextEncoder bindings
type textEncoder

@new external makeTextEncoder: unit => textEncoder = "TextEncoder"
@send external encode: (textEncoder, string) => Uint8Array.t = "encode"

// ReadableStream controller for creating custom streams
type readableStreamController

@send external enqueue: (readableStreamController, Uint8Array.t) => unit = "enqueue"
@send external close: readableStreamController => unit = "close"

// Underlying source for creating ReadableStream
type underlyingSource = {
  start?: readableStreamController => unit,
  pull?: readableStreamController => promise<unit>,
  cancel?: string => promise<unit>,
}

// Node.js stream/web ReadableStream constructor
@module("stream/web") @new
external makeReadableStream: underlyingSource => WebAPI.FileAPI.readableStream<Uint8Array.t> =
  "ReadableStream"
