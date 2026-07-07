open Vitest

let parseStatus = json =>
  JSON.parseOrThrow(json)->S.decodeOrThrow(~from=S.json, ~to=Client__Billing.statusSchema)

let activeStatus = parseStatus(`{
  "status": "active",
  "access_allowed": true,
  "has_billing_customer": true,
  "interval": "monthly",
  "current_period_end": null,
  "trial_end": null,
  "cancel_at": null,
  "canceled_at": null
}`)

describe("Client__Billing", _t => {
  test("parses billing status wire payload", t => {
    let status = parseStatus(`{
      "status": "past_due",
      "access_allowed": false,
      "has_billing_customer": true,
      "interval": "yearly",
      "current_period_end": null,
      "trial_end": null,
      "cancel_at": null,
      "canceled_at": null
    }`)

    t->expect(Client__Billing.subscriptionStatus(status))->Expect.toEqual(Client__Billing.PastDue)
    t->expect(Client__Billing.interval(status))->Expect.toEqual(Some(Client__Billing.Yearly))
    t->expect(Client__Billing.isAccessAllowed(status))->Expect.toBe(false)
  })

  test("parses live billing update date fields", t => {
    let status = parseStatus(`{
      "status": "trialing",
      "access_allowed": true,
      "has_billing_customer": true,
      "interval": "monthly",
      "current_period_end": "2026-05-31T16:04:41Z",
      "trial_end": "2026-05-31T16:04:41Z",
      "cancel_at": "2026-05-31T16:04:41Z",
      "canceled_at": "2026-05-18T15:20:44Z"
    }`)

    t
    ->expect(Client__Billing.currentPeriodEnd(status))
    ->Expect.toEqual(Some("2026-05-31T16:04:41Z"))
    t->expect(Client__Billing.cancelAt(status))->Expect.toEqual(Some("2026-05-31T16:04:41Z"))
  })

  test("preserves unknown subscription statuses", t => {
    let status = parseStatus(`{
      "status": "paused",
      "access_allowed": false,
      "has_billing_customer": true,
      "interval": null,
      "current_period_end": null,
      "trial_end": null,
      "cancel_at": null,
      "canceled_at": null
    }`)

    t
    ->expect(Client__Billing.subscriptionStatus(status))
    ->Expect.toEqual(Client__Billing.UnknownSubscriptionStatus("paused"))
    t->expect(Client__Billing.statusLabel(status))->Expect.toBe("paused")
  })

  test("derives app access from billing state", t => {
    t
    ->expect(Client__Billing.accessAllowed(Client__Billing.Loaded(activeStatus)))
    ->Expect.toBe(true)
    t->expect(Client__Billing.accessAllowed(Client__Billing.NotLoaded))->Expect.toBe(false)
    t->expect(Client__Billing.accessAllowed(Client__Billing.Error("boom")))->Expect.toBe(false)
  })
})
