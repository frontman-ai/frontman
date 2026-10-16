open Vitest

module Reducer = Client__State__StateReducer

let resetStore = () => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    Reducer.defaultState,
  )
}

afterEach(_t => resetStore())

let errorUpdate = (
  category,
  ~meta=JSON.parseOrThrow(`{"frontman.dev/agentErrorId":"error-1"}`),
) => FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.Error({
  _meta: Some(meta),
  message: "Provider failed",
  timestamp: "2026-01-01T00:00:00Z",
  retryAt: None,
  attempt: None,
  maxAttempts: None,
  category,
})

let errorEffects = category =>
  Reducer.next(
    Reducer.defaultState,
    AcpSessionUpdateReceived({taskId: "task", update: errorUpdate(category)}),
  )->Pair.second

describe("ACP billing update handling", () => {
  test("only persisted execution errors expose retry in the banner and conversation history", t => {
    [
      (`{"frontman.dev/agentErrorId":null}`, None),
      (`{"frontman.dev/agentErrorId":"error-1"}`, Some("error-1")),
    ]->Array.forEach(
      ((meta, retryErrorId)) => {
        let task =
          Client__State__Types.Task.makeNew(
            ~previewUrl="http://localhost:3000",
          )->Client__State__Types.Task.newToLoaded(~id="task", ~title="Task")
        StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
          Client__State__Store.store,
          {
            ...Reducer.defaultState,
            tasks: Dict.fromArray([("task", task)]),
            currentTask: Client__State__Types.Task.Selected("task"),
          },
        )
        Client__State__Store.dispatch(
          AcpSessionUpdateReceived({
            taskId: "task",
            update: errorUpdate(Some("billing"), ~meta=JSON.parseOrThrow(meta)),
          }),
        )
        let state = StateStore.getState(Client__State__Store.store)
        let turnError = Reducer.Selectors.turnError(state)->Option.getOrThrow
        t->expect(turnError.retryErrorId)->Expect.toEqual(retryErrorId)
        switch Reducer.Selectors.messages(state)->Array.get(0) {
        | Some(Client__State__Types.Message.Error(error)) =>
          t
          ->expect(Client__State__Types.Message.ErrorMessage.retryErrorId(error))
          ->Expect.toEqual(retryErrorId)
        | _ => failwith("Expected an error in conversation history")
        }
      },
    )
  })

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
    ->expect(
      Reducer.ConnectionEffects.billingRequestErrorMessage(error, Client__State__Store.dispatch),
    )
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
