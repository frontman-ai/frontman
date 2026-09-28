type t = WebSocketsTypes.webSocket = private {...WebSocketsTypes.webSocket}
type binaryType = WebSocketsTypes.binaryType
type messageEvent<'t> = WebSocketsTypes.messageEvent<'t> = {...WebSocketsTypes.messageEvent<'t>}
type closeEvent = WebSocketsTypes.closeEvent = private {...WebSocketsTypes.closeEvent}
type messageEventSource = WebSocketsTypes.messageEventSource

/**
`fromURL(~url: string, ~protocols: string=?)`

Creates a new `WebSocket` from a URL and an optional single protocol.

```res
let socket = WebSocket.fromURL(~url="wss://example.com/socket")
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket)
*/
@new
external fromURL: (~url: string, ~protocols: string=?) => t = "WebSocket"

/**
`fromURLWithProtocols(~url: string, ~protocols: array<string>)`

Creates a new `WebSocket` from a URL and multiple protocols.

```res
let socket =
  WebSocket.fromURLWithProtocols(
    ~url="wss://example.com/socket",
    ~protocols=["chat", "superchat"],
  )
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket)
*/
@new
external fromURLWithProtocols: (~url: string, ~protocols: array<string>) => t = "WebSocket"

include EventTarget.Impl({type t = t})

/**
Closes the WebSocket connection, optionally using code as the the WebSocket connection close code and reason as the the WebSocket connection close reason.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/close)
*/
@send
external close: (t, ~code: int=?, ~reason: string=?) => unit = "close"

/**
Transmits data using the WebSocket connection. data can be a string, a Blob, an ArrayBuffer, or an ArrayBufferView.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/send)
*/
@send
external send: (t, DataView.t) => unit = "send"

/**
Transmits data using the WebSocket connection. data can be a string, a Blob, an ArrayBuffer, or an ArrayBufferView.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/send)
*/
external sendArrayBuffer: (t, ArrayBuffer.t) => unit = "send"

/**
Transmits data using the WebSocket connection. data can be a string, a Blob, an ArrayBuffer, or an ArrayBufferView.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/send)
*/
external sendBlob: (t, Blob.t) => unit = "send"

/**
Transmits data using the WebSocket connection. data can be a string, a Blob, an ArrayBuffer, or an ArrayBufferView.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/send)
*/
external sendString: (t, string) => unit = "send"
