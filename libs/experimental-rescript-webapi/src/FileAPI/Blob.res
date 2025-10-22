open FileAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob)
*/
@new
external make: (~blobParts: array<blobPart>=?, ~options: blobPropertyBag=?) => blob = "Blob"

module Impl = (
  T: {
    type t
  },
) => {
  external asBlob: T.t => blob = "%identity"
  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob/slice)
*/
  @send
  external slice: (T.t, ~start: int=?, ~end: int=?, ~contentType: string=?) => blob = "slice"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob/stream)
*/
  @send
  external stream: T.t => readableStream<array<int>> = "stream"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob/text)
*/
  @send
  external text: T.t => promise<string> = "text"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob/arrayBuffer)
*/
  @send
  external arrayBuffer: T.t => promise<ArrayBuffer.t> = "arrayBuffer"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob/bytes)
*/
  @send
  external bytes: T.t => promise<array<int>> = "bytes"
}

include Impl({type t = blob})
