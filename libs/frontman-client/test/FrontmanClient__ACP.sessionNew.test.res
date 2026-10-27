open Vitest

module ACP = FrontmanClient__ACP

type frame = (JSON.t, JSON.t, string, string, JSON.t)
type transport = {
  frames: array<frame>,
  requests: array<JSON.t>,
}

@module("./acpReconnectTransport.mjs")
external makeTransport: unit => transport = "makeTransport"
@set external holdSessionNew: (transport, bool) => unit = "holdSessionNew"
@send external reply: (transport, frame, JSON.t) => unit = "reply"
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

@send
external trigger: (FrontmanClient__Phoenix__Channel.t, string, JSON.t) => unit = "trigger"
@send external lose: (transport, bool) => unit = "lose"
@set external setJoinError: (transport, JSON.t) => unit = "joinError"

let listenRequest = JSON.parseOrThrow(`{"jsonrpc":"2.0","id":"stream","method":"subscriptions/listen","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}},"notifications":{}}}`)

let create = connection =>
  ACP.createSession(
    connection,
    ~sessionId,
    ~onUpdate=(_, _) => (),
    ~onTitleUpdated=(_, _) => (),
    ~onParseError=_ => (),
    ~mcpServerInterface={
      server: (),
      buildDiscoverResult: _ => failwith("Unexpected discovery"),
      buildToolsListResult: _ => failwith("Unexpected listing"),
      executeTool: async (_, _, ~signal as _) => Suspended,
    },
  )

testAsync("failed session joins remove MCP listeners and registered cleanup", async t => {
  let (wire, connection) = await connect()
  setJoinError(wire, JSON.parseOrThrow(`{"reason":"rejected"}`))
  t->expect((await create(connection))->Result.isError)->Expect.toBe(true)
  t->expect(connection.sessionCleanups.contents)->Expect.toEqual([])
  t
  ->expect(connection.socket->FrontmanClient__Phoenix__Socket.channels->Array.length)
  ->Expect.toBe(1)
})

testAsync("connects without sending a client-supplied origin param", async t => {
  let (_, connection) = await connect()
  t
  ->expect(connection.socket->FrontmanBindings.Phoenix.socketParams->Dict.get("origin"))
  ->Expect.toEqual(None)
})

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

[#reply, #timeout, #disconnect, #close, #parse, #error, #lost]->Array.forEach((
  outcome: [#reply | #timeout | #disconnect | #close | #parse | #error | #lost],
) =>
  testAsync(`prompt releases Phoenix timers and listeners on ${(outcome :> string)}`, async t => {
    Vi.useFakeTimers()->ignore
    let (wire, connection) = await connect()
    let (session, _) = (await create(connection))->Result.getOrThrow
    trigger(session.channel, "mcp:message", listenRequest)
    let closed = outcome != #reply && outcome != #timeout
    let counts = () =>
      [session.channel, connection.channel]->Array.flatMap(
        channel =>
          ["phx_close", "phx_error"]->Array.map(event => wire->listenerCount(channel, event)),
      )
    let before =
      counts()->Array.mapWithIndex((count, index) => closed && index < 2 ? count - 1 : count)
    let settled = ref(0)
    let pending = ACP.sendPrompt(session, "once")->Promise.finally(
      () => {
        settled := settled.contents + 1
      },
    )
    let frame = wire.frames->Array.at(-1)->Option.getOrThrow
    let beforeCleanup = wire.frames->Array.length
    switch outcome {
    | #reply => wire->reply(frame, JSON.parseOrThrow(`{}`))
    | #timeout => (await Vi.advanceTimersByTimeAsync(120000))->ignore
    | #disconnect => ACP.disconnect(connection)
    | #close => ACP.cleanupSessionChannel(session)
    | #parse =>
      trigger(
        session.channel,
        "acp:message",
        JSON.parseOrThrow(`{"jsonrpc":"2.0","method":"session/update","params":{}}`),
      )
    | #error | #lost => wire->lose(outcome == #lost)
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
    switch closed {
    | false => ()
    | true =>
      let frames =
        wire.frames
        ->Array.slice(~start=beforeCleanup, ~end=Array.length(wire.frames))
        ->Array.filter(((_, _, topic, _, _)) => topic == `task:${sessionId}`)
      let endings = [
        (
          "mcp:message",
          JSON.parseOrThrow(`{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":"stream","_meta":{"io.modelcontextprotocol/subscriptionId":"stream"}}}`),
        ),
        (
          "mcp:message",
          JSON.parseOrThrow(`{"jsonrpc":"2.0","id":"stream","result":{"resultType":"complete","_meta":{"io.modelcontextprotocol/subscriptionId":"stream"}}}`),
        ),
        ("phx_leave", JSON.parseOrThrow(`{}`)),
      ]
      t
      ->expect(frames->Array.map(((_, _, _, event, payload)) => (event, payload)))
      ->Expect.toEqual(
        switch outcome {
        | #error => endings->Array.slice(~start=2, ~end=3)
        | #lost => []
        | _ => endings
        },
      )
      let sent = wire.frames->Array.length
      ACP.cleanupSessionChannel(session)
      t->expect(wire.frames->Array.length)->Expect.toBe(sent)
      t->expect(connection.sessionCleanups.contents)->Expect.toEqual([])
      t->expect(wire->listenerCount(session.channel, "mcp:message"))->Expect.toBe(0)
    }
    ACP.disconnect(connection)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })
)
