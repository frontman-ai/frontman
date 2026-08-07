include EventTarget.Impl({type t = EventTypes.abortSignal})

@scope("AbortSignal")
external abort: (~reason: JSON.t=?) => EventTypes.abortSignal = "abort"

@scope("AbortSignal")
external timeout: int => EventTypes.abortSignal = "timeout"

@scope("AbortSignal")
external any: array<EventTypes.abortSignal> => EventTypes.abortSignal = "any"

@send
external throwIfAborted: EventTypes.abortSignal => unit = "throwIfAborted"
