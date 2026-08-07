external asWritableStream: FileTypes.fileSystemWritableFileStream => FileTypes.writableStream<'w> =
  "%identity"
@send
external abort: (FileTypes.fileSystemWritableFileStream, ~reason: JSON.t=?) => promise<unit> =
  "abort"

@send
external close: FileTypes.fileSystemWritableFileStream => promise<unit> = "close"

@send
external getWriter: FileTypes.fileSystemWritableFileStream => FileTypes.writableStreamDefaultWriter<
  'w,
> = "getWriter"

@send
external write: (FileTypes.fileSystemWritableFileStream, DataView.t) => promise<unit> = "write"

@send
external write2: (FileTypes.fileSystemWritableFileStream, ArrayBuffer.t) => promise<unit> = "write"

@send
external write3: (FileTypes.fileSystemWritableFileStream, FileTypes.blob) => promise<unit> = "write"

@send
external write4: (FileTypes.fileSystemWritableFileStream, string) => promise<unit> = "write"

@send
external write5: (FileTypes.fileSystemWritableFileStream, FileTypes.writeParams) => promise<unit> =
  "write"

@send
external seek: (FileTypes.fileSystemWritableFileStream, int) => promise<unit> = "seek"

@send
external truncate: (FileTypes.fileSystemWritableFileStream, int) => promise<unit> = "truncate"
