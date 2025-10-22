open FileAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream)
*/
@new
external make: unit => readableStream<array<int>> = "ReadableStream"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream)
*/
@new
external make2: unit => unknown = "ReadableStream"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream)
*/
@new
external make3: unit => unknown = "ReadableStream"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream/cancel)
*/
@send
external cancel: (readableStream<'r>, ~reason: JSON.t=?) => promise<unit> = "cancel"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream/getReader)
*/
@send
external getReader: (
  readableStream<'r>,
  ~options: readableStreamGetReaderOptions=?,
) => readableStreamReader<'r> = "getReader"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream/pipeThrough)
*/
@send
external pipeThrough: (
  readableStream<'r>,
  ~transform: readableWritablePair<'t, 'r>,
  ~options: streamPipeOptions=?,
) => readableStream<'t> = "pipeThrough"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream/pipeTo)
*/
@send
external pipeTo: (
  readableStream<'r>,
  ~destination: writableStream<'r>,
  ~options: streamPipeOptions=?,
) => promise<unit> = "pipeTo"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ReadableStream/tee)
*/
@send
external tee: readableStream<'r> => array<readableStream<unit>> = "tee"
