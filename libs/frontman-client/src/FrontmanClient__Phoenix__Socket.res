// Low-level bindings to Phoenix Socket class

type t

type channel

type socketOptions = {
  timeout?: int,
  heartbeatIntervalMs?: int,
  reconnectAfterMs?: int => int,
}

@module("phoenix") @new
external make: (~endpoint: string, ~opts: socketOptions=?) => t = "Socket"

@send external connect: t => unit = "connect"

@send external disconnect: (t, ~callback: unit => unit=?) => unit = "disconnect"

@send
external channel: (t, ~topic: string, ~params: Js.Dict.t<JSON.t>=?) => channel = "channel"

@send external onOpen: (t, ~callback: unit => unit) => unit = "onOpen"

@send external onError: (t, ~callback: 'error => unit) => unit = "onError"

@send external onClose: (t, ~callback: 'event => unit) => unit = "onClose"
