open Vitest
open WebAPI
open Client__ActivationBrowserHelpers

beforeEach(() => {
  setup()
  force({
    ...StateStore.getState(Client__State__Store.store),
    settingsModalTab: Some(Activation),
    composerDraft: "Make the signup section clearer on mobile",
  })
})
afterEach(() => {
  cleanup()
  Client__ActivationTestHelpers.unstubAllGlobals()
})

[(false, "Enter"), (false, "Send"), (true, "Enter"), (true, "Send")]->Array.forEach(((
  access,
  control,
)) =>
  testAsync(
    `chat ${control} prepares ${access ? "provider" : "plan"} setup without sending`,
    async t => {
      force({
        ...Reducer.defaultState,
        connection: Client__ConnectionTestHelpers.ready(),
        billingStatus: Loaded(loaded(access, !access)),
      })
      render(<Client__Chatbox onConfigureProvider=Client__State.Actions.openProviderSetup />)
      await page
      ->getByRole("textbox", {name: "What would you like to change?"})
      ->fill("Make signup clearer")
      switch control {
      | "Enter" => await userEvent->keyboard("{Enter}")
      | _ => await page->getByRole("button", {name: "Send"})->click
      }
      await waitFor(
        () => {
          let state = StateStore.getState(Client__State__Store.store)
          t
          ->expect(state.settingsModalTab)
          ->Expect.toEqual(Some(access ? ProviderSetup : Activation))
          t->expect(state.composerDraft)->Expect.toBe("Make signup clearer")
          t->expect(Client__State.Selectors.messages(state)->Array.length)->Expect.toBe(0)
        },
      )
    },
  )
)

module Activation = {
  @react.component
  let make = () => {
    let tab = Client__State.useSelector(Client__State.Selectors.settingsModalTab)
    <Client__ActivationModal open_={tab == Some(Activation)} />
  }
}

[(1280, 900, "desktop"), (390, 844, "mobile")]->Array.forEach(((width, height, device)) =>
  testAsync(`activation preserves intent and fits ${device}`, async t => {
    await page->viewport(width, height)
    render(<Activation />)
    await waitFor(() => t->expect(query("[role=dialog]")->Option.isSome)->Expect.toBe(true))
    let dialog = query("[role=dialog]")->Option.getOrThrow
    let rect = dialog->Element.getBoundingClientRect
    t->expect(rect.left >= 0. && rect.right <= Int.toFloat(width))->Expect.toBe(true)
    t->expect(rect.top >= 0. && rect.bottom <= Int.toFloat(height))->Expect.toBe(true)
    await page->getByRole("radio", {name: "Yearly"})->click
    await waitFor(
      () =>
        t
        ->expect(
          (dialog :> DomTypes.node).textContent
          ->Null.getOrThrow
          ->String.includes("€150 per seat / year"),
        )
        ->Expect.toBe(true),
    )
    dialog->Element.scrollTo2(~x=0., ~y=0.)
    let text = (dialog :> DomTypes.node).textContent->Null.getOrThrow
    t->expect(text->String.split(" ")->Array.length <= 100)->Expect.toBe(true)
    t->expect(text->String.includes("14 days free"))->Expect.toBe(true)
    t->expect(text->String.includes("auto-renews unless canceled"))->Expect.toBe(true)
    t->expect(text->String.includes("Card required"))->Expect.toBe(true)
    t->expect(text->String.includes("provider usage billed separately"))->Expect.toBe(true)
    let cta = query("[role=dialog] button.w-full")->Option.getOrThrow->Element.getBoundingClientRect
    let terms =
      query("[role=dialog] p.leading-relaxed")->Option.getOrThrow->Element.getBoundingClientRect
    t->expect(cta.top >= rect.top && cta.bottom <= rect.bottom)->Expect.toBe(true)
    t->expect(terms.top >= rect.top && terms.bottom <= cta.top)->Expect.toBe(true)
    let _ = await page->screenshot({path: `../../dist/frontman-activation-${device}.png`})
    Client__State__Store.dispatch(BillingStatusReceived(loaded(true, false)))
    await page->getByRole("button", {name: "Connect my AI provider"})->click
    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.settingsModalTab)->Expect.toEqual(Some(ProviderSetup))
    t->expect(state.composerDraft)->Expect.toBe("Make the signup section clearer on mobile")
    t->expect(Client__State.Selectors.messages(state)->Array.length)->Expect.toBe(0)
  })
)

testAsync("ineligible accounts see a concise checkout offer without a trial promise", async t => {
  force({
    ...Reducer.defaultState,
    connection: Client__ConnectionTestHelpers.ready(),
    settingsModalTab: Some(Activation),
    billingStatus: Loaded(loaded(false, false)),
  })
  render(<Activation />)
  await waitFor(() => t->expect(query("[role=dialog]")->Option.isSome)->Expect.toBe(true))
  let text =
    (query("[role=dialog]")->Option.getOrThrow :> DomTypes.node).textContent->Null.getOrThrow
  t->expect(text->String.includes("Continue to checkout"))->Expect.toBe(true)
  t->expect(text->String.includes("€15 per seat / month"))->Expect.toBe(true)
  t->expect(text->String.includes("trial"))->Expect.toBe(false)
})
