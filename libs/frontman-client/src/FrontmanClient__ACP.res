// Main ACP Client entry point
// Orchestrates connection and initialization flow

module Types = FrontmanClient__ACP__Types
module Client = FrontmanClient__ACP__Client
module Channel = FrontmanClient__Phoenix__Channel
module Socket = FrontmanClient__Phoenix__Socket
module JsonRpc = FrontmanClient__JsonRpc

type config = {
  endpoint: string,
  sessionId: string,
  clientInfo: Types.implementation,
  clientCapabilities: Types.clientCapabilities,
}

let makeConfig = (
  ~endpoint: string,
  ~sessionId: string,
  ~name: string,
  ~version: string,
): config => {
  endpoint,
  sessionId,
  clientInfo: {
    name,
    version,
    title: None,
  },
  clientCapabilities: {
    fs: Some({readTextFile: Some(true), writeTextFile: Some(true)}),
    terminal: Some(false),
  },
}

type connection = {
  socket: Socket.t,
  channel: Channel.t,
  clientConfig: Client.config,
  state: ref<Client.state>,
}

let waitForSocket = (socket: Socket.t): promise<result<unit, string>> => {
  Promise.make((resolve, _) => {
    socket->Socket.onError(~callback=_ => resolve(Error("Socket connection failed")))
    socket->Socket.onOpen(~callback=() => resolve(Ok()))
    socket->Socket.connect
  })
}

let joinChannel = (channel: Channel.t): promise<result<unit, string>> => {
  Promise.make((resolve, _) => {
    Channel.join(channel).receive(~status="ok", ~callback=_ =>
      resolve(Ok())
    ).receive(~status="error", ~callback=err =>
      resolve(Error(`Join failed: ${JSON.stringify(err)}`))
    )->ignore
  })
}

let sendInitialize = (
  channel: Channel.t,
  state: ref<Client.state>,
  clientConfig: Client.config,
): promise<result<Types.initializeResult, string>> => {
  Promise.make((resolve, _) => {
    let id = state.contents.currentId + 1
    let params = Client.buildInitializeParams(clientConfig)
    let request = JsonRpc.Request.make(~id, ~method="initialize", ~params=Some(params))

    let pending: Client.pendingRequest = {
      resolve: json => {
        switch Client.parseInitializeResult(json) {
        | Ok(result) => resolve(Ok(result))
        | Error(e) => resolve(Error(e))
        }
      },
      reject: e => resolve(Error(e)),
    }

    state := state.contents->Client.reduce(Client.RequestSent(id, pending))

    let payload = request->JsonRpc.Request.toJson
    channel->Channel.push(~event=#"acp:message", ~payload)->ignore
  })
}

// Connect and initialize ACP
let connect = async (config: config): result<connection, string> => {
  let socket = Socket.make(~endpoint=config.endpoint)
  let channel = socket->Socket.channel(~topic=`session:${config.sessionId}`)
  let state = ref(Client.initialState)
  let clientConfig: Client.config = {
    channel,
    clientInfo: config.clientInfo,
    clientCapabilities: config.clientCapabilities,
  }

  channel->Channel.on(~event=#"acp:message", ~callback=payload => {
    state := Client.handleResponse(state.contents, payload)
  })

  let initResult = await (
    waitForSocket(socket)
    ->Result.flatMapOkAsync(_ => joinChannel(channel))
    ->Result.flatMapOkAsync(_ => sendInitialize(channel, state, clientConfig))
  )

  initResult->Result.map(result => {
    state := state.contents->Client.reduce(Client.ConnectionStateChanged(Client.Initialized(result)))
    {socket, channel, clientConfig, state}
  })
}

// Get current connection state
let getState = (conn: connection): Client.connectionState => {
  Client.getConnectionState(conn.state.contents)
}

// Check if initialized
let isInitialized = (conn: connection): bool => {
  Client.isInitialized(conn.state.contents)
}
