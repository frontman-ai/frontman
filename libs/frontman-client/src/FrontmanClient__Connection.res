// Connection management wrapper

type t = {
  socket: FrontmanClient__Phoenix__Socket.t,
  endpoint: string,
  state: ref<FrontmanClient__Types.connectionState>,
}

let make = (~endpoint: string): t => {
  let socket = FrontmanClient__Phoenix__Socket.make(~endpoint)
  {
    socket,
    endpoint,
    state: ref(FrontmanClient__Types.Disconnected),
  }
}

let getState = (t: t): FrontmanClient__Types.connectionState => t.state.contents

let getSocket = (t: t): FrontmanClient__Phoenix__Socket.t => t.socket

let connect = (t: t): promise<FrontmanClient__Types.result<unit, string>> => {
  Promise.make((resolve, _reject) => {
    t.state := FrontmanClient__Types.Connecting

    t.socket->FrontmanClient__Phoenix__Socket.onOpen(~callback=() => {
      t.state := FrontmanClient__Types.Connected
      resolve(FrontmanClient__Types.Ok())
    })

    t.socket->FrontmanClient__Phoenix__Socket.onError(~callback=_error => {
      t.state := FrontmanClient__Types.Disconnected
      resolve(FrontmanClient__Types.Error("Connection failed"))
    })

    t.socket->FrontmanClient__Phoenix__Socket.connect
  })
}

let disconnect = (t: t): unit => {
  t.socket->FrontmanClient__Phoenix__Socket.disconnect
  t.state := FrontmanClient__Types.Disconnected
}
