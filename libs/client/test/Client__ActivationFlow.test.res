open Vitest
module Reducer = Client__State__StateReducer

let active = S.parseOrThrow(
  JSON.parseOrThrow(`{"status":"active","access_allowed":true,"has_billing_customer":true,"interval":"monthly","current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`),
  ~to=Client__Billing.statusSchema,
)

test("activation preserves the draft and requires explicit review without sending", t => {
  let reduce = (state, action) => Reducer.next(state, action)->Pair.first
  let drafted = reduce(Reducer.defaultState, SetComposerDraft("Fix mobile signup"))
  let gated = reduce(reduce(drafted, ConnectionAction(Dispose)), ContinueActivation)
  t->expect(gated.settingsModalTab)->Expect.toEqual(Some(Activation))
  let canceled = reduce(gated, BillingRequestCancelled({tab: None}))
  let activated = reduce(canceled, BillingStatusReceived(active))
  t->expect(activated.settingsModalTab)->Expect.toEqual(Some(Activation))
  t
  ->expect(reduce(activated, ContinueActivation).settingsModalTab)
  ->Expect.toEqual(Some(ProviderSetup))
  let ready = {
    ...activated,
    selectedModelValue: Some("model"),
  }
  let (finished, effects) = Reducer.next(ready, ContinueActivation)
  t->expect(finished.settingsModalTab)->Expect.toBeNone
  t->expect(finished.composerDraft)->Expect.toBe("Fix mobile signup")
  t
  ->expect(effects)
  ->Expect.toEqual([Reducer.TrackActivation("setup_completed"), Reducer.FocusComposer])
  t->expect(Reducer.Selectors.messages(finished)->Array.length)->Expect.toBe(0)
})

test("payment recovery requires an existing customer with past-due or unpaid status", t => {
  let status = S.parseOrThrow(
    JSON.parseOrThrow(`{"status":"past_due","access_allowed":false,"has_billing_customer":true,"interval":"monthly","current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`),
    ~to=Client__Billing.statusSchema,
  )
  t->expect(Client__Billing.needsPaymentRecovery(status))->Expect.toBe(true)
  t->expect(Client__Billing.needsPaymentRecovery(active))->Expect.toBe(false)
})
