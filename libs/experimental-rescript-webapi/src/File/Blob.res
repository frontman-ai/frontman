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
  @send
  external slice: (T.t, ~start: int=?, ~end: int=?, ~contentType: string=?) => t = "slice"

  @send
  external stream: T.t => ReadableStream.t<array<int>> = "stream"

  @send
  external text: T.t => promise<string> = "text"

  @send
  external arrayBuffer: T.t => promise<ArrayBuffer.t> = "arrayBuffer"

  @send
  external bytes: T.t => promise<array<int>> = "bytes"
}

include Impl({type t = t})
