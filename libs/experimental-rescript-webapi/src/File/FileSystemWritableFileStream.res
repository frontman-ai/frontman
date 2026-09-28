external asWritableStream: FileTypes.fileSystemWritableFileStream => FileTypes.writableStream<'w> =
  "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/abort)
*/
@send
external abort: (FileTypes.fileSystemWritableFileStream, ~reason: JSON.t=?) => promise<unit> =
  "abort"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/close)
*/
@send
external close: FileTypes.fileSystemWritableFileStream => promise<unit> = "close"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/getWriter)
*/
@send
external getWriter: FileTypes.fileSystemWritableFileStream => FileTypes.writableStreamDefaultWriter<
  'w,
> = "getWriter"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write: (FileTypes.fileSystemWritableFileStream, DataView.t) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write2: (FileTypes.fileSystemWritableFileStream, ArrayBuffer.t) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write3: (FileTypes.fileSystemWritableFileStream, FileTypes.blob) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write4: (FileTypes.fileSystemWritableFileStream, string) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write5: (FileTypes.fileSystemWritableFileStream, FileTypes.writeParams) => promise<unit> =
  "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/seek)
*/
@send
external seek: (FileTypes.fileSystemWritableFileStream, int) => promise<unit> = "seek"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/truncate)
*/
@send
external truncate: (FileTypes.fileSystemWritableFileStream, int) => promise<unit> = "truncate"
