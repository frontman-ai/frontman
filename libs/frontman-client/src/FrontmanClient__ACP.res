// Main ACP Client entry point
// Thin orchestrator - delegates to Protocol for messaging, uses Constants for topics

module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Client = FrontmanClient__ACP__Client
module Protocol = FrontmanClient__ACP__Protocol
module Channel = FrontmanClient__Phoenix__Channel
module Socket = FrontmanClient__Phoenix__Socket
module Constants = FrontmanClient__Transport__Constants
module Sentry = FrontmanClient__Sentry
module Decoders = FrontmanClient__Decoders
module Log = FrontmanLogs.Logs.Make({
  let component = #ACP
})

type messageDirection = Protocol.messageDirection
type config = {
  endpoint: string,
  tokenUrl: string,
  loginUrl: string,
  clientInfo: Types.implementation,
  clientCapabilities: Types.clientCapabilities,
  onMessage: option<(messageDirection, JSON.t) => unit>,
  onTitleUpdated: option<(string, string) => unit>,
  onConfigOptionsUpdated: option<array<Types.sessionConfigOption> => unit>,
}

let makeConfig = (
  ~endpoint: string,
  ~tokenUrl: string,
  ~loginUrl: string,
  ~name: string,
  ~version: string,
  ~_meta: JSON.t,
  ~onMessage: option<(messageDirection, JSON.t) => unit>=?,
  ~onTitleUpdated: option<(string, string) => unit>=?,
  ~onConfigOptionsUpdated: option<array<Types.sessionConfigOption> => unit>=?,
): config => {
  endpoint,
  tokenUrl,
  loginUrl,
  clientInfo: {
    name,
    version,
    title: None,
    _meta: Some(_meta),
  },
  onTitleUpdated,
  onConfigOptionsUpdated,
  clientCapabilities: {
    fs: Some({readTextFile: Some(true), writeTextFile: Some(true)}),
    terminal: Some(false),
    elicitation: None,
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
  onUpdate: (string, Types.sessionUpdate) => unit,
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
    let response = await WebAPI.Global.fetch(tokenUrl, ~init={credentials: Include})
    if response.ok {
      let json = await response->WebAPI.Response.json
      switch json
      ->JSON.Decode.object
      ->Option.flatMap(obj => obj->Dict.get("token"))
      ->Option.flatMap(JSON.Decode.string) {
      | Some(token) => Ok(token)
      | None => Error(InvalidResponse)
      }
    } else if response.status == 401 {
      Error(NotAuthenticated)
    } else {
      Error(FetchFailed(`HTTP ${response.status->Int.toString}`))
    }
  } catch {
  | exn =>
    Error(
      FetchFailed(
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error"),
      ),
    )
  }
}

// Connect and initialize ACP
let connect = async (config: config, ~signal: option<WebAPI.EventAPI.abortSignal>=?): result<
  connection,
  connectError,
