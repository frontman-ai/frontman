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

type requestError = Client.requestError
let requestErrorFromMessage = Client.requestErrorFromMessage
let requestErrorWithCode = Client.requestErrorWithCode
let requestErrorMessage = Client.requestErrorMessage
let requestErrorIsBillingInactive = Client.requestErrorIsBillingInactive

let attachBillingStatusHandler = (~channel, ~onBillingStatusUpdated) =>
  onBillingStatusUpdated->Option.forEach(callback =>
    channel->Channel.on(~event=Constants.billingStatusUpdatedEvent, ~callback)
  )

@@live
type config = {
  endpoint: string,
  loginUrl: string,
  getAuthToken: unit => option<string>,
  clientInfo: Types.implementation,
  clientCapabilities: Types.clientCapabilities,
  onConfigOptionsUpdated: option<array<Types.sessionConfigOption> => unit>,
  onBillingStatusUpdated: option<JSON.t => unit>,
}

@@live
let makeConfig = (
  ~endpoint: string,
  ~loginUrl: string,
  ~getAuthToken: unit => option<string>,
  ~name: string,
  ~version: string,
  ~_meta: JSON.t,
  ~onConfigOptionsUpdated: option<array<Types.sessionConfigOption> => unit>=?,
  ~onBillingStatusUpdated: option<JSON.t => unit>=?,
): config => {
  endpoint,
  loginUrl,
  getAuthToken,
  clientInfo: {
    name,
    version,
    title: None,
    _meta: Some(_meta),
  },
  onConfigOptionsUpdated,
  onBillingStatusUpdated,
  clientCapabilities: {
    fs: Some({readTextFile: Some(true), writeTextFile: Some(true)}),
    terminal: Some(false),
    elicitation: None,
    _meta: None,
  },
}

type connection = {
  socket: Socket.t,
  channel: Channel.t,
  clientConfig: Client.config,
  state: ref<Client.state>,
}

@@live
type session = {
  sessionId: string,
  channel: Channel.t,
  connection: connection,
}

type sessionCommand =
  | Cancel
  | RetryTurn(string)
  | UnqueueMessage(string)

