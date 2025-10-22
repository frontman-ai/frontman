open FileAPI

external asWritableStream: fileSystemWritableFileStream => writableStream<'w> = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/abort)
*/
@send
external abort: (fileSystemWritableFileStream, ~reason: JSON.t=?) => promise<unit> = "abort"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/close)
*/
@send
external close: fileSystemWritableFileStream => promise<unit> = "close"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/getWriter)
*/
@send
external getWriter: fileSystemWritableFileStream => writableStreamDefaultWriter<'w> = "getWriter"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write: (fileSystemWritableFileStream, DataView.t) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write2: (fileSystemWritableFileStream, ArrayBuffer.t) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write3: (fileSystemWritableFileStream, blob) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write4: (fileSystemWritableFileStream, string) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/write)
*/
@send
external write5: (fileSystemWritableFileStream, writeParams) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/seek)
*/
@send
external seek: (fileSystemWritableFileStream, int) => promise<unit> = "seek"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream/truncate)
*/
@send
external truncate: (fileSystemWritableFileStream, int) => promise<unit> = "truncate"
