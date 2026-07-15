open Vitest

module Client = FrontmanClient__ACP__Client
module ACP = FrontmanClient__ACP
module Protocol = FrontmanClient__ACP__Protocol
module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module Channel = FrontmanClient__Phoenix__Channel
module Socket = FrontmanClient__Phoenix__Socket

type mockTransport = {
  socket: Socket.t,
  channel: Channel.t,
  events: array<string>,
  emit: JSON.t => unit,
}

let makeLoadTransport: (array<JSON.t>, JSON.t) => mockTransport = %raw(`
  function(history, loadResult) {
    const handlers = {};
    const events = [];
    const inertPush = { receive() { return this; } };
    const channel = {
      on(event, callback) { handlers[event] = callback; },
      off(event) {
        events.push("off:" + event);
        delete handlers[event];
      },
      leave() {
        events.push("leave");
        return inertPush;
      },
      join() {
        return {
          receive(status, callback) {
            if (status === "ok") callback({});
            return this;
          }
        };
      },
      push(event, payload) {
        if (event === "acp:message" && payload.method === "session/load") {
          const handler = handlers["acp:message"];
          for (const notification of history) handler(notification);
          events.push("load-response");
          handler({
            jsonrpc: "2.0",
            id: payload.id,
            result: loadResult
          });
        }
        return inertPush;
      }
    };
    return {
      socket: {channel() { return channel; }},
      channel,
      events,
      emit(payload) { handlers["acp:message"](payload); }
    };
  }
`)

let loadConnectionWithTransport = (history, result): (ACP.connection, mockTransport) => {
  let transport = makeLoadTransport(history, result)
  let clientConfig: Client.config = {
    channel: transport.channel,
    clientInfo: {name: "test", version: "1", title: None, _meta: None},
    clientCapabilities: {fs: None, terminal: None, elicitation: None, _meta: None},
  }
  let connection: ACP.connection = {
    socket: transport.socket,
    channel: transport.channel,
    clientConfig,
    state: ref(Client.initialState),
    onMessage: None,
  }
  (connection, transport)
}

let loadConnection = (history, result): ACP.connection => {
  let (connection, _) = loadConnectionWithTransport(history, result)
  connection
}

let negotiateV1 = (connection: ACP.connection): ACP.connection => {
  ...connection,
  state: ref({...Client.initialState, agentAttributionVersion: Some(Client.V1)}),
}

let userUpdate = messageId =>
  JSON.parseOrThrow(
    `{
    "jsonrpc":"2.0",
    "method":"session/update",
    "params":{
      "sessionId":"task-1",
      "update":{
        "sessionUpdate":"user_message_chunk",
        "messageId":"${messageId}",
        "content":{"type":"text","text":"history"},
        "_meta":{
          "frontman.dev/agentId":"agent-1",
          "frontman.dev/timestamp":"2026-07-14T12:30:01Z"
        }
      }
    }
  }`,
  )

let genericUserUpdate = JSON.parseOrThrow(`{
  "jsonrpc":"2.0",
  "method":"session/update",
  "params":{
    "sessionId":"task-1",
    "update":{
      "sessionUpdate":"user_message_chunk",
      "content":{"type":"text","text":"history"}
    }
  }
}`)

