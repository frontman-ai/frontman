type t = PushTypes.pushMessageData

@send
external json: t => JSON.t = "json"

@send
external text: t => string = "text"
