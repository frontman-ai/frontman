open Vitest
open WebAPI

module Protocol = FrontmanAiFrontmanClient.FrontmanClient__ACP__Protocol
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock
module StateProtocol = Client__State__Protocol

@schema
type attachmentMeta = {filename: string, user_image: bool}

@schema
type browserRuntime = {framework: string}

@get external getRuntime: Window.t => Nullable.t<JSON.t> = "__frontmanRuntime"
@set external setRuntime: (Window.t, Nullable.t<JSON.t>) => unit = "__frontmanRuntime"

type page
type locator
type locatorOptions = {@live name: string}
@module("vitest/browser") external page: page = "page"
@send external getByRole: (page, string, locatorOptions) => locator = "getByRole"
@send external click: locator => promise<unit> = "click"
@send external fill: (locator, string) => promise<unit> = "fill"
@send external upload: (locator, array<File.t>) => promise<unit> = "upload"
@send external elementLocator: (page, DomTypes.element) => locator = "elementLocator"
@module("vitest") @scope("vi") external waitFor: (unit => unit) => promise<unit> = "waitFor"
@module("vitest") external onTestFinished: (unit => unit) => unit = "onTestFinished"
@module("react-dom/client")
external createRoot: DomTypes.element => ReactDOM.Client.Root.t = "createRoot"

let query = (container, selector) => container->Element.querySelector(selector)->Null.getOrThrow
let textContent = element => element->Element.asNode->Node.textContent->Null.getOrThrow
let chipCount = container =>
  container->Element.querySelectorAll("[data-chip-type=file]")->NodeList.toArray->Array.length
let pause = ms => Promise.make((resolve, _) => setTimeout(() => resolve(), ms)->ignore)

let png = async name => {
  let response = await Fetch.fetch(
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=",
  )
  let blob = await response->Response.blob
  File.make(~fileBits=[Blob(blob)], ~fileName=name, ~options={type_: "image/png"})
}

let pdf = () =>
  File.make(
    ~fileBits=[String("%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF")],
    ~fileName="document.pdf",
    ~options={type_: "application/pdf"},
  )

let drop = (element, files) => {
  let transfer = DataTransfer.make()
  files->Array.forEach(file => transfer.items->DataTransferItemList.addFile(file)->ignore)
  let event = DragEvent.make(
    ~type_="drop",
    ~eventInitDict={bubbles: true, cancelable: true, dataTransfer: Null.make(transfer)},
  )
  element->Element.dispatchEvent(event->DragEvent.asEvent)->ignore
}

let mount = onSubmit => {
  let container = DomGlobal.document->Document.createElement("div")
  DomGlobal.document.body->HTMLElement.appendChild(container->Element.asNode)->ignore
  let root = createRoot(container)
  let commandsRef = React.createRef()
  root->ReactDOM.Client.Root.render(
    <React.StrictMode>
      <Client__PromptInput
        onSubmit
        onCancel={() => ()}
        commandsRef
        modelConfigOption=None
        isModelsConfigLoading=false
        selectedModelValue={Some("test:model")}
        onModelChange={_ => ()}
        agentCatalog=None
        selectedAgentId=None
        onAgentChange={_ => ()}
        onConfigureProvider={() => ()}
        isAgentRunning=false
        hasActiveACPSession=true
        placeholder="Prompt"
      />
    </React.StrictMode>,
  )
  onTestFinished(() => {
    root->ReactDOM.Client.Root.unmount()
    container->Element.remove
  })
  container
}

let unexpectedSubmit = (~text as _, ~inputItems as _) =>
  JsError.throwWithMessage("This case must not submit")

