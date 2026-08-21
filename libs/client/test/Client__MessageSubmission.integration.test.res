open Vitest

module Reducer = Client__State__StateReducer
module Task = Client__State__Types.Task
module TaskReducer = Client__Task__Reducer
module Message = Client__State__Types.Message

@send
external createDiv: (WebAPI.DomTypes.document, @as(json`"div"`) _) => WebAPI.DomTypes.htmlElement =
  "createElement"

external asReactElement: WebAPI.DomTypes.element => Dom.element = "%identity"

@module("react")
external act: (unit => unit) => unit = "act"

let setTestBrowserGlobals = (): unit => {
  let configure: unit => unit = %raw(`function() {
    globalThis.IS_REACT_ACT_ENVIRONMENT = true
    globalThis.ResizeObserver = class ResizeObserver {
      observe() {}
      unobserve() {}
      disconnect() {}
    }
    globalThis.IntersectionObserver = class IntersectionObserver {
      observe() {}
      unobserve() {}
      disconnect() {}
    }
    window.matchMedia = window.matchMedia || function() {
      return {
        matches: false,
        addEventListener() {},
        removeEventListener() {},
        addListener() {},
        removeListener() {}
      }
    }
    window.__frontmanRuntime = {framework: "vite"}
  }`)
  configure()
}

let mountedRoots = ref([])

let render = element => {
  setTestBrowserGlobals()
  let document = WebAPI.Window.current->WebAPI.Window.document
  let container = document->createDiv
  document
  ->WebAPI.Document.body
  ->Null.toOption
  ->Option.getOrThrow(~message="Test document requires a body")
  ->WebAPI.HTMLElement.appendChild(container->WebAPI.HTMLElement.asNode)
  ->ignore
  let root = ReactDOM.Client.createRoot(container->WebAPI.HTMLElement.asElement->asReactElement)
  act(() => root->ReactDOM.Client.Root.render(element))
  mountedRoots.contents->Array.push((root, container))
  container
}

let rerender = element => {
  let (root, _) = mountedRoots.contents[mountedRoots.contents->Array.length - 1]->Option.getOrThrow
  act(() => root->ReactDOM.Client.Root.render(element))
}

let unmount = (root, container) => {
  act(() => root->ReactDOM.Client.Root.unmount())
  container->WebAPI.HTMLElement.remove
}

let findButton = (container, label) =>
  container
  ->WebAPI.HTMLElement.asElement
  ->WebAPI.Element.querySelectorAll("button")
  ->WebAPI.NodeList.toArray
  ->Array.find(element =>
    element
    ->WebAPI.Element.asNode
    ->WebAPI.Node.textContent
    ->Null.toOption
    ->Option.mapOr(false, text => text->String.trim == label)
  )

let click = element => {
  let htmlElement: WebAPI.DomTypes.htmlElement = element->Obj.magic
  act(() => htmlElement->WebAPI.HTMLElement.click)
}

let forceState = state =>
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(Client__State__Store.store, state)

let makeLoadedTask = (~messages) =>
  Task.makeNew(~previewUrl="http://localhost:3000")
  ->Task.newToLoaded(~id="task-1", ~title="Test Task")
  ->Task.updateLoadedData(data => {...data, messages})

let executor: FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.agentCatalogEntry = {
  id: "executor-id",
  name: "executor",
  displayName: "Executor",
  description: "Executes work",
  color: "#985DF7",
}

afterEach(() => {
  mountedRoots.contents->Array.forEach(((root, container)) => unmount(root, container))
  mountedRoots := []
  forceState(Reducer.defaultState)
})

