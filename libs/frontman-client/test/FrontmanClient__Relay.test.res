open Vitest

module Relay = FrontmanClient__Relay

describe("Relay.connect", _t => {
  testAsync("returns Error when server is unreachable", async t => {
    // Point at a port where nothing is listening — same scenario as the Sentry bug
    let relay = Relay.make(~baseUrl="http://localhost:19999")
    let result = await Relay.connect(relay)

    switch result {
    | Error(_msg) => t->expect(true)->Expect.toBe(true)
    | Ok() => t->expect(false)->Expect.toBe(true) // should not succeed
    }
  })

  testAsync("returns Error when aborted via AbortSignal", async t => {
    // Create a controller and abort immediately — simulates component unmount during connect
    let controller = WebAPI.AbortController.make()
    WebAPI.AbortController.abort(controller)

    let relay = Relay.make(~baseUrl="http://localhost:19999")
    let result = await Relay.connect(relay, ~signal=controller.signal)

    switch result {
    | Error(_msg) => t->expect(true)->Expect.toBe(true)
    | Ok() => t->expect(false)->Expect.toBe(true) // should not succeed
    }
  })

  testAsync("sets state to Error when server is unreachable", async t => {
    let relay = Relay.make(~baseUrl="http://localhost:19999")
    let _ = await Relay.connect(relay)

    switch Relay.getState(relay) {
    | Error(_) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true) // state should be Error
    }
  })
})
