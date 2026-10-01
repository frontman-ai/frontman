open Vitest

module Reducer = Client__State__StateReducer

let resetStore = () => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    Reducer.defaultState,
  )
}

afterEach(_t => resetStore())

let errorEffects = category =>
  Reducer.next(
    Reducer.defaultState,
    AcpSessionUpdateReceived({
      taskId: "task",
      update: Error({
        _meta: Some(JSON.parseOrThrow(`{"frontman.dev/agentErrorId":"error-1"}`)),
        message: "Provider failed",
        timestamp: "2026-01-01T00:00:00Z",
        retryAt: None,
        attempt: None,
        maxAttempts: None,
        category,
      }),
    }),
  )->Pair.second

describe("ACP billing update handling", () => {
  test("provider billing errors open Providers, not Frontman Billing", t => {
    let opensProviders = switch errorEffects(Some("billing")) {
    | [
        Reducer.FlushSessionActions([
          SetSettingsModalTab({tab: Some(Providers)}),
          TaskAction({action: AgentError(_)}),
        ]),
      ] => true
    | _ => false
    }
    t->expect(opensProviders)->Expect.toBe(true)
  })

  test("billing RPC failure opens settings and retains the server message", t => {
    resetStore()
    let error = Client__ConnectionReducer.ACP.requestErrorWithCode(
      ~code=FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc.ErrorCode.billingInactive,
      ~message="Alternate billing copy",
    )
    t
    ->expect(Client__ConnectionReducer.billingRequestErrorMessage(error))
    ->Expect.toBe("Alternate billing copy")
    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.settingsModalTab)->Expect.toEqual(Some(Client__State__Types.Billing))
  })

  test("does not open settings for non-billing error category", t => {
    let onlyTaskError = switch errorEffects(Some("rate_limit")) {
    | [Reducer.FlushSessionActions([TaskAction({action: AgentError(_)})])] => true
    | _ => false
    }
    t->expect(onlyTaskError)->Expect.toBe(true)
  })
})
