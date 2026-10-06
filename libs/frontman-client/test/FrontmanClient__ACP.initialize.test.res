open Vitest

module ACP = FrontmanClient__ACP
module Client = FrontmanClient__ACP__Client
module Channel = FrontmanClient__Phoenix__Channel
module Socket = FrontmanClient__Phoenix__Socket

type transport = {
  @live
  mutable holdInitialize: bool,
  frames: array<JSON.t>,
}

@module("./acpReconnectTransport.mjs")
external makeTransport: unit => transport = "makeTransport"
@send external reply: (transport, JSON.t, JSON.t) => unit = "reply"
@send external listenerCount: (transport, Channel.t, string) => int = "listenerCount"
@send external isConnected: Socket.t => bool = "isConnected"
@module("vitest") @scope("vi") external clearAllTimers: unit => unit = "clearAllTimers"
@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"

afterEach(() => {
  clearAllTimers()
  Vi.useRealTimers()->ignore
  unstubAllGlobals()
})

[0, 2, 999]->Array.forEach(version => {
  testAsync(
    `unsupported initialize response version ${version->Int.toString} disposes connection`,
    async t => {
      Vi.useFakeTimers()->ignore
      let wire = makeTransport()
      wire.holdInitialize = true
      let config = ACP.makeConfig(
        ~endpoint="ws://localhost/socket",
        ~loginUrl="https://localhost/login",
        ~getAuthToken=() => Some("test-token"),
        ~name="test",
        ~version="1",
        ~_meta=JSON.parseOrThrow(`{"framework":"wordpress"}`),
        ~onConfigOptionsUpdated=_ => (),
        ~onBillingStatusUpdated=_ => (),
      )
      let owned = ref(None)
      let pending = ACP.connect(config, ~onConnectionCreated=conn => owned := Some(conn))
      let _ = await Vi.advanceTimersByTimeAsync(0)
      let conn = owned.contents->Option.getOrThrow
      let frame = wire.frames->Array.at(-1)->Option.getOrThrow
      wire->reply(frame, JSON.parseOrThrow(`{"protocolVersion":${version->Int.toString}}`))

      t
      ->expect(await pending)
      ->Expect.toEqual(
        Error(ACP.ConnectionFailed(`Unsupported ACP protocol version: ${version->Int.toString}`)),
      )
      t->expect(ACP.getState(conn))->Expect.toEqual(Client.Disconnected)
      t->expect(conn.state.contents.agentAttributionConfiguration)->Expect.toEqual(None)
      t->expect(Channel.state(conn.channel))->Expect.toBe("closed")
      t->expect(isConnected(conn.socket))->Expect.toBe(false)
      ["acp:message", "config_options_updated", "billing_status_updated"]->Array.forEach(
        event => t->expect(wire->listenerCount(conn.channel, event))->Expect.toBe(0),
      )
      t->expect(Vi.getTimerCount())->Expect.toBe(0)
      ACP.disconnect(conn)
      t->expect(Vi.getTimerCount())->Expect.toBe(0)
    },
  )
})
