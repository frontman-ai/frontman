open Vitest

let resetStore = () => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    Client__State__StateReducer.defaultState,
  )
}

afterEach(_t => resetStore())

describe("Client__FrontmanProvider billing update handling", () => {
  test("provider billing errors open Providers, not Frontman Billing", t => {
    resetStore()
    Client__State.Actions.openSettingsModalOnBilling()

    Client__FrontmanProvider.openProviderSettingsForErrorCategory(Some("billing"))

    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.settingsModalTab)->Expect.toEqual(Some(Client__State__Types.Providers))
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
    resetStore()

    Client__FrontmanProvider.openProviderSettingsForErrorCategory(Some("rate_limit"))

    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.settingsModalTab)->Expect.toEqual(None)
  })
})
