open Vitest
open WebAPI
open Client__ActivationBrowserHelpers

afterEach(cleanup)

let renderSetup = (~isWordpress) =>
  render(
    <Client__ProviderSetupModal
      open_=true
      isWordpress
      onOpenSettings={() => Client__State.Actions.openSettingsModalOnProviders()}
      onOpenGeneralSettings={() => Client__State.Actions.openSettingsModal()}
    />,
  )

testAsync("WordPress shortcut opens General rather than Providers", async t => {
  force(Initialization.defaultState)
  renderSetup(~isWordpress=true)
  await page->getByRole("button", {name: "Connect an AI assistant"})->click
  await waitFor(() =>
    t
    ->expect(StateStore.getState(Client__State__Store.store).settingsModalTab)
    ->Expect.toEqual(Some(General))
  )
})

testAsync("other frameworks retain only provider setup", async t => {
  force(Initialization.defaultState)
  renderSetup(~isWordpress=false)
  await waitFor(() =>
    t->expect(query("[data-slot='dialog-content']")->Option.isSome)->Expect.toBe(true)
  )
  let text = DomGlobal.document.body->HTMLElement.asElement->Element.asNode
  let text = text.textContent->Null.getOrThrow
  t->expect(text->String.includes("Connect an AI assistant"))->Expect.toBe(false)
  await page->getByRole("button", {name: "Connect AI provider"})->click
  await waitFor(() =>
    t
    ->expect(StateStore.getState(Client__State__Store.store).settingsModalTab)
    ->Expect.toEqual(Some(Providers))
  )
})
