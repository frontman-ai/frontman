@@warning("-30")

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

@editor.completeFrom(Blob)
type blob = BaseFile.blob = private {
  size: int,
  @as("type")
  type_: string,
}

type readableStream<'r> = {
  locked: bool,
}

type writableStream<'w> = {
  locked: bool,
}

@editor.completeFrom(WritableStreamDefaultController)
type writableStreamDefaultController = private {
  signal: EventTypes.abortSignal,
}

@editor.completeFrom(WebApiFile)
type file = BaseFile.file = private {
  ...blob,
  name: string,
  lastModified: int,
  webkitRelativePath: string,
}

@editor.completeFrom(FileSystemHandle)
type fileSystemHandle = private {
  kind: fileSystemHandleKind,
  name: string,
}

@editor.completeFrom(FileSystemDirectoryHandle)
type fileSystemDirectoryHandle = private {
  ...fileSystemHandle,
}

@editor.completeFrom(FileSystemFileHandle)
type fileSystemFileHandle = private {
  ...fileSystemHandle,
}

@editor.completeFrom(FileSystemWritableFileStream)
type fileSystemWritableFileStream = private {
  ...writableStream<unknown>,
}

@unboxed
type blobPart =
  | String(string)
  | Blob(blob)

type queuingStrategy<'t> = unknown

type underlyingSink<'t> = unknown

type underlyingSource<'t> = unknown

type readableStreamReader<'t> = unknown

type writableStreamDefaultWriter<'t> = unknown

type fileSystemWriteChunkType = unknown

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
  mutable mode?: readableStreamReaderMode,
}

type readableWritablePair<'r, 'w> = {
  mutable readable: readableStream<'r>,
  mutable writable: writableStream<'w>,
}

type streamPipeOptions = {
  mutable preventClose?: bool,
  mutable preventAbort?: bool,
  mutable preventCancel?: bool,
  mutable signal?: EventTypes.abortSignal,
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
