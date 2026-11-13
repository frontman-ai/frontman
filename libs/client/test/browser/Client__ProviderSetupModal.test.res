open Vitest
open WebAPI
open Client__ActivationBrowserHelpers

afterEach(cleanup)

let renderSetup = (~assistant=false) =>
  render(
    <Client__ProviderSetupModal
      open_=true
      onOpenSettings={() => Client__State.Actions.openSettingsModalOnProviders()}
      onConnectAssistant=?{assistant
        ? Some(Client__State.Actions.openWordPressAssistantSetup)
        : None}
    />,
  )

testAsync("provider setup opens Providers", async t => {
  force(Initialization.defaultState)
  renderSetup()
  await waitFor(() =>
    t->expect(query("[data-slot='dialog-content']")->Option.isSome)->Expect.toBe(true)
  )
  let text = DomGlobal.document.body->HTMLElement.asElement->Element.asNode
  let text = text.textContent->Null.getOrThrow
  t->expect(text->String.includes("Connect your agent"))->Expect.toBe(false)
  t->expect(text->String.includes("Connect your account or add an API key"))->Expect.toBe(true)
  await page->getByRole("button", {name: "Connect AI provider"})->click
  await waitFor(() =>
    t
    ->expect(StateStore.getState(Client__State__Store.store).settingsModalTab)
    ->Expect.toEqual(Some(Providers))
  )
})

testAsync(
  "WordPress assistant setup explains requirements and opens General without provider setup",
  async t => {
    await page->viewport(1280, 720)
    force(Initialization.defaultState)
    renderSetup(~assistant=true)
    await waitFor(() => {
      let text = DomGlobal.document.body->HTMLElement.asElement->Element.asNode
      let text = text.textContent->Null.getOrThrow
      t->expect(query("h2[data-slot='dialog-title']")->Option.isSome)->Expect.toBe(true)
      t->expect(text->String.includes(`Let’s get you started`))->Expect.toBe(true)
      t
      ->expect(text->String.includes("how would you like to work with frontman?"))
      ->Expect.toBe(true)
      t->expect(text->String.includes("From your favorite agent"))->Expect.toBe(true)
      t->expect(text->String.includes("Here, with a live preview"))->Expect.toBe(true)
      t->expect(text->String.includes("Make my homepage headline clearer."))->Expect.toBe(true)
      t->expect(text->String.includes("ChatGPT"))->Expect.toBe(false)
    })
    let colorOf = selector =>
      WebAPI.Window.getComputedStyle(WebAPI.Window.current, ~elt=query(selector)->Option.getOrThrow)
    t->expect(colorOf(".frontman-onboarding").backgroundColor)->Expect.toBe("rgb(2, 6, 23)")
    t
    ->expect(colorOf(".frontman-onboarding section").backgroundColor)
    ->Expect.toBe("rgb(15, 23, 42)")
    t
    ->expect(colorOf(".frontman-onboarding button").backgroundColor)
    ->Expect.toBe("rgb(136, 71, 217)")
    t->expect(colorOf(".frontman-onboarding button").color)->Expect.toBe("rgb(248, 250, 252)")
    let _ = await page->screenshot({path: "node_modules/.cache/frontman-onboarding-brand.png"})
    await page->getByRole("button", {name: "Connect your agent"})->click
    await waitFor(() => {
      let state = StateStore.getState(Client__State__Store.store)
      t->expect(state.settingsModalTab)->Expect.toEqual(Some(General))
      t->expect(state.wordPressAssistantSetupSelected)->Expect.toBe(true)
      t->expect(state.configOptions)->Expect.toEqual(None)
    })
    let text = DomGlobal.document.body->HTMLElement.asElement->Element.asNode
    let text = text.textContent->Null.getOrThrow
    t
    ->expect(text->String.includes("No additional AI API key needed for Frontman."))
    ->Expect.toBe(true)
    t->expect(text->String.includes("active Frontman subscription or trial"))->Expect.toBe(true)
    t->expect(text->String.includes("active paid Frontman subscription"))->Expect.toBe(false)
    t->expect(text->String.includes("WordPress administrator access"))->Expect.toBe(true)
    t->expect(text->String.includes("Use the same Frontman account"))->Expect.toBe(true)

    Client__State.Actions.closeSettingsModal()
    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.settingsModalTab)->Expect.toEqual(None)
    t
    ->expect(Client__State__Selectors.providerSetupPromptRequired(state, Wordpress))
    ->Expect.toBe(false)
  },
)

testAsync("WordPress editor setup still opens Providers", async t => {
  await page->viewport(640, 360)
  force(Initialization.defaultState)
  renderSetup(~assistant=true)
  await page->getByRole("button", {name: "Edit in Frontman"})->click
  await waitFor(() => {
    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.settingsModalTab)->Expect.toEqual(Some(Providers))
    t->expect(state.wordPressAssistantSetupSelected)->Expect.toBe(false)
  })
})
