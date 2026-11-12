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

testAsync(
  "typing only notifies content-presence transitions and preserves submitted text",
  async t => {
    let changes = []
    let submitted = ref("")
    let submittedFiles = ref(0)
    let container = DomGlobal.document->Document.createElement("div")
    DomGlobal.document.body->HTMLElement.appendChild(container->Element.asNode)->ignore
    let root = createRoot(container)
    let commandsRef = React.createRef()
    let render = disabled =>
      root->ReactDOM.Client.Root.render(
        <React.StrictMode>
          <Client__GetStartedTasks
            recentTasks=[]
            onResume={_ => ()}
            onSelect={text =>
              commandsRef.current
              ->Nullable.toOption
              ->Option.forEach((commands: Client__PromptEditor.commands) =>
                commands.insertText(text)
              )}
          />
          <Client__PromptEditor
            disabled
            placeholder="Prompt"
            isEnrichingAnnotations=false
            hasAnnotations=false
            commandsRef
            onHasContentChange={value => changes->Array.push(value)}
            onSubmit={(text, files) => {
              submitted := text
              submittedFiles := files->Array.length
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
    let text = "Change the heading to Hello Frontman. " ++ "a"->String.repeat(120)
    await userEvent->keyboard(text)
    t->expect(changes)->Expect.toEqual([true])
    t
    ->expect(
      container
      ->Element.querySelector("[role=textbox]")
      ->Null.getOrThrow
      ->Element.asNode
      ->Node.textContent
      ->Null.getOrThrow,
    )
    ->Expect.toBe(text)
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
    let element = container->Element.querySelector("[role=textbox]")->Null.getOrThrow
    let editor = element->FrontmanBindings.Bindings__Tiptap__Core.elementEditor
    let trace = []
    let snapshot = (phase, event: option<EventTypes.event>) => {
      let state = editor->FrontmanBindings.Bindings__Tiptap__Core.state
      let selection = DomGlobal.document->Document.getSelection->Null.toOption
      {
        "phase": phase,
        "timeMs": Date.now(),
        "event": event->Option.map(event => (event.type_, event.isTrusted, event.defaultPrevented)),
        "documentFocused": DomGlobal.document->Document.hasFocus,
        "editable": element->Element.getAttribute("contenteditable"),
        "domText": element->Element.asNode->Node.textContent,
        "domSelection": selection->Option.map(selection => (
          selection.anchorNode->Null.toOption->Option.map(node => node.nodeName),
          selection.anchorOffset,
          selection.focusNode->Null.toOption->Option.map(node => node.nodeName),
          selection.focusOffset,
        )),
        "modelSelection": (state.selection.from, state.selection.to_),
        "modelEmpty": editor->FrontmanBindings.Bindings__Tiptap__Core.isEmpty,
        "model": editor->FrontmanBindings.Bindings__Tiptap__Core.getJSON,
      }
    }
    let record = (phase, event) =>
      switch trace->Array.length < 32 {
      | false => ()
      | true => trace->Array.push(snapshot(phase, event))
      }
    let keydown = (phase, event: UiEventsTypes.keyboardEvent) =>
      switch event.key {
      | "Delete" => record(phase, Some(event->KeyboardEvent.asEvent))
      | _ => ()
      }
    element->Element.addEventListener(
      Keydown,
      event => keydown("keydown capture", event),
      ~options={capture: true},
    )
    element->Element.addEventListener(Keydown, event => keydown("keydown bubble", event))
    element->Element.addEventListener(Beforeinput, event => record("beforeinput", Some(event)))
    element->Element.addEventListener(Input, event => record("input", Some(event)))
    let selectionCapture = event => record("selectionchange capture", Some(event))
    let selectionBubble = event => record("selectionchange bubble", Some(event))
    DomGlobal.document->Document.addEventListener(
      Selectionchange,
      selectionCapture,
      ~options={capture: true},
    )
    DomGlobal.document->Document.addEventListener(Selectionchange, selectionBubble)
    onTestFinished(() => {
      DomGlobal.document->Document.removeEventListener(
        Selectionchange,
        selectionCapture,
        ~options={capture: true},
      )
      DomGlobal.document->Document.removeEventListener(Selectionchange, selectionBubble)
    })
    record("before fill", None)
    await textbox->fill("Another draft")
    record("after nonempty fill", None)
    await textbox->fill("")
    record("after empty fill", None)
    try {
      await waitFor(() => t->expect(changes)->Expect.toEqual([true, false, true, false]))
    } catch {
    | error =>
      Console.log(("Prompt clear failure", Window.current->Window.navigator->Navigator.userAgent))
      trace->Array.forEach(entry => Console.log(entry->JSON.stringifyAny->Option.getOrThrow))
      Console.log(snapshot("assertion failed", None)->JSON.stringifyAny->Option.getOrThrow)
      Console.log(("Content-presence notifications", changes))
      throw(error)
    }
    await textbox->fill("Keep this draft")
    let file = WebAPI.File.make(
      ~fileBits=[String("image")],
      ~fileName="example.png",
      ~options={type_: "image/png"},
    )
    commandsRef.current
    ->Nullable.toOption
    ->Option.getOrThrow
    ->((commands: Client__PromptEditor.commands) => commands.dropFiles([file]))
    await waitFor(() =>
      t
      ->expect(
        container->Element.querySelector("[data-chip-type=file]")->Null.toOption->Option.isSome,
      )
      ->Expect.toBe(true)
    )
    Client__PromptEditor.focus()
    await userEvent->keyboard("{Control>}a{/Control}")
    await page->getByRole("button", {name: "Make this heading a little larger"})->click
    await waitFor(() =>
      t
      ->expect(
        container
        ->Element.querySelector("[role=textbox]")
        ->Null.getOrThrow
        ->Element.asNode
        ->Node.textContent
        ->Null.getOrThrow
        ->String.includes("Make this heading a little larger"),
      )
      ->Expect.toBe(true)
    )
    t
    ->expect(
      container->Element.querySelector("[data-chip-type=file]")->Null.toOption->Option.isSome,
    )
    ->Expect.toBe(true)
    t->expect(submitted.contents)->Expect.toBe(text)
    await userEvent->keyboard(" please{Enter}")
    await waitFor(() =>
      t
      ->expect(submitted.contents)
      ->Expect.toBe("Keep this draft Make this heading a little larger please")
    )
    t->expect(submittedFiles.contents)->Expect.toBe(1)
  },
)
