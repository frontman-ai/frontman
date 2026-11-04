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

// Temporary diagnostics: capture the DOM and ProseMirror document at test boundaries.
let snapshot: (DomTypes.element, string, array<bool>) => unit = %raw(`
  function(container, label, changes) {
    const dom = container.querySelector('[role="textbox"]');
    const desc = dom?.pmViewDesc;
    console.info("PROMPT_DIAGNOSTIC", JSON.stringify({
      label, time: performance.now(), changes: [...changes],
      html: dom?.outerHTML, document: desc?.node?.toJSON(), dirty: desc?.dirty
    }));
  }
`)

testAsync(
  "typing only notifies content-presence transitions and preserves submitted text",
  async t => {
    let changes = []
    let submitted = ref("")
    let container = DomGlobal.document->Document.createElement("div")
    DomGlobal.document.body->HTMLElement.appendChild(container->Element.asNode)->ignore
    let root = createRoot(container)
    let commandsRef = React.createRef()
    let render = disabled =>
      root->ReactDOM.Client.Root.render(
        <React.StrictMode>
          <Client__PromptEditor
            disabled
            placeholder="Prompt"
            isEnrichingAnnotations=false
            hasAnnotations=false
            commandsRef
            onHasContentChange={value => {
              changes->Array.push(value)
              snapshot(container, "callback", changes)
            }}
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
      snapshot(container, "test finished", changes)
      root->ReactDOM.Client.Root.unmount()
      container->Element.remove
    })
    render(false)
    let textbox = page->getByRole("textbox", {name: "Prompt"})
    await textbox->click
    let text = "Change the heading to Hello Frontman. " ++ "a"->String.repeat(120)
    await userEvent->keyboard(text)
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
    snapshot(container, "before fill", changes)
    await textbox->fill("Another draft")
    snapshot(container, "after fill", changes)
    await textbox->fill("")
    snapshot(container, "after clear", changes)
    await waitFor(() => t->expect(changes)->Expect.toEqual([true, false, true, false]))
  },
)