> => {
  // Initialize logging
  let isDev: bool = %raw("import.meta.env?.DEV ?? true")
  FrontmanLogs.Logs.setLogLevel(if isDev { Debug } else { Error })
  FrontmanLogs.Logs.addHandler(FrontmanLogs.Logs.Console.handler)
  FrontmanLogs.Logs.addHandler(FrontmanClient__Sentry__LogHandler.handler)

  // Initialize Sentry on first connection
  Sentry.initialize()
  Sentry.addBreadcrumb(~category=#acp, ~message="Starting ACP connection")

  // Fetch socket token
  let tokenResult = switch await fetchSocketToken(config.tokenUrl) {
  | Ok(token) => Ok(token)
  | Error(NotAuthenticated) => Error(AuthRequired({loginUrl: config.loginUrl}))
  | Error(FetchFailed(msg)) =>
    Log.error(`Token fetch failed: ${msg}`)
    Error(ConnectionFailed(`Token fetch failed: ${msg}`))
  | Error(InvalidResponse) =>
    Log.error("Invalid token response")
    Error(ConnectionFailed("Invalid token response"))
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
    | (Error(e), _) =>
      Log.error(`Socket connection failed: ${e}`)
      Error(ConnectionFailed(e))
    | (Ok(), Ok()) =>
      Sentry.addBreadcrumb(~category=#acp, ~message="Socket connected, joining channel")
      switch await joinChannel(channel) {
      | Error(AuthRequired({loginUrl})) => Error(AuthRequired({loginUrl: loginUrl}))
      | Error(JoinFailed(e)) =>
        Log.error(`Channel join failed: ${e}`)
        Error(ConnectionFailed(e))
      | Ok() => Ok()
      }
    }

    switch (joinResult, checkAborted(signal)) {
    | (_, Error(_)) => Error(ConnectionFailed("Connection aborted"))
    | (Error(e), _) => Error(e)
    | (Ok(), Ok()) =>
      // Listen for title updates on the tasks channel
      switch config.onTitleUpdated {
      | Some(callback) =>
        channel->Channel.on(~event=#title_updated, ~callback=payload => {
          switch payload->Decoders.parseSchema(Types.titleUpdatedSchema) {
          | Ok({sessionId, title}) => callback(sessionId, title)
          | Error(e) =>
            Log.error(`Failed to parse title_updated payload: ${e}`)
          }
        })
      | None => ()
      }

      // Listen for config option updates (pushed after key saves/OAuth)
      switch config.onConfigOptionsUpdated {
      | Some(callback) =>
        channel->Channel.on(~event=#config_options_updated, ~callback=payload => {
          switch payload->Decoders.parseSchema(Types.configOptionsUpdatedSchema) {
          | Ok({configOptions}) => callback(configOptions)
          | Error(e) =>
            Log.error(`Failed to parse config_options_updated payload: ${e}`)
          }
        })
      | None => ()
      }

      Sentry.addBreadcrumb(~category=#acp, ~message="Channel joined, sending initialize")
      switch await Protocol.sendInitialize(
        ~channel,
        ~state,
        ~clientConfig,
        ~onMessage=config.onMessage,
      ) {
      | Error(e) =>
        Log.error(`ACP initialize failed: ${e}`)
        Error(ConnectionFailed(e))
      | Ok(result) =>
        Sentry.addBreadcrumb(~category=#acp, ~message="ACP initialized successfully")
        state :=
          state.contents->Client.reduce(Client.ConnectionStateChanged(Client.Initialized(result)))
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
// onUpdate receives (sessionId, update) per ACP session/update notification params
let joinSession = async (
  conn: connection,
  sessionId: string,
  ~onUpdate: (string, Types.sessionUpdate) => unit,
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
    ~onParseError=Some(err => Log.warning(`Session message parse error: ${err}`)),
  )

  // Attach MCP handler before joining - server sends mcp:message immediately on join
  mcpServerInterface->Option.forEach(serverInterface => {
    let handler: MCP.mcpHandler<'server> = {
      serverInterface,
      channel: sessionChannel,
      sessionId,
      onMessage: onMcpMessage,
    }
    sessionChannel->Channel.on(~event=#"mcp:message", ~callback=payload => {
      MCP.handleMessage(handler, payload)->ignore
    })
  })

  let joinResult = await joinChannel(sessionChannel)

  joinResult
  ->Result.mapError(err => {
    let errMsg = switch err {
    | AuthRequired({loginUrl}) => `Auth required: ${loginUrl}`
    | JoinFailed(msg) => msg
    }
    Log.error(`Session join failed: ${errMsg}`)
    errMsg
  })
  ->Result.map(_ => {
    Sentry.addBreadcrumb(~category=#session, ~message=`Joined session ${sessionId}`)
    {
      sessionId,
      channel: sessionChannel,
      connection: conn,
      onUpdate,
    }
  })
}

// Create a new ACP session and auto-join the session channel
// Client generates sessionId (UUID) and sends it to the server
// mcpServerInterface is attached before channel join to handle server's immediate MCP init
// onUpdate receives (sessionId, update) per ACP session/update notification params
let createSession = async (
  conn: connection,
  ~sessionId: string,
  ~onUpdate: (string, Types.sessionUpdate) => unit,
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
  ~onMcpMessage: option<(MCP.messageDirection, JSON.t) => unit>=?,
): result<(session, option<array<Types.sessionConfigOption>>), string> => {
  Sentry.addBreadcrumb(~category=#session, ~message=`Creating new session with id: ${sessionId}`)

  let sessionNewResult = await Protocol.sendSessionNew(
    ~channel=conn.channel,
    ~state=conn.state,
    ~sessionId,
    ~onMessage=conn.onMessage,
  )

  switch sessionNewResult {
  | Ok(result) =>
    let joinResult = await joinSession(conn, result.sessionId, ~onUpdate, ~mcpServerInterface?, ~onMcpMessage?)
    switch joinResult {
    | Ok(session) => Ok((session, result.configOptions))
    | Error(e) => Error(e)
    }
  | Error(err) =>
    Log.error(`Session creation failed: ${err}`)
    Error(err)
  }
}

// Send a prompt to the session with additional content blocks
let sendPrompt = async (
  session: session,
  text: string,
  ~additionalBlocks: array<Types.contentBlock>=[],
  ~_meta: option<JSON.t>=None,
): result<Types.promptResult, string> => {
  // Build prompt array starting with the text block
  let textBlock: Types.contentBlock = TextContent({text, _meta: None, annotations: None})
  // Workaround for Sury bug in jsonableValidation (Sury.res.mjs line 1304):
  // reverseConvertToJsonOrThrow rejects S.option fields inside S.union object arms
  // because it passes the union as parent instead of the enclosing object when walking
  // properties, causing the undefined check to fail with "not valid JSON".
  // reverseConvertOrThrow performs the same conversion without the broken pre-check.
  // Obj.magic is safe here: the output is structurally JSON (objects, strings, arrays)
  // with absent keys for None values — reverseConvertOrThrow just returns unknown.
  let allBlocks = Array.concat([textBlock], additionalBlocks)->Array.map(block =>
    (block->S.reverseConvertOrThrow(Types.contentBlockSchema): unknown)->Obj.magic
  )

  await Protocol.sendPrompt(
    ~channel=session.channel,
    ~state=session.connection.state,
    ~sessionId=session.sessionId,
    ~prompt=allBlocks,
    ~_meta,
    ~onMessage=session.connection.onMessage,
  )
}

// Cancel an in-flight prompt
// ACP spec: session/cancel is a notification (fire-and-forget).
// The pending session/prompt request will resolve with stopReason: "cancelled".
let cancelPrompt = (session: session): unit => {
  Protocol.sendCancel(
    ~channel=session.channel,
    ~sessionId=session.sessionId,
    ~onMessage=session.connection.onMessage,
  )
}

// List user's sessions (non-ACP channel message)
let listSessions = (conn: connection): promise<result<array<Types.sessionSummary>, string>> => {
  Promise.make((resolve, _) => {
    let pushRef =
      conn.channel->Channel.push(~event=#list_sessions, ~payload=JSON.Encode.object(Dict.make()))
    pushRef.receive(~status="ok", ~callback=response => {
      switch response->Decoders.parseSchema(Types.listSessionsResultSchema) {
      | Ok({sessions}) => resolve(Ok(sessions))
      | Error(e) => resolve(Error(e))
      }
    }).receive(~status="error", ~callback=err => {
      resolve(Error(JSON.stringify(err)))
    })->ignore
  })
}

// Delete a session (non-ACP channel event)
let deleteSession = (conn: connection, sessionId: string): promise<result<unit, string>> => {
  Promise.make((resolve, _) => {
    let params: Types.deleteSessionParams = {sessionId: sessionId}
    let payload = params->S.reverseConvertToJsonOrThrow(Types.deleteSessionParamsSchema)
    let pushRef = conn.channel->Channel.push(~event=#delete_session, ~payload)
    pushRef.receive(~status="ok", ~callback=_ => resolve(Ok())).receive(
      ~status="error",
      ~callback=err => resolve(Error(JSON.stringify(err))),
    )->ignore
  })
}

// Load an existing session (ACP compliant)
// History is streamed via session/update notifications to onUpdate callback
// onUpdate receives (sessionId, update) per ACP session/update notification params
let loadSession = async (
  conn: connection,
  sessionId: string,
  ~onUpdate: (string, Types.sessionUpdate) => unit,
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
  ~onMcpMessage: option<(MCP.messageDirection, JSON.t) => unit>=?,
): result<(session, Types.sessionLoadResult), string> => {
  // First join the session channel to receive history updates
  let joinResult = await joinSession(
    conn,
    sessionId,
    ~onUpdate,
    ~mcpServerInterface?,
    ~onMcpMessage?,
  )

  switch joinResult {
  | Error(e) => Error(e)
  | Ok(session) =>
    // Send ACP session/load request to session channel (not tasks channel)
    // History notifications are sent to the channel that receives this request,
    // and the onUpdate callback is attached to the session channel in joinSession.
    // Include clientInfo metadata in _meta so the task channel can extract
    // env API keys for config option resolution (env keys are only sent
    // during initialize on the tasks channel, not available on session channels).
    let params: Types.sessionLoadParams = {
      sessionId,
      cwd: "/",
      mcpServers: [],
      _meta: conn.clientConfig.clientInfo._meta,
    }
    let loadResult = await Protocol.sendRequest(
      ~channel=session.channel,
      ~state=conn.state,
      ~method="session/load",
      ~params=Some(params->S.reverseConvertToJsonOrThrow(Types.sessionLoadParamsSchema)),
      ~parseResult=Client.parseSessionLoadResult,
      ~onMessage=conn.onMessage,
    )

    switch loadResult {
    | Ok(result) => Ok((session, result))
    | Error(e) => Error(e)
    }
  }
}
