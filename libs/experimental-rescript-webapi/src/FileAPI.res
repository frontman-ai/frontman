@@warning("-30")

open Prelude
open EventAPI

type endingType =
  | @as("native") Native
  | @as("transparent") Transparent

type readableStreamReaderMode = | @as("byob") Byob

type fileSystemHandleKind =
  | @as("directory") Directory
  | @as("file") File

type writeCommandType =
  | @as("seek") Seek
  | @as("truncate") Truncate
  | @as("write") Write

/**
A file-like object of immutable, raw data. Blobs represent data that isn't necessarily in a JavaScript-native format. The File interface is based on Blob, inheriting blob functionality and expanding it to support files on the user's system.
[See Blob on MDN](https://developer.mozilla.org/docs/Web/API/Blob)
*/
@editor.completeFrom(Blob)
type blob = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob/size)
    */
  size: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Blob/type)
    */
  @as("type")
  type_: string,
}

/**
This Streams API interface represents a readable stream of byte data. The Fetch API offers a concrete instance of a ReadableStream through the body property of a Response object.
[See ReadableStream on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream)
*/
type readableStream<'r> = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream/locked)
    */
  locked: bool,
}

/**
This Streams API interface provides a standard abstraction for writing streaming data to a destination, known as a sink. This object comes with built-in backpressure and queuing.
[See WritableStream on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream)
*/
type writableStream<'w> = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/locked)
    */
  locked: bool,
}

/**
This Streams API interface represents a controller allowing control of a WritableStream's state. When constructing a WritableStream, the underlying sink is given a corresponding WritableStreamDefaultController instance to manipulate.
[See WritableStreamDefaultController on MDN](https://developer.mozilla.org/docs/Web/API/WritableStreamDefaultController)
*/
@editor.completeFrom(WritableStreamDefaultController)
type writableStreamDefaultController = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStreamDefaultController/signal)
    */
  signal: abortSignal,
}

/**
Provides information about files and allows JavaScript in a web page to access their content.
[See File on MDN](https://developer.mozilla.org/docs/Web/API/File)
*/
@editor.completeFrom(File)
type file = {
  ...blob,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/File/name)
    */
  name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/File/lastModified)
    */
  lastModified: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/File/webkitRelativePath)
    */
  webkitRelativePath: string,
}

/**
[See FileSystemHandle on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemHandle)
*/
@editor.completeFrom(FileSystemHandle)
type fileSystemHandle = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/kind)
    */
  kind: fileSystemHandleKind,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/name)
    */
  name: string,
}

/**
[See FileSystemDirectoryHandle on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle)
*/
@editor.completeFrom(FileSystemDirectoryHandle)
type fileSystemDirectoryHandle = {
  ...fileSystemHandle,
}

/**
[See FileSystemFileHandle on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle)
*/
@editor.completeFrom(FileSystemFileHandle)
type fileSystemFileHandle = {
  ...fileSystemHandle,
}

/**
[See FileSystemWritableFileStream on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemWritableFileStream)
*/
@editor.completeFrom(FileSystemWritableFileStream)
type fileSystemWritableFileStream = {
  ...writableStream<any>,
}

@unboxed
type blobPart =
  | String(string)
  | Blob(blob)
// | ArrayBuffer(ArrayBuffer.t)
// | TypedArray(TypedArray.t<int>)

type queuingStrategy<'t> = any

type underlyingSink<'t> = any

type readableStreamReader<'t> = any

type writableStreamDefaultWriter<'t> = any

type fileSystemWriteChunkType = any

type underlyingSourceCancelCallback = JSON.t => promise<unit>

type blobPropertyBag = {
  @as("type") mutable type_?: string,
  mutable endings?: endingType,
}

type underlyingByteSource = {
  @as("type") mutable type_: unknown,
  mutable autoAllocateChunkSize?: int,
  mutable start?: unknown,
  mutable pull?: unknown,
  mutable cancel?: underlyingSourceCancelCallback,
}

type readableStreamGetReaderOptions = {
  /**
    Creates a ReadableStreamBYOBReader and locks the stream to the new reader.

This call behaves the same way as the no-argument variant, except that it only works on readable byte streams, i.e. streams which were constructed specifically with the ability to handle "bring your own buffer" reading. The returned BYOB reader provides the ability to directly read individual chunks from the stream via its read() method, into developer-supplied buffers, allowing more precise control over allocation.
    */
  mutable mode?: readableStreamReaderMode,
}

type readableWritablePair<'r, 'w> = {
  mutable readable: readableStream<'r>,
  /**
    Provides a convenient, chainable way of piping this readable stream through a transform stream (or any other { writable, readable } pair). It simply pipes the stream into the writable side of the supplied pair, and returns the readable side for further use.

Piping a stream will lock it for the duration of the pipe, preventing any other consumer from acquiring a reader.
    */
  mutable writable: writableStream<'w>,
}

type streamPipeOptions = {
  /**
    Pipes this readable stream to a given writable stream destination. The way in which the piping process behaves under various error conditions can be customized with a number of passed options. It returns a promise that fulfills when the piping process completes successfully, or rejects if any errors were encountered.

Piping a stream will lock it for the duration of the pipe, preventing any other consumer from acquiring a reader.

Errors and closures of the source and destination streams propagate as follows:

An error in this source readable stream will abort destination, unless preventAbort is truthy. The returned promise will be rejected with the source's error, or with any error that occurs during aborting the destination.

An error in destination will cancel this source readable stream, unless preventCancel is truthy. The returned promise will be rejected with the destination's error, or with any error that occurs during canceling the source.

When this source readable stream closes, destination will be closed, unless preventClose is truthy. The returned promise will be fulfilled once this process completes, unless an error is encountered while closing the destination, in which case it will be rejected with that error.

If destination starts out closed or closing, this source readable stream will be canceled, unless preventCancel is true. The returned promise will be rejected with an error indicating piping to a closed stream failed, or with any error that occurs during canceling the source.

The signal option can be set to an AbortSignal to allow aborting an ongoing pipe operation via the corresponding AbortController. In this case, this source readable stream will be canceled, and destination aborted, unless the respective options preventCancel or preventAbort are set.
    */
  mutable preventClose?: bool,
  mutable preventAbort?: bool,
  mutable preventCancel?: bool,
  mutable signal?: abortSignal,
}

type filePropertyBag = {
  ...blobPropertyBag,
  mutable lastModified?: int,
}

type fileSystemGetFileOptions = {mutable create?: bool}

type fileSystemGetDirectoryOptions = {mutable create?: bool}

type fileSystemRemoveOptions = {mutable recursive?: bool}

type fileSystemCreateWritableOptions = {mutable keepExistingData?: bool}

type writeParams = {
  @as("type") mutable type_: writeCommandType,
  mutable size?: Null.t<int>,
  mutable position?: Null.t<int>,
  mutable data?: Null.t<unknown>,
}