describe("ACP Client State Reducer", _t => {
  test("initialState has correct defaults", t => {
    let state = Client.initialState

    t->expect(state.currentId)->Expect.toEqual(0)
    t->expect(state.acpState)->Expect.toEqual(Client.Disconnected)
    t->expect(Client.getAgentAttributionVersion(state))->Expect.toEqual(None)
    t->expect(state.pendingRequests->Dict.keysToArray->Array.length)->Expect.toEqual(0)
  })

  test("RequestSent action updates currentId and pendingRequests", t => {
    let state = Client.initialState
    let pending: Client.pendingRequest = {
      method: "test",
      sessionId: None,
      resolve: _ => (),
      reject: _ => (),
    }

    let newState = state->Client.reduce(Client.RequestSent(1, pending))

    t->expect(newState.currentId)->Expect.toEqual(1)
    t->expect(newState.pendingRequests->Dict.get("1")->Option.isSome)->Expect.toEqual(true)
  })

  test("ResponseReceived action removes from pendingRequests", t => {
    let pending: Client.pendingRequest = {
      method: "test",
      sessionId: None,
      resolve: _ => (),
      reject: _ => (),
    }

    let state =
      Client.initialState
      ->Client.reduce(Client.RequestSent(1, pending))
      ->Client.reduce(Client.ResponseReceived(1))

    t->expect(state.pendingRequests->Dict.get("1"))->Expect.toEqual(None)
  })

  test("ACPStateChanged action updates acpState", t => {
    let state = Client.initialState
    let initResult: Types.initializeResult = {
      protocolVersion: 1,
      agentCapabilities: None,
      agentInfo: Some({name: "test", version: "1.0", title: None, _meta: None}),
      authMethods: None,
    }

    let newState = state->Client.reduce(Client.ACPStateChanged(Client.Initialized(initResult)))

    t->expect(Client.isInitialized(newState))->Expect.toEqual(true)
    t->expect(Client.getAgentAttributionVersion(newState))->Expect.toEqual(None)
  })

  test("ACPStateChanged records negotiated agent attribution v1", t => {
    let initResult: Types.initializeResult = {
      protocolVersion: 1,
      agentCapabilities: Some({
        loadSession: None,
        mcpCapabilities: None,
        promptCapabilities: None,
        _meta: Some(Types.agentAttributionV1CapabilityMetadata),
      }),
      agentInfo: None,
      authMethods: None,
    }

    let newState =
      Client.initialState->Client.reduce(Client.ACPStateChanged(Client.Initialized(initResult)))

    t->expect(Client.getAgentAttributionVersion(newState))->Expect.toEqual(Some(Client.V1))
  })

  test("multiple RequestSent actions accumulate", t => {
    let pending1: Client.pendingRequest = {
      method: "one",
      sessionId: None,
      resolve: _ => (),
      reject: _ => (),
    }
    let pending2: Client.pendingRequest = {
      method: "two",
      sessionId: None,
      resolve: _ => (),
      reject: _ => (),
    }

    let state =
      Client.initialState
      ->Client.reduce(Client.RequestSent(1, pending1))
      ->Client.reduce(Client.RequestSent(2, pending2))

    t->expect(state.currentId)->Expect.toEqual(2)
    t->expect(state.pendingRequests->Dict.keysToArray->Array.length)->Expect.toEqual(2)
  })
})

describe("ACP Client Connection State", _t => {
  test("isInitialized returns false for Disconnected", t => {
    let state = {...Client.initialState, acpState: Client.Disconnected}
    t->expect(Client.isInitialized(state))->Expect.toEqual(false)
  })

  test("isInitialized returns false for Connecting", t => {
    let state = {...Client.initialState, acpState: Client.Connecting}
    t->expect(Client.isInitialized(state))->Expect.toEqual(false)
  })

  test("isInitialized returns true for Initialized", t => {
    let initResult: Types.initializeResult = {
      protocolVersion: 1,
      agentCapabilities: None,
      agentInfo: None,
      authMethods: None,
    }
    let state = {...Client.initialState, acpState: Client.Initialized(initResult)}
    t->expect(Client.isInitialized(state))->Expect.toEqual(true)
  })

  test("getACPState returns current state", t => {
    let state = {...Client.initialState, acpState: Client.Connecting}
    t->expect(Client.getACPState(state))->Expect.toEqual(Client.Connecting)
  })
})

