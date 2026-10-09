open Vitest
open WebAPI

@module("../../src/index.css?inline") external styles: string = "default"
@set external setTextContent: (DomTypes.element, string) => unit = "textContent"

type page
type locator
type userEvent
type locatorOptions = {name: string, exact: bool}
type screenshotOptions = {path: string}
@module("vitest/browser") external page: page = "page"
@module("vitest/browser") external userEvent: userEvent = "userEvent"
@send external getByRole: (page, string, locatorOptions) => locator = "getByRole"
@send external click: locator => promise<unit> = "click"
@send external fill: (locator, string) => promise<unit> = "fill"
@send external keyboard: (userEvent, string) => promise<unit> = "keyboard"
@send external screenshot: (locator, screenshotOptions) => promise<string> = "screenshot"
@send external viewport: (page, int, int) => promise<unit> = "viewport"
@module("vitest") @scope("vi") external waitFor: (unit => unit) => promise<unit> = "waitFor"
@module("vitest") external onTestFinished: (unit => unit) => unit = "onTestFinished"
@module("react-dom/client")
external createRoot: DomTypes.element => ReactDOM.Client.Root.t = "createRoot"

let question = "How likely are you to recommend Frontman to a friend or colleague?"
let byRole = (role, name) => page->getByRole(role, {name, exact: true})
let element = (container, selector) => container->Element.querySelector(selector)->Null.getOrThrow
let checked = (container, score) =>
  element(container, `[role=radio][aria-label="${score->Int.toString}"]`)
  ->Element.getAttribute("aria-checked")
  ->Null.getOrThrow
let disabled = (container, selector) =>
  element(container, selector)->Element.hasAttribute("disabled")

let mount = () => {
  let stylesheet = DomGlobal.document->Document.createElement("style")
  stylesheet->setTextContent(styles)
  DomGlobal.document.body->HTMLElement.appendChild(stylesheet->Element.asNode)->ignore
  let scores = []
  let comments = []
  let submissions = ref(0)
  let skips = ref(0)
  let container = DomGlobal.document->Document.createElement("div")
  container->Element.setAttribute(~qualifiedName="role", ~value="region")
  container->Element.setAttribute(~qualifiedName="aria-label", ~value="Feedback preview")
  container->Element.setAttribute(
    ~qualifiedName="style",
    ~value="width:320px;padding:16px;box-sizing:border-box",
  )
  DomGlobal.document.body->HTMLElement.appendChild(container->Element.asNode)->ignore
  let root = createRoot(container)
  onTestFinished(() => {
    root->ReactDOM.Client.Root.unmount()
    container->Element.remove
    stylesheet->Element.remove
  })
  let render = (~score=None, ~comment="", ~submitting=false, ~error=?) =>
    root->ReactDOM.Client.Root.render(
      <Client__CustomerFeedbackPanel
        score
        comment
        submitting
        ?error
        onScoreChanged={value => scores->Array.push(value)}
        onCommentChanged={value => comments->Array.push(value)}
        onSubmit={() => submissions := submissions.contents + 1}
        onSkip={() => skips := skips.contents + 1}
      />,
    )
  (container, render, scores, comments, submissions, skips)
}

testAsync("no preselection; zero and ten submit; Skip is independent", async t => {
  let (container, render, scores, _, submissions, skips) = mount()
  render()
  await waitFor(() => t->expect(disabled(container, "button[type=submit]"))->Expect.toBe(true))
  t
  ->expect(container->Element.querySelectorAll("[role=radio]")->NodeList.toArray->Array.length)
  ->Expect.toBe(11)
  t
  ->expect(
    container->Element.querySelectorAll("[aria-checked=true]")->NodeList.toArray->Array.length,
  )
  ->Expect.toBe(0)
  t->expect(disabled(container, "button[type=button]"))->Expect.toBe(false)
  await byRole("button", "Skip")->click
  t->expect(skips.contents)->Expect.toBe(1)
  t->expect(submissions.contents)->Expect.toBe(0)
  await byRole("radio", "0")->click
  t->expect(scores)->Expect.toEqual([0])
  t->expect(checked(container, 0))->Expect.toBe("false")
  t->expect(submissions.contents)->Expect.toBe(0)
  render(~score=Some(0))
  await waitFor(() => t->expect(checked(container, 0))->Expect.toBe("true"))
  t->expect(disabled(container, "button[type=submit]"))->Expect.toBe(false)
  await byRole("button", "Send feedback")->click
  t->expect(submissions.contents)->Expect.toBe(1)
  await byRole("radio", "10")->click
  t->expect(scores)->Expect.toEqual([0, 10])
  render(~score=Some(10))
  await waitFor(() => t->expect(checked(container, 10))->Expect.toBe("true"))
  t->expect(checked(container, 0))->Expect.toBe("false")
  await byRole("button", "Send feedback")->click
  t->expect(submissions.contents)->Expect.toBe(2)
})

