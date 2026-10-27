open Vitest
open WebAPI
open Client__ActivationBrowserHelpers

afterEach(cleanup)

let text = () =>
  (container.contents->Option.getOrThrow :> DomTypes.node).textContent->Null.getOrThrow

let renderBilling = (~status, ~remaining, ~cancelAt, ~canceledAt) => {
  let subscriptionAccess = status == "active" || (cancelAt == "null" && canceledAt == "null")
  let remainingJson = subscriptionAccess ? "null" : Int.toString(remaining)
  let billing = S.parseOrThrow(
    JSON.parseOrThrow(
      `{"status":"${status}","can_start_turn":${Bool.toString(
          subscriptionAccess || remaining > 0,
        )},"pretrial_runs_remaining":${remainingJson},"has_billing_customer":true,"interval":"monthly","current_period_end":"2026-06-01T00:00:00Z","trial_end":"2026-06-01T00:00:00Z","cancel_at":${cancelAt},"canceled_at":${canceledAt}}`,
    ),
    ~to=Billing.statusSchema,
  )
  force({...Reducer.defaultState, billingStatus: Loaded(billing)})
  render(<Client__SettingsModal__Tab__Billing />)
}

[0, 1]->Array.forEach(remaining =>
  [
    (`"2026-06-01T00:00:00Z"`, "null"),
    ("null", `"2026-05-25T00:00:00Z"`),
    (`"2026-06-01T00:00:00Z"`, `"2026-05-25T00:00:00Z"`),
  ]->Array.forEach(((cancelAt, canceledAt)) =>
    testAsync(
      `canceled trial with ${Int.toString(remaining)} free prompts: ${cancelAt}, ${canceledAt}`,
      async t => {
        renderBilling(~status="trialing", ~remaining, ~cancelAt, ~canceledAt)
        await waitFor(() => t->expect(text()->String.includes("Trial canceled"))->Expect.toBe(true))
        t->expect(text()->String.includes("Your trial access has ended."))->Expect.toBe(true)
        t->expect(text()->String.includes("Access remains active until"))->Expect.toBe(false)
        t->expect(text()->String.includes("Manage in Stripe"))->Expect.toBe(true)
        switch remaining {
        | 0 =>
          t
          ->expect(text()->String.includes("Manage billing in Stripe to restore access."))
          ->Expect.toBe(true)
          t->expect(text()->String.includes("remaining free prompts"))->Expect.toBe(false)
        | _ =>
          t
          ->expect(text()->String.includes("You can still use your remaining free prompts."))
          ->Expect.toBe(true)
        }
      },
    )
  )
)

testAsync("paid subscriptions retain access until scheduled cancellation", async t => {
  renderBilling(
    ~status="active",
    ~remaining=0,
    ~cancelAt=`"2026-06-01T00:00:00Z"`,
    ~canceledAt=`"2026-05-25T00:00:00Z"`,
  )
  await waitFor(() =>
    t->expect(text()->String.includes("Subscription scheduled to cancel"))->Expect.toBe(true)
  )
  t->expect(text()->String.includes("Access remains active until"))->Expect.toBe(true)
  t->expect(text()->String.includes("Trial canceled"))->Expect.toBe(false)
})

testAsync("ongoing trials do not show a cancellation notice", async t => {
  renderBilling(~status="trialing", ~remaining=0, ~cancelAt="null", ~canceledAt="null")
  await waitFor(() => t->expect(text()->String.includes("Manage in Stripe"))->Expect.toBe(true))
  t->expect(text()->String.includes("Trial canceled"))->Expect.toBe(false)
  t->expect(text()->String.includes("Subscription scheduled to cancel"))->Expect.toBe(false)
})
