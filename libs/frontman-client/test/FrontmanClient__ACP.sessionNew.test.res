open Vitest

module ACP = FrontmanClient__ACP

type transport = {
  frames: array<JSON.t>,
  requests: array<JSON.t>,
}

@module("./acpReconnectTransport.mjs")
external makeTransport: unit => transport = "makeTransport"
@set external holdSessionNew: (transport, bool) => unit = "holdSessionNew"
@send external reply: (transport, JSON.t, JSON.t) => unit = "reply"
@send
external listenerCount: (transport, FrontmanClient__Phoenix__Channel.t, string) => int =
  "listenerCount"
@module("vitest") @scope("vi") external clearAllTimers: unit => unit = "clearAllTimers"
@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"
@module("vitest") external onTestFinished: (unit => unit) => unit = "onTestFinished"

afterEach(() => {
  clearAllTimers()
  Vi.useRealTimers()->ignore
  unstubAllGlobals()
})

let sessionId = "12345678-1234-1234-1234-123456789abc"
let connect = async () => {
  let wire = makeTransport()
  let connection = await ACP.connect(
    ACP.makeConfig(
      ~endpoint="ws://localhost/socket",
      ~loginUrl="https://localhost/login",
      ~getAuthToken=() => Some("test-token"),
      ~name="test",
      ~version="1",
      ~_meta=JSON.parseOrThrow(`{"framework":"wordpress"}`),
    ),
  )
  let connection = connection->Result.getOrThrow
  onTestFinished(() => ACP.disconnect(connection))
  (wire, connection)
}

let create = connection =>
  ACP.createSession(connection, ~sessionId, ~onUpdate=(_, _) => (), ~onTitleUpdated=(_, _) => ())

@send
external trigger: (FrontmanClient__Phoenix__Channel.t, string, JSON.t) => unit = "trigger"
@send external lose: (transport, bool) => unit = "lose"
@set external setJoinError: (transport, JSON.t) => unit = "joinError"

let mcpInterface: FrontmanClient__MCP__Types.serverInterface<unit> = {
  server: (),
  buildDiscoverResult: _ => failwith("Unexpected discovery"),
  buildToolsListResult: _ => failwith("Unexpected listing"),
  executeTool: async (_, _) => Suspended,
}

let listenRequest = JSON.parseOrThrow(`{
  "jsonrpc":"2.0","id":"stream","method":"subscriptions/listen",
  "params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}},"notifications":{}}
}`)

[#close, #disconnect, #parseError]->Array.forEach(outcome =>
  testAsync("session MCP teardown precedes leave and is idempotent", async t => {
    let (wire, connection) = await connect()
    let (session, _) =
      (
        await ACP.createSession(
          connection,
          ~sessionId,
          ~onUpdate=(_, _) => (),
          ~onTitleUpdated=(_, _) => (),
          ~onParseError=_ => (),
          ~mcpServerInterface=mcpInterface,
        )
      )->Result.getOrThrow
    trigger(session.channel, "mcp:message", listenRequest)
    switch outcome {
    | #close => ACP.cleanupSessionChannel(session)
    | #disconnect => ACP.disconnect(connection)
    | #parseError =>
      trigger(
        session.channel,
        "acp:message",
        JSON.parseOrThrow(`{"jsonrpc":"2.0","method":"session/update","params":{}}`),
      )
    }
    let sessionFrames = () =>
      wire.frames->Array.filter(
        frame =>
          frame->S.parseOrThrow(~to=S.array(S.json))->Array.at(2) ==
            Some(JSON.Encode.string(`task:${sessionId}`)),
      )
    let endings =
      sessionFrames()
      ->Array.slice(~start=2, ~end=5)
      ->Array.map(
        frame => frame->S.parseOrThrow(~to=S.array(S.json))->Array.slice(~start=3, ~end=5),
      )
    t
    ->expect(endings)
    ->Expect.toEqual([
      [
        JSON.Encode.string("mcp:message"),
        JSON.parseOrThrow(`{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":"stream","_meta":{"io.modelcontextprotocol/subscriptionId":"stream"}}}`),
      ],
      [
        JSON.Encode.string("mcp:message"),
        JSON.parseOrThrow(`{"jsonrpc":"2.0","id":"stream","result":{"resultType":"complete","_meta":{"io.modelcontextprotocol/subscriptionId":"stream"}}}`),
      ],
      [JSON.Encode.string("phx_leave"), JSON.parseOrThrow(`{}`)],
    ])
    let count = sessionFrames()->Array.length
    ACP.cleanupSessionChannel(session)
    ACP.disconnect(connection)
    t->expect(sessionFrames()->Array.length)->Expect.toBe(count)
    t->expect(wire->listenerCount(session.channel, "mcp:message"))->Expect.toBe(0)
  })
)

testAsync("failed session joins remove MCP listeners and registered cleanup", async t => {
  let (wire, connection) = await connect()
  setJoinError(wire, JSON.parseOrThrow(`{"reason":"rejected"}`))
  let result = await ACP.createSession(
    connection,
    ~sessionId,
    ~onUpdate=(_, _) => (),
    ~onTitleUpdated=(_, _) => (),
    ~mcpServerInterface=mcpInterface,
  )
  t->expect(result->Result.isError)->Expect.toBe(true)
  t->expect(connection.sessionCleanups.contents)->Expect.toEqual([])
  t
  ->expect(connection.socket->FrontmanClient__Phoenix__Socket.channels->Array.length)
  ->Expect.toBe(1)
})