describe("ACP Client buildInitializeParams", _t => {
  test("builds correct JSON structure", t => {
    let mockChannel = %raw(`{push: () => {}, on: () => {}}`)

    let config: Client.config = {
      channel: mockChannel,
      clientInfo: {name: "test-client", version: "1.0.0", title: None, _meta: None},
      clientCapabilities: {
        fs: Some({readTextFile: Some(true), writeTextFile: Some(false)}),
        terminal: Some(true),
        elicitation: None,
        _meta: None,
      },
    }

    let json = Client.buildInitializeParams(config)
    let obj = json->JSON.Decode.object->Option.getOrThrow

    t->expect(obj->Dict.get("protocolVersion"))->Expect.toEqual(Some(JSON.Encode.int(1)))

    let advertisedVersion =
      obj
      ->Dict.get("clientCapabilities")
      ->Option.flatMap(JSON.Decode.object)
      ->Option.flatMap(capabilities => capabilities->Dict.get("_meta"))
      ->Option.flatMap(JSON.Decode.object)
      ->Option.flatMap(
        metadata =>
          metadata->Dict.get(
            Types.ExtensionKey.make(Types.ExtensionKey.Namespace)->Types.ExtensionKey.toString,
          ),
      )
      ->Option.flatMap(JSON.Decode.object)
      ->Option.flatMap(frontman => frontman->Dict.get("agentAttribution"))
      ->Option.flatMap(JSON.Decode.object)
      ->Option.flatMap(attribution => attribution->Dict.get("version"))
      ->Option.flatMap(JSON.Decode.float)
      ->Option.map(Float.toInt)

    t->expect(advertisedVersion)->Expect.toEqual(Some(1))

    let clientInfoJson = obj->Dict.get("clientInfo")->Option.flatMap(JSON.Decode.object)
    t
    ->expect(clientInfoJson->Option.flatMap(c => c->Dict.get("name")))
    ->Expect.toEqual(Some(JSON.Encode.string("test-client")))
  })
})

