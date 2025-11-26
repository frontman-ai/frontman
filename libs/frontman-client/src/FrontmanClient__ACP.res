// Main ACP Client entry point
// Orchestrates connection and initialization flow

module Types = FrontmanClient__ACP__Types
module Client = FrontmanClient__ACP__Client
module Channel = FrontmanClient__Phoenix__Channel
module Socket = FrontmanClient__Phoenix__Socket
module JsonRpc = FrontmanClient__JsonRpc

type messageDirection = Send | Receive

type config = {
  endpoint: string,
  clientInfo: Types.implementation,
  clientCapabilities: Types.clientCapabilities,
  onMessage: option<(messageDirection, JSON.t) => unit>,
}

let makeConfig = (
  ~endpoint: string,
  ~name: string,
  ~version: string,
  ~onMessage: option<(messageDirection, JSON.t) => unit>=?,
): config => {
  endpoint,
  clientInfo: {
    name,
    version,
    title: None,
  },
  clientCapabilities: {
    fs: Some({readTextFile: Some(true), writeTextFile: Some(true)}),
    terminal: Some(false),
  },
  onMessage,
}

type connection = {
  socket: Socket.t,
  channel: Channel.t,
  clientConfig: Client.config,
  state: ref<Client.state>,
  onMessage: option<(messageDirection, JSON.t) => unit>,
}

type session = {
  sessionId: string,
  channel: Channel.t,
  connection: connection,
  onUpdate: Types.sessionUpdate => unit,
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
  onMessage: option<(messageDirection, JSON.t) => unit>,
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
    onMessage->Option.forEach(cb => cb(Send, payload))
    channel->Channel.push(~event=#"acp:message", ~payload)->ignore
  })
}

// Connect and initialize ACP
let connect = async (config: config): result<connection, string> => {
  let socket = Socket.make(~endpoint=config.endpoint)
  let channel = socket->Socket.channel(~topic="sessions")
  let state = ref(Client.initialState)
  let clientConfig: Client.config = {
    channel,
    clientInfo: config.clientInfo,
    clientCapabilities: config.clientCapabilities,
  }

  channel->Channel.on(~event=#"acp:message", ~callback=payload => {
    config.onMessage->Option.forEach(cb => cb(Receive, payload))
    state := Client.handleResponse(state.contents, payload)
  })

  let initResult = await (
    waitForSocket(socket)
    ->Result.flatMapOkAsync(_ => joinChannel(channel))
    ->Result.flatMapOkAsync(_ => sendInitialize(channel, state, clientConfig, config.onMessage))
  )

  initResult->Result.map(result => {
    state := state.contents->Client.reduce(Client.ConnectionStateChanged(Client.Initialized(result)))
    {socket, channel, clientConfig, state, onMessage: config.onMessage}
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

// Join a session channel
let joinSession = async (
  conn: connection,
  sessionId: string,
  ~onUpdate: Types.sessionUpdate => unit,
): result<session, string> => {
  let sessionChannel = conn.socket->Socket.channel(~topic=`session:${sessionId}`)

  sessionChannel->Channel.on(~event=#"acp:message", ~callback=payload => {
    conn.onMessage->Option.forEach(cb => cb(Receive, payload))

    switch Client.parseSessionUpdateNotification(payload) {
    | Ok(notification) => onUpdate(notification.params.update)
    | Error(_) =>
      // Not a notification - handle as response
      conn.state := Client.handleResponse(conn.state.contents, payload)
    }
  })

  let joinResult = await joinChannel(sessionChannel)

  joinResult->Result.map(_ => {
    sessionId,
    channel: sessionChannel,
    connection: conn,
    onUpdate,
  })
}

// Create a new ACP session and auto-join the session channel
let createSession = async (
  conn: connection,
  ~onUpdate: Types.sessionUpdate => unit,
): result<session, string> => {
  let sessionNewResult = await Promise.make((resolve, _) => {
    let id = conn.state.contents.currentId + 1
    let request = JsonRpc.Request.make(
      ~id,
      ~method="session/new",
      ~params=Some(JSON.Encode.object(Dict.make())),
    )

    let pending: Client.pendingRequest = {
      resolve: json => {
        switch Client.parseSessionNewResult(json) {
        | Ok(result) => resolve(Ok(result))
        | Error(e) => resolve(Error(e))
        }
      },
      reject: e => resolve(Error(e)),
    }

    conn.state := conn.state.contents->Client.reduce(Client.RequestSent(id, pending))

    let payload = request->JsonRpc.Request.toJson
    conn.onMessage->Option.forEach(cb => cb(Send, payload))
    conn.channel->Channel.push(~event=#"acp:message", ~payload)->ignore
  })

  switch sessionNewResult {
  | Ok(result) => await joinSession(conn, result.sessionId, ~onUpdate)
  | Error(err) => Error(err)
  }
}

// Send a prompt to the session
let sendPrompt = async (session: session, text: string): result<Types.promptResult, string> => {
  let id = session.connection.state.contents.currentId + 1

  let promptParams = JSON.Encode.object(
    Dict.fromArray([
      ("sessionId", JSON.Encode.string(session.sessionId)),
      (
        "prompt",
        JSON.Encode.array([
          JSON.Encode.object(
            Dict.fromArray([("type", JSON.Encode.string("text")), ("text", JSON.Encode.string(text))]),
          ),
        ]),
      ),
    ]),
  )

  let request = JsonRpc.Request.make(~id, ~method="session/prompt", ~params=Some(promptParams))

  await Promise.make((resolve, _) => {
    let pending: Client.pendingRequest = {
      resolve: json => {
        switch Client.parsePromptResult(json) {
        | Ok(result) => resolve(Ok(result))
        | Error(e) => resolve(Error(e))
        }
      },
      reject: e => resolve(Error(e)),
    }

    session.connection.state :=
      session.connection.state.contents->Client.reduce(Client.RequestSent(id, pending))

    let payload = request->JsonRpc.Request.toJson
    session.connection.onMessage->Option.forEach(cb => cb(Send, payload))
    session.channel->Channel.push(~event=#"acp:message", ~payload)->ignore
  })
}
