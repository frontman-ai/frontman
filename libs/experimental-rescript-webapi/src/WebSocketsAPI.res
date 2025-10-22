@@warning("-30")

open Prelude
open EventAPI
open ChannelMessagingAPI

type binaryType =
  | @as("arraybuffer") Arraybuffer
  | @as("blob") Blob

type messageEventSource = any

/**
Provides the API for creating and managing a WebSocket connection to a server, as well as for sending and receiving data on the connection.
[See WebSocket on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket)
*/
@editor.completeFrom(WebSocket)
type webSocket = {
  ...eventTarget,
  /**
    Returns the URL that was used to establish the WebSocket connection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/url)
    */
  url: string,
  /**
    Returns the state of the WebSocket object's connection. It can have the values described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/readyState)
    */
  readyState: int,
  /**
    Returns the number of bytes of application data (UTF-8 text and binary data) that have been queued using send() but not yet been transmitted to the network.

If the WebSocket connection is closed, this attribute's value will only increase with each call to the send() method. (The number does not reset to zero once the connection closes.)
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/bufferedAmount)
    */
  bufferedAmount: int,
  /**
    Returns the extensions selected by the server, if any.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/extensions)
    */
  extensions: string,
  /**
    Returns the subprotocol selected by the server, if any. It can be used in conjunction with the array form of the constructor's second argument to perform subprotocol negotiation.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/protocol)
    */
  protocol: string,
  /**
    Returns a string that indicates how binary data from the WebSocket object is exposed to scripts:

Can be set, to change how binary data is returned. The default is "blob".
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/WebSocket/binaryType)
    */
  mutable binaryType: binaryType,
}

/**
A CloseEvent is sent to clients using WebSockets when the connection is closed. This is delivered to the listener indicated by the WebSocket object's onclose attribute.
[See CloseEvent on MDN](https://developer.mozilla.org/docs/Web/API/CloseEvent)
*/
@editor.completeFrom(CloseEvent)
type closeEvent = {
  ...event,
  /**
    Returns true if the connection closed cleanly; false otherwise.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CloseEvent/wasClean)
    */
  wasClean: bool,
  /**
    Returns the WebSocket connection close code provided by the server.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CloseEvent/code)
    */
  code: int,
  /**
    Returns the WebSocket connection close reason provided by the server.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/CloseEvent/reason)
    */
  reason: string,
}

/**
A message received by a target object.
[See MessageEvent on MDN](https://developer.mozilla.org/docs/Web/API/MessageEvent)
*/
type messageEvent<'t> = {
  ...event,
  /**
    Returns the data of the message.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MessageEvent/data)
    */
  data: 't,
  /**
    Returns the origin of the message, for server-sent events and cross-document messaging.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MessageEvent/origin)
    */
  origin: string,
  /**
    Returns the last event ID string, for server-sent events.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MessageEvent/lastEventId)
    */
  lastEventId: string,
  /**
    Returns the WindowProxy of the source window, for cross-document messaging, and the MessagePort being attached, in the connect event fired at SharedWorkerGlobalScope objects.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MessageEvent/source)
    */
  source: Null.t<messageEventSource>,
  /**
    Returns the MessagePort array sent with the message, for cross-document messaging and channel messaging.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/MessageEvent/ports)
    */
  ports: array<messagePort>,
}

type closeEventInit = {
  ...eventInit,
  mutable wasClean?: bool,
  mutable code?: int,
  mutable reason?: string,
}

type messageEventInit<'t> = {
  ...eventInit,
  mutable data?: 't,
  mutable origin?: string,
  mutable lastEventId?: string,
  mutable source?: Null.t<messageEventSource>,
  mutable ports?: array<messagePort>,
}
