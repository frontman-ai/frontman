open Vitest

let resetStore = () => {
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    Client__State__StateReducer.defaultState,
  )
}

afterEach(_t => resetStore())

describe("Client__FrontmanProvider billing update handling", () => {
  test("opens Billing settings for billing error category", t => {
    resetStore()

    Client__FrontmanProvider.openBillingSettingsForErrorCategory(Some("billing"))

    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.settingsModalTab)->Expect.toEqual(Some(Client__State__Types.Billing))
  })

  test("does not open settings for non-billing error category", t => {
    resetStore()

    Client__FrontmanProvider.openBillingSettingsForErrorCategory(Some("rate_limit"))

    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.settingsModalTab)->Expect.toEqual(None)
  })
})
