// Unified FrontmanClient - merges Connection + Session + MCP Server

type t = {
  endpoint: string,
  sessionId: string,
}

let make = (~endpoint: string, ~sessionId: string): t => {
  {
    endpoint,
    sessionId,
  }
}

let connect = (
  client: t,
  ~_onReady: option<unit => unit>=?,
  ~onError: option<string => unit>=?,
  (),
): promise<result<unit, string>> => {
  Promise.make((_resolve, _reject) => {
    let socket = FrontmanClient__Phoenix__Socket.make(~endpoint=client.endpoint)
    socket->FrontmanClient__Phoenix__Socket.onError(~callback=_error => {
      onError->Option.forEach(cb => cb("Socket error"))
    })

    // When socket opens, join channel
    socket->FrontmanClient__Phoenix__Socket.onOpen(~callback=() => {
      let _channel =
        socket->FrontmanClient__Phoenix__Socket.channel(~topic=`session:${client.sessionId}`)
    })
    // Join channel
  })
}
