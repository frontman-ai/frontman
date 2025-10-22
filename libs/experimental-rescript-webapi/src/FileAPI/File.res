open FileAPI

include Blob.Impl({type t = file})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/File)
*/
@new
external make: (
  ~fileBits: array<blobPart>,
  ~fileName: string,
  ~options: filePropertyBag=?,
) => file = "File"
