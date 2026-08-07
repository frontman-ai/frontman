type t<'r> = FileTypes.readableStream<'r>

@new
external make: unit => t<'t> = "ReadableStream"

@new
external fromUnderlyingSource: (
  FileTypes.underlyingSource<'t>,
  ~strategy: FileTypes.queuingStrategy<'t>=?,
) => t<'t> = "ReadableStream"

@send
external cancel: (t<'r>, ~reason: JSON.t=?) => promise<unit> = "cancel"

@send
external getReader: (
  t<'r>,
  ~options: FileTypes.readableStreamGetReaderOptions=?,
) => FileTypes.readableStreamReader<'r> = "getReader"

@send
external pipeThrough: (
  t<'r>,
  ~transform: FileTypes.readableWritablePair<'t, 'r>,
  ~options: FileTypes.streamPipeOptions=?,
) => t<'t> = "pipeThrough"

@send
external pipeTo: (
  t<'r>,
  ~destination: FileTypes.writableStream<'r>,
  ~options: FileTypes.streamPipeOptions=?,
) => promise<unit> = "pipeTo"

@send
external tee: t<'r> => array<t<unit>> = "tee"
