open Vitest
open WebAPI

type page
type locator
type userEvent
type locatorOptions = {@live name: string}
@module("vitest/browser") external page: page = "page"
@module("vitest/browser") external userEvent: userEvent = "userEvent"
@send external getByRole: (page, string, locatorOptions) => locator = "getByRole"
@send external click: locator => promise<unit> = "click"
@send external fill: (locator, string) => promise<unit> = "fill"
@send external keyboard: (userEvent, string) => promise<unit> = "keyboard"
@module("vitest") @scope("vi") external waitFor: (unit => unit) => promise<unit> = "waitFor"
@module("vitest") external onTestFinished: (unit => unit) => unit = "onTestFinished"
@module("react-dom/client")
external createRoot: DomTypes.element => ReactDOM.Client.Root.t = "createRoot"

module ContentObserver = {
  @react.component
  let make = (~changes: array<bool>, ~renders: ref<int>) => {
    let hasContent = Client__State.useSelector(Client__State.Selectors.composerHasContent)
    renders := renders.contents + 1
    React.useEffect1(() => {
      changes->Array.push(hasContent)->ignore
      None
    }, [hasContent])
    React.null
  }
}

testAsync(
  "reducer-owned content presence only rerenders on transitions and preserves submitted text",
  async t => {
    Client__State.Actions.composerContentChanged(false)
    let changes = []
    let renders = ref(0)
    let submitted = ref("")
    let container = DomGlobal.document->Document.createElement("div")
    DomGlobal.document.body->HTMLElement.appendChild(container->Element.asNode)->ignore
    let root = createRoot(container)
    let commandsRef = React.createRef()
    let render = disabled =>
      root->ReactDOM.Client.Root.render(
        <React.StrictMode>
          <ContentObserver changes renders />
          <Client__PromptEditor
            disabled
            placeholder="Prompt"
            isEnrichingAnnotations=false
            hasAnnotations=false
            commandsRef
            onSubmit={(text, _) => {
              submitted := text
              Promise.resolve(Ok())
            }}
            onPreviewImage={_ => ()}
            onFileSizeError={message => JsError.throwWithMessage(message)}
          />
        </React.StrictMode>,
      )
    onTestFinished(() => {
      root->ReactDOM.Client.Root.unmount()
      container->Element.remove
    })
    render(false)
    let textbox = page->getByRole("textbox", {name: "Prompt"})
    await textbox->click
    changes->Array.splice(~start=0, ~remove=changes->Array.length, ~insert=[])->ignore
    let text = "Change the heading to Hello Frontman. " ++ "a"->String.repeat(120)
    await userEvent->keyboard("C")
    await waitFor(() => t->expect(changes)->Expect.toEqual([true]))
    let rendersAfterTransition = renders.contents
    await userEvent->keyboard(text->String.slice(~start=1, ~end=String.length(text)))
    t->expect(renders.contents)->Expect.toBe(rendersAfterTransition)
    t->expect(changes)->Expect.toEqual([true])
    t->expect(container.textContent->Null.getOrThrow)->Expect.toBe(text)
    render(true)
    await waitFor(() =>
      t
      ->expect(
        container->Element.querySelector("[contenteditable=false]")->Null.toOption->Option.isSome,
      )
      ->Expect.toBe(true)
    )
    render(false)
    await waitFor(() =>
      t
      ->expect(
        container->Element.querySelector("[contenteditable=true]")->Null.toOption->Option.isSome,
      )
      ->Expect.toBe(true)
    )
    t->expect(changes)->Expect.toEqual([true])
    await textbox->click
    await userEvent->keyboard("{Enter}")
    await waitFor(() => t->expect(submitted.contents)->Expect.toBe(text))
    await waitFor(() => t->expect(changes)->Expect.toEqual([true, false]))
    await textbox->fill("Another draft")
    await textbox->fill("")
    await waitFor(() => t->expect(changes)->Expect.toEqual([true, false, true, false]))
    await textbox->fill("Draft before unmount")
    await waitFor(() =>
      t
      ->expect(
        Client__State__Store.store->StateStore.getState->Client__State.Selectors.composerHasContent,
      )
      ->Expect.toBe(true)
    )
    root->ReactDOM.Client.Root.render(React.null)
    await waitFor(() =>
      t
      ->expect(
        Client__State__Store.store->StateStore.getState->Client__State.Selectors.composerHasContent,
      )
      ->Expect.toBe(false)
    )
    render(false)
    await textbox->fill("Remounted draft")
    await waitFor(() =>
      t
      ->expect(
        Client__State__Store.store->StateStore.getState->Client__State.Selectors.composerHasContent,
      )
      ->Expect.toBe(true)
    )
  },
)
