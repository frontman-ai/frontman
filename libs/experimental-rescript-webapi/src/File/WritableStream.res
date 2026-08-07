@new
external make: (
  ~underlyingSink: FileTypes.underlyingSink<'w>=?,
  ~strategy: FileTypes.queuingStrategy<'w>=?,
) => FileTypes.writableStream<'w> = "WritableStream"

@send
external abort: (FileTypes.writableStream<'w>, ~reason: JSON.t=?) => promise<unit> = "abort"

@send
external close: FileTypes.writableStream<'w> => promise<unit> = "close"

@send
external getWriter: FileTypes.writableStream<'w> => FileTypes.writableStreamDefaultWriter<'w> =
  "getWriter"