testAsync("comment callbacks and loading/error preserve the controlled draft", async t => {
  let (container, render, _, comments, submissions, skips) = mount()
  render(~score=Some(0))
  let textbox = byRole("textbox", "What's the main reason for your score? (optional)")
  await textbox->fill("The preview is slow.")
  t->expect(comments)->Expect.toEqual(["The preview is slow."])
  render(~score=Some(0), ~comment="The preview is slow.", ~submitting=true)
  await waitFor(() => t->expect(disabled(container, "textarea"))->Expect.toBe(true))
  t->expect(disabled(container, "button[type=submit]"))->Expect.toBe(true)
  t->expect(disabled(container, "button[type=button]"))->Expect.toBe(true)
  t
  ->expect(element(container, "form")->Element.getAttribute("aria-busy")->Null.getOrThrow)
  ->Expect.toBe("true")
  t
  ->expect(element(container, "[role=status]").textContent->Null.getOrThrow)
  ->Expect.toBe("Sending feedback…")
  t
  ->expect(
    container
    ->Element.querySelectorAll("[role=radio][aria-disabled=true]")
    ->NodeList.toArray
    ->Array.length,
  )
  ->Expect.toBe(11)
  render(
    ~score=Some(0),
    ~comment="The preview is slow.",
    ~error="Could not send feedback. Try again.",
  )
  await waitFor(() =>
    t
    ->expect(element(container, "[role=alert]").textContent->Null.getOrThrow)
    ->Expect.toBe("Could not send feedback. Try again.")
  )
  t->expect(checked(container, 0))->Expect.toBe("true")
  let textarea =
    element(
      container,
      "textarea",
    )->FrontmanBindings.Bindings__WebAPI.unsafeTextAreaElementFromElement
  t->expect(textarea.value)->Expect.toBe("The preview is slow.")
  t->expect(disabled(container, "textarea"))->Expect.toBe(false)
  t
  ->expect(element(container, "textarea")->Element.getAttribute("maxlength")->Null.getOrThrow)
  ->Expect.toBe("2000")
  t->expect(submissions.contents)->Expect.toBe(0)
  t->expect(skips.contents)->Expect.toBe(0)
})

testAsync("radio arrow keys follow ascending scores and remain parent-controlled", async t => {
  let (container, render, scores, _, submissions, _) = mount()
  render()
  await waitFor(() => t->expect(checked(container, 0))->Expect.toBe("false"))
  element(container, "[role=radio][aria-label='0']")
  ->FrontmanBindings.Bindings__WebAPI.unsafeHtmlElementFromElement
  ->HTMLElement.focus
  await userEvent->keyboard("{ArrowRight}")
  t->expect(scores)->Expect.toEqual([1])
  render(~score=Some(1))
  await waitFor(() => t->expect(checked(container, 1))->Expect.toBe("true"))
  await userEvent->keyboard("{ArrowLeft}")
  t->expect(scores)->Expect.toEqual([1, 0])
  render(~score=Some(9))
  await waitFor(() => t->expect(checked(container, 9))->Expect.toBe("true"))
  element(container, "[role=radio][aria-label='9']")
  ->FrontmanBindings.Bindings__WebAPI.unsafeHtmlElementFromElement
  ->HTMLElement.focus
  await userEvent->keyboard("{ArrowRight}")
  t->expect(scores)->Expect.toEqual([1, 0, 10])
  t->expect(submissions.contents)->Expect.toBe(0)
})

[(320, "light"), (640, "light"), (320, "dark"), (640, "dark")]->Array.forEach(((width, theme)) => {
  testAsync(`fits ${width->Int.toString}px ${theme} panel with 44px targets`, async t => {
    await page->viewport(width, 900)
    let (container, render, _, _, _, _) = mount()
    container->Element.setAttribute(~qualifiedName="class", ~value=theme)
    container->Element.setAttribute(
      ~qualifiedName="style",
      ~value=`width:${width->Int.toString}px;padding:16px;box-sizing:border-box`,
    )
    render(~score=Some(0), ~comment="The preview is slow.")
    await waitFor(() => t->expect(checked(container, 0))->Expect.toBe("true"))
    let bounds = container->Element.getBoundingClientRect
    let radios = container->Element.querySelectorAll("[role=radio]")->NodeList.toArray
    radios->Array.forEach(
      radio => {
        let rect = radio->Element.getBoundingClientRect
        t->expect(rect.width >= 44.0 && rect.height >= 44.0)->Expect.toBe(true)
        t->expect(rect.left >= bounds.left && rect.right <= bounds.right)->Expect.toBe(true)
      },
    )
    switch width {
    | 320 =>
      let first = radios[0]->Option.getOrThrow->Element.getBoundingClientRect
      let last = radios[10]->Option.getOrThrow->Element.getBoundingClientRect
      t->expect(last.top > first.top)->Expect.toBe(true)
    | _ => ()
    }
    let group = element(container, "[role=radiogroup]")
    let questionId = group->Element.getAttribute("aria-labelledby")->Null.getOrThrow
    let legend = DomGlobal.document->Document.getElementById(questionId)->Null.getOrThrow
    t->expect(legend.textContent->Null.getOrThrow)->Expect.toBe(question)
    let _path = await byRole("region", "Feedback preview")->screenshot({
      path: `../../../../.impeccable/review/nps-${width->Int.toString}-${theme}.png`,
    })
    await page->viewport(800, 600)
  })
})
