type t = {
  socket: FrontmanClient__Phoenix__Socket.t,
  endpoint: string,
  state: ref<FrontmanClient__Types.connectionState>,
}

let getSocket = (t: t): FrontmanClient__Phoenix__Socket.t => t.socket
