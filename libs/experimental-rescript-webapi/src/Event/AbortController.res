@new
external make: unit => EventTypes.abortController = "AbortController"

@send
external abort: (EventTypes.abortController, ~reason: JSON.t=?) => unit = "abort"
