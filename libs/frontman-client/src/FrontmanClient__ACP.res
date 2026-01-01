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

// Connect and initialize ACP
let connect = async (config: config): result<connection, string> => {
  let socket = Socket.make(~endpoint=config.endpoint)
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

  let initResult = await waitForSocket(socket)
  ->Result.flatMapOkAsync(_ => joinChannel(channel))
  ->Result.flatMapOkAsync(_ =>
    Protocol.sendInitialize(~channel, ~state, ~clientConfig, ~onMessage=config.onMessage)
  )

  initResult->Result.map(result => {
    state :=
      state.contents->Client.reduce(Client.ConnectionStateChanged(Client.Initialized(result)))
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

// Join a session channel (internal helper)
// onBeforeJoin is called after channel creation but before join - use it to attach
// additional handlers (like MCP) that must be ready before server sends messages
let joinSession = async (
  conn: connection,
  sessionId: string,
  ~onUpdate: Types.sessionUpdate => unit,
  ~onBeforeJoin: option<Channel.t => unit>=?,
): result<session, string> => {
  let sessionChannel = conn.socket->Socket.channel(~topic=Constants.makeTaskTopic(sessionId))

  Protocol.attachMessageHandler(
    ~channel=sessionChannel,
    ~state=conn.state,
    ~onUpdate=Some(onUpdate),
    ~onMessage=conn.onMessage,
    ~onParseError=Some(err => Console.warn(`Session message parse error: ${err}`)),
  )

  // Call onBeforeJoin callback to allow attaching additional handlers (e.g., MCP)
  // This MUST happen before joinChannel to avoid race conditions where the server
  // sends messages before handlers are attached
  onBeforeJoin->Option.forEach(cb => cb(sessionChannel))

  let joinResult = await joinChannel(sessionChannel)

  joinResult->Result.map(_ => {
    sessionId,
    channel: sessionChannel,
    connection: conn,
    onUpdate,
  })
}

// Create a new ACP session and auto-join the session channel
// onBeforeJoin is called after channel creation but before join - use it to attach
// additional handlers (like MCP) that must be ready before server sends messages
let createSession = async (
  conn: connection,
  ~onUpdate: Types.sessionUpdate => unit,
  ~onBeforeJoin: option<Channel.t => unit>=?,
): result<session, string> => {
  let sessionNewResult = await Protocol.sendSessionNew(
    ~channel=conn.channel,
    ~state=conn.state,
    ~onMessage=conn.onMessage,
  )

  switch sessionNewResult {
  | Ok(result) => await joinSession(conn, result.sessionId, ~onUpdate, ~onBeforeJoin?)
  | Error(err) => Error(err)
  }
}

// Send a prompt to the session with additional content blocks
let sendPrompt = async (
  session: session,
  text: string,
  ~additionalBlocks: array<Types.contentBlock>=[],
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
    ~onMessage=session.connection.onMessage,
  )
}
