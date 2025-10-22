open FileAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream)
*/
@new
external make: (
  ~underlyingSink: underlyingSink<'w>=?,
  ~strategy: queuingStrategy<'w>=?,
) => writableStream<'w> = "WritableStream"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/abort)
*/
@send
external abort: (writableStream<'w>, ~reason: JSON.t=?) => promise<unit> = "abort"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/close)
*/
@send
external close: writableStream<'w> => promise<unit> = "close"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStream/getWriter)
*/
@send
external getWriter: writableStream<'w> => writableStreamDefaultWriter<'w> = "getWriter"
