include Event.Impl({type t = WebSocketsTypes.closeEvent})

@new
external make: (
  ~type_: string,
  ~eventInitDict: WebSocketsTypes.closeEventInit=?,
) => WebSocketsTypes.closeEvent = "CloseEvent"