[false, true]->Array.forEach(transportLoss =>
  testAsync(
    `connection loss drops MCP streams without terminal sends (${Bool.toString(transportLoss)})`,
    async t => {
      let (wire, connection) = await connect()
      let (session, _) =
        (
          await ACP.createSession(
            connection,
            ~sessionId,
            ~onUpdate=(_, _) => (),
            ~onTitleUpdated=(_, _) => (),
            ~mcpServerInterface=mcpInterface,
          )
        )->Result.getOrThrow
      trigger(session.channel, "mcp:message", listenRequest)
      wire->lose(transportLoss)
      ACP.cleanupSessionChannel(session)
      ACP.disconnect(connection)
      let messages =
        wire.frames->Array.filter(
          frame =>
            frame->S.parseOrThrow(~to=S.array(S.json))->Array.at(3) ==
              Some(JSON.Encode.string("mcp:message")),
        )
      t->expect(messages->Array.length)->Expect.toBe(1)
      t->expect(connection.sessionCleanups.contents)->Expect.toEqual([])
      t->expect(wire->listenerCount(session.channel, "mcp:message"))->Expect.toBe(0)
    },
  )
)

[
  JSON.Encode.null,
  JSON.Encode.bool(false),
  JSON.Encode.string("invalid"),
]->Array.forEach(capability =>
  testAsync(`refuses unsupported stable-ID capability ${JSON.stringify(capability)}`, async t => {
    let (wire, connection) = await connect()
    let result = switch ACP.getState(connection) {
    | Initialized(result) => result
    | _ => failwith("Expected initialized connection")
    }
    let capabilities = result.agentCapabilities->Option.getOrThrow
    connection.state := {
        ...connection.state.contents,
        acpState: Initialized({
          ...result,
          agentCapabilities: Some({
            ...capabilities,
            _meta: Some(
              JSON.Encode.object(Dict.fromArray([("frontman.dev/sessionId", capability)])),
            ),
          }),
        }),
      }
    t->expect((await create(connection))->Result.isError)->Expect.toBe(true)
    t->expect(wire.requests->Array.length)->Expect.toBe(1)
  })
)

testAsync("stable-ID creation uses ACP params and rejects a changed returned ID", async t => {
  let (wire, connection) = await connect()
  holdSessionNew(wire, true)
  let pending = create(connection)
  let request = wire.requests->Array.at(-1)->Option.getOrThrow
  let params = request->S.parseOrThrow(~to=S.object(s => s.field("params", S.json)))
  t
  ->expect(params)
  ->Expect.toEqual(
    JSON.parseOrThrow(
      `{"cwd":"/","mcpServers":[],"_meta":{"frontman.dev/sessionId":"${sessionId}"}}`,
    ),
  )
  wire->reply(
    wire.frames->Array.at(-1)->Option.getOrThrow,
    JSON.parseOrThrow(`{"sessionId":"87654321-1234-1234-1234-123456789abc"}`),
  )
  t->expect((await pending)->Result.isError)->Expect.toBe(true)
  t
  ->expect(connection.socket->FrontmanClient__Phoenix__Socket.channels->Array.length)
  ->Expect.toBe(1)
})

[#reply, #timeout, #disconnect, #close]->Array.forEach((
  outcome: [#reply | #timeout | #disconnect | #close],
) =>
  testAsync(`prompt releases Phoenix timers and listeners on ${(outcome :> string)}`, async t => {
    Vi.useFakeTimers()->ignore
    let (wire, connection) = await connect()
    let (session, _) = (await create(connection))->Result.getOrThrow
    let counts = () =>
      [session.channel, connection.channel]->Array.flatMap(
        channel =>
          ["phx_close", "phx_error"]->Array.map(event => wire->listenerCount(channel, event)),
      )
    let before = counts()
    let settled = ref(0)
    let pending = ACP.sendPrompt(session, "once")->Promise.then(
      result => {
        settled := settled.contents + 1
        Promise.resolve(result)
      },
    )
    let frame = wire.frames->Array.at(-1)->Option.getOrThrow
    switch outcome {
    | #reply => wire->reply(frame, JSON.parseOrThrow(`{}`))
    | #timeout => (await Vi.advanceTimersByTimeAsync(120000))->ignore
    | #disconnect => ACP.disconnect(connection)
    | #close => ACP.cleanupSessionChannel(session)
    }
    let result = await pending
    t->expect(result->Result.isOk)->Expect.toBe(outcome == #reply)
    switch outcome {
    | #timeout =>
      t
      ->expect(result)
      ->Expect.toEqual(
        Error(ACP.requestErrorFromMessage("Request session/prompt timed out after 120000ms")),
      )
    | _ => ()
    }
    t->expect(counts())->Expect.toEqual(before)
    wire->reply(frame, JSON.parseOrThrow(`{}`))
    (await Promise.resolve())->ignore
    t->expect(settled.contents)->Expect.toBe(1)
    ACP.disconnect(connection)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })
)
