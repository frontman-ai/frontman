type t = ChannelMessagingTypes.messagePort = private {...ChannelMessagingTypes.messagePort}
type structuredSerializeOptions = ChannelMessagingTypes.structuredSerializeOptions

include EventTarget.Impl({type t = t})

@send
external postMessage: (t, ~message: JSON.t, ~transfer: array<Dict.t<string>>) => unit =
  "postMessage"

@send
external postMessage2: (t, ~message: JSON.t, ~options: structuredSerializeOptions=?) => unit =
  "postMessage"

@send
external start: t => unit = "start"

@send
external close: t => unit = "close"
