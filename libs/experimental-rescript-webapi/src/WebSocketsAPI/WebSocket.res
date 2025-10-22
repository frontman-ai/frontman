open WebSocketsAPI
open FileAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket)
*/
@new
external make: (~url: string, ~protocols: string=?) => webSocket = "WebSocket"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket)
*/
@new
external make2: (~url: string, ~protocols: array<string>=?) => webSocket = "WebSocket"

include EventTarget.Impl({type t = webSocket})

/**
Closes the WebSocket connection, optionally using code as the the WebSocket connection close code and reason as the the WebSocket connection close reason.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/close)
*/
@send
external close: (webSocket, ~code: int=?, ~reason: string=?) => unit = "close"

/**
Transmits data using the WebSocket connection. data can be a string, a Blob, an ArrayBuffer, or an ArrayBufferView.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/send)
*/
@send
external send: (webSocket, DataView.t) => unit = "send"

/**
Transmits data using the WebSocket connection. data can be a string, a Blob, an ArrayBuffer, or an ArrayBufferView.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/send)
*/
@send
external send2: (webSocket, ArrayBuffer.t) => unit = "send"

/**
Transmits data using the WebSocket connection. data can be a string, a Blob, an ArrayBuffer, or an ArrayBufferView.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/send)
*/
@send
external send3: (webSocket, blob) => unit = "send"

/**
Transmits data using the WebSocket connection. data can be a string, a Blob, an ArrayBuffer, or an ArrayBufferView.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/send)
*/
@send
external send4: (webSocket, string) => unit = "send"