let cleanupChannel = channel => {
  switch Channel.state(channel) {
  | "closed" | "leaving" => ()
  | _ =>
    channel->Channel.off(~event=#"acp:message")
    channel->Channel.off(~event=#"mcp:message")
    channel->Channel.off(~event=#title_updated)
    channel->Channel.off(~event=#config_options_updated)
    channel->Channel.off(~event=#billing_status_updated)
    Channel.leave(channel)->ignore
  }
}

let cleanupSessionChannel = (session: session): unit => cleanupChannel(session.channel)

let cleanupConnection = (socket, state: ref<Client.state>): unit => {
  state := state.contents->Client.reduce(Client.ACPStateChanged(Disconnected))
  socket->Socket.channels->Array.forEach(cleanupChannel)
  Socket.disconnect(socket)
}

let disconnect = (conn: connection): unit => cleanupConnection(conn.socket, conn.state)

type connectError =
  | AuthRequired({loginUrl: string})
  | ConnectionFailed(string)

let joinChannel = (channel: Channel.t, ~onError: string => unit): promise<
  result<unit, connectError>,
> => {
  Promise.make((resolve, _) => {
    [#phx_error, #phx_close]->Array.forEach(event =>
      channel->Channel.on(
        ~event,
        ~callback=payload => {
          switch (event, payload == JSON.Encode.string("leave")) {
          | (#phx_close, true) => ()
          | _ =>
            resolve(Error(ConnectionFailed(Protocol.connectionLost)))
            onError(Protocol.connectionLost)
          }
        },
      )
    )
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
      | _ => resolve(Error(ConnectionFailed(JSON.stringify(err))))
      }
    }).receive(~status="timeout", ~callback=_ =>
      resolve(Error(ConnectionFailed("Channel join timed out")))
    )->ignore
  })
}

let checkAborted = (signal: option<WebAPI.EventTypes.abortSignal>): result<unit, string> => {
  switch signal {
  | Some(s) if s.aborted => Error("Connection aborted")
  | _ => Ok()
  }
}

@@live
let connect = async (
  config: config,
  ~signal: option<WebAPI.EventTypes.abortSignal>=?,
  ~onError: string => unit,
): result<connection, connectError> => {
  Sentry.initialize()
  Sentry.addBreadcrumb(~category=#acp, ~message="Starting ACP connection")

  let tokenResult = switch config.getAuthToken() {
  | Some(token) => Ok(token)
  | None => Error(AuthRequired({loginUrl: config.loginUrl}))
  }

  switch (tokenResult, checkAborted(signal)) {
  | (_, Error(_)) => Error(ConnectionFailed("Connection aborted"))
  | (Error(e), _) => Error(e)
  | (Ok(token), Ok()) =>
    let socketOpts: Socket.socketOptions = {
      authToken: token,
      params: Dict.fromArray([
        (
          "origin",
          WebAPI.Window.current
          ->WebAPI.Window.location
          ->FrontmanBindings.Bindings__WebAPI.locationOrigin,
        ),
      ]),
    }
    let socket = Socket.make(~endpoint=config.endpoint, ~opts=socketOpts)
    let channel = socket->Socket.channel(~topic=Constants.tasksTopic)
    let state = ref(Client.initialState)
    let clientConfig: Client.config = {
      clientInfo: config.clientInfo,
      clientCapabilities: config.clientCapabilities,
    }

    Protocol.attachMessageHandler(~channel, ~state, ~onUpdate=None, ~onParseError=None)

    Socket.connect(socket)
    let joinResult = await joinChannel(channel, ~onError=error => {
      cleanupConnection(socket, state)
      onError(error)
    })

    switch (joinResult, checkAborted(signal)) {
    | (_, Error(_)) =>
      cleanupConnection(socket, state)
      Error(ConnectionFailed("Connection aborted"))
    | (Error(e), _) =>
      cleanupConnection(socket, state)
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

      attachBillingStatusHandler(~channel, ~onBillingStatusUpdated=config.onBillingStatusUpdated)

      Sentry.addBreadcrumb(~category=#acp, ~message="Channel joined, sending initialize")
      switch await Protocol.sendInitialize(~channel, ~state, ~clientConfig) {
      | Error(error) =>
        let e = requestErrorMessage(error)
        Log.error(`ACP initialize failed: ${e}`)
        cleanupConnection(socket, state)
        Error(ConnectionFailed(e))
      | Ok(result) =>
        Sentry.addBreadcrumb(~category=#acp, ~message="ACP initialized successfully")
        state := state.contents->Client.reduce(Client.ACPStateChanged(Client.Initialized(result)))
        Ok({socket, channel, clientConfig, state})
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
  ~mcpServerInterface: option<MCPTypes.serverInterface<'server>>=?,
): result<session, string> => {
  let sessionChannel = conn.socket->Socket.channel(~topic=Constants.makeTaskTopic(sessionId))
  let handleSessionError = err => {
    cleanupChannel(sessionChannel)
    switch onParseError {
    | Some(callback) => callback(err)
    | None => throw(SessionMessageParseError(err))
    }
  }

  Protocol.attachMessageHandler(
    ~channel=sessionChannel,
    ~state=conn.state,
    ~onUpdate=Some(onUpdate),
    ~onParseError=Some(handleSessionError),
  )

  mcpServerInterface->Option.forEach(serverInterface => {
    MCP.attach(~channel=sessionChannel, ~sessionId, ~serverInterface)->ignore
  })

  sessionChannel->Channel.on(~event=#title_updated, ~callback=payload => {
    switch payload->Decoders.parseSchema(Types.titleUpdatedSchema) {
    | Ok({sessionId, title}) => onTitleUpdated(sessionId, title)
    | Error(e) => Log.error(`Failed to parse title_updated payload: ${e}`)
    }
  })

  let joinResult = await joinChannel(sessionChannel, ~onError=handleSessionError)

  joinResult
  ->Result.mapError(err => {
    cleanupChannel(sessionChannel)
    let errMsg = switch err {
    | AuthRequired({loginUrl}) => `Auth required: ${loginUrl}`
    | ConnectionFailed(msg) => msg
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
): result<(session, Types.sessionNewResult), requestError> => {
  Sentry.addBreadcrumb(~category=#session, ~message=`Creating new session with id: ${sessionId}`)

  let sessionNewResult = await Protocol.sendSessionNew(
    ~channel=conn.channel,
    ~state=conn.state,
    ~sessionId,
  )

  switch sessionNewResult {
  | Ok(result) =>
    switch result.sessionId == sessionId {
    | false =>
      Error(
        requestErrorFromMessage(`session/new returned unexpected session ID: ${result.sessionId}`),
      )
    | true =>
      let joinResult = await joinSession(
        conn,
        result.sessionId,
        ~onUpdate=validatedUpdateHandler(conn, sessionId, onUpdate),
        ~onTitleUpdated,
        ~onParseError?,
        ~mcpServerInterface?,
      )
      switch joinResult {
      | Ok(session) => Ok((session, result))
      | Error(e) => Error(requestErrorFromMessage(e))
      }
    }
  | Error(err) =>
    Log.error(`Session creation failed: ${requestErrorMessage(err)}`)
    Error(err)
  }
}

@@live
let sendPrompt = async (
  session: session,
  text: string,
  ~additionalBlocks: array<ContentBlock.t>=[],
  ~_meta: option<JSON.t>=None,
): result<Types.promptResult, requestError> => {
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
  )
}

let sendSessionCommand = (session: session, command: sessionCommand): unit => {
  switch command {
  | Cancel => Protocol.sendCancel(~channel=session.channel, ~sessionId=session.sessionId)
  | RetryTurn(retriedErrorId) =>
    Protocol.sendSessionCommand(
      ~channel=session.channel,
      ~sessionId=session.sessionId,
      ~command="retry_turn",
      ~argument=Some(("retriedErrorId", JSON.Encode.string(retriedErrorId))),
    )
  | UnqueueMessage(messageId) =>
    Protocol.sendSessionCommand(
      ~channel=session.channel,
      ~sessionId=session.sessionId,
      ~command="unqueue_message",
      ~argument=Some(("messageId", JSON.Encode.string(messageId))),
    )
  }
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
): result<(session, Types.sessionLoadResult), string> => {
  let buffering = ref(true)
  let bufferedUpdates = ref([])
  let parseError = ref(None)
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
    ~mcpServerInterface?,
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
      ~method=#"session/load",
      ~params=Some(
        params->S.decodeOrThrow(
          ~from=Types.sessionLoadParamsSchema,
          ~to=S.json->S.noValidation(true),
        ),
      ),
      ~parseResult=Client.parseSessionLoadResult,
    )
    let validatedLoad = switch parseError.contents {
    | Some(error) => Error(error)
    | None =>
      loadResult
      ->Result.mapError(requestErrorMessage)
      ->Result.flatMap(result =>
        bufferedUpdates.contents
        ->Array.reduce(Ok(), (validation, (updateSessionId, update)) =>
          validation->Result.flatMap(() => validate(updateSessionId, update))
        )
        ->Result.map(() => result)
      )
    }

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
