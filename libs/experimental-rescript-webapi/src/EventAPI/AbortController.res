open EventAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbortController)
*/
@new
external make: unit => abortController = "AbortController"

/**
Invoking this method will set this object's AbortSignal's aborted flag and signal to any observers that the associated activity is to be aborted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbortController/abort)
*/
@send
external abort: (abortController, ~reason: JSON.t=?) => unit = "abort"
