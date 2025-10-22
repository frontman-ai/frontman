open WebSocketsAPI

include Event.Impl({type t = closeEvent})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CloseEvent)
*/
@new
external make: (~type_: string, ~eventInitDict: closeEventInit=?) => closeEvent = "CloseEvent"
