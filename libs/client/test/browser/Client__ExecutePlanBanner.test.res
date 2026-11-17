open Vitest
open WebAPI

module Reducer = Client__State__StateReducer
module Selectors = Client__State__Selectors
module Task = Client__State__Types.Task
module Connection = Client__ConnectionReducer
module ACP = Connection.ACP

type page
type locator
type locatorOptions = {@live name: string}
type visibilityAssertion = {toBeVisible: unit => promise<unit>}
@module("vitest/browser") external page: page = "page"
@send external getByRole: (page, string, locatorOptions) => locator = "getByRole"
@send external getByText: (page, string) => locator = "getByText"
@send external click: locator => promise<unit> = "click"
@module("vitest") @scope("expect")
external expectElement: locator => visibilityAssertion = "element"
@module("vitest") external onTestFinished: (unit => unit) => unit = "onTestFinished"
@module("react-dom/client")
external createRoot: DomTypes.element => ReactDOM.Client.Root.t = "createRoot"
@get external getRuntime: Window.t => Nullable.t<JSON.t> = "__frontmanRuntime"
@set external setRuntime: (Window.t, Nullable.t<JSON.t>) => unit = "__frontmanRuntime"

let planner: ACP.Types.agentCatalogEntry = {
  id: "planner-banner",
  name: "planner",
  displayName: "Planner",
  description: "Plans work",
  color: "#F59E0B",
}
let executor: ACP.Types.agentCatalogEntry = {
  id: "executor-banner",
  name: "executor",
  displayName: "Executor",
  description: "Executes work",
  color: "#985DF7",
}

/**
 * Use actual transport objects, but stop before opening a socket. This test
 * observes reducer effects, not their execution or an LLM response.
 */
let localConnection = async taskId => {
  let acp = ACP.makeConfig(
    ~endpoint="ws://localhost:4000/socket",
    ~loginUrl="http://localhost:4000/users/log-in",
    ~getAuthToken=() => Some("local-browser-test"),
    ~name="banner-test",
    ~version="1",
    ~_meta=JSON.Encode.object(Dict.make()),
  )
  let captured = ref(None)
  let result = await ACP.connect(
    acp,
    ~onConnectionCreated=connection => {
      captured := Some(connection)
      connection.dispose()
    },
  )
  switch result {
  | Error(ConnectionFailed("Connection aborted")) => ()
  | _ => failwith("Expected to stop before opening the socket")
  }
  let connection = captured.contents->Option.getOrThrow
  let channel = connection.socket->ACP.Socket.channel(~topic=`task:${taskId}`)
  let session: ACP.session = {
    sessionId: taskId,
    channel,
    connection,
    cleanup: () => ACP.cleanupChannel(channel),
  }
  onTestFinished(() => {
    ACP.cleanupSessionChannel(session)
    ACP.disconnect(connection)
  })
  let lifetimeAbortController = AbortController.make()
  onTestFinished(() => lifetimeAbortController->AbortController.abort)
  let relayConfig = Connection.Relay.makeConfig(~baseUrl="http://localhost:4000")
  let relay: Connection.Relay.connected = {
    config: relayConfig,
    tools: [],
    serverInfo: {name: "banner-test", version: "1"},
    signal: lifetimeAbortController.signal,
  }
  let mcp = Connection.MCPServer.makeConfig()
  let state: Connection.state = {
    config: {acp, relay: relayConfig, mcp},
    connection: Ok(
      Some({
        lifetimeAbortController,
        phase: Ready({
          connection,
          relay,
          mcpServer: Connection.MCPServer.make(mcp, ~relay),
          session: SessionActive({session, requestId: ref()}),
        }),
      }),
    ),
  }
  Some(state)
}

