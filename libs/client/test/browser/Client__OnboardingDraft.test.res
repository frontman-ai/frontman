open Vitest
open WebAPI
open Client__ActivationBrowserHelpers

beforeEach(setup)
afterEach(() => {
  cleanup()
  Client__ActivationTestHelpers.unstubAllGlobals()
})

testAsync("starter suggestions prepare a draft without executing an edit", async t => {
  render(
    <Client__GetStartedTasks
      onSelect=Client__State.Actions.setComposerDraft recentTasks=[] onResume={_ => ()}
    />,
  )
  let suggestion = Client__GetStartedTasks.tasks->Array.get(0)->Option.getOrThrow
  await page->getByRole("button", {name: suggestion})->click
  let state = StateStore.getState(Client__State__Store.store)
  t->expect(state.composerDraft)->Expect.toBe(suggestion)
  t->expect(Client__State.Selectors.messages(state)->Array.length)->Expect.toBe(0)
})

testAsync("chat submit keeps its original icon-only Send button", async t => {
  let clicked = ref(false)
  render(
    <Client__PromptInput.SubmitButton
      disabled=false showStop=false onClick={() => clicked := true} onCancel={() => ()}
    />,
  )
  await waitFor(() => t->expect(query("button")->Option.isSome)->Expect.toBe(true))
  let button = query("button")->Option.getOrThrow
  t->expect((button :> DomTypes.node).textContent->Null.getOrThrow->String.trim)->Expect.toBe("")
  await page->getByRole("button", {name: "Send"})->click
  t->expect(clicked.contents)->Expect.toBe(true)
})

module Composer = {
  @react.component
  let make = (~submitted, ~prepared) => {
    let draft = Client__State.useSelector(Client__State.Selectors.composerDraft)
    <Client__PromptEditor
      draft
      onDraftChange=Client__State.Actions.setComposerDraft
      onPrepareSubmit={() => {
        prepared := prepared.contents + 1
        false
      }}
      disabled=false
      placeholder="Your next improvement"
      isEnrichingAnnotations=false
      hasAnnotations=false
      submitSignal=0
      attachSignal=0
      dropFilesSignal=0
      droppedFiles=[]
      onHasContentChange={_ => ()}
      onSubmit={(_, _) => {
        submitted := true
        Promise.resolve(Ok())
      }}
      onPreviewImage={_ => ()}
      onFileSizeError={_ => ()}
    />
  }
}

testAsync("Enter opens preparation without submitting or losing an editable draft", async t => {
  let submitted = ref(false)
  let prepared = ref(0)
  render(<Composer submitted prepared />)
  let textbox = page->getByRole("textbox", {name: "Your next improvement"})
  await textbox->fill("Make signup easier <not HTML>")
  await userEvent->keyboard("{Enter}")
  await waitFor(() => t->expect(prepared.contents)->Expect.toBe(1))
  t->expect(submitted.contents)->Expect.toBe(false)
  t
  ->expect(StateStore.getState(Client__State__Store.store).composerDraft)
  ->Expect.toBe("Make signup easier <not HTML>")
})

testAsync("welcome typing preserves spaces and newlines with the chat editor mounted", async t => {
  let submitted = ref(false)
  let prepared = ref(0)
  render(
    <>
      <div hidden=true>
        <Composer submitted prepared />
      </div>
      <Client__WelcomeModal loginUrl="https://frontman.test/login" onSignIn={() => ()} />
    </>,
  )
  let textarea = page->getByRole("textbox", {name: "What would you like to improve first?"})
  await textarea->fill("Make")
  await userEvent->keyboard("{Space}")
  await waitFor(() =>
    t->expect(StateStore.getState(Client__State__Store.store).composerDraft)->Expect.toBe("Make ")
  )
  await userEvent->keyboard("signup")
  await userEvent->keyboard("{Enter}")
  await waitFor(() =>
    t
    ->expect(StateStore.getState(Client__State__Store.store).composerDraft)
    ->Expect.toBe("Make signup\n")
  )
  await userEvent->keyboard("clearer")
  await waitFor(() =>
    t
    ->expect(StateStore.getState(Client__State__Store.store).composerDraft)
    ->Expect.toBe("Make signup\nclearer")
  )
  t->expect(submitted.contents)->Expect.toBe(false)
  t->expect(prepared.contents)->Expect.toBe(0)
})
