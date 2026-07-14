/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream)
*/
@new
external make: (
  ~underlyingSink: FileTypes.underlyingSink<'w>=?,
  ~strategy: FileTypes.queuingStrategy<'w>=?,
) => FileTypes.writableStream<'w> = "WritableStream"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/abort)
*/
@send
external abort: (FileTypes.writableStream<'w>, ~reason: JSON.t=?) => promise<unit> = "abort"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/close)
*/
@send
external close: FileTypes.writableStream<'w> => promise<unit> = "close"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/getWriter)
*/
@send
external getWriter: FileTypes.writableStream<'w> => FileTypes.writableStreamDefaultWriter<'w> =
  "getWriter"
