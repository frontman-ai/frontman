/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob)
*/
type t = FileTypes.blob = private {...FileTypes.blob}
type blobPart = FileTypes.blobPart
type blobPropertyBag = FileTypes.blobPropertyBag

@new
external make: (~blobParts: array<blobPart>=?, ~options: blobPropertyBag=?) => t = "Blob"

module Impl = (
  T: {
    type t
  },
) => {
  external asBlob: T.t => t = "%identity"
  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob/slice)
*/
  @send
  external slice: (T.t, ~start: int=?, ~end: int=?, ~contentType: string=?) => t = "slice"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob/stream)
*/
  @send
  external stream: T.t => ReadableStream.t<array<int>> = "stream"

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

include Impl({type t = t})
