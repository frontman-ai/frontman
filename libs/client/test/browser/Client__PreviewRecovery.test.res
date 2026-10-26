open Vitest
module Frame = Client__PreviewFrame
module Task = Client__State__Types.Task
module Context = Client__Tool__PreviewContext
module Fixture = Client__FormFixture
module Test = Client__ActivationBrowserHelpers

let previewUrl = `${(
    WebAPI.Window.current->WebAPI.Window.location
  ).origin}/test/browser/preview.html`
let redirectUrl = previewUrl ++ "?redirect"
let state = () => StateStore.getState(Client__State__Store.store)
let renderedFrame = () =>
  Test.query("iframe[title^='Preview - ']")
  ->Option.getOrThrow
  ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
  ->Option.getOrThrow
let waitReady = () =>
  Test.waitFor(() => {
    let context = Context.get()->Option.getOrThrow(~message="Preview is unavailable")
    switch context.doc.url == previewUrl {
    | true => ()
    | false => failwith("Preview has not returned to the supported page")
    }
  })
let load = async (frame: WebAPI.DomTypes.htmliFrameElement, url) => {
  frame.src = url
  await Test.waitFor(() =>
    switch (url == redirectUrl, Frame.read(frame)) {
    | (true, None) => ()
    | (false, Some({doc})) if doc.url == url => ()
    | _ => failwith("Preview navigation has not finished")
    }
  )
}
let screenshot = async () =>
  JSON.stringify(await Fixture.execute(~name="take_screenshot", `{"selector":"#marker"}`))
let executeJs = async () =>
  JSON.stringify(await Fixture.execute(~name="execute_js", `{"expression":"document.title"}`))

beforeEachAsync(async () => {
  Client__ActivationTestHelpers.setup()
  Test.force({...Test.original, currentTask: Task.New(Task.makeNew(~previewUrl))})
  await Test.page->Test.viewport(1280, 900)
  Test.render(
    <>
      <Client__TopBar
        chatboxWidth=300
        workspaceView=Preview
        onWorkspaceViewChange={_ => ()}
        onSettingsClick={() => ()}
      />
      <Client__WebPreview />
    </>,
  )
  await waitReady()
})
afterEach(() => {
  Test.cleanup()
  Client__ActivationTestHelpers.unstubAllGlobals()
})

testAsync(
  "redirect rejects stale contexts; parent reset restores screenshot and JavaScript tools",
  async t => {
    let frame = renderedFrame()
    let previousState = state()
    let {doc, win} = Context.get()->Option.getOrThrow
    let window = {FrontmanBindings.Bindings__WebAPI.window: win}
    let nested =
      doc
      ->WebAPI.Document.querySelector("iframe")
      ->Null.getOrThrow
      ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
      ->Option.getOrThrow
    t->expect(Frame.read(nested)->Option.isSome)->Expect.toBe(true)
    await load(frame, redirectUrl)
    t->expect(Frame.isCurrent(~doc, ~window))->Expect.toBe(false)
    Test.force(previousState)
    t
    ->expect((await executeJs())->String.includes("Preview frame not available"))
    ->Expect.toBe(true)
    let cleared = Client__State.Selectors.previewFrame(state())
    t->expect(cleared.contentDocument)->Expect.toEqual(None)
    t->expect(cleared.contentWindow)->Expect.toEqual(None)
    Test.force(previousState)
    t->expect((await screenshot())->String.includes("not available"))->Expect.toBe(true)
    Client__State.Actions.setCurrentPreviewUrl(~url=previewUrl)
    await waitReady()
    t->expect(Frame.isCurrent(~doc, ~window))->Expect.toBe(false)
    t->expect((await executeJs())->String.includes("Supported preview"))->Expect.toBe(true)
    t->expect((await screenshot())->String.includes("image/jpeg"))->Expect.toBe(true)
  },
)

