open Vitest
open WebAPI
open Client__ActivationBrowserHelpers

beforeEach(setup)
afterEach(() => {
  cleanup()
  Client__ActivationTestHelpers.unstubAllGlobals()
})

[
  ("active", "monthly"),
  ("active", "yearly"),
  ("trialing", "monthly"),
  ("trialing", "yearly"),
]->Array.forEach(((status, interval)) =>
  testAsync(`existing ${status} ${interval} plans do not assume a renewal price`, async t => {
    let billing = S.parseOrThrow(
      JSON.parseOrThrow(
        `{"status":"${status}","access_allowed":true,"has_billing_customer":true,"interval":"${interval}","current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`,
      ),
      ~to=Billing.statusSchema,
    )
    force({...StateStore.getState(Client__State__Store.store), billingStatus: Loaded(billing)})
    render(<Client__SettingsModal__Tab__Billing />)
    await waitFor(() => t->expect(query("button")->Option.isSome)->Expect.toBe(true))
    let text = (container.contents->Option.getOrThrow :> DomTypes.node).textContent->Null.getOrThrow
    t->expect(text->String.includes("Manage in Stripe"))->Expect.toBe(true)
    t
    ->expect(
      text->String.includes(Billing.intervalLabel(Billing.interval(billing)->Option.getOrThrow)),
    )
    ->Expect.toBe(true)
    t->expect(text->String.includes("Renewal price"))->Expect.toBe(false)
    t->expect(text->String.includes("€"))->Expect.toBe(false)
    t->expect(text->String.includes("See your offer"))->Expect.toBe(false)
  })
)

[Billing.Monthly, Billing.Yearly]->Array.forEach(interval =>
  testAsync(
    `billing settings launch ${Billing.intervalLabel(interval)} checkout directly`,
    async t => {
      let calls = ref([])
      let navigations = ref([])
      let tab = makeBillingTab(
        ~closed=false,
        ~close=() => (),
        ~location={"assign": url => navigations.contents->Array.push(url)},
      )
      spyOn(WebAPI.Window.current, "open")->mockImplementation(
        (_: string, _: string) => Null.make(tab),
      )
      Client__EmbeddedAuth.saveToken("billing-settings-test")
      Client__ActivationTestHelpers.stubGlobal(
        "fetch",
        (url: string, init: WebAPI.FetchTypes.requestInit) => {
          calls.contents->Array.push((url, init.body))
          Promise.resolve(
            WebAPI.Response.fromString(
              switch url->String.endsWith("/status") {
              | true =>
                loaded(false, false)
                ->S.decodeOrThrow(~from=Billing.statusSchema, ~to=S.json->S.noValidation(true))
                ->JSON.stringify
              | false => `{"url":"https://billing.stripe.test/session"}`
              },
              ~init={status: 200},
            ),
          )
        },
      )
      force({
        ...Reducer.defaultState,
        connection: Client__ConnectionTestHelpers.ready(~apiBaseUrl="https://api.example"),
        settingsModalTab: Some(Billing),
        billingStatus: Loaded(loaded(false, false)),
      })
      render(<Client__SettingsModal__Tab__Billing />)
      let button = page->getByRole("button", {name: `Choose ${Billing.intervalLabel(interval)}`})
      await button->click
      await waitFor(
        () =>
          t
          ->expect(navigations.contents)
          ->Expect.toEqual(["about:blank", "https://billing.stripe.test/session"]),
      )
      let body = switch interval {
      | Monthly => `{"interval":"monthly"}`
      | Yearly => `{"interval":"yearly"}`
      }
      let (url, requestBody) = calls.contents->Array.get(0)->Option.getOrThrow
      t->expect(url)->Expect.toBe("https://api.example/api/billing/checkout")
      t->expect(requestBody)->Expect.toEqual(Some(WebAPI.BodyInit.fromString(body)))
      t->expect(query("button[disabled]")->Option.isSome)->Expect.toBe(true)
      await page->getByRole("button", {name: "Canceled checkout? Choose again"})->click
      await button->click
      await waitFor(() => t->expect(calls.contents->Array.length)->Expect.toBe(3))
      let state = StateStore.getState(Client__State__Store.store)
      t->expect(state.settingsModalTab)->Expect.toEqual(Some(Billing))
      t->expect(Client__State.Selectors.messages(state)->Array.length)->Expect.toBe(0)
    },
  )
)