testAsync("explains the switch and submits a completed plan through Executor only once", async t => {
  let previousRuntime = getRuntime(Window.current)
  setRuntime(
    Window.current,
    Nullable.make(JSON.Encode.object(dict{"framework": JSON.Encode.string("nextjs")})),
  )
  onTestFinished(() => setRuntime(Window.current, previousRuntime))
  let taskId = "banner-plan"
  let connection = await localConnection(taskId)
  let imageMessage = Client__Message.User({
    id: "user-image",
    content: [
      Client__State__Types.UserContentPart.text("Use this image in the plan"),
      Image({
        id: Some("reference-image"),
        image: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jWZkAAAAASUVORK5CYII=",
        mediaType: Some("image/png"),
        name: Some("reference.png"),
      }),
    ],
    annotations: [],
    agentId: planner.id,
  })
  let plan = Client__Message.Assistant(
    Completed({
      id: "assistant-plan",
      content: [Client__State__Types.AssistantContentPart.text("1. Add the image")],
      agentId: planner.id,
    }),
  )
  let task = switch Task.makeNew(~previewUrl="http://localhost:3000", ~clientId=taskId) {
  | New(draft) =>
    Task.Loaded(Task.promoteDraft(draft, ~id=taskId, ~title="Plan", ~timestamp=0.0))
  | _ => failwith("Expected a new task")
  }->Task.updateConversation(data => {
    ...data,
    messages: Client__MessageStore.fromArray([imageMessage, plan]),
  })
  let initial = {
    ...Client__State__Initialization.defaultState,
    currentTask: Task.Selected(taskId),
    tasks: Dict.fromArray([(taskId, task)]),
    connection,
    agentCatalog: Some([planner, executor]),
    selectedAgentId: Some(planner.id),
    selectedModelValue: Some("test:model"),
  }
  t->expect(Selectors.pendingPlanHandoff(initial)->Option.isSome)->Expect.toBe(true)
  let (approved, approvalEffects) = Reducer.next(
    initial,
    AddUserMessage({
      id: Client__Message.UserMessageId.make(),
      timestamp: Date.now(),
      content: [Client__State__Types.UserContentPart.text("Approved, implement it")],
      annotationId: None,
      onComplete: _ => (),
    }),
  )
  t->expect(approved.selectedAgentId)->Expect.toEqual(Some(planner.id))
  switch approvalEffects {
  | [Client__State__Protocol.SendMessage({submission: {agentId}})] =>
    t->expect(agentId)->Expect.toBe(planner.id)
  | _ => failwith("Expected chat approval to submit through Planner")
  }
  let state = ref(initial)
  let effects = ref([])
  let execute = () => {
    let (nextState, nextEffects) = Reducer.next(
      state.contents,
      ExecutePendingPlan({id: Client__Message.UserMessageId.make(), timestamp: Date.now()}),
    )
    state := nextState
    effects := Array.concat(effects.contents, nextEffects)
  }
  let container = DomGlobal.document->Document.createElement("div")
  DomGlobal.document.body->HTMLElement.appendChild(container->Element.asNode)->ignore
  let root = createRoot(container)
  onTestFinished(() => {
    root->ReactDOM.Client.Root.unmount()
    container->Element.remove
  })
  root->ReactDOM.Client.Root.render(<Client__ExecutePlanBanner onExecute=execute />)
  let button = page->getByRole("button", {name: "Execute plan"})
  await expectElement(button).toBeVisible()
  await expectElement(
    page->getByText("Switches to Executor to make changes. Approval text does not switch agents."),
  ).toBeVisible()
  await button->click
  t->expect(state.contents.selectedAgentId)->Expect.toEqual(Some(executor.id))
  t->expect(Selectors.isAgentRunning(state.contents))->Expect.toBe(true)
  t->expect(Selectors.pendingPlanHandoff(state.contents))->Expect.toEqual(None)
  switch effects.contents {
  | [Client__State__Protocol.SendMessage({taskId: submittedTaskId, submission: {content, agentId}})] =>
    t->expect(submittedTaskId)->Expect.toBe(taskId)
    t->expect(agentId)->Expect.toBe(executor.id)
    t
    ->expect(Client__Task__Reducer.extractTextFromUserContent(content))
    ->Expect.toBe(Client__State__Protocol.executePlanPrompt)
  | _ => failwith("Expected exactly one Executor submission")
  }
  t->expect(Selectors.messages(state.contents))->Expect.toEqual([imageMessage, plan])
  let firstEffects = effects.contents
  await button->click
  t->expect(effects.contents)->Expect.toEqual(firstEffects)
  t->expect(Selectors.messages(state.contents))->Expect.toEqual([imageMessage, plan])
})