testAsync("drop rejection retains the draft and accepted PNG until explicit dismissal", async t => {
  let container = mount(unexpectedSubmit)
  await page->getByRole("textbox", {name: "Prompt"})->fill("Keep this draft")
  let target = query(container, "fieldset")
  drop(target, [await png("accepted.png")])
  await waitFor(() => t->expect(chipCount(container))->Expect.toBe(1))
  drop(target, [pdf()])
  await waitFor(() =>
    t->expect(textContent(container)->String.includes(Protocol.unsupportedAttachmentError))
    ->Expect.toBe(true)
  )
  t->expect(chipCount(container))->Expect.toBe(1)
  t->expect(textContent(query(container, "[role=textbox]"))->String.includes("Keep this draft"))
  ->Expect.toBe(true)
  t->expect(textContent(query(container, "[data-chip-type=file]"))->String.includes("accepted.png"))
  ->Expect.toBe(true)
  await pause(3200)
  t->expect(textContent(query(container, "[role=alert]"))->String.includes(Protocol.unsupportedAttachmentError))
  ->Expect.toBe(true)
  await page->getByRole("button", {name: "Dismiss error"})->click
  t->expect(container->Element.querySelector("[role=alert]")->Null.toOption)->Expect.toBeNone
  t->expect(chipCount(container))->Expect.toBe(1)
})

testAsync("picker accepts images only and a mixed editor drop keeps its PNG", async t => {
  let container = mount(unexpectedSubmit)
  await page->getByRole("textbox", {name: "Prompt"})->fill("Mixed draft")
  let input = query(container, "input[type=file]")
  t->expect(input->Element.getAttribute("accept")->Null.getOrThrow)
  ->Expect.toBe(Client__PromptEditor.acceptedPromptFileTypesString)
  await page->elementLocator(input)->upload([await png("picker.png")])
  await waitFor(() => t->expect(chipCount(container))->Expect.toBe(1))
  await page->elementLocator(input)->upload([pdf()])
  await waitFor(() =>
    t->expect(textContent(query(container, "[role=alert]"))->String.includes(Protocol.unsupportedAttachmentError))
    ->Expect.toBe(true)
  )
  t->expect(chipCount(container))->Expect.toBe(1)
  await page->getByRole("button", {name: "Dismiss error"})->click
  drop(query(container, "[role=textbox]"), [await png("mixed.png"), pdf()])
  await waitFor(() => t->expect(chipCount(container))->Expect.toBe(2))
  await waitFor(() =>
    t->expect(textContent(container)->String.includes(Protocol.unsupportedAttachmentError))
    ->Expect.toBe(true)
  )
  t->expect(textContent(container)->String.includes("document.pdf"))->Expect.toBe(false)
  t->expect(textContent(query(container, "[role=textbox]"))->String.includes("Mixed draft"))
  ->Expect.toBe(true)
  t->expect(textContent(container)->String.includes("PNG, JPEG, GIF, WebP"))->Expect.toBe(true)
})

testAsync("a PDF alone creates no chip and file-size errors also persist", async t => {
  let container = mount(unexpectedSubmit)
  await page->getByRole("textbox", {name: "Prompt"})->fill("Keep size-error draft")
  drop(query(container, "[role=textbox]"), [pdf()])
  await waitFor(() =>
    t->expect(textContent(query(container, "[role=alert]"))->String.includes(Protocol.unsupportedAttachmentError))
    ->Expect.toBe(true)
  )
  t->expect(chipCount(container))->Expect.toBe(0)
  await page->getByRole("button", {name: "Dismiss error"})->click
  let oversized = File.make(
    ~fileBits=[String("x"->String.repeat(10 * 1024 * 1024 + 1))],
    ~fileName="oversized.png",
    ~options={type_: "image/png"},
  )
  drop(query(container, "fieldset"), [oversized])
  await waitFor(() =>
    t->expect(textContent(query(container, "[role=alert]"))->String.includes("oversized.png exceeds 10MB limit"))
    ->Expect.toBe(true)
  )
  await pause(3200)
  t->expect(textContent(query(container, "[role=alert]"))->String.includes("oversized.png"))
  ->Expect.toBe(true)
  await page->getByRole("button", {name: "Dismiss error"})->click
  t->expect(container->Element.querySelector("[role=alert]")->Null.toOption)->Expect.toBeNone
  t->expect(chipCount(container))->Expect.toBe(0)
  t->expect(textContent(query(container, "[role=textbox]")))->Expect.toBe("Keep size-error draft")
})

