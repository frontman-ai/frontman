open Vitest
module ACP = FrontmanClient__ACP
module Channel = FrontmanClient__Phoenix__Channel

type request = {method: string, params: JSON.t}
type wire = {
  requests: array<request>,
  mutable holdInitialize: bool,
  mutable joinError: option<JSON.t>,
  initialize: (int, option<JSON.t>) => unit,
  lose: bool => unit,
  emit: (string, JSON.t) => unit,
  listenerCount: (Channel.t, string) => int,
}
@module("./acpReconnectTransport.mjs") external makeTransport: unit => wire = "makeTransport"
@module("vitest") @scope("vi") external unstubGlobals: unit => unit = "unstubAllGlobals"

let connections: ref<array<ACP.connection>> = ref([])
beforeEach(() => Vi.useFakeTimers()->ignore)
afterEach(() => {
  connections.contents->Array.forEach(conn => ACP.disconnect(conn))
  connections := []
  Vi.clearAllTimers()->ignore
  Vi.useRealTimers()->ignore
  unstubGlobals()
})
let config = (~framework="wordpress", ~onConfigOptionsUpdated=?) =>
  ACP.makeConfig(
    ~endpoint="ws://localhost/socket",
    ~loginUrl="https://localhost/login",
    ~getAuthToken=() => Some("test-token"),
    ~name="test",
    ~version="1",
    ~_meta=JSON.parseOrThrow(`{"framework":"${framework}"}`),
    ~onConfigOptionsUpdated?,
  )
let remember = conn => {
  connections := Array.concat(connections.contents, [conn])
  conn
}
let create = conn =>
  ACP.createSession(
    conn,
    ~sessionId="conversation",
    ~onUpdate=(_, _) => (),
    ~onTitleUpdated=(_, _) => (),
  )
let methods = wire => wire.requests->Array.map(request => request.method)
let params = (wire, index) => (wire.requests[index]->Option.getOrThrow).params

[false, true]->Array.forEach(transport =>
  testAsync(
    `reinitializes real Phoenix ${transport ? "transport" : "channel"} rejoin before session/new`,
    async t => {
      let wire = makeTransport()
      let configs = ref(0)
      let reconnects = ref(0)
      let conn =
        (
          await ACP.connect(
            config(~onConfigOptionsUpdated=_ => configs := configs.contents + 1),
            ~onReconnect=result => {
              result->Result.getOrThrow->ignore
              reconnects := reconnects.contents + 1
            },
          )
        )
        ->Result.getOrThrow
        ->remember
      let listenerCount = wire.listenerCount(conn.channel, "acp:message")
      wire.lose(transport)
      t->expect(ACP.isInitialized(conn))->Expect.toBe(false)
      t->expect((await create(conn))->Result.isError)->Expect.toBe(true)
      wire.holdInitialize = true
      (await Vi.advanceTimersByTimeAsync(1000))->ignore
      t->expect(methods(wire))->Expect.toEqual(["initialize", "initialize"])
      t->expect(params(wire, 0))->Expect.toEqual(params(wire, 1))
      t->expect((await create(conn))->Result.isError)->Expect.toBe(true)
      wire.initialize(1, None)
      (await Vi.advanceTimersByTimeAsync(0))->ignore
      t->expect((await create(conn))->Result.isOk)->Expect.toBe(true)
      t->expect(methods(wire))->Expect.toEqual(["initialize", "initialize", "session/new"])
      t->expect(reconnects.contents)->Expect.toBe(1)
      t->expect(wire.listenerCount(conn.channel, "acp:message"))->Expect.toBe(listenerCount)
      wire.emit("config_options_updated", JSON.parseOrThrow(`{"configOptions":[]}`))
      t->expect(configs.contents)->Expect.toBe(1)
    },
  )
)

