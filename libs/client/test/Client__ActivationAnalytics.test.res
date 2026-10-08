open Vitest
module Reducer = Client__State__StateReducer

beforeEach(Client__ActivationTestHelpers.setup)
afterEach(Client__ActivationTestHelpers.unstubAllGlobals)

test("activation tracking sends step and framework only", t => {
  let tracked = ref([])
  Client__ActivationTestHelpers.stubGlobal(
    "heap",
    {
      "track": (name: string, properties: JSON.t) =>
        tracked.contents->Array.push((name, properties)),
    },
  )
  Client__Analytics.track(ActivationStep("request_drafted"))
  t
  ->expect(tracked.contents)
  ->Expect.toEqual([
    ("activation_step", JSON.parseOrThrow(`{"framework":"vite","step":"request_drafted"}`)),
  ])
})

test("draft and offer events follow transitions rather than repeated updates", t => {
  let (blank, blankEffects) = Reducer.next(Reducer.defaultState, SetComposerDraft(" "))
  t->expect(blankEffects)->Expect.toEqual([])
  let (drafted, effects) = Reducer.next(blank, SetComposerDraft("Private request"))
  t->expect(effects)->Expect.toEqual([Reducer.TrackActivation("request_drafted")])
  let (_, repeatedDraft) = Reducer.next(drafted, SetComposerDraft("Private request edited"))
  t->expect(repeatedDraft)->Expect.toEqual([])
  let (offered, effects) = Reducer.next(drafted, SetSettingsModalTab({tab: Some(Billing)}))
  t->expect(effects)->Expect.toEqual([Reducer.TrackActivation("offer_viewed")])
  let (_, repeatedOffer) = Reducer.next(offered, SetSettingsModalTab({tab: Some(Billing)}))
  t->expect(repeatedOffer)->Expect.toEqual([])
})

test("checkout tracking excludes duplicate requests and portal visits", t => {
  let state = {
    ...Reducer.defaultState,
    connection: Client__ConnectionTestHelpers.ready(~apiBaseUrl="https://api.example"),
  }
  let (opening, effects) = Reducer.next(state, RequestBilling(Checkout(Monthly)))
  t
  ->expect(
    effects->Array.some(effect =>
      switch effect {
      | Reducer.TrackActivation("checkout_started") => true
      | _ => false
      }
    ),
  )
  ->Expect.toBe(true)
  let (_, repeated) = Reducer.next(opening, RequestBilling(Checkout(Monthly)))
  t->expect(repeated)->Expect.toEqual([])
  let (_, portal) = Reducer.next(state, RequestBilling(CustomerPortal))
  t
  ->expect(
    portal->Array.some(effect =>
      switch effect {
      | Reducer.TrackActivation("checkout_started") => true
      | _ => false
      }
    ),
  )
  ->Expect.toBe(false)
})

test("provider setup completion only tracks when leaving setup with a selected model", t => {
  let ready = {
    ...Reducer.defaultState,
    settingsModalTab: Some(ProviderSetup),
    selectedModelValue: Some("model"),
    composerDraft: "Private request",
  }
  let (finished, effects) = Reducer.next(ready, ContinueActivation)
  t->expect(finished.settingsModalTab)->Expect.toBeNone
  t->expect(finished.composerDraft)->Expect.toBe(ready.composerDraft)
  t
  ->expect(effects)
  ->Expect.toEqual([Reducer.TrackActivation("setup_completed"), Reducer.FocusComposer])
  let (_, repeated) = Reducer.next(finished, ContinueActivation)
  t->expect(repeated)->Expect.toEqual([Reducer.FocusComposer])
  let (_, incomplete) = Reducer.next({...ready, selectedModelValue: None}, ContinueActivation)
  t->expect(incomplete)->Expect.toEqual([Reducer.FocusComposer])
})
