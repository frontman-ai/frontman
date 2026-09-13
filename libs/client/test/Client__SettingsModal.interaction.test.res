open Vitest
open FrontmanBindings.Bindings__Test__Vitest
module Dom = Test__Dom
module R = Test__React
module Types = Client__State__Types
module Reducer = Client__State__StateReducer
module Card = Client__SettingsModal.CustomProviderCard
module Section = Client__SettingsModal.CustomProvidersSection
let store = Client__State__Store.store
let saved: Types.customProvider = {
  id: "provider-1",
  name: "Unsaved provider",
  baseUrl: "https://old.example.com/v1",
  hasApiKey: false,
  models: ["old-model"],
  lockVersion: 1,
}
let latest = {...saved, name: "Latest provider", lockVersion: 3}
let root = ref(None)
let container = ref(None)
let element = () => container.contents->Option.getOrThrow
let input = hint => Dom.query(~root=element(), `input[placeholder="${hint}"]`)
let button = text =>
  element()
  ->WebAPI.Element.querySelectorAll("button")
  ->WebAPI.NodeList.toArray
  ->Array.find(button =>
    (button->WebAPI.Element.asNode).textContent->Null.getOrThrow->String.includes(text)
  )
  ->Option.getOrThrow
let mutation = () => StateStore.getState(store).customProviderMutation
let storage = WebAPI.Window.current->WebAPI.Window.localStorage
let setState = (~providers=[], ~mutation=Types.CustomProviderMutationIdle, ()) => {
  storage->WebAPI.Storage.setItem(~key="frontman:embeddedClientToken", ~value="test-token")
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    store,
    {
      ...Reducer.defaultState,
      acpSession: AcpSessionActive({
        sendPrompt: (_, ~sessionId as _, ~additionalBlocks as _, ~onComplete as _, ~_meta as _) =>
          (),
        sendSessionCommand: _ => (),
        loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
        deleteSession: (_, ~onComplete as _) => (),
        requireAuthentication: () => (),
        apiBaseUrl: "/api",
      }),
      customProviders: Some(providers),
      customProviderMutation: mutation,
    },
  )
}
let fail = operation =>
  setState(
    ~mutation=CustomProviderMutationFailed({operation, error: CustomProviderConflict(latest)}),
    (),
  )
let render = async component => {
  let node = Dom.document->WebAPI.Document.createElement("div")
  container := Some(node)
  let created = R.createRoot(node)
  root := Some(created)
  await R.act(async () => created->R.render(component))
}
let rerender = component => R.act(async () => root.contents->Option.getOrThrow->R.render(component))
let fill = (placeholder, value) => R.fill(input(placeholder), value)
let click = text => R.act(async () => button(text)->Dom.click)
let requests: ref<array<(string, WebAPI.Request.requestInit)>> = ref([])
let respond: ref<unit => Promise.t<WebAPI.Response.t>> = ref(() => Promise.make((_, _) => ()))
let updateRequest = async index => {
  let (_, init) = requests.contents->Array.get(index)->Option.getOrThrow
  let json = await WebAPI.Request.fromURL("https://settings.test/", ~init)->WebAPI.Request.json
  S.parseOrThrow(json, ~to=Reducer.customProviderUpdateRequestSchema)
}
let confirmCalls = ref([])
let confirmResult = ref(true)
beforeEach(() => {
  Dom.actEnvironment(WebAPI.Window.current, true)
  requests := []
  confirmCalls := []
  confirmResult := true
  respond := (() => Promise.make((_, _) => ()))
  vi->stubGlobal("fetch", (url: string, init: WebAPI.Request.requestInit) => {
    requests := requests.contents->Array.concat([(url, init)])
    respond.contents()
  })
  vi->stubGlobal("confirm", (message: string) => {
    confirmCalls := confirmCalls.contents->Array.concat([message])
    confirmResult.contents
  })
})
afterEachAsync(async () => {
  await R.act(async () => root.contents->Option.forEach(R.unmount))
  root := None
  container := None
  storage->WebAPI.Storage.removeItem("frontman:embeddedClientToken")
  vi->unstubAllGlobals
})

