open Vitest

afterEach(() => {
  Vi.useRealTimers()->ignore
})

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
    let ref = 0;
    const events = [];
    const inertPush = { receive() { return this; } };
    const channel = {
      state: "joined",
      on(event, callback) { (handlers[event] ||= new Map()).set(++ref, callback); return ref; },
      off(event, ref) {
        if (ref !== undefined) { handlers[event]?.delete(ref); return; }
        events.push("off:" + event);
        delete handlers[event];
      },
      leave() {
        events.push("leave");
        this.state = "closed";
        handlers.phx_close?.forEach(callback => callback("leave"));
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
          const handler = payload => handlers["acp:message"]?.forEach(callback => callback(payload));
          for (const notification of history) handler(notification);
          if (this.state === "closed") return inertPush;
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
      emit(payload) { handlers["acp:message"].forEach(callback => callback(payload)); }
    };
  }
`)

let loadConnectionWithTransport = (history, result): (ACP.connection, mockTransport) => {
  let transport = makeLoadTransport(history, result)
  let clientConfig: Client.config = {
    clientInfo: {name: "test", version: "1", title: None, _meta: None},
    clientCapabilities: {fs: None, terminal: None, elicitation: None, _meta: None},
  }
  let connection: ACP.connection = {
    socket: transport.socket,
    channel: transport.channel,
    clientConfig,
    state: ref(Client.initialState),
  }
  (connection, transport)
}

let loadConnection = (history, result): ACP.connection => {
  let (connection, _) = loadConnectionWithTransport(history, result)
  connection
}

let attributionConfiguration = (~id="agent-1") =>
  JSON.parseOrThrow(
    `{"agentAttribution":{"version":1},"agents":[{"id":"${id}","name":"executor","displayName":"Executor","description":"Executes work","color":"#985DF7"}],"defaultAgentId":"${id}"}`,
  )->S.parseOrThrow(~to=Types.agentAttributionConfigurationMetadataSchema)

let negotiateV1 = (connection: ACP.connection, ~id="agent-1"): ACP.connection => {
  ...connection,
  state: ref({
    ...Client.initialState,
    agentAttributionConfiguration: Some(attributionConfiguration(~id)),
  }),
}

let userUpdate = (
  messageId,
  ~sessionId="task-1",
  ~agentId="agent-1",
  ~timestamp="2026-07-14T12:30:01Z",
) =>
  JSON.parseOrThrow(
    `{
    "jsonrpc":"2.0",
    "method":"session/update",
    "params":{
      "sessionId":"${sessionId}",
      "update":{
        "sessionUpdate":"user_message_chunk",
        "messageId":"${messageId}",
        "content":{"type":"text","text":"history"},
        "_meta":{
          "frontman.dev/agentId":"${agentId}",
          "frontman.dev/timestamp":"${timestamp}"
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

let loadResult = JSON.parseOrThrow(`{}`)

let loadCleanupEvents = [
  "load-response",
  "off:acp:message",
  "off:mcp:message",
  "off:title_updated",
  "off:config_options_updated",
  "off:billing_status_updated",
  "leave",
]

let loadSession = (connection, ~onLoadResult, ~onUpdate, ~onParseError=?) =>
  ACP.loadSession(
    connection,
    "task-1",
    ~onLoadResult,
    ~onUpdate,
    ~onTitleUpdated=(_, _) => (),
    ~onParseError?,
  )

let loadWithoutDelivery = async connection => {
  let events = ref([])
  let result = await loadSession(
    connection,
    ~onLoadResult=_ => events := events.contents->Array.concat(["load"]),
    ~onUpdate=(_, _) => events := events.contents->Array.concat(["update"]),
  )
  (result, events.contents)
}

describe("ACP Client State Reducer", _t => {
  test("initialState has correct defaults", t => {
    let state = Client.initialState

    t->expect(state.currentId)->Expect.toEqual(0)
    t->expect(state.acpState)->Expect.toEqual(Client.Disconnected)
    t->expect(state.agentAttributionConfiguration)->Expect.toEqual(None)
    t->expect(state.pendingRequests->Dict.keysToArray->Array.length)->Expect.toEqual(0)
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
    t->expect(newState.agentAttributionConfiguration)->Expect.toEqual(None)
  })

  test("ACPStateChanged records negotiated agent attribution configuration", t => {
    let initResult: Types.initializeResult = {
      protocolVersion: 1,
      agentCapabilities: Some({
        loadSession: None,
        mcpCapabilities: None,
        promptCapabilities: None,
        _meta: Some(
          JSON.parseOrThrow(`{"frontman.dev":{"agentAttribution":{"version":1},"agents":[{"id":"agent-1","name":"executor","displayName":"Executor","description":"Executes work","color":"#985DF7"}],"defaultAgentId":"agent-1"}}`),
        ),
      }),
      agentInfo: None,
      authMethods: None,
    }

    let newState =
      Client.initialState->Client.reduce(Client.ACPStateChanged(Client.Initialized(initResult)))

    t
    ->expect(newState.agentAttributionConfiguration)
    ->Expect.toEqual(Some(attributionConfiguration()))
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
    let metadata = JSON.parseOrThrow(`{
      "other.vendor":{"enabled":true},
      "frontman.dev":{"futureFeature":{"version":3}}
    }`)

    let config: Client.config = {
      clientInfo: {name: "test-client", version: "1.0.0", title: None, _meta: None},
      clientCapabilities: {
        fs: Some({readTextFile: Some(true), writeTextFile: Some(false)}),
        terminal: Some(true),
        elicitation: None,
        _meta: Some(Obj.magic(metadata)),
      },
    }

    let json = Client.buildInitializeParams(config)
    t
    ->expect(json)
    ->Expect.toEqual(
      JSON.parseOrThrow(`{
        "protocolVersion":1,
        "clientCapabilities":{
          "fs":{"readTextFile":true,"writeTextFile":false},
          "terminal":true,
          "_meta":{
            "other.vendor":{"enabled":true},
            "frontman.dev":{
              "futureFeature":{"version":3},
              "agentAttribution":{"version":1}
            }
          }
        },
        "clientInfo":{"name":"test-client","version":"1.0.0"}
      }`),
    )
  })
})

describe("ACP Client parseInitializeResult", _t => {
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

  test("records no extension for absent or unsupported advertisements", t => {
    [
      `{"protocolVersion":1}`,
      `{"protocolVersion":1,"agentCapabilities":{"_meta":{"frontman.dev":{"agentAttribution":{"version":2}}}}}`,
    ]->Array.forEach(
      json =>
        switch Client.parseInitializeResult(JSON.parseOrThrow(json)) {
        | Ok(parsed) =>
          t->expect(Client.parseAgentAttributionConfiguration(parsed))->Expect.toEqual(Ok(None))
        | Error(_) => failwith("Expected unnegotiated metadata to remain generic")
        },
    )
  })

  test("rejects recognized v1 with missing or malformed configuration", t => {
    [
      `{"protocolVersion":1,"agentCapabilities":{"_meta":{"frontman.dev":{"agentAttribution":{"version":1}}}}}`,
      `{"protocolVersion":1,"agentCapabilities":{"_meta":{"frontman.dev":{"agentAttribution":"invalid"}}}}`,
      `{"protocolVersion":1,"agentCapabilities":{"_meta":{"frontman.dev":{"agentAttribution":{"version":1},"agents":[],"defaultAgentId":"agent-1"}}}}`,
    ]->Array.forEach(
      json =>
        t
        ->expect(Client.parseInitializeResult(JSON.parseOrThrow(json))->Result.isError)
        ->Expect.toBe(true),
    )
  })

  test("keeps configurations isolated between connections", t => {
    let first = loadConnection([], loadResult)->negotiateV1(~id="agent-1")
    let second = loadConnection([], loadResult)->negotiateV1(~id="agent-2")

    t
    ->expect(first.state.contents.agentAttributionConfiguration->Option.map(c => c.defaultAgentId))
    ->Expect.toEqual(Some("agent-1"))
    t
    ->expect(second.state.contents.agentAttributionConfiguration->Option.map(c => c.defaultAgentId))
    ->Expect.toEqual(Some("agent-2"))
  })

  test("does not mislabel unrelated initialize validation errors", t => {
    let json = JSON.parseOrThrow(`{
      "protocolVersion":1,
      "agentCapabilities":{
        "loadSession":"invalid",
        "_meta":{"frontman.dev":{"agentAttribution":{"version":1}}}
      }
    }`)

    t->expect(Client.parseInitializeResult(json)->Result.isError)->Expect.toBe(true)
  })
})

@send external trigger: (Channel.t, string, JSON.t, ~ref: string=?) => unit = "trigger"
type pushRef = {ref: string}
@get external joinPush: Channel.t => pushRef = "joinPush"
@get external pushBuffer: Channel.t => array<pushRef> = "pushBuffer"
@get external pushPayload: pushRef => unit => JSON.t = "payload"
@send external socketClosed: (Socket.t, JSON.t) => unit = "onConnClose"

let joinedChannel = async (socket, ~onError, ~topic="task:test") => {
  let channel = socket->Socket.channel(~topic)
  let joined = ACP.joinChannel(channel, ~onError)
  trigger(
    channel,
    "phx_reply",
    JSON.parseOrThrow(`{"status":"ok","response":{}}`),
    ~ref=joinPush(channel).ref,
  )
  (await joined)->Result.getOrThrow
  channel
}

let request = (channel, state) =>
  Protocol.sendRequest(
    ~channel,
    ~state,
    ~method=#"session/prompt",
    ~params=None,
    ~timeoutMs=10,
    ~parseResult=json => Ok(json),
  )

let reply = (channel, response) =>
  trigger(
    channel,
    "phx_reply",
    response,
    ~ref=(pushBuffer(channel)->Array.get(0)->Option.getOrThrow).ref,
  )

let acceptedReply = JSON.parseOrThrow(`{"status":"ok","response":{"acp:message":{"jsonrpc":"2.0","id":1,"result":"accepted"}}}`)

describe("ACP request and channel lifetime", _t => {
  [
    (#initialize, "initialize"),
    (#"session/new", "session/new"),
    (#"session/load", "session/load"),
    (#"session/prompt", "session/prompt"),
  ]->Array.forEach(((method, wireMethod)) => {
    testAsync(
      `serializes ${wireMethod} and clears its request timer`,
      async t => {
        Vi.useFakeTimers()->ignore
        let socket = Socket.make(~endpoint="ws://localhost/socket")
        let channel = await joinedChannel(socket, ~onError=_ => ())
        let state = ref(Client.initialState)
        let pending = Protocol.sendRequest(
          ~channel,
          ~state,
          ~method,
          ~params=None,
          ~parseResult=json => Ok(json),
        )
        let push = pushBuffer(channel)->Array.get(0)->Option.getOrThrow
        let sentMethod = S.parseOrThrow(
          pushPayload(push)(),
          ~to=S.object(s => s.field("method", S.string)),
        )
        t->expect(sentMethod)->Expect.toEqual(wireMethod)
        reply(channel, acceptedReply)
        t->expect(await pending)->Expect.toEqual(Ok(JSON.Encode.string("accepted")))
        t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
        t->expect(Vi.getTimerCount())->Expect.toBe(0)
        ACP.cleanupChannel(channel)
      },
    )
  })

  testAsync("preserves billing error codes through response settlement", async t => {
    Vi.useFakeTimers()->ignore
    let socket = Socket.make(~endpoint="ws://localhost/socket")
    let channel = await joinedChannel(socket, ~onError=_ => ())
    let state = ref(Client.initialState)
    let pending = request(channel, state)
    let message =
      JsonRpc.Response.makeError(
        ~id=JsonRpc.Id.fromInt(1),
        ~error=JsonRpc.RpcError.make(
          ~code=JsonRpc.ErrorCode.billingInactive,
          ~message="Alternate billing copy",
          ~data=None,
        ),
      )->JsonRpc.Response.toJson
    Protocol.handleIncomingMessage(~state, ~onUpdate=None, ~onParseError=None, message)
    t
    ->expect(await pending)
    ->Expect.toEqual(
      Error(
        Client.requestErrorWithCode(
          ~code=JsonRpc.ErrorCode.billingInactive,
          ~message="Alternate billing copy",
        ),
      ),
    )
    t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
    ACP.cleanupChannel(channel)
  })

  testAsync("billing status callback is detached during connection cleanup", async t => {
    Vi.useFakeTimers()->ignore
    let socket = Socket.make(~endpoint="ws://localhost/socket")
    let channel = await joinedChannel(socket, ~onError=_ => ())
    let received = ref(None)
    ACP.attachBillingStatusHandler(
      ~channel,
      ~onBillingStatusUpdated=Some(payload => received := Some(payload)),
    )
    let payload = JSON.parseOrThrow(`{"status":"none"}`)
    trigger(channel, "billing_status_updated", payload)
    t->expect(received.contents)->Expect.toEqual(Some(payload))
    ACP.cleanupConnection(socket, ref(Client.initialState))
    received := None
    trigger(channel, "billing_status_updated", payload)
    t->expect(received.contents)->Expect.toEqual(None)
  })

  testAsync("response settlement preserves requests created by the result handler", async t => {
    Vi.useFakeTimers()->ignore
    let socket = Socket.make(~endpoint="ws://localhost/socket")
    let channel = await joinedChannel(socket, ~onError=_ => ())
    let state = ref(Client.initialState)
    let followup = ref(None)
    let pending = Protocol.sendRequest(
      ~channel,
      ~state,
      ~method=#initialize,
      ~params=None,
      ~parseResult=json => {
        followup := Some(request(channel, state))
        Ok(json)
      },
    )
    reply(channel, acceptedReply)
    t->expect(await pending)->Expect.toEqual(Ok(JSON.Encode.string("accepted")))
    t->expect(state.contents.currentId)->Expect.toBe(2)
    t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual(["2"])
    ACP.cleanupConnection(socket, state)
    t
    ->expect(await followup.contents->Option.getOrThrow)
    ->Expect.toEqual(Error(Client.requestErrorFromMessage(Protocol.connectionLost)))
    t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
  })

  [#socketLoss, #timeout]->Array.forEach(failure =>
    testAsync(
      `joining without a socket settles on ${failure->String.make}`,
      async t => {
        Vi.useFakeTimers()->ignore
        let socket = Socket.make(~endpoint="ws://localhost/socket", ~opts={timeout: 10})
        let channel = socket->Socket.channel(~topic="tasks")
        let joined = ACP.joinChannel(channel, ~onError=_ => ACP.cleanupChannel(channel))
        switch failure {
        | #socketLoss => socketClosed(socket, JSON.parseOrThrow(`{"code":1000}`))
        | #timeout => (await Vi.advanceTimersByTimeAsync(10))->ignore
        }
        t->expect((await joined)->Result.isError)->Expect.toBe(true)
        ACP.cleanupChannel(channel)
      },
    )
  )

  [
    ("success", Some(acceptedReply), Ok(JSON.Encode.string("accepted"))),
    (
      "push error",
      Some(JSON.parseOrThrow(`{"status":"error","response":{}}`)),
      Error(Client.requestErrorFromMessage("ACP request failed")),
    ),
    (
      "RPC error",
      Some(
        JSON.parseOrThrow(`{"status":"ok","response":{"acp:message":{"jsonrpc":"2.0","id":1,"error":{"code":-32600,"message":"Invalid request"}}}}`),
      ),
      Error(Client.requestErrorWithCode(~code=-32600, ~message="Invalid request")),
    ),
    (
      "null result",
      Some(
        JSON.parseOrThrow(`{"status":"ok","response":{"acp:message":{"jsonrpc":"2.0","id":1,"result":null}}}`),
      ),
      Ok(JSON.Encode.null),
    ),
    (
      "timeout",
      None,
      Error(Client.requestErrorFromMessage("Request session/prompt timed out after 10ms")),
    ),
  ]->Array.forEach(((name, response, expected)) =>
    testAsync(
      `settles request on ${name}`,
      async t => {
        Vi.useFakeTimers()->ignore
        let socket = Socket.make(~endpoint="ws://localhost/socket")
        let channel = await joinedChannel(socket, ~onError=_ => ())
        let state = ref(Client.initialState)
        let pending = request(channel, state)
        switch response {
        | Some(response) => reply(channel, response)
        | None => (await Vi.advanceTimersByTimeAsync(10))->ignore
        }
        t->expect(await pending)->Expect.toEqual(expected)
        t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
        ACP.cleanupChannel(channel)
      },
    )
  )

  testAsync("rejects malformed push envelopes immediately", async t => {
    Vi.useFakeTimers()->ignore
    let socket = Socket.make(~endpoint="ws://localhost/socket")
    let channel = await joinedChannel(socket, ~onError=_ => ())
    let state = ref(Client.initialState)
    let pending = request(channel, state)
    reply(channel, JSON.parseOrThrow(`{"status":"ok","response":{}}`))
    t->expect((await pending)->Result.isError)->Expect.toBe(true)
    t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
    ACP.cleanupChannel(channel)
  })

  [#channelError, #channelClose, #socketLoss]->Array.forEach(failure => {
    testAsync(
      `reports idle ${failure->String.make} but not intentional cleanup`,
      async t => {
        Vi.useFakeTimers()->ignore
        let socket = Socket.make(~endpoint="ws://localhost/socket")
        let errors = ref([])
        let onError = error => errors := errors.contents->Array.concat([error])
        ACP.cleanupChannel(await joinedChannel(socket, ~onError))
        t->expect(errors.contents)->Expect.toEqual([])
        let channel = await joinedChannel(socket, ~onError)
        switch failure {
        | #channelError => trigger(channel, "phx_error", JSON.Encode.null)
        | #channelClose => trigger(channel, "phx_close", JSON.Encode.null)
        | #socketLoss => socketClosed(socket, JSON.parseOrThrow(`{"code":1000}`))
        }
        t->expect(errors.contents)->Expect.toEqual([Protocol.connectionLost])
        ACP.cleanupChannel(channel)
      },
    )

    testAsync(
      `settles affected requests on ${failure->String.make}`,
      async t => {
        Vi.useFakeTimers()->ignore
        let socket = Socket.make(~endpoint="ws://localhost/socket")
        let errors = ref([])
        let channel = await joinedChannel(
          socket,
          ~onError=error => errors := errors.contents->Array.concat([error]),
        )
        let state = ref(Client.initialState)
        let accepted = request(channel, state)
        reply(channel, acceptedReply)
        t->expect(await accepted)->Expect.toEqual(Ok(JSON.Encode.string("accepted")))
        let pending = request(channel, state)
        let other = await joinedChannel(socket, ~onError=_ => (), ~topic="task:other")
        let otherPending = request(other, state)
        t->expect(state.contents.currentId)->Expect.toBe(3)
        t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual(["2", "3"])
        switch failure {
        | #channelError => trigger(channel, "phx_error", JSON.Encode.null)
        | #channelClose => trigger(channel, "phx_close", JSON.Encode.null)
        | #socketLoss => socketClosed(socket, JSON.parseOrThrow(`{"code":1000}`))
        }
        t
        ->expect(await pending)
        ->Expect.toEqual(Error(Client.requestErrorFromMessage(Protocol.connectionLost)))
        t
        ->expect(await request(channel, state))
        ->Expect.toEqual(Error(Client.requestErrorFromMessage(Protocol.connectionLost)))
        t->expect(errors.contents)->Expect.toEqual([Protocol.connectionLost])
        switch failure {
        | #channelError | #channelClose =>
          t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual(["3"])
        | #socketLoss =>
          t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
        }
        ACP.cleanupConnection(socket, state)
        t
        ->expect(await otherPending)
        ->Expect.toEqual(Error(Client.requestErrorFromMessage(Protocol.connectionLost)))
        t->expect(socket->Socket.channels->Array.length)->Expect.toBe(0)
        t->expect(errors.contents)->Expect.toEqual([Protocol.connectionLost])
        (await Vi.advanceTimersByTimeAsync(20))->ignore
        t->expect(state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
      },
    )
  })
})

describe("ACP Client handleResponse", _t => {
  test("unknown agent_turn_complete notification is ignored without resolving prompt", t => {
    let resolved = ref(None)
    let parseError = ref(None)
    let updateReceived = ref(false)
    let pending: Client.pendingRequest = {
      resolve: json => resolved := json->JSON.Decode.object,
      reject: _ => (),
    }
    let state = ref(Client.initialState->Client.reduce(Client.RequestSent(1, pending)))

    let payload = JSON.parseOrThrow(`{
      "jsonrpc":"2.0", "method":"session/update",
      "params":{"sessionId":"task-1","update":{"sessionUpdate":"agent_turn_complete","stopReason":"end_turn"}}
    }`)

    Protocol.handleIncomingMessage(
      ~state,
      ~onUpdate=Some(
        (_sessionId, update) =>
          switch update {
          | Unknown({sessionUpdate: "agent_turn_complete"}) => updateReceived := true
          | _ => ()
          },
      ),
      ~onParseError=Some(error => parseError := Some(error)),
      payload,
    )

    t->expect(parseError.contents)->Expect.toEqual(None)
    t->expect(updateReceived.contents)->Expect.toEqual(true)
    t->expect(resolved.contents)->Expect.toEqual(None)
    t->expect(state.contents.pendingRequests->Dict.get("1")->Option.isSome)->Expect.toEqual(true)
  })
})

describe("ACP session/load ordering", () => {
  testAsync("validates replay with connection configuration before delivery", async t => {
    let events = ref([])
    let connection =
      loadConnection([userUpdate("user-1"), userUpdate("user-2")], loadResult)->negotiateV1

    let result = await loadSession(
      connection,
      ~onLoadResult=_ => events := events.contents->Array.concat(["load"]),
      ~onUpdate=(_, update) =>
        switch update {
        | UserMessageChunk({messageId}) =>
          events := events.contents->Array.concat([`update:${messageId}`])
        | _ => ()
        },
    )

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t->expect(events.contents)->Expect.toEqual(["load", "update:user-1", "update:user-2"])
  })

  testAsync("generic load without extension metadata still releases replay", async t => {
    let events = ref([])
    let connection = loadConnection(
      [genericUserUpdate],
      JSON.parseOrThrow(`{"_meta":{"frontman.dev/agents":"future-catalog"}}`),
    )

    let result = await loadSession(
      connection,
      ~onLoadResult=result => {
        t->expect(result._meta->Option.isSome)->Expect.toBe(true)
        events := events.contents->Array.concat(["load"])
      },
      ~onUpdate=(_, update) =>
        switch update {
        | GenericUserMessageChunk({messageId: None}) =>
          events := events.contents->Array.concat(["generic-update"])
        | _ => ()
        },
    )

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t->expect(events.contents)->Expect.toEqual(["load", "generic-update"])
  })

  testAsync("rejects invalid replay before delivery", async t => {
    let malformedUpdate = JSON.parseOrThrow(`{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"task-1","update":{"sessionUpdate":"user_message_chunk","content":{"type":"text","text":"history"},"_meta":{"frontman.dev/agentId":"agent-1","frontman.dev/timestamp":"2026-07-14T12:30:01Z"}}}}`)
    let (connection, transport) = loadConnectionWithTransport([malformedUpdate], loadResult)
    let connection = connection->negotiateV1
    let (result, events) = await loadWithoutDelivery(connection)
    t->expect(result->Result.isError)->Expect.toBe(true)
    t->expect(result == Error(Protocol.connectionLost))->Expect.toBe(false)
    t->expect(events)->Expect.toEqual([])
    t
    ->expect(transport.events)
    ->Expect.toEqual(loadCleanupEvents->Array.filter(event => event != "load-response"))
    t->expect(connection.state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])

    let (result, events) = await loadWithoutDelivery(
      loadConnection([userUpdate("user-1")], loadResult)->negotiateV1(~id="agent-2"),
    )
    t
    ->expect(result)
    ->Expect.toEqual(Error("Session update references unknown agent: agent-1"))
    t->expect(events)->Expect.toEqual([])

    let (result, events) = await loadWithoutDelivery(
      loadConnection([userUpdate("user-1", ~sessionId="task-2")], loadResult)->negotiateV1,
    )
    t->expect(result)->Expect.toEqual(Error("Session update task-2 received on task-1"))
    t->expect(events)->Expect.toEqual([])
  })

  testAsync("negotiated v1 closes a loaded session after a live update callback fails", async t => {
    let loaded = ref(false)
    let parseError = ref(None)
    let (connection, transport) = loadConnectionWithTransport([], loadResult)
    let connection = connection->negotiateV1

    let result = await loadSession(
      connection,
      ~onLoadResult=_ => loaded := true,
      ~onUpdate=(_, _) => failwith("unknown attributed agent"),
      ~onParseError=error => parseError := Some(error),
    )
    t->expect(loaded.contents)->Expect.toBe(true)
    transport.emit(userUpdate("user-1"))

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t->expect(parseError.contents)->Expect.toEqual(Some("unknown attributed agent"))
    t->expect(transport.events)->Expect.toEqual(loadCleanupEvents)
  })

  testAsync("negotiated v1 closes the session when buffered replay delivery fails", async t => {
    let parseError = ref(None)
    let (connection, transport) = loadConnectionWithTransport([userUpdate("user-1")], loadResult)
    let connection = connection->negotiateV1

    let result = await loadSession(
      connection,
      ~onLoadResult=_ => (),
      ~onUpdate=(_, _) => failwith("replay delivery failed"),
      ~onParseError=error => parseError := Some(error),
    )

    t->expect(result)->Expect.toEqual(Error("replay delivery failed"))
    t->expect(parseError.contents)->Expect.toEqual(Some("replay delivery failed"))
    t->expect(transport.events)->Expect.toEqual(loadCleanupEvents)
  })

  testAsync("rejects unknown live attribution before delivery", async t => {
    let events = ref([])
    let parseError = ref(None)
    let (connection, transport) = loadConnectionWithTransport([], loadResult)
    let connection = connection->negotiateV1

    let result = await loadSession(
      connection,
      ~onLoadResult=_ => events := events.contents->Array.concat(["load"]),
      ~onUpdate=(_, _) => events := events.contents->Array.concat(["update"]),
      ~onParseError=error => parseError := Some(error),
    )
    transport.emit(userUpdate("user-1", ~agentId="agent-2"))

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t
    ->expect(parseError.contents)
    ->Expect.toEqual(Some("Session update references unknown agent: agent-2"))
    t->expect(events.contents)->Expect.toEqual(["load"])
  })

  testAsync("rejects live message identity changes before delivery", async t => {
    let events = ref([])
    let parseError = ref(None)
    let (connection, transport) = loadConnectionWithTransport([userUpdate("user-1")], loadResult)
    let connection = connection->negotiateV1

    let result = await loadSession(
      connection,
      ~onLoadResult=_ => (),
      ~onUpdate=(_, _) => events := events.contents->Array.concat(["update"]),
      ~onParseError=error => parseError := Some(error),
    )
    transport.emit(userUpdate("user-1", ~timestamp="2026-07-14T12:30:02Z"))

    t->expect(result->Result.isOk)->Expect.toBe(true)
    t->expect(parseError.contents)->Expect.toEqual(Some("Message user-1 changed timestamps"))
    t->expect(events.contents)->Expect.toEqual(["update"])
  })
})
