open Vitest
module Frame = Client__PreviewFrame
module Browser = FrontmanBindings.Bindings__WebAPI
module Task = Client__State__Types.Task
module Reducer = Client__Task__Reducer
module Context = Client__Tool__PreviewContext
module HttpTool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
module MCP = HttpTool.MCP
module Test = Client__ActivationBrowserHelpers

let originalState = StateStore.getState(Client__State__Store.store)
let origin = (WebAPI.Window.current->WebAPI.Window.location).origin
let frames = ref([])
let runtimes = ref([])
let frameOf = element => element->Browser.iframeElementFromElement->Option.getOrThrow
let mount = () => {
  let element = WebAPI.DomGlobal.document->WebAPI.Document.createElement("iframe")
  WebAPI.DomGlobal.document.body
  ->WebAPI.HTMLElement.appendChild((element :> WebAPI.DomTypes.node))
  ->ignore
  let frame = frameOf(element)
  frames := frames.contents->Array.concat([frame])
  frame
}
let load = (frame, url) =>
  Promise.make((resolve, reject) => {
    let timer = setTimeout(() => reject(Failure("Preview fixture load timed out")), 3000)
    let onLoad = _ => {
      clearTimeout(timer)
      resolve()
    }
    frame->WebAPI.HTMLIFrameElement.addEventListener(
      WebAPI.EventTypes.Load,
      onLoad,
      ~options={once: true},
    )
    frame.src = url
  })
let storeTask = task =>
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    {...originalState, currentTask: Task.New(task)},
  )
let attach = frame => {
  let {doc, win} = frame->Frame.read->Option.getOrThrow
  let task =
    Task.makeNew(~previewUrl=`${origin}/__preview_page`)->Reducer.Lens.setPreviewFrame(
      ~contentDocument=Some(doc),
      ~contentWindow=Some({window: win}),
    )
  storeTask(task)
  (task, doc, {Browser.window: win})
}
let screenshot = () =>
  Client__Tool__TakeScreenshot.execute(
    {selector: Some("#marker"), fullPage: None},
    ~taskId="preview",
    ~toolCallId="screenshot",
  )
let executeJs = () =>
  Client__Tool__ExecuteJs.execute(
    {expression: "document.title", timeout: None},
    ~taskId="preview",
    ~toolCallId="js",
  )
let json = result =>
  result->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json)->JSON.stringify

beforeEach(Client__ActivationTestHelpers.setup)
afterEach(() => {
  runtimes.contents->Array.forEach(Client__PreviewRuntime.close)
  runtimes := []
  Test.cleanup()
  frames.contents->Array.forEach(WebAPI.HTMLIFrameElement.remove)
  frames := []
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    originalState,
  )
  Client__ActivationTestHelpers.unstubAllGlobals()
})

testAsync(
  "redirect makes cached tools unavailable; parent navigation restores screenshot and JS",
  async t => {
    let frame = mount()
    await load(frame, "/__preview_page")
    let (task, doc, window) = attach(frame)
    t->expect(Context.get()->Option.isSome)->Expect.toBe(true)
    let nested = doc->WebAPI.Document.querySelector("iframe")->Null.getOrThrow->frameOf
    t->expect(nested->Frame.read->Option.isSome)->Expect.toBe(true)
    t->expect((await executeJs())->json->String.includes("Supported preview"))->Expect.toBe(true)
    await load(frame, "/__preview_redirect")
    t->expect(frame->Browser.iframeWindowHandle->Option.isSome)->Expect.toBe(true)
    t->expect(Frame.validate(~doc, ~window))->Expect.toEqual(None)
    t->expect(frame->Frame.read)->Expect.toEqual(None)
    let runtime = Client__PreviewRuntime.make(
      ~iframe=frame,
      ~targetOrigin=origin,
      ~channel="preview-regression",
    )
    runtimes := [runtime]
    let statuses = ref([])
    let removeListener = Client__PreviewRuntime.onStatus(runtime, status =>
      statuses := statuses.contents->Array.concat([status])
    )
    let unavailableJs = (await executeJs())->json
    t->expect(unavailableJs->String.includes("Preview frame not available"))->Expect.toBe(true)
    t->expect(unavailableJs->String.includes("BS_PRIVATE_NESTED_SOME_NONE"))->Expect.toBe(false)
    let state = StateStore.getState(Client__State__Store.store)
    let cleared = Client__State.Selectors.previewFrame(state)
    t->expect(cleared.contentDocument)->Expect.toEqual(None)
    t->expect(cleared.contentWindow)->Expect.toEqual(None)
    storeTask(task)
    t->expect((await screenshot())->json->String.includes("not available"))->Expect.toBe(true)
    Client__State.Actions.setCurrentPreviewUrl(~url=`${origin}/__preview_page`)
    let reset = Client__State.Selectors.previewFrame(
      StateStore.getState(Client__State__Store.store),
    )
    t->expect(reset.navigationKey)->Expect.toBe(1)
    t->expect(reset.contentWindow)->Expect.toEqual(None)
    await load(frame, reset.url)
    t
    ->expect(
      statuses.contents->Array.some(status => status == Runtime.Disconnected("Iframe reloaded")),
    )
    ->Expect.toBe(true)
    t->expect(Client__PreviewRuntime.status(runtime))->Expect.toEqual(Runtime.Connecting)
    Client__PreviewRuntime.close(runtime)
    await load(frame, reset.url)
    t
    ->expect(Client__PreviewRuntime.status(runtime))
    ->Expect.toEqual(Runtime.Closed("Runtime closed"))
    removeListener()
    let _ = attach(frame)
    t->expect(Frame.validate(~doc, ~window))->Expect.toEqual(None)
    t->expect((await executeJs())->json->String.includes("Supported preview"))->Expect.toBe(true)
    t->expect((await screenshot())->json->String.includes("image/jpeg"))->Expect.toBe(true)
  },
)

