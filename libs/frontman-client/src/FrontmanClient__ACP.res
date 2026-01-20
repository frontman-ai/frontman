// Main ACP Client entry point
// Thin orchestrator - delegates to Protocol for messaging, uses Constants for topics

module Types = FrontmanClient__ACP__Types
module Client = FrontmanClient__ACP__Client
module Protocol = FrontmanClient__ACP__Protocol
module Channel = FrontmanClient__Phoenix__Channel
module Socket = FrontmanClient__Phoenix__Socket
module Constants = FrontmanClient__Transport__Constants

type messageDirection = Protocol.messageDirection
let send = Protocol.Send
let receive = Protocol.Receive

type config = {
  endpoint: string,
  tokenUrl: string,
  loginUrl: string,
  clientInfo: Types.implementation,
  clientCapabilities: Types.clientCapabilities,
  onMessage: option<(messageDirection, JSON.t) => unit>,
}

let makeConfig = (
  ~endpoint: string,
  ~tokenUrl: string,
  ~loginUrl: string,
  ~name: string,
  ~version: string,
  ~metadata: option<JSON.t>=?,
  ~onMessage: option<(messageDirection, JSON.t) => unit>=?,
): config => {
  endpoint,
  tokenUrl,
  loginUrl,
  clientInfo: {
    name,
    version,
    title: None,
    metadata,
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

type joinError =
  | AuthRequired({loginUrl: string})
  | JoinFailed(string)

let joinChannel = (channel: Channel.t): promise<result<unit, joinError>> => {
  Promise.make((resolve, _) => {
    Channel.join(channel).receive(~status="ok", ~callback=_ =>
      resolve(Ok())
    ).receive(~status="error", ~callback=err => {
      // Parse error to check for auth failure
      let parsed = err->JSON.Decode.object
      let reason =
        parsed->Option.flatMap(o => o->Dict.get("reason")->Option.flatMap(JSON.Decode.string))
      let loginUrl =
        parsed->Option.flatMap(o => o->Dict.get("login_url")->Option.flatMap(JSON.Decode.string))

      switch (reason, loginUrl) {
      | (Some("unauthorized"), Some(url)) => resolve(Error(AuthRequired({loginUrl: url})))
      | _ => resolve(Error(JoinFailed(JSON.stringify(err))))
      }
    })->ignore
  })
}

// Helper to check abort status
let checkAborted = (signal: option<WebAPI.EventAPI.abortSignal>): result<unit, string> => {
  switch signal {
  | Some(s) if s.aborted => Error("Connection aborted")
  | _ => Ok()
  }
}

type connectError =
  | AuthRequired({loginUrl: string})
  | ConnectionFailed(string)

type tokenError =
  | FetchFailed(string)
  | NotAuthenticated
  | InvalidResponse

// Fetch socket auth token from the server (for cross-origin auth)
let fetchSocketToken = async (tokenUrl: string): result<string, tokenError> => {
  try {
    let response = await WebAPI.Global.fetch(
      tokenUrl,
      ~init={credentials: Include},
    )
    if response.ok {
      let json = await response->WebAPI.Response.json
      switch json->JSON.Decode.object->Option.flatMap(obj => obj->Dict.get("token"))->Option.flatMap(JSON.Decode.string) {
      | Some(token) => Ok(token)
      | None => Error(InvalidResponse)
      }
    } else if response.status == 401 {
      Error(NotAuthenticated)
    } else {
      Error(FetchFailed(`HTTP ${response.status->Int.toString}`))
    }
  } catch {
  | Exn.Error(e) => Error(FetchFailed(Exn.message(e)->Option.getOr("Unknown error")))
  }
}

// Connect and initialize ACP
let connect = async (config: config, ~signal: option<WebAPI.EventAPI.abortSignal>=?): result<
  connection,
  connectError,
> => {
  // Fetch socket token
  let tokenResult = switch await fetchSocketToken(config.tokenUrl) {
  | Ok(token) => Ok(token)
  | Error(NotAuthenticated) => Error(AuthRequired({loginUrl: config.loginUrl}))
  | Error(FetchFailed(msg)) => Error(ConnectionFailed(`Token fetch failed: ${msg}`))
  | Error(InvalidResponse) => Error(ConnectionFailed("Invalid token response"))
  }

  switch (tokenResult, checkAborted(signal)) {
  | (_, Error(_)) => Error(ConnectionFailed("Connection aborted"))
  | (Error(e), _) => Error(e)
  | (Ok(token), Ok()) =>
    let socketOpts: Socket.socketOptions = {params: Dict.fromArray([("token", token)])}
    let socket = Socket.make(~endpoint=config.endpoint, ~opts=socketOpts)
    let channel = socket->Socket.channel(~topic=Constants.tasksTopic)
    let state = ref(Client.initialState)
    let clientConfig: Client.config = {
      channel,
      clientInfo: config.clientInfo,
      clientCapabilities: config.clientCapabilities,
    }

    Protocol.attachMessageHandler(
      ~channel,
      ~state,
      ~onUpdate=None,
      ~onMessage=config.onMessage,
      ~onParseError=None,
    )

    let socketResult = await waitForSocket(socket)

    let joinResult = switch (socketResult, checkAborted(signal)) {
    | (_, Error(_)) => Error(ConnectionFailed("Connection aborted"))
    | (Error(e), _) => Error(ConnectionFailed(e))
    | (Ok(), Ok()) =>
      switch await joinChannel(channel) {
      | Error(AuthRequired({loginUrl})) => Error(AuthRequired({loginUrl: loginUrl}))
      | Error(JoinFailed(e)) => Error(ConnectionFailed(e))
      | Ok() => Ok()
      }
    }

    switch (joinResult, checkAborted(signal)) {
    | (_, Error(_)) => Error(ConnectionFailed("Connection aborted"))
    | (Error(e), _) => Error(e)
    | (Ok(), Ok()) =>
      switch await Protocol.sendInitialize(~channel, ~state, ~clientConfig, ~onMessage=config.onMessage) {
      | Error(e) => Error(ConnectionFailed(e))
      | Ok(result) =>
        state := state.contents->Client.reduce(Client.ConnectionStateChanged(Client.Initialized(result)))
        Ok({socket, channel, clientConfig, state, onMessage: config.onMessage})
      }
    }
  }
}

// Get current connection state
let getState = (conn: connection): Client.connectionState => {
  Client.getConnectionState(conn.state.contents)
}

// Check if initialized
let isInitialized = (conn: connection): bool => {
  Client.isInitialized(conn.state.contents)
}

module MCP = FrontmanClient__MCP
module MCPTypes = FrontmanClient__MCP__Types

// Join a session channel (internal helper)
// mcpServerInterface is used to create MCP handler BEFORE joining to avoid race with server MCP init
let joinSession = async (
  conn: connection,
  sessionId: string,
  ~onUpdate: Types.sessionUpdate => unit,
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
  ~onMcpMessage: option<(MCP.messageDirection, JSON.t) => unit>=?,
): result<session, string> => {
  let sessionChannel = conn.socket->Socket.channel(~topic=Constants.makeTaskTopic(sessionId))

  // Attach ACP handler before joining
  Protocol.attachMessageHandler(
    ~channel=sessionChannel,
    ~state=conn.state,
    ~onUpdate=Some(onUpdate),
    ~onMessage=conn.onMessage,
    ~onParseError=Some(err => Console.warn(`Session message parse error: ${err}`)),
  )

  // Attach MCP handler before joining - server sends mcp:message immediately on join
  mcpServerInterface->Option.forEach(serverInterface => {
    let handler: MCP.mcpHandler<'server> = {
      serverInterface,
      channel: sessionChannel,
      onMessage: onMcpMessage,
    }
    sessionChannel->Channel.on(~event=#"mcp:message", ~callback=payload => {
      MCP.handleMessage(handler, payload)->ignore
    })
  })

  let joinResult = await joinChannel(sessionChannel)

  joinResult
  ->Result.mapError(err =>
    switch err {
    | AuthRequired({loginUrl}) => `Auth required: ${loginUrl}`
    | JoinFailed(msg) => msg
    }
  )
  ->Result.map(_ => {
    sessionId,
    channel: sessionChannel,
    connection: conn,
    onUpdate,
  })
}