testAsync("real reducer rejection retains the draft and serialized PNG resource", async t => {
  let submittedText = ref(None)
  let resources = ref([])
  let previousRuntime = getRuntime(Window.current)
  setRuntime(
    Window.current,
    {framework: "vite"}
    ->S.decodeOrThrow(~from=browserRuntimeSchema, ~to=S.json)
    ->Nullable.make,
  )
  onTestFinished(() => setRuntime(Window.current, previousRuntime))
  let state = {
    ...Client__State__Initialization.defaultState,
    selectedModelValue: Some("test:model"),
    selectedAgentId: Some("planner"),
  }
  let container = mount((~text, ~inputItems) => {
    submittedText := Some(text)
    let content = Array.concat(
      [Client__State__Types.UserContentPart.Text({text: text})],
      inputItems->Array.map(item =>
        Client__State__Types.UserContentPart.Image({
          id: Some(item.id),
          image: item.dataUrl,
          mediaType: Some(item.mediaType),
          name: Some(item.name),
        })
      ),
    )
    resources :=
      content
      ->Client__Task__Reducer.extractAttachmentsFromUserContent
      ->Client__State__Prompt.buildAttachmentContentBlocks
    Promise.make((resolve, _) => {
      let (rejected, effects) = Client__State__StateReducer.next(
        state,
        StateProtocol.AddUserMessage({
          id: Client__Message.UserMessageId.make(),
          timestamp: 0.,
          content,
          annotationId: None,
          onComplete: resolve,
        }),
      )
      t->expect(Client__State__Selectors.messages(rejected))->Expect.toEqual([])
      t->expect(effects->Array.length)->Expect.toBe(1)
      effects->Array.forEach(effect =>
        switch effect {
        | StateProtocol.SubmissionCompleted(_) =>
          Client__State__Effects.handleEffect(effect, rejected, _ =>
            JsError.throwWithMessage("SubmissionCompleted must not dispatch")
          )
        | _ => JsError.throwWithMessage("Rejection must not start a network effect")
        }
      )
    })
  })
  await page->getByRole("textbox", {name: "Prompt"})->fill("Send this screenshot")
  drop(query(container, "fieldset"), [await png("submitted.png")])
  await waitFor(() => t->expect(chipCount(container))->Expect.toBe(1))
  await page->getByRole("button", {name: "Send (Enter)"})->click
  await waitFor(() =>
    t->expect(textContent(query(container, "[role=alert]"))->String.includes("Cannot send message: no active connection"))
    ->Expect.toBe(true)
  )
  t->expect(submittedText.contents)->Expect.toEqual(Some("Send this screenshot"))
  t->expect(chipCount(container))->Expect.toBe(1)
  t->expect(textContent(query(container, "[role=textbox]"))->String.includes("Send this screenshot"))
  ->Expect.toBe(true)
  t->expect(resources.contents->Array.length)->Expect.toBe(1)
  switch resources.contents->Array.get(0)->Option.getOrThrow {
  | ContentBlock.EmbeddedResource({
      resource: BlobResourceContents({uri, mimeType, blob}),
      _meta,
    }) =>
    t->expect(uri->String.startsWith("attachment://att_"))->Expect.toBe(true)
    t->expect(uri->String.endsWith("/submitted.png"))->Expect.toBe(true)
    t->expect(mimeType)->Expect.toEqual(Some("image/png"))
    t->expect(blob->String.length > 0)->Expect.toBe(true)
    t->expect(blob->String.startsWith("iVBOR"))->Expect.toBe(true)
    let meta = _meta->Option.getOrThrow->S.parseOrThrow(~to=attachmentMetaSchema)
    t->expect(meta.filename)->Expect.toBe("submitted.png")
    t->expect(meta.user_image)->Expect.toBe(true)
  | _ => JsError.throwWithMessage("Expected one embedded PNG resource")
  }
  await page->getByRole("button", {name: "Dismiss error"})->click
  t->expect(container->Element.querySelector("[role=alert]")->Null.toOption)->Expect.toBeNone
  t->expect(chipCount(container))->Expect.toBe(1)
})
