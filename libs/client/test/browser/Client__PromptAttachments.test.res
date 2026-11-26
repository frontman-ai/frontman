open Vitest
open WebAPI

module Protocol = FrontmanAiFrontmanClient.FrontmanClient__ACP__Protocol

type page
type locator
type locatorOptions = {@live name: string}
@module("vitest/browser") external page: page = "page"
@send external getByRole: (page, string, locatorOptions) => locator = "getByRole"
@send external click: locator => promise<unit> = "click"
@send external fill: (locator, string) => promise<unit> = "fill"
@module("vitest") @scope("vi") external waitFor: (unit => unit) => promise<unit> = "waitFor"
@module("vitest") external onTestFinished: (unit => unit) => unit = "onTestFinished"
@module("react-dom/client")
external createRoot: DomTypes.element => ReactDOM.Client.Root.t = "createRoot"

let query = (container, selector) => container->Element.querySelector(selector)->Null.getOrThrow
let textContent = element => element->Element.asNode->Node.textContent->Null.getOrThrow
let chipCount = container =>
  container->Element.querySelectorAll("[data-chip-type=file]")->NodeList.toArray->Array.length

let drop = (element, file) => {
  let transfer = DataTransfer.make()
  transfer.items->DataTransferItemList.addFile(file)->ignore
  let event = DragEvent.make(
    ~type_="drop",
    ~eventInitDict={bubbles: true, cancelable: true, dataTransfer: Null.make(transfer)},
  )
  element->Element.dispatchEvent(event->DragEvent.asEvent)->ignore
}

testAsync("drop rejection retains the draft and PNG until explicit dismissal", async t => {
  let container = DomGlobal.document->Document.createElement("div")
  DomGlobal.document.body->HTMLElement.appendChild(container->Element.asNode)->ignore
  let root = createRoot(container)
  onTestFinished(() => {
    root->ReactDOM.Client.Root.unmount()
    container->Element.remove
  })
  let commandsRef = React.createRef()
  root->ReactDOM.Client.Root.render(
    <React.StrictMode>
      <Client__PromptInput
        onSubmit={(~text as _, ~inputItems as _) =>
          JsError.throwWithMessage("This case must not submit")}
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
  await page->getByRole("textbox", {name: "Prompt"})->fill("Keep this draft")
  let attachButton = query(container, "button[aria-label='Attach images']")
  t->expect(attachButton->Element.getAttribute("title")->Null.getOrThrow)
  ->Expect.toBe("Attach images (PNG, JPEG, GIF, WebP up to 10MB). Or paste text.")

  let response = await Fetch.fetch(
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=",
  )
  let blob = await response->Response.blob
  let png = File.make(
    ~fileBits=[Blob(blob)], ~fileName="accepted.png", ~options={type_: "image/png"},
  )
  let pdf = File.make(
    ~fileBits=[String("%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF")],
    ~fileName="document.pdf",
    ~options={type_: "application/pdf"},
  )
  let target = query(container, "fieldset")
  drop(target, png)
  await waitFor(() => t->expect(chipCount(container))->Expect.toBe(1))
  t->expect(textContent(query(container, "[data-chip-type=file]"))->String.includes("accepted.png"))
  ->Expect.toBe(true)

  drop(target, pdf)
  await waitFor(() =>
    t->expect(textContent(query(container, "[role=alert]"))->String.includes(Protocol.unsupportedAttachmentError))
    ->Expect.toBe(true)
  )
  t->expect(chipCount(container))->Expect.toBe(1)
  t->expect(textContent(container)->String.includes("document.pdf"))->Expect.toBe(false)
  t->expect(textContent(query(container, "[role=textbox]"))->String.includes("Keep this draft"))
  ->Expect.toBe(true)
  t->expect(textContent(query(container, "[data-chip-type=file]"))->String.includes("accepted.png"))
  ->Expect.toBe(true)

  await Promise.make((resolve, _) => setTimeout(() => resolve(), 3200)->ignore)
  t->expect(textContent(query(container, "[role=alert]"))->String.includes(Protocol.unsupportedAttachmentError))
  ->Expect.toBe(true)
  await page->getByRole("button", {name: "Dismiss error"})->click
  await waitFor(() =>
    t->expect(container->Element.querySelector("[role=alert]")->Null.toOption)->Expect.toBeNone
  )
  t->expect(chipCount(container))->Expect.toBe(1)
  t->expect(textContent(query(container, "[role=textbox]"))->String.includes("Keep this draft"))
  ->Expect.toBe(true)
})
