module Connection = Client__ConnectionReducer
module ACP = Connection.ACP

let makeStore = (state, handle) =>
  StateStore.make(
    module(
      {
        include Client__State__StateReducer
        let handleEffect = handle
      }
    ),
    state,
  )

let config = (~apiBaseUrl="http://localhost:4000"): Connection.config => {
  acp: ACP.makeConfig(
    ~endpoint="ws://test",
    ~loginUrl=`${apiBaseUrl}/users/log-in`,
    ~getAuthToken=() => None,
    ~name="test",
    ~version="1",
    ~_meta=JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("test"))])),
  ),
  relay: Connection.Relay.makeConfig(~baseUrl="http://test"),
  mcp: Connection.MCPServer.makeConfig(),
}
let connection: ACP.connection = Obj.magic({
  "state": ref({
    ...FrontmanAiFrontmanClient.FrontmanClient__ACP__Client.initialState,
    acpState: Initialized(Obj.magic({"protocolVersion": 1})),
  }),
  "dispose": () => (),
})
let session = (sessionId): ACP.session => {
  sessionId,
  connection,
  channel: Obj.magic({"off": _ => (), "leave": () => ()}),
  onUpdate: (_, _) => (),
}
let modelConfig = (~models=["test:model"]): array<Connection.ACPTypes.sessionConfigOption> =>
  switch models->Array.get(0) {
  | None => []
  | Some(value) => [
      SelectConfigOption({
        id: "model",
        name: "Model",
        description: None,
        category: Some(Model),
        currentValue: value,
        options: Ungrouped(
          models->Array.map(value => {
            Connection.ACPTypes.value,
            name: value,
            description: None,
            _meta: None,
          }),
        ),
        _meta: None,
      }),
    ]
  }
let ready = (~sessionId=None, ~apiBaseUrl="http://localhost:4000"): option<
  Connection.state,
> => Some({
  config: config(~apiBaseUrl),
  connection: Ok(
    Some({
      lifetimeAbortController: WebAPI.AbortController.make(),
      phase: Ready({
        connection,
        relay: Obj.magic({"id": "relay"}),
        mcpServer: Obj.magic({"tools": []}),
        session: switch sessionId {
        | None => NoSession
        | Some(id) =>
          SessionActive({
            session: session(id),
            requestId: ref(),
            configOptions: modelConfig(),
            configPending: false,
            configError: None,
          })
        },
      }),
    }),
  ),
})

