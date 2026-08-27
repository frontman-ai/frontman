module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock
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

let checkAborted = (signal: option<WebAPI.EventTypes.abortSignal>): result<unit, string> => {
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

let fetchSocketToken = async (tokenUrl: string): result<string, tokenError> => {
  try {
    let response = await WebAPI.Fetch.fetch(tokenUrl, ~init={credentials: Include})
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

@@live
let connect = async (config: config, ~signal: option<WebAPI.EventTypes.abortSignal>=?): result<
  connection,
  connectError,
> => {
  Sentry.initialize()
  Sentry.addBreadcrumb(~category=#acp, ~message="Starting ACP connection")

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
    | (_, Error(_)) =>
      cleanupChannel(channel)
      Socket.disconnect(socket)
      Error(ConnectionFailed("Connection aborted"))
    | (Error(e), _) =>
      cleanupChannel(channel)
      Socket.disconnect(socket)
      Error(e)
    | (Ok(), Ok()) =>
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

@@live
let getState = (conn: connection): Client.acpState => {
  Client.getACPState(conn.state.contents)
}

@@live
let isInitialized = (conn: connection): bool => {
  Client.isInitialized(conn.state.contents)
}

@@live
let getAgentAttributionConfiguration = (conn: connection): option<
  Types.agentAttributionConfigurationMetadata,
> => conn.state.contents.agentAttributionConfiguration

module MCP = FrontmanClient__MCP
module MCPTypes = FrontmanClient__MCP__Types

exception SessionMessageParseError(string)

let validatedUpdateHandler = (conn, sessionId, onUpdate) => {
  let validate = Client.makeSessionUpdateValidator(conn.state.contents, ~sessionId)
  (sessionId, update) =>
    switch validate(sessionId, update) {
    | Ok() => onUpdate(sessionId, update)
    | Error(error) => failwith(error)
    }
}

let joinSession = async (
  conn: connection,
  sessionId: string,
  ~onUpdate: (string, Types.sessionUpdate) => unit,
  ~onTitleUpdated: (string, string) => unit,
  ~onParseError: option<string => unit>=?,
  ~cleanupOnParseError: option<ref<bool>>=?,
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
  ~onMcpMessage: option<(MCP.messageDirection, JSON.t) => unit>=?,
): result<session, string> => {
  let sessionChannel = conn.socket->Socket.channel(~topic=Constants.makeTaskTopic(sessionId))
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

  Protocol.attachMessageHandler(
    ~channel=sessionChannel,
    ~state=conn.state,
    ~onUpdate=Some(onUpdate),
    ~onMessage=conn.onMessage,
    ~onParseError=Some(handleParseError),
  )

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
      onUpdate,
    }
  })
}

@@live
let createSession = async (
  conn: connection,
  ~sessionId: string,
  ~onUpdate: (string, Types.sessionUpdate) => unit,
  ~onTitleUpdated: (string, string) => unit,
  ~onParseError: option<string => unit>=?,
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
  ~onMcpMessage: option<(MCP.messageDirection, JSON.t) => unit>=?,
): result<(session, Types.sessionNewResult), string> => {
  Sentry.addBreadcrumb(~category=#session, ~message=`Creating new session with id: ${sessionId}`)

  let sessionNewResult = await Protocol.sendSessionNew(
    ~channel=conn.channel,
    ~state=conn.state,
    ~sessionId,
    ~onMessage=conn.onMessage,
  )

  switch sessionNewResult {
  | Ok(result) =>
    switch result.sessionId == sessionId {
    | false => Error(`session/new returned unexpected session ID: ${result.sessionId}`)
    | true =>
      let joinResult = await joinSession(
        conn,
        result.sessionId,
        ~onUpdate=validatedUpdateHandler(conn, sessionId, onUpdate),
        ~onTitleUpdated,
        ~onParseError?,
        ~mcpServerInterface?,
        ~onMcpMessage?,
      )
      switch joinResult {
      | Ok(session) => Ok((session, result))
      | Error(e) => Error(e)
      }
    }
  | Error(err) =>
    Log.error(`Session creation failed: ${err}`)
    Error(err)
  }
}

@@live
let sendPrompt = async (
  session: session,
  text: string,
  ~additionalBlocks: array<ContentBlock.t>=[],
  ~_meta: option<JSON.t>=None,
): result<Types.promptResult, string> => {
  let baseBlocks: array<ContentBlock.t> = switch text->String.trim != "" {
  | true => [TextContent({text, _meta: None, annotations: None})]
  | false => []
  }

  let allBlocks =
    Array.concat(baseBlocks, additionalBlocks)->Array.map(block =>
      block->S.decodeOrThrow(~from=ContentBlock.schema, ~to=S.json->S.noValidation(true))
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

type sessionCommand = Cancel | Retry(string) | Unqueue(string)

let sendSessionCommand = (session: session, command: sessionCommand): unit => {
  let (method, fields) = switch command {
  | Cancel => ("session/cancel", [])
  | Retry(retriedErrorId) => (
      "session/retry_turn",
      [("retriedErrorId", JSON.Encode.string(retriedErrorId))],
    )
  | Unqueue(messageId) => (
      "session/unqueue_message",
      [("messageId", JSON.Encode.string(messageId))],
    )
  }
  Protocol.sendNotification(
    ~channel=session.channel,
    ~method,
    ~params=Array.concat([("sessionId", JSON.Encode.string(session.sessionId))], fields),
    ~onMessage=session.connection.onMessage,
  )
}

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

@@live
let loadSession = async (
  conn: connection,
  sessionId: string,
  ~onLoadResult: Types.sessionLoadResult => unit,
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
  let validate = Client.makeSessionUpdateValidator(conn.state.contents, ~sessionId)
  let handleUpdate = (sessionId, update) =>
    switch buffering.contents {
    | true => bufferedUpdates := bufferedUpdates.contents->Array.concat([(sessionId, update)])
    | false =>
      switch validate(sessionId, update) {
      | Ok() => onUpdate(sessionId, update)
      | Error(error) => failwith(error)
      }
    }

  let joinResult = await joinSession(
    conn,
    sessionId,
    ~onUpdate=handleUpdate,
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
  )

  switch joinResult {
  | Error(e) => Error(e)
  | Ok(session) =>
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

    let validatedLoad = loadResult->Result.flatMap(result =>
      switch parseError.contents {
      | Some(error) => Error(error)
      | None =>
        bufferedUpdates.contents
        ->Array.reduce(Ok(), (validation, (updateSessionId, update)) =>
          validation->Result.flatMap(() => validate(updateSessionId, update))
        )
        ->Result.map(() => result)
      }
    )

    switch validatedLoad {
    | Error(error) =>
      cleanupSessionChannel(session)
      Error(error)
    | Ok(result) =>
      onLoadResult(result)
      buffering := false
      try {
        bufferedUpdates.contents->Array.forEach(((sessionId, update)) =>
          onUpdate(sessionId, update)
        )
        bufferedUpdates := []
        Ok((session, result))
      } catch {
      | Failure(error) =>
        cleanupSessionChannel(session)
        onParseError->Option.forEach(callback => callback(error))
        Error(error)
      | exn =>
        let error =
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Session update handler failed")
        cleanupSessionChannel(session)
        onParseError->Option.forEach(callback => callback(error))
        Error(error)
      }
    }
  }
}
