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
  let (drafted, effects) = Reducer.next(Reducer.defaultState, SetComposerDraft("Private request"))
  t->expect(effects)->Expect.toEqual([Reducer.TrackActivation("request_drafted")])
  let (_, repeatedDraft) = Reducer.next(drafted, SetComposerDraft("Private request edited"))
  t->expect(repeatedDraft)->Expect.toEqual([])
  let (offered, effects) = Reducer.next(drafted, SetSettingsModalTab({tab: Some(Activation)}))
  t->expect(effects)->Expect.toEqual([Reducer.TrackActivation("offer_viewed")])
  let (_, repeatedOffer) = Reducer.next(offered, SetSettingsModalTab({tab: Some(Activation)}))
  t->expect(repeatedOffer)->Expect.toEqual([])
})
