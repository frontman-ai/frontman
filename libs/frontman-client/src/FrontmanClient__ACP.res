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
@@live
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

@@live
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
    _meta: None,
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

@@live
type session = {
  sessionId: string,
  channel: Channel.t,
  connection: connection,
  onUpdate: (string, Types.sessionUpdate) => unit,
}

let cleanupChannel = channel => {
  channel->Channel.off(~event=#"acp:message")
  channel->Channel.off(~event=#"mcp:message")
  channel->Channel.off(~event=#title_updated)
  Channel.leave(channel)->ignore
}

let cleanupSessionChannel = (session: session): unit => cleanupChannel(session.channel)

let disconnect = (conn: connection, ~session: option<session>=?): unit => {
  session->Option.forEach(cleanupSessionChannel)
  conn.channel->Channel.off(~event=#"acp:message")
  conn.channel->Channel.off(~event=#config_options_updated)
  Channel.leave(conn.channel)->ignore
  Socket.disconnect(conn.socket)
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
@@live
let connect = async (config: config, ~signal: option<WebAPI.EventAPI.abortSignal>=?): result<
  connection,
  connectError,
> => {
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
      // Listen for config option updates (pushed after key saves/OAuth)
      switch config.onConfigOptionsUpdated {
      | Some(callback) =>
        channel->Channel.on(~event=#config_options_updated, ~callback=payload => {
          switch payload->Decoders.parseSchema(Types.configOptionsUpdatedSchema) {
          | Ok({configOptions}) => callback(configOptions)
          | Error(e) => Log.error(`Failed to parse config_options_updated payload: ${e}`)
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
        state := state.contents->Client.reduce(Client.ACPStateChanged(Client.Initialized(result)))
        Ok({
          socket,
          channel,
          clientConfig,
          state,
          onMessage: config.onMessage,
        })
      }
    }
  }
}

// Get current connection state
@@live
let getState = (conn: connection): Client.acpState => {
  Client.getACPState(conn.state.contents)
}

// Check if initialized
@@live
let isInitialized = (conn: connection): bool => {
  Client.isInitialized(conn.state.contents)
}

@@live
let getAgentAttributionVersion = (conn: connection): option<Client.agentAttributionVersion> =>
  conn.state.contents.agentAttributionVersion

module MCP = FrontmanClient__MCP
module MCPTypes = FrontmanClient__MCP__Types

exception SessionMessageParseError(string)

// Join a session channel (internal helper)
// mcpServerInterface is used to create MCP handler BEFORE joining to avoid race with server MCP init
// onUpdate receives (sessionId, update) per ACP session/update notification params
let joinSession = async (
  conn: connection,
  sessionId: string,
  ~onUpdate: (string, Types.sessionUpdate) => unit,
  ~catalog: option<array<Types.agentCatalogEntry>>,
  ~onTitleUpdated: (string, string) => unit,
  ~onParseError: option<string => unit>=?,
  ~cleanupOnParseError: option<ref<bool>>=?,
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
  ~onMcpMessage: option<(MCP.messageDirection, JSON.t) => unit>=?,
  ~validateUpdates=true,
): result<session, string> => {
  let sessionChannel = conn.socket->Socket.channel(~topic=Constants.makeTaskTopic(sessionId))
  let validator = Client.makeSessionUpdateValidator(conn.state.contents, ~sessionId, catalog)
  let handleUpdate = (notificationSessionId, update) =>
    switch validateUpdates {
    | false => onUpdate(notificationSessionId, update)
    | true =>
      switch validator(notificationSessionId, update) {
      | Ok() => onUpdate(notificationSessionId, update)
      | Error(error) => failwith(error)
      }
    }
  let handleParseError = err => {
    switch cleanupOnParseError->Option.mapOr(true, enabled => enabled.contents) {
    | true => cleanupChannel(sessionChannel)
    | false => ()
    }
    switch onParseError {
    | Some(callback) => callback(err)
    | None => throw(SessionMessageParseError(err))
    }
  }

  // Attach ACP handler before joining
  Protocol.attachMessageHandler(
    ~channel=sessionChannel,
    ~state=conn.state,
    ~onUpdate=Some(handleUpdate),
    ~onMessage=conn.onMessage,
    ~onParseError=Some(handleParseError),
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

  // Listen for title updates on the session channel
  sessionChannel->Channel.on(~event=#title_updated, ~callback=payload => {
    switch payload->Decoders.parseSchema(Types.titleUpdatedSchema) {
    | Ok({sessionId, title}) => onTitleUpdated(sessionId, title)
    | Error(e) => Log.error(`Failed to parse title_updated payload: ${e}`)
    }
  })

  let joinResult = await joinChannel(sessionChannel)

  joinResult
  ->Result.mapError(err => {
    cleanupChannel(sessionChannel)
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
      onUpdate: handleUpdate,
    }
  })
}

// Create a new ACP session and auto-join the session channel
// Client generates sessionId (UUID) and sends it to the server
// mcpServerInterface is attached before channel join to handle server's immediate MCP init
// onUpdate receives (sessionId, update) per ACP session/update notification params
@@live
let createSession = async (
  conn: connection,
  ~sessionId: string,
  ~onUpdate: (string, Types.sessionUpdate) => unit,
  ~onTitleUpdated: (string, string) => unit,
  ~onParseError: option<string => unit>=?,
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
  ~onMcpMessage: option<(MCP.messageDirection, JSON.t) => unit>=?,
): result<(session, Types.sessionNewResult, option<array<Types.agentCatalogEntry>>), string> => {
  Sentry.addBreadcrumb(~category=#session, ~message=`Creating new session with id: ${sessionId}`)

  let sessionNewResult = await Protocol.sendSessionNew(
    ~channel=conn.channel,
    ~state=conn.state,
    ~sessionId,
    ~onMessage=conn.onMessage,
  )

  switch sessionNewResult {
  | Ok(result) =>
    switch (
      result.sessionId == sessionId,
      Client.validateSessionMetadata(conn.state.contents, result._meta, "session/new"),
    ) {
    | (false, _) => Error(`session/new returned unexpected session ID: ${result.sessionId}`)
    | (true, Error(e)) => Error(e)
    | (true, Ok(catalog)) =>
      let joinResult = await joinSession(
        conn,
        result.sessionId,
        ~onUpdate,
        ~catalog,
        ~onTitleUpdated,
        ~onParseError?,
        ~mcpServerInterface?,
        ~onMcpMessage?,
      )
      switch joinResult {
      | Ok(session) => Ok((session, result, catalog))
      | Error(e) => Error(e)
      }
    }
  | Error(err) =>
    Log.error(`Session creation failed: ${err}`)
    Error(err)
  }
}

// Send a prompt to the session with additional content blocks
@@live
let sendPrompt = async (
  session: session,
  text: string,
  ~additionalBlocks: array<Types.contentBlock>=[],
  ~_meta: option<JSON.t>=None,
): result<Types.promptResult, string> => {
  let baseBlocks: array<Types.contentBlock> = switch text->String.trim != "" {
  | true => [TextContent({text, _meta: None, annotations: None})]
  | false => []
  }

  // Serialize through S.unknown to avoid strict JSON checks on option fields inside union arms.
  let allBlocks =
    Array.concat(baseBlocks, additionalBlocks)->Array.map(block =>
      block->S.decodeOrThrow(~from=Types.contentBlockSchema, ~to=S.json->S.noValidation(true))
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
let cancelPrompt = (session: session): unit => {
  Protocol.sendCancel(
    ~channel=session.channel,
    ~sessionId=session.sessionId,
    ~onMessage=session.connection.onMessage,
  )
}

// Retry a failed turn
// Frontman extension: session/retry_turn is a notification (fire-and-forget).
let retryTurn = (session: session, ~retriedErrorId: string): unit => {
  Protocol.sendRetryTurn(
    ~channel=session.channel,
    ~sessionId=session.sessionId,
    ~retriedErrorId,
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
    let payload =
      params->S.decodeOrThrow(
        ~from=Types.deleteSessionParamsSchema,
        ~to=S.json->S.noValidation(true),
      )
    let pushRef = conn.channel->Channel.push(~event=#delete_session, ~payload)
    pushRef.receive(~status="ok", ~callback=_ => resolve(Ok())).receive(
      ~status="error",
      ~callback=err => resolve(Error(JSON.stringify(err))),
    )->ignore
  })
}

// Load an existing session while preserving ACP history-before-response wire ordering.
// History callbacks are buffered until onLoadResult installs validated response metadata.
@@live
let loadSession = async (
  conn: connection,
  sessionId: string,
  ~onLoadResult: (Types.sessionLoadResult, option<array<Types.agentCatalogEntry>>) => unit,
  ~onUpdate: (string, Types.sessionUpdate) => unit,
  ~onTitleUpdated: (string, string) => unit,
  ~onParseError: option<string => unit>=?,
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
  ~onMcpMessage: option<(MCP.messageDirection, JSON.t) => unit>=?,
): result<(session, Types.sessionLoadResult), string> => {
  let buffering = ref(true)
  let bufferedUpdates = ref([])
  let parseError = ref(None)
  let cleanupOnParseError = ref(false)
  let validator = ref(None)
  let handleUpdate = (sessionId, update) =>
    switch buffering.contents {
    | true => bufferedUpdates := bufferedUpdates.contents->Array.concat([(sessionId, update)])
    | false => {
        let validate =
          validator.contents->Option.getOrThrow(~message="Loaded session validator is required")
        switch validate(sessionId, update) {
        | Ok() => onUpdate(sessionId, update)
        | Error(error) => failwith(error)
        }
      }
    }

  // First join the session channel to receive history updates
  let joinResult = await joinSession(
    conn,
    sessionId,
    ~onUpdate=handleUpdate,
    ~catalog=None,
    ~onTitleUpdated,
    ~onParseError=err =>
      switch buffering.contents {
      | false =>
        switch onParseError {
        | Some(callback) => callback(err)
        | None => throw(SessionMessageParseError(err))
        }
      | true =>
        switch parseError.contents {
        | None => parseError := Some(err)
        | Some(_) => ()
        }
      },
    ~cleanupOnParseError,
    ~mcpServerInterface?,
    ~onMcpMessage?,
    ~validateUpdates=false,
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
      ~params=Some(
        params->S.decodeOrThrow(
          ~from=Types.sessionLoadParamsSchema,
          ~to=S.json->S.noValidation(true),
        ),
      ),
      ~parseResult=Client.parseSessionLoadResult,
      ~onMessage=conn.onMessage,
    )
    cleanupOnParseError := true

    switch loadResult {
    | Ok(result) => {
        let validation = switch parseError.contents {
        | Some(e) => Error(e)
        | None =>
          Client.validateSessionMetadata(
            conn.state.contents,
            result._meta,
            "session/load",
          )->Result.flatMap(catalog => {
            let validate = Client.makeSessionUpdateValidator(
              conn.state.contents,
              ~sessionId,
              catalog,
            )
            validator := Some(validate)
            bufferedUpdates.contents->Array.reduce(Ok(catalog), (
              result,
              (updateSessionId, update),
            ) =>
              result->Result.flatMap(
                catalog => validate(updateSessionId, update)->Result.map(() => catalog),
              )
            )
          })
        }

        switch validation {
        | Error(e) => {
            cleanupSessionChannel(session)
            Error(e)
          }
        | Ok(catalog) => {
            onLoadResult(result, catalog)
            buffering := false
            let replayError = try {
              bufferedUpdates.contents->Array.forEach(((sessionId, update)) =>
                onUpdate(sessionId, update)
              )
              None
            } catch {
            | Failure(error) => Some(error)
            | exn =>
              Some(
                exn
                ->JsExn.fromException
                ->Option.flatMap(JsExn.message)
                ->Option.getOr("Session update handler failed"),
              )
            }
            switch replayError {
            | Some(error) =>
              cleanupSessionChannel(session)
              onParseError->Option.forEach(callback => callback(error))
              Error(error)
            | None =>
              bufferedUpdates := []
              Ok((session, result))
            }
          }
        }
      }
    | Error(e) => {
        cleanupSessionChannel(session)
        Error(e)
      }
    }
  }
}
