@@warning("-30")

open EventAPI

/**
The EventSource interface is web content's interface to server-sent events.

An EventSource instance opens a persistent connection to an HTTP server, which sends events in text/event-stream format. The connection remains open until closed by calling EventSource.close().

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventSource)
*/
@editor.completeFrom(EventSource)
type eventSource = {
  ...eventTarget,
  /**
    Returns the state of the connection. It can have the values described below.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventSource/readyState)
    */
  @as("readyState")
  readyState: int,
  /**
    Returns the URL that was used to establish the connection.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventSource/url)
    */
  url: string,
  /**
    Indicates whether the EventSource object was instantiated with cross-origin (CORS) credentials set.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventSource/withCredentials)
    */
  withCredentials: bool,
}

type eventSourceInit = {
  /**
    A boolean value indicating whether the EventSource object was instantiated with cross-origin (CORS) credentials set.
    */
  mutable withCredentials?: bool,
}

/**
Creates a new EventSource to handle receiving server-sent events from a specified URL, optionally in credentials mode.

readyState values:
- CONNECTING (0): The connection has not yet been established, or it was closed and is trying to reconnect
- OPEN (1): The connection is open and firing events
- CLOSED (2): The connection is not open, and the event source is not trying to reconnect

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventSource/EventSource)
*/
@new
external make: (~url: string, ~eventSourceInitDict: eventSourceInit=?) => eventSource =
  "EventSource"

module Impl = (
  T: {
    type t
  },
) => {
  include EventTarget.Impl({type t = T.t})

  external asEventSource: T.t => eventSource = "%identity"

  /**
Closes the connection, if any, and sets the readyState attribute to CLOSED. If the connection is already closed, the method does nothing.

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/EventSource/close)
*/
  @send
  external close: T.t => unit = "close"
}

include Impl({type t = eventSource})
