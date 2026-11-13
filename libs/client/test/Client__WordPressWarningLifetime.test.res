open Vitest

module Connection = Client__ConnectionReducer
module Reducer = Client__State__StateReducer

let config: Connection.config = {
  acp: Connection.ACP.makeConfig(
    ~endpoint="ws://localhost",
    ~loginUrl="http://localhost/users/log-in",
    ~getAuthToken=() => None,
    ~name="test",
    ~version="1",
    ~_meta=JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("wordpress"))])),
  ),
  relay: Connection.Relay.makeConfig(~baseUrl="http://localhost"),
  mcp: Connection.MCPServer.makeConfig(),
}

let signal = (state: Client__State__Types.state) => {
  let connection = state.connection->Option.getOrThrow
  let runtime = connection.connection->Result.getOrThrow->Option.getOrThrow
  runtime.lifetimeAbortController.signal
}

let observes = effects =>
  effects->Array.some(effect =>
    switch effect {
    | Client__State__Protocol.ObserveWordPressWarning => true
    | _ => false
    }
  )

test("new lifetimes observe the warning and reject old dismissal callbacks", t => {
  let (state, effects) = Reducer.next(
    Client__State__Initialization.defaultState,
    InitializeConnection(config),
  )
  t->expect(observes(effects))->Expect.toBe(true)
  let oldSignal = signal(state)
  let (state, _) = Reducer.next(state, ConnectionAction(Dispose))
  let (state, effects) = Reducer.next(state, ConnectionAction(Initialize))
  t->expect(observes(effects))->Expect.toBe(true)
  let (state, _) = Reducer.next(state, WordPressWarningCleared(oldSignal))
  t->expect(state.wordPressWarningReady)->Expect.toBe(false)
  let (state, _) = Reducer.next(state, WordPressWarningCleared(signal(state)))
  t->expect(state.wordPressWarningReady)->Expect.toBe(true)
  let (state, _) = Reducer.next(state, ConnectionAction(Dispose))
  let (_, effects) = Reducer.next(state, ConnectionAction(Initialize))
  t->expect(observes(effects))->Expect.toBe(false)
})

test("authentication retries retain the observer on the same lifetime", t => {
  let (state, _) = Reducer.next(
    Client__State__Initialization.defaultState,
    InitializeConnection(config),
  )
  let currentSignal = signal(state)
  let (state, effects) = Reducer.next(
    state,
    ConnectionAction(ConnectionResultReceived({
      signal: currentSignal,
      result: Error(AuthenticationRequired({loginUrl: "http://localhost/users/log-in"})),
    })),
  )
  t->expect(observes(effects))->Expect.toBe(false)
  let (state, effects) = Reducer.next(state, ConnectionAction(RetryAuthentication))
  t->expect(observes(effects))->Expect.toBe(false)
  t->expect(signal(state) === currentSignal)->Expect.toBe(true)
  let (state, _) = Reducer.next(state, WordPressWarningCleared(currentSignal))
  t->expect(state.wordPressWarningReady)->Expect.toBe(true)
})
