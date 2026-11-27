open Vitest
open WebAPI
open Client__ActivationBrowserHelpers

@get external getRuntime: Window.t => Nullable.t<JSON.t> = "__frontmanRuntime"
@set external setRuntime: (Window.t, Nullable.t<JSON.t>) => unit = "__frontmanRuntime"

let previousRuntime = ref(Nullable.null)
let previousHtmlClass = ref("")

beforeEach(() => {
  let html = query("html")->Option.getOrThrow
  previousHtmlClass := html->Element.getAttribute("class")->Null.getOr("")
  html->Element.setAttribute(~qualifiedName="class", ~value="dark")
  previousRuntime := getRuntime(Window.current)
  setRuntime(Window.current, Nullable.make(JSON.parseOrThrow(`{"framework":"wordpress","wordpressSettingsUrl":"https://example.test/wp-admin/admin.php?page=frontman"}`)))
  let config = DomGlobal.document->Document.createElement("div")
  config->Element.setAttribute(~qualifiedName="id", ~value="frontman-runtime-config")
  config->Element.setAttribute(~qualifiedName="data-frontman-intent", ~value="assistant")
  DomGlobal.document.body->HTMLElement.appendChild(config->Element.asNode)->ignore
})

afterEach(() => {
  cleanup()
  query("html")
  ->Option.getOrThrow
  ->Element.setAttribute(~qualifiedName="class", ~value=previousHtmlClass.contents)
  query("#frontman-runtime-config")->Option.forEach(Element.remove)
  setRuntime(Window.current, previousRuntime.contents)
})

let expectSetup = async (t, expectedText) => {
  await waitFor(() => {
    let content = query(".assistant-setup-card, [data-slot='dialog-content']")->Option.getOrThrow
    let text = (content->Element.asNode).textContent->Null.getOrThrow
    t->expect(text->String.includes(expectedText))->Expect.toBe(true)
    t->expect(Window.getComputedStyle(Window.current, ~elt=content).opacity)->Expect.toBe("1")
  })
}

// Synthetic local states exercise the production card, CSS and state actions.
// Card-only fixtures do not mount App's connection-fetch effect.
let _ = [
  ("unlinked", Client__State__Types.WordPressUnlinked),
  ("linked", WordPressLinked({enabled: true})),
]
->Array.forEach(((name, status)) =>
  testAsync(`assistant arrival shows focused connection: ${name}`, async t => {
    await page->viewport(1280, 800)
    force({
      ...Initialization.defaultState,
      connection: Client__ConnectionTestHelpers.ready(),
      wordPressConnectionStatus: status,
      userProfile: Some({id: "local-fixture", email: "owner@example.test", name: Some("Site owner")}),
    })
    t->expect(Client__RuntimeConfig.read().assistantSetupRequested)->Expect.toBe(true)
    Client__State.Actions.startWordPressAssistantArrival()
    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.settingsModalTab)->Expect.toEqual(None)
    t
    ->expect(Client__State__Selectors.providerSetupPromptRequired(state, Wordpress))
    ->Expect.toBe(false)
    render(<Client__AssistantSetup />)
    await expectSetup(
      t,
      name == "linked"
        ? "Your original assistant setup tab updates automatically"
        : "Enable MCP and connect",
    )
    t->expect(query("[data-slot='dialog-content']")->Option.isNone)->Expect.toBe(true)
    let text = query(".assistant-setup-card")->Option.getOrThrow->Element.asNode
    t->expect(text.textContent->Null.getOrThrow->String.includes("Providers"))->Expect.toBe(false)
    await page->getByRole("button", {name: "Open Frontman editor instead"})->click
    let state = StateStore.getState(Client__State__Store.store)
    t->expect(state.wordPressAssistantArrival)->Expect.toEqual(Some(false))
    t->expect(state.wordPressAssistantSetupSelected)->Expect.toBe(false)
  })
)

testAsync("disabled connection offers enable, not a completed handoff", async t => {
  force({...Initialization.defaultState, connection: Client__ConnectionTestHelpers.ready(), wordPressConnectionStatus: WordPressLinked({enabled: false})})
  render(<Client__AssistantSetup />)
  await waitFor(() => {
    let text = query(".assistant-setup-card")->Option.getOrThrow->Element.asNode
    t->expect(text.textContent->Null.getOrThrow->String.includes("Enable MCP"))->Expect.toBe(true)
    t->expect(text.textContent->Null.getOrThrow->String.includes("Return"))->Expect.toBe(false)
    t->expect(text.textContent->Null.getOrThrow->String.includes("updates automatically"))->Expect.toBe(false)
  })
})

testAsync("connecting remains pending without a second approval", async t => {
  force({...Initialization.defaultState, connection: Client__ConnectionTestHelpers.ready(), wordPressConnectionStatus: WordPressLinking})
  render(<Client__AssistantSetup />)
  await waitFor(() => {
    let button = query(".assistant-setup-card button[disabled]")->Option.getOrThrow
    t->expect(button->Element.asNode->Node.textContent->Null.getOrThrow)->Expect.toBe("Connecting...")
  })
})

