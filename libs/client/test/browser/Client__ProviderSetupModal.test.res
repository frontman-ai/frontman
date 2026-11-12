open Vitest
open WebAPI
open Client__ActivationBrowserHelpers

afterEach(cleanup)

let renderSetup = () =>
  render(
    <Client__ProviderSetupModal
      open_=true
      onOpenSettings={() => Client__State.Actions.openSettingsModalOnProviders()}
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
  t->expect(text->String.includes("Connect an AI assistant"))->Expect.toBe(false)
  t->expect(text->String.includes("Connect your account or add an API key"))->Expect.toBe(true)
  await page->getByRole("button", {name: "Connect AI provider"})->click
  await waitFor(() =>
    t
    ->expect(StateStore.getState(Client__State__Store.store).settingsModalTab)
    ->Expect.toEqual(Some(Providers))
  )
})
