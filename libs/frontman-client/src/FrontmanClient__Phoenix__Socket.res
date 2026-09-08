type t

type channel

@@live
type socketOptions = {
  timeout?: int,
  heartbeatIntervalMs?: int,
  reconnectAfterMs?: int => int,
  params?: Dict.t<string>,
  authToken?: string,
}

@module("phoenix") @new
external make: (~endpoint: string, ~opts: socketOptions=?) => t = "Socket"

@send external connect: t => unit = "connect"

@send external disconnect: (t, ~callback: unit => unit=?) => unit = "disconnect"

@get external channels: t => array<channel> = "channels"

@send
external channel: (t, ~topic: string, ~params: dict<JSON.t>=?) => channel = "channel"