testAsync("assistant arrival keeps authentication visible and restores the focused card", async t => {
  let connection: Client__ConnectionReducer.state = {
    config: Client__ConnectionTestHelpers.config(),
    connection: Ok(Some({
      lifetimeAbortController: WebAPI.AbortController.make(),
      phase: WaitingForAuthentication({loginUrl: "https://auth.example.test/sign-in"}),
    })),
  }
  force({...Initialization.defaultState, connection: Some(connection)})
  render(<Client__App />)
  await waitFor(() => {
    let text = query("[data-slot='dialog-content']")->Option.getOrThrow->Element.asNode
    t->expect(text.textContent->Null.getOrThrow->String.includes("Welcome to Frontman"))->Expect.toBe(true)
    t->expect(query(".assistant-setup-card")->Option.isNone)->Expect.toBe(true)
    t->expect(StateStore.getState(Client__State__Store.store).settingsModalTab)->Expect.toEqual(None)
  })
  let state = StateStore.getState(Client__State__Store.store)
  force({...state, connection: None, wordPressConnectionStatus: WordPressUnlinked})
  await waitFor(() => {
    t->expect(query(".assistant-setup-card")->Option.isSome)->Expect.toBe(true)
    t->expect(query("[data-slot='dialog-content']")->Option.isNone)->Expect.toBe(true)
  })
})

let _ = [
  Client__ConnectionReducer.ACPError("Unable to connect to Frontman."),
  RelayError("Unable to connect to the site relay."),
]->Array.forEach(error =>
  testAsync("assistant arrival exposes initial connection failure recovery", async t => {
    force({
      ...Initialization.defaultState,
      connection: Some({
        config: Client__ConnectionTestHelpers.config(),
        connection: Error(error),
      }),
    })
    render(<Client__App />)
    await waitFor(() => {
      let text = query(".assistant-setup-card")->Option.getOrThrow->Element.asNode->Node.textContent->Null.getOrThrow
      let message = switch error {
      | ACPError(message) | RelayError(message) => message
      }
      t->expect(text->String.includes(message))->Expect.toBe(true)
      t->expect(text->String.includes("Reload Frontman"))->Expect.toBe(true)
      t->expect(text->String.includes("Check again"))->Expect.toBe(false)
      t->expect(text->String.includes("Enable MCP and connect"))->Expect.toBe(false)
      t->expect(query("[data-slot='dialog-content']")->Option.isNone)->Expect.toBe(true)
    })
  })
)

testAsync("assistant arrival waits for Frontman before offering site connection", async t => {
  force(Initialization.defaultState)
  render(<Client__App />)
  await waitFor(() => {
    let text = query(".assistant-setup-card")->Option.getOrThrow->Element.asNode->Node.textContent->Null.getOrThrow
    t->expect(text->String.includes("Connecting to Frontman..."))->Expect.toBe(true)
    t->expect(text->String.includes("Enable MCP and connect"))->Expect.toBe(false)
  })
})

testAsync("assistant arrival exposes WordPress sign-in and reload recovery", async t => {
  force({
    ...Initialization.defaultState,
    wordPressConnectionStatus: WordPressConnectionFailed("WordPress login required."),
  })
  Client__State__Store.dispatch(WordPressAuthenticationRequired(Some("https://example.test/wp-login.php")))
  render(<Client__App />)
  await waitFor(() => {
    let card = query(".assistant-setup-card")->Option.getOrThrow
    let text = card->Element.asNode->Node.textContent->Null.getOrThrow
    t->expect(text->String.includes("Log in to WordPress (new tab)"))->Expect.toBe(true)
    t->expect(text->String.includes("Reload Frontman"))->Expect.toBe(true)
    t->expect(text->String.includes("Check again"))->Expect.toBe(false)
    t->expect(text->String.includes("Providers"))->Expect.toBe(false)
    let login = query(".assistant-setup-card a")->Option.getOrThrow
    t->expect(login->Element.getAttribute("href")->Null.getOrThrow)->Expect.toBe("https://example.test/wp-login.php")
    t->expect(login->Element.getAttribute("target")->Null.getOrThrow)->Expect.toBe("_blank")
    t->expect(query("[data-slot='dialog-content']")->Option.isNone)->Expect.toBe(true)
  })
})

testAsync("direct editor keeps provider setup", async t => {
  await page->viewport(1280, 800)
  query("#frontman-runtime-config")
  ->Option.getOrThrow
  ->Element.setAttribute(~qualifiedName="data-frontman-intent", ~value="")
  force(Initialization.defaultState)
  t->expect(Client__RuntimeConfig.read().assistantSetupRequested)->Expect.toBe(false)
  render(
    <Client__ProviderSetupModal
      open_=true onOpenSettings=Client__State.Actions.openSettingsModalOnProviders
    />,
  )
  await expectSetup(t, "Connect AI provider")
  await page->getByRole("button", {name: "Connect AI provider"})->click
  let state = StateStore.getState(Client__State__Store.store)
  t->expect(state.wordPressAssistantSetupSelected)->Expect.toBe(false)
  t->expect(state.settingsModalTab)->Expect.toEqual(Some(Providers))
})