testAsync("toolbar reload and address entry recover without restarting the client", async t => {
  let frame = renderedFrame()
  Client__State.Actions.observePreviewUrl(
    ~clientId=Client__State.Selectors.currentTaskClientId(state()),
    ~navigationKey=0,
    ~url=previewUrl ++ "#observed",
  )
  await Test.waitFor(() => t->expect(renderedFrame())->Expect.toBe(frame))
  let input = {
    Client__Tool__ExecuteJs.expression: `location.href = '${redirectUrl}'`,
    timeout: None,
  }
  let _ = await Fixture.execute(
    ~name="execute_js",
    input->S.decodeOrThrow(~from=Client__Tool__ExecuteJs.inputSchema, ~to=S.jsonString),
  )
  await Test.waitFor(() => t->expect(Context.get())->Expect.toEqual(None))
  await Test.page->Test.getByRole("button", {name: "Reload"})->Test.click
  await Test.waitFor(() => t->expect(renderedFrame() === frame)->Expect.toBe(false))
  let address = Test.page->Test.getByRole("textbox", {name: "Preview URL"})
  await address->Test.fill(previewUrl)
  await Test.userEvent->Test.keyboard("{Enter}")
  await waitReady()
  t->expect((await executeJs())->String.includes("Supported preview"))->Expect.toBe(true)
  let recovered = renderedFrame()
  await Test.page->Test.getByRole("button", {name: "Reload"})->Test.click
  await Test.waitFor(() => t->expect(renderedFrame() === recovered)->Expect.toBe(false))
  await waitReady()
})

testAsync(
  "retained task frames cannot update another task or reuse a replaced document",
  async t => {
    let make = id => Task.makeNew(~previewUrl)->Task.newToLoaded(~id, ~title=id)
    let tasks = Dict.fromArray([("first", make("first")), ("second", make("second"))])
    Test.force({...Test.original, tasks, currentTask: Task.Selected("first")})
    await waitReady()
    let frame = renderedFrame()
    let old = Context.get()->Option.getOrThrow
    await load(frame, redirectUrl)
    Client__State.Actions.switchTask(~taskId="second")
    await waitReady()
    let current = Context.get()->Option.getOrThrow
    t->expect(current.doc === old.doc)->Expect.toBe(false)
    await load(frame, previewUrl)
    t->expect((Context.get()->Option.getOrThrow).doc)->Expect.toBe(current.doc)
    await load(frame, redirectUrl)
    Client__State.Actions.switchTask(~taskId="first")
    await Test.waitFor(() => t->expect(Context.get())->Expect.toEqual(None))
    Client__State.Actions.setCurrentPreviewUrl(~url=previewUrl)
    await waitReady()
    t->expect((Context.get()->Option.getOrThrow).doc === old.doc)->Expect.toBe(false)
    t->expect((await screenshot())->String.includes("image/jpeg"))->Expect.toBe(true)
  },
)

testAsync("annotation enrichment unwraps the preview window handle", async t => {
  let {doc, win} = Context.get()->Option.getOrThrow
  FrontmanBindings.Bindings__Test__AstroAnnotations.setAnnotationsApi(
    win,
    {
      get: _ => Nullable.null,
      has: _ => false,
      size: () => 0,
      contentFile: Nullable.make("src/Preview.astro"),
    },
  )
  let resolved = ref(None)
  Client__Task__Reducer.fetchAnnotationDetails(
    ~id="annotation",
    ~element=doc->WebAPI.Document.querySelector("#marker")->Null.getOrThrow,
    ~document=Some(doc),
    ~contentWindow=Some({window: win}),
    ~dispatch=action =>
      switch action {
      | AnnotationDetailsResolved({sourceLocation}) => resolved := Some(sourceLocation)
      | _ => failwith("Unexpected annotation action")
      },
  )
  await Test.waitFor(() =>
    t
    ->expect((resolved.contents->Option.getOrThrow->Result.getOrThrow->Option.getOrThrow).file)
    ->Expect.toBe("src/Preview.astro")
  )
})