describe("message submission integration", () => {
  test("local send failure does not invoke server turn retry", t => {
    let retryCalls = ref([])
    let error = Message.ErrorMessage.make(
      ~id="user-1-send-failed",
      ~error="Connection failed",
      ~category=#unknown,
    )
    let task = makeLoadedTask(~messages=[Message.Error(error)])
    let tasks = Dict.make()
    tasks->Dict.set("task-1", task)
    forceState({
      ...Reducer.defaultState,
      tasks,
      currentTask: Task.Selected("task-1"),
      acpSession: AcpSessionActive({
        sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _, ~_meta as _) => (),
        cancelPrompt: () => (),
        retryTurn: errorId => retryCalls.contents->Array.push(errorId),
        loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
        deleteSession: (_, ~onComplete as _) => (),
        apiBaseUrl: "http://localhost:4000",
      }),
      agentCatalog: Some([executor]),
      selectedAgentId: Some(executor.id),
    })

    let container = render(<Client__Chatbox onConfigureProvider={() => ()} />)

    t->expect(findButton(container, "Retry"))->Expect.toEqual(None)
    t->expect(retryCalls.contents)->Expect.toEqual([])
  })

  testAsync("double-clicking Update starts one submission", async t => {
    let createSessionCalls = ref([])
    let createSessionComplete: ref<option<result<string, string> => unit>> = ref(None)
    let sendPromptCalls = ref([])
    let context = {
      ...Client__FrontmanProvider.defaultContextValue,
      createSession: (~sessionId, ~onComplete) => {
        createSessionCalls.contents->Array.push(sessionId)
        createSessionComplete := Some(onComplete)
      },
    }
    forceState({
      ...Reducer.defaultState,
      updateInfo: Some({
        npmPackage: "@frontman-ai/vite",
        installedVersion: "1.0.0",
        latestVersion: "1.1.0",
      }),
      selectedAgentId: Some(executor.id),
      agentCatalog: Some([executor]),
      acpSession: AcpSessionActive({
        sendPrompt: (text, ~additionalBlocks as _, ~onComplete as _, ~_meta as _) =>
          sendPromptCalls.contents->Array.push(text),
        cancelPrompt: () => (),
        retryTurn: _ => (),
        loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
        deleteSession: (_, ~onComplete as _) => (),
        apiBaseUrl: "http://localhost:4000",
      }),
    })

    let container = render(
      <Client__FrontmanProvider.ContextProvider value=context>
        <Client__Chatbox onConfigureProvider={() => ()} />
      </Client__FrontmanProvider.ContextProvider>,
    )
    let updateButton = findButton(container, "Update")->Option.getOrThrow
    click(updateButton)
    click(updateButton)
    await Promise.resolve()

    t->expect(createSessionCalls.contents->Array.length)->Expect.toBe(1)
    t
    ->expect(
      container
      ->WebAPI.HTMLElement.asNode
      ->WebAPI.Node.textContent
      ->Null.toOption
      ->Option.getOr("")
      ->String.includes("Queued (1)"),
    )
    ->Expect.toBe(true)
    t
    ->expect(Reducer.Selectors.messages(StateStore.getState(Client__State__Store.store)))
    ->Expect.toEqual([])
    let complete = createSessionComplete.contents->Option.getOrThrow
    act(() => complete(Ok(createSessionCalls.contents[0]->Option.getOrThrow)))
    await Promise.resolve()
    t
    ->expect(
      Reducer.Selectors.queuedUserMessages(
        StateStore.getState(Client__State__Store.store),
      )->Array.length,
    )
    ->Expect.toBe(1)
    t->expect(sendPromptCalls.contents->Array.length)->Expect.toBe(1)
  })

  testAsync("submission waits for a loading task session", async t => {
    let createSessionCalls = ref([])
    let sendPromptCalls = ref([])
    let context = {
      ...Client__FrontmanProvider.defaultContextValue,
      createSession: (~sessionId, ~onComplete as _) =>
        createSessionCalls.contents->Array.push(sessionId),
    }
    let (loadingTask, _) = TaskReducer.next(
      Task.makeUnloaded(~id="task-1", ~title="Task", ~createdAt=1000., ~updatedAt=1000.),
      LoadStarted({previewUrl: "http://localhost:3000"}),
    )
    let tasks = Dict.make()
    tasks->Dict.set("task-1", loadingTask)
    forceState({
      ...Reducer.defaultState,
      tasks,
      currentTask: Task.Selected("task-1"),
      updateInfo: Some({
        npmPackage: "@frontman-ai/vite",
        installedVersion: "1.0.0",
        latestVersion: "1.1.0",
      }),
      selectedAgentId: Some(executor.id),
      agentCatalog: Some([executor]),
      acpSession: AcpSessionActive({
        sendPrompt: (text, ~additionalBlocks as _, ~onComplete as _, ~_meta as _) =>
          sendPromptCalls.contents->Array.push(text),
        cancelPrompt: () => (),
        retryTurn: _ => (),
        loadTask: (_, ~needsHistory as _, ~onComplete as _) => (),
        deleteSession: (_, ~onComplete as _) => (),
        apiBaseUrl: "http://localhost:4000",
      }),
    })

    let view = context =>
      <Client__FrontmanProvider.ContextProvider value=context>
        <Client__Chatbox onConfigureProvider={() => ()} />
      </Client__FrontmanProvider.ContextProvider>
    let container = render(view(context))
    click(findButton(container, "Update")->Option.getOrThrow)
    await Promise.resolve()

    t->expect(createSessionCalls.contents)->Expect.toEqual([])
    rerender(view({...context, session: Some(Obj.magic({"sessionId": "task-1"}))}))
    await Promise.resolve()
    t->expect(sendPromptCalls.contents)->Expect.toEqual([])
    act(
      () =>
        Client__State__Store.dispatch(
          Reducer.TaskAction({target: Reducer.ForTask("task-1"), action: TaskReducer.LoadComplete}),
        ),
    )
    await Promise.resolve()
    t->expect(sendPromptCalls.contents->Array.length)->Expect.toBe(1)
  })
})