describe("ACP Client parseInitializeResult", _t => {
  test("parses valid result", t => {
    let json = Dict.make()
    json->Dict.set("protocolVersion", JSON.Encode.int(1))

    let result = Client.parseInitializeResult(JSON.Encode.object(json))

    switch result {
    | Ok(parsed) => t->expect(parsed.protocolVersion)->Expect.toEqual(1)
    | Error(_) => failwith("Expected Ok result")
    }
  })

  test("returns error for invalid JSON", t => {
    let result = Client.parseInitializeResult(JSON.Encode.string("invalid"))

    t->expect(Result.isError(result))->Expect.toEqual(true)
  })

  test("rejects unsupported ACP protocol version", t => {
    let json = JSON.Encode.object(Dict.fromArray([("protocolVersion", JSON.Encode.int(2))]))

    t
    ->expect(Client.parseInitializeResult(json))
    ->Expect.toEqual(Error("Unsupported ACP protocol version: 2"))
  })

  test("records no extension when server advertisement is absent", t => {
    let json = JSON.Encode.object(Dict.fromArray([("protocolVersion", JSON.Encode.int(1))]))
    let result = Client.parseInitializeResult(json)

    switch result {
    | Ok(parsed) => t->expect(Client.negotiateAgentAttributionVersion(parsed))->Expect.toEqual(None)
    | Error(_) => failwith("Expected generic initialize result to parse")
    }
  })

  test("records no extension when server advertises unsupported version", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([
        ("protocolVersion", JSON.Encode.int(1)),
        (
          "agentCapabilities",
          JSON.Encode.object(
            Dict.fromArray([
              (
                "_meta",
                JSON.Encode.object(
                  Dict.fromArray([
                    (
                      "frontman.dev",
                      JSON.Encode.object(
                        Dict.fromArray([
                          (
                            "agentAttribution",
                            JSON.Encode.object(Dict.fromArray([("version", JSON.Encode.int(2))])),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    )
    let result = Client.parseInitializeResult(json)

    switch result {
    | Ok(parsed) => t->expect(Client.negotiateAgentAttributionVersion(parsed))->Expect.toEqual(None)
    | Error(_) => failwith("Expected unsupported extension version to parse")
    }
  })

  test("rejects malformed server agent attribution advertisement", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([
        ("protocolVersion", JSON.Encode.int(1)),
        (
          "agentCapabilities",
          JSON.Encode.object(
            Dict.fromArray([
              (
                "_meta",
                JSON.Encode.object(
                  Dict.fromArray([
                    (
                      "frontman.dev",
                      JSON.Encode.object(
                        Dict.fromArray([("agentAttribution", JSON.Encode.string("invalid"))]),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    )

    t->expect(Client.parseInitializeResult(json)->Result.isError)->Expect.toBe(true)
  })

  test("does not mislabel unrelated initialize validation errors", t => {
    let json = JSON.Encode.object(
      Dict.fromArray([
        ("protocolVersion", JSON.Encode.int(1)),
        (
          "agentCapabilities",
          JSON.Encode.object(
            Dict.fromArray([
              ("loadSession", JSON.Encode.string("invalid")),
              (
                "_meta",
                JSON.Encode.object(
                  Dict.fromArray([
                    (
                      "frontman.dev",
                      JSON.Encode.object(
                        Dict.fromArray([
                          (
                            "agentAttribution",
                            JSON.Encode.object(Dict.fromArray([("version", JSON.Encode.int(1))])),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    )

    t->expect(Client.parseInitializeResult(json)->Result.isError)->Expect.toBe(true)
  })
})

describe("ACP Client handleResponse", _t => {
  test("resolves pending request on success", t => {
    let resolved = ref(false)
    let pending: Client.pendingRequest = {
      method: "test",
      sessionId: None,
      resolve: _ => resolved := true,
      reject: _ => (),
    }

    let state = Client.initialState->Client.reduce(Client.RequestSent(1, pending))

    let responseJson = Dict.make()
    responseJson->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
    responseJson->Dict.set("id", JSON.Encode.int(1))
    responseJson->Dict.set("result", JSON.Encode.string("success"))

    Client.handleResponse(state, JSON.Encode.object(responseJson))->ignore

    t->expect(resolved.contents)->Expect.toEqual(true)
  })

  test("rejects pending request on error", t => {
    let rejected = ref(false)
    let pending: Client.pendingRequest = {
      method: "test",
      sessionId: None,
      resolve: _ => (),
      reject: _ => rejected := true,
    }

    let state = Client.initialState->Client.reduce(Client.RequestSent(2, pending))

    let errorObj = Dict.make()
    errorObj->Dict.set("code", JSON.Encode.int(-32600))
    errorObj->Dict.set("message", JSON.Encode.string("Invalid request"))

    let responseJson = Dict.make()
    responseJson->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
    responseJson->Dict.set("id", JSON.Encode.int(2))
    responseJson->Dict.set("error", JSON.Encode.object(errorObj))

    Client.handleResponse(state, JSON.Encode.object(responseJson))->ignore

    t->expect(rejected.contents)->Expect.toEqual(true)
  })

  test("removes request from pending after handling", t => {
    let pending: Client.pendingRequest = {
      method: "test",
      sessionId: None,
      resolve: _ => (),
      reject: _ => (),
    }

    let state = Client.initialState->Client.reduce(Client.RequestSent(3, pending))

    let responseJson = Dict.make()
    responseJson->Dict.set("jsonrpc", JSON.Encode.string("2.0"))
    responseJson->Dict.set("id", JSON.Encode.int(3))
    responseJson->Dict.set("result", JSON.Encode.null)

    let newState = Client.handleResponse(state, JSON.Encode.object(responseJson))

    t->expect(newState.pendingRequests->Dict.get("3"))->Expect.toEqual(None)
  })

  test("resolves pending request by method from notification", t => {
    let resolved = ref(None)
    let promptPending: Client.pendingRequest = {
      method: "session/prompt",
      sessionId: Some("task-1"),
      resolve: json => resolved := json->JSON.Decode.object,
      reject: _ => (),
    }
    let loadPending: Client.pendingRequest = {
      method: "session/load",
      sessionId: Some("task-1"),
      resolve: _ => (),
      reject: _ => (),
    }

    let state =
      Client.initialState
      ->Client.reduce(Client.RequestSent(1, promptPending))
      ->Client.reduce(Client.RequestSent(2, loadPending))

    let result = JSON.Encode.object(Dict.make())

    let newState =
      state->Client.resolvePendingSessionRequest(
        ~method="session/prompt",
        ~sessionId="task-1",
        ~result,
      )

    t->expect(resolved.contents->Option.isSome)->Expect.toEqual(true)
    t->expect(newState.pendingRequests->Dict.get("1"))->Expect.toEqual(None)
    t->expect(newState.pendingRequests->Dict.get("2")->Option.isSome)->Expect.toEqual(true)
  })

  test("does not resolve pending prompt for another session", t => {
    let resolved = ref(false)
    let pending: Client.pendingRequest = {
      method: "session/prompt",
      sessionId: Some("task-1"),
      resolve: _ => resolved := true,
      reject: _ => (),
    }
    let state = Client.initialState->Client.reduce(Client.RequestSent(1, pending))
    let result = JSON.Encode.object(Dict.make())

    let newState =
      state->Client.resolvePendingSessionRequest(
        ~method="session/prompt",
        ~sessionId="task-2",
        ~result,
      )

    t->expect(resolved.contents)->Expect.toEqual(false)
    t->expect(newState.pendingRequests->Dict.get("1")->Option.isSome)->Expect.toEqual(true)
  })

  test("unknown agent_turn_complete notification is ignored without resolving prompt", t => {
    let resolved = ref(None)
    let parseError = ref(None)
    let updateReceived = ref(false)
    let pending: Client.pendingRequest = {
      method: "session/prompt",
      sessionId: Some("task-1"),
      resolve: json => resolved := json->JSON.Decode.object,
      reject: _ => (),
    }
    let state = ref(Client.initialState->Client.reduce(Client.RequestSent(1, pending)))

    let payload = JSON.Encode.object(
      Dict.fromArray([
        ("jsonrpc", JSON.Encode.string("2.0")),
        ("method", JSON.Encode.string("session/update")),
        (
          "params",
          JSON.Encode.object(
            Dict.fromArray([
              ("sessionId", JSON.Encode.string("task-1")),
              (
                "update",
                JSON.Encode.object(
                  Dict.fromArray([
                    ("sessionUpdate", JSON.Encode.string("agent_turn_complete")),
                    ("stopReason", JSON.Encode.string("end_turn")),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    )

    Protocol.handleIncomingMessage(
      ~state,
      ~onUpdate=Some(
        (_sessionId, update) =>
          switch update {
          | Unknown({sessionUpdate: "agent_turn_complete"}) => updateReceived := true
          | _ => ()
          },
      ),
      ~onMessage=None,
      ~onParseError=Some(error => parseError := Some(error)),
      payload,
    )

    t->expect(parseError.contents)->Expect.toEqual(None)
    t->expect(updateReceived.contents)->Expect.toEqual(true)
    t->expect(resolved.contents)->Expect.toEqual(None)
    t->expect(state.contents.pendingRequests->Dict.get("1")->Option.isSome)->Expect.toEqual(true)
  })

  test("update callback exceptions are reported as parse failures", t => {
    let parseError = ref(None)
    let state = ref({...Client.initialState, agentAttributionVersion: Some(Client.V1)})

    Protocol.handleIncomingMessage(
      ~state,
      ~onUpdate=Some((_sessionId, _update) => failwith("unknown attributed agent")),
      ~onMessage=None,
      ~onParseError=Some(error => parseError := Some(error)),
      userUpdate("user-1"),
    )

    t->expect(parseError.contents)->Expect.toEqual(Some("unknown attributed agent"))
  })
})

describe("ACP session/load ordering", () => {
  test("session/new parser preserves catalog metadata", t => {
    let result = Client.parseSessionNewResult(
      JSON.parseOrThrow(`{
        "sessionId":"task-1",
        "_meta":{
          "frontman.dev/agents":[{
            "id":"agent-1",
            "name":"executor",
            "displayName":"Executor",
            "description":"Executes work",
            "color":"#985DF7"
          }]
        }
      }`),
    )

    switch result {
    | Ok({_meta: Some({agents: Some([agent])})}) => t->expect(agent.id)->Expect.toBe("agent-1")
    | _ => failwith("Expected session/new catalog metadata")
    }
  })

  testAsync("fresh load without history installs result without replay callbacks", async t => {
    let events = ref([])
    let connection = loadConnection([], JSON.parseOrThrow(`{}`))

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=_ => events := events.contents->Array.concat(["load"]),
      ~onUpdate=(_, _) => events := events.contents->Array.concat(["update"]),
      ~onTitleUpdated=(_, _) => (),
    )

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t->expect(events.contents)->Expect.toEqual(["load"])
  })

  testAsync("installs load metadata before delivering replay in wire order", async t => {
    let events = ref([])
    let loadResult = JSON.parseOrThrow(`{
      "_meta":{
        "frontman.dev/agents":[{
          "id":"agent-1",
          "name":"executor",
          "displayName":"Executor",
          "description":"Executes work",
          "color":"#985DF7"
        }]
      }
    }`)
    let connection =
      loadConnection([userUpdate("user-1"), userUpdate("user-2")], loadResult)->negotiateV1

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=_ => events := events.contents->Array.concat(["catalog"]),
      ~onUpdate=(_, update) =>
        switch update {
        | UserMessageChunk({messageId}) =>
          events := events.contents->Array.concat([`update:${messageId}`])
        | _ => ()
        },
      ~onTitleUpdated=(_, _) => (),
    )

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t->expect(events.contents)->Expect.toEqual(["catalog", "update:user-1", "update:user-2"])
  })

  testAsync("generic load without extension metadata still releases replay", async t => {
    let events = ref([])
    let connection = loadConnection([userUpdate("user-1")], JSON.parseOrThrow(`{}`))

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=result => {
        t->expect(result._meta)->Expect.toEqual(None)
        events := events.contents->Array.concat(["load"])
      },
      ~onUpdate=(_, _) => events := events.contents->Array.concat(["update"]),
      ~onTitleUpdated=(_, _) => (),
    )

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t->expect(events.contents)->Expect.toEqual(["load", "update"])
  })

  testAsync("unnegotiated load accepts a base ACP chunk without Frontman fields", async t => {
    let events = ref([])
    let connection = loadConnection([genericUserUpdate], JSON.parseOrThrow(`{}`))

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=_ => events := events.contents->Array.concat(["load"]),
      ~onUpdate=(_, update) =>
        switch update {
        | GenericUserMessageChunk({messageId: None}) =>
          events := events.contents->Array.concat(["generic-update"])
        | _ => ()
        },
      ~onTitleUpdated=(_, _) => (),
    )

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t->expect(events.contents)->Expect.toEqual(["load", "generic-update"])
  })

  testAsync("invalid load metadata discards buffered replay", async t => {
    let events = ref([])
    let invalidLoadResult = JSON.parseOrThrow(`{
      "_meta":{
        "frontman.dev/agents":[
          {
            "id":"agent-1",
            "name":"executor",
            "displayName":"Executor",
            "description":"Executes work",
            "color":"#985DF7"
          },
          {
            "id":"agent-1",
            "name":"planner",
            "displayName":"Planner",
            "description":"Plans work",
            "color":"#F59E0B"
          }
        ]
      }
    }`)
    let connection = loadConnection([userUpdate("user-1")], invalidLoadResult)

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=_ => events := events.contents->Array.concat(["load"]),
      ~onUpdate=(_, _) => events := events.contents->Array.concat(["update"]),
      ~onTitleUpdated=(_, _) => (),
    )

    t->expect(result->Result.isError)->Expect.toBe(true)
    t->expect(events.contents)->Expect.toEqual([])
  })

  testAsync("negotiated v1 rejects a load result without catalog metadata", async t => {
    let events = ref([])
    let connection = loadConnection([userUpdate("user-1")], JSON.parseOrThrow(`{}`))->negotiateV1

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=_ => events := events.contents->Array.concat(["load"]),
      ~onUpdate=(_, _) => events := events.contents->Array.concat(["update"]),
      ~onTitleUpdated=(_, _) => (),
    )

    t->expect(result)->Expect.toEqual(Error("session/load missing frontman.dev/agents metadata"))
    t->expect(events.contents)->Expect.toEqual([])
  })

  testAsync("negotiated v1 discards replay after a malformed history notification", async t => {
    let events = ref([])
    let malformedUpdate = JSON.parseOrThrow(`{
      "jsonrpc":"2.0",
      "method":"session/update",
      "params":{
        "sessionId":"task-1",
        "update":{
          "sessionUpdate":"user_message_chunk",
          "content":{"type":"text","text":"history"},
          "_meta":{
            "frontman.dev/agentId":"agent-1",
            "frontman.dev/timestamp":"2026-07-14T12:30:01Z"
          }
        }
      }
    }`)
    let loadResult = JSON.parseOrThrow(`{
      "_meta":{
        "frontman.dev/agents":[{
          "id":"agent-1",
          "name":"executor",
          "displayName":"Executor",
          "description":"Executes work",
          "color":"#985DF7"
        }]
      }
    }`)
    let (connection, transport) = loadConnectionWithTransport([malformedUpdate], loadResult)
    let connection = connection->negotiateV1

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=_ => events := events.contents->Array.concat(["load"]),
      ~onUpdate=(_, _) => events := events.contents->Array.concat(["update"]),
      ~onTitleUpdated=(_, _) => (),
    )

    t->expect(result->Result.isError)->Expect.toBe(true)
    t->expect(events.contents)->Expect.toEqual([])
    t
    ->expect(transport.events)
    ->Expect.toEqual([
      "load-response",
      "off:acp:message",
      "off:mcp:message",
      "off:title_updated",
      "leave",
    ])
  })

  testAsync("negotiated v1 closes a loaded session after a live update callback fails", async t => {
    let parseError = ref(None)
    let loadResult = JSON.parseOrThrow(`{
      "_meta":{
        "frontman.dev/agents":[{
          "id":"agent-1",
          "name":"executor",
          "displayName":"Executor",
          "description":"Executes work",
          "color":"#985DF7"
        }]
      }
    }`)
    let (connection, transport) = loadConnectionWithTransport([], loadResult)
    let connection = connection->negotiateV1

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=_ => (),
      ~onUpdate=(_, _) => failwith("unknown attributed agent"),
      ~onTitleUpdated=(_, _) => (),
      ~onParseError=error => parseError := Some(error),
    )
    transport.emit(userUpdate("user-1"))

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t->expect(parseError.contents)->Expect.toEqual(Some("unknown attributed agent"))
    t
    ->expect(transport.events)
    ->Expect.toEqual(["load-response", "off:acp:message", "leave"])
  })

  testAsync("negotiated v1 closes the session when buffered replay delivery fails", async t => {
    let parseError = ref(None)
    let loadResult = JSON.parseOrThrow(`{
      "_meta":{
        "frontman.dev/agents":[{
          "id":"agent-1",
          "name":"executor",
          "displayName":"Executor",
          "description":"Executes work",
          "color":"#985DF7"
        }]
      }
    }`)
    let (connection, transport) = loadConnectionWithTransport([userUpdate("user-1")], loadResult)
    let connection = connection->negotiateV1

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=_ => (),
      ~onUpdate=(_, _) => failwith("replay delivery failed"),
      ~onTitleUpdated=(_, _) => (),
      ~onParseError=error => parseError := Some(error),
    )

    t->expect(result)->Expect.toEqual(Error("replay delivery failed"))
    t->expect(parseError.contents)->Expect.toEqual(Some("replay delivery failed"))
    t
    ->expect(transport.events)
    ->Expect.toEqual([
      "load-response",
      "off:acp:message",
      "off:mcp:message",
      "off:title_updated",
      "leave",
    ])
  })

  testAsync("negotiated v1 rejects replay attribution absent from catalog", async t => {
    let events = ref([])
    let loadResult = JSON.parseOrThrow(`{
      "_meta":{
        "frontman.dev/agents":[{
          "id":"agent-2",
          "name":"planner",
          "displayName":"Planner",
          "description":"Plans work",
          "color":"#F59E0B"
        }]
      }
    }`)
    let connection = loadConnection([userUpdate("user-1")], loadResult)->negotiateV1

    let result = await ACP.loadSession(
      connection,
      "task-1",
      ~onLoadResult=_ => events := events.contents->Array.concat(["load"]),
      ~onUpdate=(_, _) => events := events.contents->Array.concat(["update"]),
      ~onTitleUpdated=(_, _) => (),
    )

    t
    ->expect(result)
    ->Expect.toEqual(Error("session/load replay references unknown agent: agent-1"))
    t->expect(events.contents)->Expect.toEqual([])
  })
})
