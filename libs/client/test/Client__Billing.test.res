open Vitest

let parseStatus = json =>
  JSON.parseOrThrow(json)->S.decodeOrThrow(~from=S.json, ~to=Client__Billing.statusSchema)

let activeStatus = parseStatus(`{
  "status": "active",
  "can_start_turn": true,
  "has_billing_customer": true,
  "interval": "monthly",
  "current_period_end": null,
  "trial_end": null,
  "cancel_at": null,
  "canceled_at": null
}`)

describe("Client__Billing", _t => {
  test("only advertises a positive server-confirmed trial for eligible checkout users", t => {
    [
      (true, 14, false, Some(14)),
      (true, 7, false, Some(7)),
      (false, 7, false, None),
      (true, 0, false, None),
      (true, 7, true, Some(7)),
    ]->Array.forEach(
      ((eligible, days, access, expected)) => {
        let status = parseStatus(
          `{"status":"none","can_start_turn":${Bool.toString(
              access,
            )},"has_billing_customer":false,"trial_eligible":${Bool.toString(
              eligible,
            )},"trial_days":${Int.toString(days)},"pretrial_runs_remaining":${access
              ? "5"
              : "0"},"interval":null,"current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`,
        )
        t->expect(Client__Billing.offeredTrialDays(status))->Expect.toEqual(expected)
      },
    )
    t->expect(Client__Billing.offeredTrialDays(activeStatus))->Expect.toBeNone
  })

  test("keeps no-card runs separate from trial billing", t => {
    let status = parseStatus(`{
      "status": "none",
      "can_start_turn": true,
      "pretrial_runs_remaining": 5,
      "has_billing_customer": false,
      "trial_eligible": true,
      "trial_days": 7,
      "interval": null,
      "current_period_end": null,
      "trial_end": null,
      "cancel_at": null,
      "canceled_at": null
    }`)

    t->expect(Client__Billing.pretrialRunsRemaining(status))->Expect.toEqual(Some(5))
    t->expect(Client__Billing.offeredTrialDays(status))->Expect.toEqual(Some(7))
    t
    ->expect(Client__Billing.activationMessage(status))
    ->Expect.toBe(
      "Your remaining lifetime BYOK runs are available without a card. Pro access does not use these runs; unused runs stay available afterwards. AI usage is billed separately by your provider.",
    )
  })

  test("parses billing status wire payload", t => {
    let status = parseStatus(`{
      "status": "past_due",
      "can_start_turn": false,
      "has_billing_customer": true,
      "interval": "yearly",
      "current_period_end": null,
      "trial_end": null,
      "cancel_at": null,
      "canceled_at": null
    }`)

    t->expect(Client__Billing.subscriptionStatus(status))->Expect.toEqual(Client__Billing.PastDue)
    t->expect(Client__Billing.interval(status))->Expect.toEqual(Some(Client__Billing.Yearly))
    t->expect(Client__Billing.canStartTurn(status))->Expect.toBe(false)
  })

  test("checkout eligibility is separate from usage access", t => {
    [
      ("active", true, false),
      ("trialing", true, false),
      ("past_due", false, false),
      ("past_due", true, false),
      ("unpaid", true, true),
      ("none", false, true),
      ("canceled", false, true),
      ("canceled", true, true),
      ("incomplete", true, true),
      ("none", true, true),
      ("incomplete", false, true),
      ("incomplete_expired", false, true),
      ("unpaid", false, true),
    ]->Array.forEach(
      ((subscriptionStatus, accessAllowed, expected)) => {
        let status = parseStatus(
          `{"status":"${subscriptionStatus}","can_start_turn":${Bool.toString(
              accessAllowed,
            )},"pretrial_runs_remaining":${switch subscriptionStatus {
            | "active" | "trialing" => "null"
            | _ => accessAllowed ? "4" : "0"
            }},"has_billing_customer":true,"interval":null,"current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`,
        )
        t->expect(Client__Billing.canStartCheckout(status))->Expect.toBe(expected)
        switch Client__Billing.subscriptionStatus(status) {
        | PastDue if !accessAllowed =>
          t->expect(Client__Billing.canStartTurn(status))->Expect.toBe(false)
          t->expect(Client__Billing.canManage(status))->Expect.toBe(true)
          t
          ->expect(Client__Billing.activationMessage(status))
          ->Expect.toBe("Your payment failed. Manage billing in Stripe to restore access.")
        | _
          if accessAllowed && subscriptionStatus != "active" && subscriptionStatus != "trialing" =>
          t
          ->expect(Client__Billing.activationMessage(status)->String.includes("runs are available"))
          ->Expect.toBe(true)
          t
          ->expect(
            Client__Billing.activationMessage(status)->String.includes("Start a subscription"),
          )
          ->Expect.toBe(false)
        | _ => ()
        }
      },
    )
  })

  test("trial checkout is available at every allowance balance", t => {
    [0, 1, 2, 3, 4, 5]->Array.forEach(
      remaining => {
        let status = parseStatus(
          `{"status":"none","can_start_turn":${Bool.toString(
              remaining > 0,
            )},"pretrial_runs_remaining":${Int.toString(
              remaining,
            )},"has_billing_customer":false,"trial_eligible":true,"trial_days":7,"interval":null,"current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`,
        )
        t->expect(Client__Billing.canStartCheckout(status))->Expect.toBe(true)
        t
        ->expect(Client__Billing.offeredTrialDays(status))
        ->Expect.toEqual(Some(7))
      },
    )
    t
    ->expect(
      Client__Billing.canStartCheckout(
        parseStatus(`{"status":"none","can_start_turn":false,"has_billing_customer":false,"interval":null,"current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`),
      ),
    )
    ->Expect.toBe(true)
  })

  test("parses live billing update date fields", t => {
    let status = parseStatus(`{
      "status": "trialing",
      "can_start_turn": true,
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
    t->expect(Client__Billing.trialEnd(status))->Expect.toEqual(Some("2026-05-31T16:04:41Z"))
  })

  test("preserves unknown subscription statuses", t => {
    let status = parseStatus(`{
      "status": "paused",
      "can_start_turn": false,
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
    ->expect(Client__Billing.canStartTurnFromState(Client__Billing.Loaded(activeStatus)))
    ->Expect.toBe(true)
    t->expect(Client__Billing.canStartTurnFromState(Client__Billing.NotLoaded))->Expect.toBe(false)
    t
    ->expect(Client__Billing.canStartTurnFromState(Client__Billing.Error("boom")))
    ->Expect.toBe(false)
  })
})
