open Vitest

module Reducer = Client__State__StateReducer

@module("react-dom/client")
external createRoot: WebAPI.DomTypes.element => ReactDOM.Client.Root.t = "createRoot"
@module("react-dom") external flushSync: (unit => unit) => unit = "flushSync"

test("WordPress login recovery is deduplicated and independent of Frontman authentication", t => {
  let initial = {...Reducer.defaultState, connection: Client__ConnectionTestHelpers.ready()}
  let loginUrl = Some("https://example.test/subdir/wp-login.php?redirect_to=frontman")
  let (state, effects) = Reducer.next(initial, WordPressAuthenticationRequired(loginUrl))
  t->expect(state.wordPressLoginRecovery)->Expect.toEqual(Some({loginUrl: loginUrl}))
  t->expect(state.connection)->Expect.toEqual(initial.connection)
  t->expect(state.tasks)->Expect.toEqual(initial.tasks)
  t->expect(state.currentTask)->Expect.toEqual(initial.currentTask)
  t->expect(effects)->Expect.toEqual([])
  let (duplicate, duplicateEffects) = Reducer.next(state, WordPressAuthenticationRequired(None))
  t->expect(duplicate == state)->Expect.toBe(true)
  t->expect(duplicateEffects)->Expect.toEqual([])
  let (afterSuccess, _) = Reducer.next(state, WordPressUpdatesChecked(None))
  t->expect(afterSuccess.wordPressLoginRecovery)->Expect.toEqual(state.wordPressLoginRecovery)
  let (reloaded, reloadEffects) = Reducer.next(state, ReloadAfterWordPressLogin)
  t->expect(reloaded == state)->Expect.toBe(true)
  t->expect(reloadEffects)->Expect.toEqual([Reducer.ReloadFrontman])
})

test("login recovery banner has an accessible native link and explicit reload", t => {
  let original = StateStore.getState(Client__State__Store.store)
  let loginUrl = "https://example.test/subdir/wp-login.php?redirect_to=frontman"
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    {
      ...original,
      wordPressLoginRecovery: Some({loginUrl: Some(loginUrl)}),
    },
  )
  let container = WebAPI.DomGlobal.document->WebAPI.Document.createElement("div")
  let root = createRoot(container)
  flushSync(() => root->ReactDOM.Client.Root.render(<Client__WordPressLoginBanner />))
  let markup = container.innerHTML
  flushSync(() => root->ReactDOM.Client.Root.unmount())
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    original,
  )
  t->expect(markup->String.includes("role=\"alert\""))->Expect.toBe(true)
  t->expect(markup->String.includes(`href="${loginUrl}"`))->Expect.toBe(true)
  t->expect(markup->String.includes("target=\"_blank\""))->Expect.toBe(true)
  t->expect(markup->String.includes("Reload Frontman"))->Expect.toBe(true)
  t->expect(markup->String.includes("ask the agent to continue"))->Expect.toBe(true)
  t->expect(markup->String.split("role=\"alert\"")->Array.length)->Expect.toBe(2)
})

test("missing optional login URL keeps recovery instructions and reload without a link", t => {
  let original = StateStore.getState(Client__State__Store.store)
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    {
      ...original,
      wordPressLoginRecovery: Some({loginUrl: None}),
    },
  )
  let container = WebAPI.DomGlobal.document->WebAPI.Document.createElement("div")
  let root = createRoot(container)
  flushSync(() => root->ReactDOM.Client.Root.render(<Client__WordPressLoginBanner />))
  let markup = container.innerHTML
  flushSync(() => root->ReactDOM.Client.Root.unmount())
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    original,
  )
  t->expect(markup->String.includes("href="))->Expect.toBe(false)
  t->expect(markup->String.includes("WordPress login required"))->Expect.toBe(true)
  t->expect(markup->String.includes("ask the agent to continue"))->Expect.toBe(true)
  t->expect(markup->String.includes("Reload Frontman"))->Expect.toBe(true)
})