let renderPreview = async () => {
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
}
let renderedFrame = () =>
  Test.container.contents
  ->Option.getOrThrow
  ->WebAPI.Element.querySelector("iframe[title^='Preview - ']")
  ->Null.getOrThrow
  ->frameOf
let waitReady = t =>
  Test.waitFor(() =>
    t
    ->expect(Context.get()->Option.map(context => context.doc.title))
    ->Expect.toEqual(Some("Supported preview"))
  )

testAsync(
  "toolbar reload and address entry replace an inaccessible child without restarting",
  async t => {
    let task = Task.makeNew(~previewUrl=`${origin}/__preview_page`)
    storeTask(task)
    await renderPreview()
    await waitReady(t)
    let frame = renderedFrame()
    Client__State.Actions.observePreviewUrl(
      ~clientId=Task.getClientId(task),
      ~navigationKey=0,
      ~url=`${origin}/__preview_page#observed`,
    )
    await Test.waitFor(() => t->expect(renderedFrame())->Expect.toBe(frame))
    let _ = await Client__Tool__ExecuteJs.execute(
      {expression: "location.href = '/__preview_redirect'", timeout: None},
      ~taskId="preview",
      ~toolCallId="navigate",
    )
    await Test.waitFor(() => t->expect(frame->Frame.read)->Expect.toEqual(None))
    await Test.waitFor(() => t->expect(Context.get())->Expect.toEqual(None))
    await Test.page->Test.getByRole("button", {name: "Reload"})->Test.click
    await Test.waitFor(() => t->expect(renderedFrame() === frame)->Expect.toBe(false))
    let address = Test.page->Test.getByRole("textbox", {name: "Preview URL"})
    await address->Test.fill(`${origin}/__preview_page`)
    await Test.userEvent->Test.keyboard("{Enter}")
    await waitReady(t)
    t->expect((await executeJs())->json->String.includes("Supported preview"))->Expect.toBe(true)
    t->expect((await screenshot())->json->String.includes("image/jpeg"))->Expect.toBe(true)
    let recovered = renderedFrame()
    await Test.page->Test.getByRole("button", {name: "Reload"})->Test.click
    await Test.waitFor(() => t->expect(renderedFrame() === recovered)->Expect.toBe(false))
    await waitReady(t)
  },
)

testAsync(
  "switching away from and back to an inaccessible task never reuses its old document",
  async t => {
    let make = id =>
      Task.makeNew(~previewUrl=`${origin}/__preview_page`)->Task.newToLoaded(~id, ~title=id)
    let first = make("first")
    let second = make("second")
    let tasks = Dict.fromArray([("first", first), ("second", second)])
    StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
      Client__State__Store.store,
      {...originalState, tasks, currentTask: Task.Selected("first")},
    )
    await renderPreview()
    await waitReady(t)
    let frame = renderedFrame()
    let old = Context.get()->Option.getOrThrow
    await load(frame, "/__preview_redirect")
    await Test.waitFor(() => t->expect(Context.get())->Expect.toEqual(None))
    Client__State.Actions.switchTask(~taskId="second")
    await waitReady(t)
    let current = Context.get()->Option.getOrThrow
    t->expect(current.doc === old.doc)->Expect.toBe(false)
    await load(frame, "/__preview_page")
    t->expect((Context.get()->Option.getOrThrow).doc)->Expect.toBe(current.doc)
    await load(frame, "/__preview_redirect")
    Client__State.Actions.switchTask(~taskId="first")
    await Test.waitFor(() => t->expect(Context.get())->Expect.toEqual(None))
    t->expect((await executeJs())->json->String.includes("not available"))->Expect.toBe(true)
    Client__State.Actions.setCurrentPreviewUrl(~url=`${origin}/__preview_page`)
    await waitReady(t)
    t->expect((Context.get()->Option.getOrThrow).doc === old.doc)->Expect.toBe(false)
    t->expect((await screenshot())->json->String.includes("image/jpeg"))->Expect.toBe(true)
  },
)

testAsync("annotation enrichment unwraps the exact preview window handle", async t => {
  let frame = mount()
  await load(frame, "/__preview_page")
  let {doc, win} = Frame.read(frame)->Option.getOrThrow
  FrontmanBindings.AstroAnnotations.setAnnotationsApi(
    win,
    {
      get: _ => Nullable.null,
      has: _ => false,
      size: () => 0,
      contentFile: Nullable.make("src/Preview.astro"),
    },
  )
  let resolved = ref(None)
  Reducer.fetchAnnotationDetails(
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
