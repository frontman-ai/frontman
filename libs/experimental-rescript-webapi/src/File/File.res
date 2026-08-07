type t = FileTypes.file = private {...FileTypes.file}

include Blob.Impl({type t = t})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/File)
*/
@new
external make: (
  ~fileBits: array<FileTypes.blobPart>,
  ~fileName: string,
  ~options: FileTypes.filePropertyBag=?,
) => t = "File"

let isInstanceOf = (_: 't): bool => %raw(`param instanceof File`)
