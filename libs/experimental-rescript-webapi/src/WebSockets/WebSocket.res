type t = WebSocketsTypes.webSocket = private {...WebSocketsTypes.webSocket}
type binaryType = WebSocketsTypes.binaryType
type messageEvent<'t> = WebSocketsTypes.messageEvent<'t> = {...WebSocketsTypes.messageEvent<'t>}
type closeEvent = WebSocketsTypes.closeEvent = private {...WebSocketsTypes.closeEvent}
type messageEventSource = WebSocketsTypes.messageEventSource

@new
external fromURL: (~url: string, ~protocols: string=?) => t = "WebSocket"

@new
external fromURLWithProtocols: (~url: string, ~protocols: array<string>) => t = "WebSocket"

include EventTarget.Impl({type t = t})

@send
external close: (t, ~code: int=?, ~reason: string=?) => unit = "close"

@send
external send: (t, DataView.t) => unit = "send"

external sendArrayBuffer: (t, ArrayBuffer.t) => unit = "send"

external sendBlob: (t, Blob.t) => unit = "send"

external sendString: (t, string) => unit = "send"