module Integration = {
  module App = Client__State__StateReducer
  module Types = Connection.ACPTypes
  type store = StateStore.t<App.state, App.action, App.effect>
  type native
  type frame = (Null.t<string>, Null.t<string>, string, string, JSON.t)
  let frameSchema = S.tuple(s => (
    s.item(0, S.null(S.string)),
    s.item(1, S.null(S.string)),
    s.item(2, S.string),
    s.item(3, S.string),
    s.item(4, S.json),
  ))
  @schema type request = {id: int, method: string, params: JSON.t}
  @schema type receipt = {status: string, response: JSON.t}
  @schema type error = {code: int, message: string}
  type wire = {
    mutable holdSessionNew: bool,
    reply: (frame, JSON.t, option<JSON.t>) => unit,
    emit: (string, JSON.t) => unit,
    lose: bool => unit,
  }
  @module("../../frontman-client/test/acpReconnectTransport.mjs")
  external makeWire: unit => wire = "makeTransport"
  @module("vitest") @scope("vi") external stub: (string, 'a) => unit = "stubGlobal"
  @get
  external native: FrontmanAiFrontmanClient.FrontmanClient__Phoenix__Socket.t => native = "conn"
  @get external send: native => string => unit = "send"
  @send external bind: (string => unit, native) => string => unit = "bind"
  @set external setSend: (native, string => unit) => unit = "send"
  type incoming = {data: string}
  @get external onmessage: native => incoming => unit = "onmessage"
  @set external runtime: (WebAPI.DomTypes.window, option<JSON.t>) => unit = "__frontmanRuntime"
  let a = "test:A"
  let b = "test:B"
  let options = model =>
    modelConfig(~models=model == a ? [a, b] : [b, a])->Array.map(option =>
      switch option {
      | Types.SelectConfigOption(config) =>
        let options = switch config.options {
        | Ungrouped(options) => options
        | Grouped(_) => failwith("Expected flat fixture")
        }
        Types.SelectConfigOption({
          ...config,
          options: Grouped([{group: "test", name: "test", options, _meta: None}]),
        })
      }
    )
  let payload = ((_, _, _, _, payload): frame) => payload
  let request = frame => S.parseOrThrow(payload(frame), ~to=requestSchema)
  let sessionId = frame =>
    S.parseOrThrow(request(frame).params, ~to=Types.deleteSessionParamsSchema).sessionId
  let start = async () => {
    let window = WebAPI.Window.current
    let wire = makeWire()
    stub("window", window)
    runtime(window, Some(JSON.parseOrThrow(`{"framework":"nextjs"}`)))
    wire.holdSessionNew = true
    let frames: array<frame> = []
    let store: ref<option<store>> = ref(None)
    let lifetime = WebAPI.AbortController.make()
    let emit = (socket, frame) =>
      (socket->onmessage)({data: S.decodeOrThrow(frame, ~from=frameSchema, ~to=S.jsonString)})
    let dispatch = action => store.contents->Option.getOrThrow->StateStore.dispatch(action)
    let conn = ref(None)
    let config = config()
    let pending = ACP.connect(
      {
        ...config.acp,
        getAuthToken: () => Some("integration"),
        onConfigOptionsUpdated: Some(
          configOptions => dispatch(CatalogReceived({signal: lifetime.signal, configOptions})),
        ),
      },
      ~signal=lifetime.signal,
      ~onConnectionCreated=created => conn := Some(created),
      ~onReconnecting=() => dispatch(ConnectionAction(ACPReconnecting({signal: lifetime.signal}))),
      ~onReconnect=result =>
        dispatch(
          ConnectionAction(
            ACPReconnected({signal: lifetime.signal, result: Ok(result->Result.getOrThrow)}),
          ),
        ),
    )
    let socket = native(conn.contents->Option.getOrThrow->(conn => conn.ACP.socket))
    let original = bind(send(socket), socket)
    setSend(socket, data => {
      let frame = S.decodeOrThrow(data, ~from=S.jsonString, ~to=frameSchema)
      frames->Array.push(frame)
      original(data)
      switch frame {
      | (join, ref, topic, "list_sessions", _) =>
        let response = S.decodeOrThrow(
          {Types.sessions: []},
          ~from=Types.listSessionsResultSchema,
          ~to=S.json,
        )
        emit(
          socket,
          (
            join,
            ref,
            topic,
            "phx_reply",
            S.decodeOrThrow({status: "ok", response}, ~from=receiptSchema, ~to=S.json),
          ),
        )
      | _ => ()
      }
    })
    let connection = (await pending)->Result.getOrThrow
    let relay: Connection.Relay.connected = {
      config: config.relay,
      tools: [],
      serverInfo: {name: "fixture", version: "1"},
      signal: lifetime.signal,
    }
    let state: App.state = {
      ...App.defaultState,
      draftModelPreference: Some(b),
      selectedAgentId: Some("agent-1"),
      connection: Some({
        config,
        connection: Ok(
          Some({
            lifetimeAbortController: lifetime,
            phase: Ready({
              connection,
              relay,
              mcpServer: Connection.MCPServer.make(config.mcp, ~relay),
              session: NoSession,
            }),
          }),
        ),
      }),
    }
    let instance = makeStore(state, App.handleEffect)
    store := Some(instance)
    wire.emit(
      "config_options_updated",
      S.decodeOrThrow(
        {Types.configOptions: options(a)},
        ~from=Types.configOptionsUpdatedSchema,
        ~to=S.json,
      ),
    )
    let matches = method =>
      frames->Array.filter(frame =>
        switch frame {
        | (_, _, _, "acp:message", _) => request(frame).method == method
        | _ => false
        }
      )
    let last = method => {
      let matches = matches(method)
      matches->Array.get(matches->Array.length - 1)->Option.getOrThrow
    }
    let reply = (frame, json) => wire.reply(frame, json, None)
    let reject = frame =>
      wire.reply(
        frame,
        JSON.Encode.null,
        Some(
          S.decodeOrThrow({code: -32602, message: "Unknown model"}, ~from=errorSchema, ~to=S.json),
        ),
      )
    let created = (frame, model) =>
      reply(
        frame,
        S.decodeOrThrow(
          {
            Types.sessionId: sessionId(frame),
            configOptions: Some(options(model)),
            modes: None,
            _meta: None,
          },
          ~from=Types.sessionNewResultSchema,
          ~to=S.json,
        ),
      )
    let configured = (frame, model) =>
      reply(
        frame,
        S.decodeOrThrow(
          {Types.configOptions: options(model)},
          ~from=Types.configOptionsUpdatedSchema,
          ~to=S.json,
        ),
      )
    let notify = (frame, update) => {
      let (join, _, topic, _, _) = frame
      let notification: Types.sessionUpdateNotification = {
        jsonrpc: "2.0",
        method: "session/update",
        params: {sessionId: sessionId(frame), update},
      }
      emit(
        socket,
        (
          join,
          Null.null,
          topic,
          "acp:message",
          S.decodeOrThrow(notification, ~from=Types.sessionUpdateNotificationSchema, ~to=S.json),
        ),
      )
    }
    let loaded = (frame, model) =>
      reply(
        frame,
        S.decodeOrThrow(
          {Types.configOptions: Some(options(model)), modes: None, _meta: None},
          ~from=Types.sessionLoadResultSchema,
          ~to=S.json,
        ),
      )
    (instance, wire, matches, last, created, configured, reject, notify, loaded)
  }
}