describe("provider settings state integration", _ => {
  testAsync("saving reconciles draft and resets API-key state", async t => {
    let updated = {...saved, name: "Saved provider", lockVersion: 2}
    respond :=
      (
        () =>
          Promise.resolve(
            WebAPI.Response.fromString(
              Reducer.jsonString({Types.provider: updated}, Types.customProviderResponseSchema),
            ),
          )
      )

    setState()
    await render(<Card provider={Some(saved)} />)
    await fill("Optional API key", "replacement-key")
    await click("Save")
    await rerender(<Card provider={Some(updated)} />)
    t->expect(input("Provider name")->Dom.value)->Expect.toBe(updated.name)
    t->expect(Dom.query(~root=element(), `input[type="password"]`)->Dom.value)->Expect.toBe("")
    respond := (() => Promise.make((_, _) => ()))
    await fill("Provider name", "Saved provider again")
    await click("Save")
    let (_, _, _, version, (action, _)) = await updateRequest(1)
    t->expect(version)->Expect.toBe(2)
    t->expect(action)->Expect.toBe("keep")
  })

  testAsync("provider actions share hierarchy and follow dirty state", async t => {
    setState()
    await render(<Card provider={Some(saved)} />)
    t->expect(button("Save").parentElement)->Expect.toBe(button("Cancel").parentElement)
    t->expect(button("Delete").parentElement)->Expect.toBe(button("Cancel").parentElement)
    t->expect(button("Save")->Dom.disabled)->Expect.toBe(true)
    t->expect(button("Cancel")->Dom.disabled)->Expect.toBe(true)
    await fill("Provider name", "Changed provider")
    t->expect(button("Save")->Dom.disabled)->Expect.toBe(false)
    t->expect(button("Cancel")->Dom.disabled)->Expect.toBe(false)
    await click("Cancel")
    t->expect(input("Provider name")->Dom.value)->Expect.toBe(saved.name)
    t->expect(button("Save")->Dom.disabled)->Expect.toBe(true)
    t->expect(button("Cancel")->Dom.disabled)->Expect.toBe(true)
  })

  testAsync("provider card reports unsaved changes", async t => {
    let dirty = ref(None)
    setState()
    await render(<Card provider={Some(saved)} onDirtyChange={value => dirty := Some(value)} />)
    t->expect(dirty.contents)->Expect.toEqual(Some(false))
    await fill("Provider name", "Changed provider")
    t->expect(dirty.contents)->Expect.toEqual(Some(true))
    await click("Cancel")
    t->expect(dirty.contents)->Expect.toEqual(Some(false))
  })

  test("settings close requires confirmation for unsaved changes", t => {
    let opened = ref(None)
    let change = value => opened := Some(value)
    confirmResult := false
    Client__SettingsModal.requestSettingsOpenChange(false, true, change)
    t
    ->expect(confirmCalls.contents)
    ->Expect.toEqual(["You have unsaved changes. Discard them and close?"])
    t->expect(opened.contents)->Expect.toEqual(None)
    confirmResult := true
    Client__SettingsModal.requestSettingsOpenChange(false, true, change)
    t->expect(opened.contents)->Expect.toEqual(Some(false))
    confirmCalls := []
    Client__SettingsModal.requestSettingsOpenChange(false, false, change)
    t->expect(confirmCalls.contents)->Expect.toEqual([])
    t->expect(opened.contents)->Expect.toEqual(Some(false))
  })

  testAsync("editing a model name updates the draft", async t => {
    setState()
    await render(<Card provider={Some(saved)} />)
    let model =
      element()
      ->WebAPI.Element.querySelectorAll("input")
      ->WebAPI.NodeList.toArray
      ->Array.find(input => input->Dom.value === "old-model")
      ->Option.getOrThrow
    await R.fill(model, "renamed-model")
    t->expect(button("Save")->Dom.disabled)->Expect.toBe(false)
    await click("Save")
    let (_, _, models, _, _) = await updateRequest(0)
    t->expect(models)->Expect.toEqual(["renamed-model"])
  })

  testAsync("conflicts require confirmation and use latest versions", async t => {
    setState()
    await render(<Card provider={Some(saved)} />)
    await fill("Optional API key", "replacement-key")
    await R.act(async () => fail(SavingCustomProvider(Some(saved.id))))
    confirmResult := false
    await click("Overwrite latest")
    t->expect(requests.contents)->Expect.toEqual([])
    confirmResult := true
    await click("Overwrite latest")
    let (name, _, _, version, _) = await updateRequest(0)
    t->expect((name, version))->Expect.toEqual((saved.name, 3))
    await R.act(async () => fail(DeletingCustomProvider(saved.id)))
    await click("Cancel delete")
    t->expect(input("Provider name")->Dom.value)->Expect.toBe(saved.name)
    t->expect(mutation())->Expect.toEqual(CustomProviderMutationIdle)
    await R.act(async () => fail(DeletingCustomProvider(saved.id)))
    await click("Delete latest")
    let (url, _) = requests.contents->Array.get(1)->Option.getOrThrow
    t->expect(url->String.includes("lock_version=3"))->Expect.toBe(true)
    await R.act(async () => fail(SavingCustomProvider(Some(saved.id))))
    await click("Load latest")
    t->expect(input("Provider name")->Dom.value)->Expect.toBe(latest.name)
    t->expect(input("Optional API key")->Dom.value)->Expect.toBe("")
    await click("Save")
    let (_, _, _, _, (action, _)) = await updateRequest(2)
    t->expect(action)->Expect.toBe("keep")
  })

  testAsync("section recovers and acknowledges terminal mutations", async t => {
    setState(
      ~mutation=CustomProviderMutationFailed({
        operation: SavingCustomProvider(None),
        error: CustomProviderNotFound,
      }),
      (),
    )
    await render(<Section />)
    await click("Dismiss")
    t->expect(button("Add Additional Provider")->Dom.disabled)->Expect.toBe(false)
    await click("Add Additional Provider")
    await R.act(
      async () =>
        setState(~mutation=CustomProviderMutationSucceeded(SavingCustomProvider(None)), ()),
    )
    t->expect(button("Add Additional Provider")->Dom.disabled)->Expect.toBe(false)
    await R.act(
      async () =>
        setState(~mutation=CustomProviderMutationSucceeded(DeletingCustomProvider(saved.id)), ()),
    )
    t->expect(mutation())->Expect.toEqual(CustomProviderMutationIdle)
  })

  testAsync("section aggregates unsaved provider changes", async t => {
    let dirty = ref(None)
    setState(~providers=[saved], ())
    await render(<Section onDirtyChange={value => dirty := Some(value)} />)
    t->expect(dirty.contents)->Expect.toEqual(Some(false))
    await fill("Provider name", "Changed provider")
    t->expect(dirty.contents)->Expect.toEqual(Some(true))
  })
})