// Create a new ACP session and auto-join the session channel
// mcpServerInterface is attached before channel join to handle server's immediate MCP init
let createSession = async (
  conn: connection,
  ~onUpdate: Types.sessionUpdate => unit,
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
  ~onMcpMessage: option<(MCP.messageDirection, JSON.t) => unit>=?,
): result<session, string> => {
  let sessionNewResult = await Protocol.sendSessionNew(
    ~channel=conn.channel,
    ~state=conn.state,
    ~onMessage=conn.onMessage,
  )

  switch sessionNewResult {
  | Ok(result) =>
    await joinSession(conn, result.sessionId, ~onUpdate, ~mcpServerInterface?, ~onMcpMessage?)
  | Error(err) => Error(err)
  }
}

// Send a prompt to the session with additional content blocks
let sendPrompt = async (
  session: session,
  text: string,
  ~additionalBlocks: array<Types.contentBlock>=[],
  ~metadata: option<JSON.t>=None,
): result<Types.promptResult, string> => {
  // Build prompt array starting with the text block
  let textBlock = JSON.Encode.object(
    Dict.fromArray([("type", JSON.Encode.string("text")), ("text", JSON.Encode.string(text))]),
  )

  let allBlocks = if Array.length(additionalBlocks) > 0 {
    let additionalBlocksJson =
      additionalBlocks->Array.map(block =>
        block->S.reverseConvertToJsonOrThrow(Types.contentBlockSchema)
      )
    Array.concat([textBlock], additionalBlocksJson)
  } else {
    [textBlock]
  }

  await Protocol.sendPrompt(
    ~channel=session.channel,
    ~state=session.connection.state,
    ~sessionId=session.sessionId,
    ~prompt=allBlocks,
    ~metadata,
    ~onMessage=session.connection.onMessage,
  )
}
