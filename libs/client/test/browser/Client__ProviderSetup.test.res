open Vitest
open WebAPI
open Client__ActivationBrowserHelpers

@send external selectOptions: (locator, string) => promise<unit> = "selectOptions"
@send external getByLabelText: (page, string) => locator = "getByLabelText"

beforeEach(() => {
  setup()
  Client__EmbeddedAuth.saveToken("provider-setup-test")
  Client__ActivationTestHelpers.stubGlobal("fetch", (url: string) => {
    let body = switch url->String.split("/api/")->Array.get(1)->Option.getOrThrow {
    | "user/api-keys" => `{"providers":[]}`
    | "user/custom-providers" => `{"data":[]}`
    | "oauth/anthropic/status" | "oauth/openai/status" => `{"connected":false}`
    | _ => failwith(`Unexpected provider request: ${url}`)
    }
    Promise.resolve(WebAPI.Response.fromString(body, ~init={status: 200}))
  })
  force({
    ...Reducer.defaultState,
    connection: Client__ConnectionTestHelpers.ready(),
    settingsModalTab: Some(ProviderSetup),
    composerDraft: "Make signup clearer",
    billingStatus: Loaded(loaded(true, false)),
    selectedModelValue: Some("model"),
  })
})
afterEach(() => {
  cleanup()
  Client__ActivationTestHelpers.unstubAllGlobals()
})

module Provider = {
  @react.component
  let make = () => {
    let tab = Client__State.useSelector(Client__State.Selectors.settingsModalTab)
    <Client__SettingsModal
      open_={tab == Some(ProviderSetup)}
      setup=true
      initialTab="providers"
      onOpenChange={open_ => {
        switch open_ {
        | false => Client__State.Actions.closeSettingsModal()
        | true => ()
        }
      }}
    />
  }
}

testAsync("focused provider setup carries the request and fits mobile", async t => {
  await page->viewport(390, 844)
  render(<Provider />)
  await waitFor(() => t->expect(query("select")->Option.isSome)->Expect.toBe(true))
  let dialog = query("[role=dialog]")->Option.getOrThrow
  let rect = dialog->Element.getBoundingClientRect
  t->expect(rect.left >= 0. && rect.right <= 390.)->Expect.toBe(true)
  t->expect(rect.top >= 0. && rect.bottom <= 844.)->Expect.toBe(true)
  t
  ->expect(
    (dialog :> DomTypes.node).textContent->Null.getOrThrow->String.includes("Make signup clearer"),
  )
  ->Expect.toBe(true)
  let _ = await page->screenshot({path: "../../dist/frontman-provider-mobile.png"})
  await page->getByRole("button", {name: "Review my request"})->click
  await waitFor(() => t->expect(query("[role=dialog]")->Option.isNone)->Expect.toBe(true))
  let state = StateStore.getState(Client__State__Store.store)
  t->expect(state.composerDraft)->Expect.toBe("Make signup clearer")
  t->expect(Client__State.Selectors.messages(state)->Array.length)->Expect.toBe(0)
})

testAsync("unsaved provider inputs stay visible until saved or cleared", async t => {
  render(<Provider />)
  let chooser = page->getByRole("combobox", {name: "1. Choose your provider"})
  await chooser->selectOptions("openrouter")
  let input = page->getByLabelText("OpenRouter API key")
  await input->fill("unsaved-key")
  await waitFor(() => t->expect(query("select[disabled]")->Option.isSome)->Expect.toBe(true))
  t
  ->expect(
    (query("[role=dialog]")->Option.getOrThrow :> DomTypes.node).textContent
    ->Null.getOrThrow
    ->String.includes("Save or clear your changes before switching providers."),
  )
  ->Expect.toBe(true)
  await input->fill("")
  await waitFor(() => t->expect(query("select[disabled]")->Option.isNone)->Expect.toBe(true))
  await chooser->selectOptions("openai")
  await page->getByRole("button", {name: "Review my request"})->click
  await waitFor(() => t->expect(query("[role=dialog]")->Option.isNone)->Expect.toBe(true))
  t
  ->expect(StateStore.getState(Client__State__Store.store).composerDraft)
  ->Expect.toBe("Make signup clearer")
})

testAsync("closing focused setup returns without sending the draft", async t => {
  render(<Provider />)
  await page->getByRole("button", {name: "Close settings"})->click
  await waitFor(() => t->expect(query("[role=dialog]")->Option.isNone)->Expect.toBe(true))
  let state = StateStore.getState(Client__State__Store.store)
  t->expect(state.composerDraft)->Expect.toBe("Make signup clearer")
  t->expect(Client__State.Selectors.messages(state)->Array.length)->Expect.toBe(0)
})