testAsync(
  "rapid rejoins ignore stale success and reject pending prompts without replay",
  async t => {
    let wire = makeTransport()
    let conn = (await ACP.connect(config()))->Result.getOrThrow->remember
    let (session, _) = (await create(conn))->Result.getOrThrow
    let pending = ACP.sendPrompt(session, "only once")
    wire.holdInitialize = true
    wire.lose(true)
    t->expect(() => ACP.sendSessionCommand(session, Cancel))->Expect.toThrow
    t->expect(() => ACP.sendSessionCommand(session, RetryTurn("old-turn")))->Expect.toThrow
    t->expect((await pending)->Result.isError)->Expect.toBe(true)
    t->expect((await ACP.listSessions(conn))->Result.isError)->Expect.toBe(true)
    t->expect((await ACP.deleteSession(conn, "conversation"))->Result.isError)->Expect.toBe(true)
    (await Vi.advanceTimersByTimeAsync(1000))->ignore
    wire.initialize(1, None)
    wire.lose(false)
    (await Vi.advanceTimersByTimeAsync(1000))->ignore
    t->expect(ACP.isInitialized(conn))->Expect.toBe(false)
    wire.initialize(1, None)
    (await Vi.advanceTimersByTimeAsync(0))->ignore
    t->expect(ACP.isInitialized(conn))->Expect.toBe(false)
    wire.initialize(2, None)
    (await Vi.advanceTimersByTimeAsync(0))->ignore
    t->expect(ACP.isInitialized(conn))->Expect.toBe(true)
    t
    ->expect(methods(wire)->Array.filter(method => method == "session/prompt")->Array.length)
    ->Expect.toBe(1)
    t->expect(conn.state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
    let listing = ACP.listSessions(conn)
    let deletion = ACP.deleteSession(conn, "conversation")
    (await Vi.advanceTimersByTimeAsync(10000))->ignore
    t->expect((await listing)->Result.isError)->Expect.toBe(true)
    t->expect((await deletion)->Result.isError)->Expect.toBe(true)
    ACP.disconnect(conn, ~session)
    (await Vi.advanceTimersByTimeAsync(120000))->ignore
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  },
)

["error", "timeout", "unauthorized", "close", "abort", "disconnect"]->Array.forEach(failure =>
  testAsync(`reconnect ${failure} never restores stale readiness`, async t => {
    let wire = makeTransport()
    let controller = WebAPI.AbortController.make()
    let results = ref([])
    let conn =
      (
        await ACP.connect(
          config(),
          ~signal=controller.signal,
          ~onReconnect=result => results := Array.concat(results.contents, [result]),
        )
      )
      ->Result.getOrThrow
      ->remember
    (await create(conn))->Result.getOrThrow->ignore
    wire.holdInitialize = true
    wire.lose(false)
    switch failure {
    | "unauthorized" =>
      wire.joinError = Some(
        JSON.parseOrThrow(`{"reason":"unauthorized","login_url":"https://localhost/login"}`),
      )
    | _ => ()
    }
    (await Vi.advanceTimersByTimeAsync(1000))->ignore
    switch failure {
    | "error" =>
      wire.initialize(1, Some(JSON.parseOrThrow(`{"code":-32602,"message":"bad handshake"}`)))
    | "timeout" => (await Vi.advanceTimersByTimeAsync(120000))->ignore
    | "close" => wire.emit("phx_close", JSON.parseOrThrow(`{}`))
    | "abort" => WebAPI.AbortController.abort(controller)
    | "disconnect" => ACP.disconnect(conn)
    | _ => ()
    }
    (await Vi.advanceTimersByTimeAsync(0))->ignore
    t->expect(ACP.isInitialized(conn))->Expect.toBe(false)
    t->expect((await create(conn))->Result.isError)->Expect.toBe(true)
    switch failure {
    | "abort" | "disconnect" => t->expect(results.contents->Array.length)->Expect.toBe(0)
    | "unauthorized" =>
      t
      ->expect(results.contents)
      ->Expect.toEqual([Error(ACP.AuthRequired({loginUrl: "https://localhost/login"}))])
    | _ =>
      t->expect(results.contents->Array.length)->Expect.toBe(1)
      t->expect(results.contents->Array.every(Result.isError))->Expect.toBe(true)
    }
    switch failure {
    | "unauthorized" => ()
    | _ => wire.initialize(1, None)
    }
    (await Vi.advanceTimersByTimeAsync(0))->ignore
    t->expect(ACP.isInitialized(conn))->Expect.toBe(false)
    t->expect(conn.state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })
)

["astro", "nextjs", "vite"]->Array.forEach(framework =>
  testAsync(`preserves ${framework} metadata across rejoin`, async t => {
    let wire = makeTransport()
    let conn = (await ACP.connect(config(~framework)))->Result.getOrThrow->remember
    wire.lose(false)
    (await Vi.advanceTimersByTimeAsync(1000))->ignore
    t->expect(params(wire, 0))->Expect.toEqual(params(wire, 1))
    t->expect((await create(conn))->Result.isOk)->Expect.toBe(true)
  })
)

testAsync("does not synthesize genuinely missing framework metadata", async t => {
  makeTransport()->ignore
  let base = config()
  let conn =
    (
      await ACP.connect({
        ...base,
        clientInfo: {...base.clientInfo, _meta: Some(JSON.parseOrThrow(`{}`))},
      })
    )
    ->Result.getOrThrow
    ->remember
  t
  ->expect((await create(conn))->Result.mapError(ACP.requestErrorMessage))
  ->Expect.toEqual(Error("Missing framework in clientInfo"))
})
