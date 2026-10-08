open Vitest

module ACP = FrontmanClient__ACP

type wire = {requests: array<JSON.t>}
@module("./acpReconnectTransport.mjs") external makeTransport: unit => wire = "makeTransport"
@set external holdTasksJoin: (wire, bool) => unit = "holdTasksJoin"
@module("vitest") external onTestFinished: (unit => unit) => unit = "onTestFinished"
@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"

[
  "startup abort",
  "startup disconnect",
  "join timeout",
  "active abort",
  "active disconnect",
]->Array.forEach(scenario =>
  testAsync(`intentional cleanup and startup settlement: ${scenario}`, async t => {
    Vi.useFakeTimers()->ignore
    let wire = makeTransport()
    onTestFinished(
      () => {
        Vi.clearAllTimers()->ignore
        Vi.useRealTimers()->ignore
        unstubAllGlobals()
      },
    )
    let controller = WebAPI.AbortController.make()
    let owned = ref(None)
    let losses = ref(0)
    let config = ACP.makeConfig(
      ~endpoint="ws://localhost/socket",
      ~loginUrl="https://localhost/login",
      ~getAuthToken=() => Some("test-token"),
      ~name="test",
      ~version="1",
      ~_meta=JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("wordpress"))])),
    )
    holdTasksJoin(wire, scenario == "join timeout")
    let pending = ACP.connect(
      config,
      ~signal=controller.signal,
      ~onConnectionCreated=connection => {
        owned := Some(connection)
        switch scenario {
        | "startup abort" => WebAPI.AbortController.abort(controller)
        | "startup disconnect" => ACP.disconnect(connection)
        | _ => ()
        }
      },
      ~onConnectionLost=_ => losses := losses.contents + 1,
    )
    switch scenario {
    | "join timeout" => (await Vi.advanceTimersByTimeAsync(20000))->ignore
    | _ => ()
    }
    let result = await pending
    let connection = owned.contents->Option.getOrThrow
    switch scenario {
    | "active abort" | "active disconnect" =>
      t->expect(result->Result.isOk)->Expect.toBe(true)
      let (session, _) =
        (
          await ACP.createSession(
            connection,
            ~sessionId="conversation",
            ~onUpdate=(_, _) => (),
            ~onTitleUpdated=(_, _) => (),
          )
        )->Result.getOrThrow
      let prompt = ACP.sendPrompt(session, "only once")
      switch scenario {
      | "active abort" => WebAPI.AbortController.abort(controller)
      | _ => ACP.disconnect(connection)
      }
      t->expect((await prompt)->Result.isError)->Expect.toBe(true)
    | _ =>
      t->expect(result->Result.isError)->Expect.toBe(true)
      t->expect(wire.requests)->Expect.toEqual([])
    }
    t->expect(ACP.isInitialized(connection))->Expect.toBe(false)
    t->expect(connection.state.contents.pendingRequests->Dict.keysToArray)->Expect.toEqual([])
    t->expect(losses.contents)->Expect.toBe(0)
    t->expect(Vi.getTimerCount())->Expect.toBe(0)
  })
)
