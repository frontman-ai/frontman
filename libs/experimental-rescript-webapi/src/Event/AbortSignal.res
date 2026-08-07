include EventTarget.Impl({type t = EventTypes.abortSignal})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbortSignal/abort_static)
*/
@scope("AbortSignal")
external abort: (~reason: JSON.t=?) => EventTypes.abortSignal = "abort"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbortSignal/timeout_static)
*/
@scope("AbortSignal")
external timeout: int => EventTypes.abortSignal = "timeout"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbortSignal/any_static)
*/
@scope("AbortSignal")
external any: array<EventTypes.abortSignal> => EventTypes.abortSignal = "any"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/AbortSignal/throwIfAborted)
*/
@send
external throwIfAborted: EventTypes.abortSignal => unit = "throwIfAborted"
