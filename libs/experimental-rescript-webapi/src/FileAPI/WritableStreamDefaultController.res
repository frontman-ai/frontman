open FileAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WritableStreamDefaultController/error)
*/
@send
external error: (writableStreamDefaultController, ~e: JSON.t=?) => unit = "error"
