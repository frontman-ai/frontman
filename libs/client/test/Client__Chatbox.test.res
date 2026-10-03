open Vitest

module Chatbox = Client__Chatbox
module Message = Client__State__Types.Message

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

describe("shouldRenderTurnError", () => {
  test("hides turn error when matching error message is already rendered", t => {
    let error = Message.ErrorMessage.make(
      ~id="agent-error-1",
      ~error="Authentication failed",
      ~category=#auth,
    )
    t
    ->expect(Chatbox.shouldRenderTurnError([Message.Error(error)], "agent-error-1"))
    ->Expect.toBe(false)
  })

  test("shows turn error when no matching error message exists", t => {
    let otherError = Message.ErrorMessage.make(
      ~id="older-error",
      ~error="Earlier failure",
      ~category=#auth,
    )

    t
    ->expect(Chatbox.shouldRenderTurnError([Message.Error(otherError)], "agent-error-1"))
    ->Expect.toBe(true)
  })
})

describe("selectGetStartedTask", () => {
  test("opens provider settings instead of submitting when setup is required", t => {
    let configuredProvider = ref(false)
    let submittedTask = ref(None)

    Chatbox.selectGetStartedTask(
      ~providerSetupRequired=true,
      ~onConfigureProvider=() => configuredProvider := true,
      ~onSelect=text => submittedTask := Some(text),
      "Make the main heading bigger and bolder",
    )

    t->expect(configuredProvider.contents)->Expect.toBe(true)
    t->expect(submittedTask.contents)->Expect.toEqual(None)
  })

  test("submits the task when a provider is configured", t => {
    let configuredProvider = ref(false)
    let submittedTask = ref(None)

    Chatbox.selectGetStartedTask(
      ~providerSetupRequired=false,
      ~onConfigureProvider=() => configuredProvider := true,
      ~onSelect=text => submittedTask := Some(text),
      "Make the main heading bigger and bolder",
    )

    t->expect(configuredProvider.contents)->Expect.toBe(false)
    t
    ->expect(submittedTask.contents)
    ->Expect.toEqual(Some("Make the main heading bigger and bolder"))
  })
})

module Submission = {
  type runtime = {"framework": string, "traits": array<string>}
  @set external setRuntime: (WebAPI.DomTypes.window, option<runtime>) => unit = "__frontmanRuntime"
  type actions
  type calls = {calls: array<array<JSON.t>>}
  type spy = {mock: calls}
  @module("../src/state/Client__State.res.mjs") external actions: actions = "Actions"
  @module("vitest") @scope("vi") external spyOn: (actions, string) => spy = "spyOn"
  @send external mockReturnValue: (spy, unit) => unit = "mockReturnValue"
  @module("vitest") @scope("vi") external restoreAllMocks: unit => unit = "restoreAllMocks"
}

describe("sendUserMessage", () => {
  open Submission
  afterEach(() => {
    setRuntime(WebAPI.DomGlobal.window, None)
    restoreAllMocks()
  })

  testAsync("preflight prevents phantom tasks and reloads interrupted history", async t => {
    let runtime = ref({"framework": "nextjs", "traits": []})
    setRuntime(WebAPI.DomGlobal.window, Some(runtime.contents))
    let reload = spyOn(actions, "switchTask")
    let send = spyOn(actions, "addUserMessage")
    mockReturnValue(reload, ())
    mockReturnValue(send, ())
    let created = ref(0)
    let submit = (content, currentTaskId) =>
      Chatbox.sendUserMessage(
        ~session=None,
        ~createSession=(~onComplete) => {
          created := created.contents + 1
          runtime :=
            {"framework": runtime.contents["framework"], "traits": ["x"->String.repeat(8_000_000)]}
          setRuntime(WebAPI.DomGlobal.window, Some(runtime.contents))
          onComplete(Ok("new-session"))
        },
        ~currentTaskId,
        ~content,
        ~annotations=[],
        ~agentId="executor",
      )
    let image = Client__State.UserContentPart.File({
      file: "data:image/png;base64," ++ "A"->String.repeat(4_000_000),
    })
    t
    ->expect(await submit([image, image], None)->Promise.thenResolve(Result.isError))
    ->Expect.toBe(true)
    t->expect(created.contents)->Expect.toBe(0)
    let text = [Client__State.UserContentPart.Text({text: "draft"})]
    t
    ->expect(await submit(text, Some("history"))->Promise.thenResolve(Result.isError))
    ->Expect.toBe(true)
    t->expect(reload.mock.calls)->Expect.toEqual([[JSON.Encode.string("history")]])
    t->expect(await submit(text, None)->Promise.thenResolve(Result.isError))->Expect.toBe(true)
    t->expect(created.contents)->Expect.toBe(1)
    t->expect(send.mock.calls)->Expect.toEqual([])
  })
})

describe("ExecutePlanAction", () => {
  test("hides execute action without a selected model", t => {
    let html = renderToStaticMarkup(
      <Chatbox.ExecutePlanAction
        pendingPlanHandoff={Some()} selectedModelValue=None onExecute={() => ()}
      />,
    )

    t->expect(html->String.includes("Execute plan"))->Expect.toBe(false)
  })

  test("shows execute action when a plan and model are available", t => {
    let html = renderToStaticMarkup(
      <Chatbox.ExecutePlanAction
        pendingPlanHandoff={Some()} selectedModelValue={Some("test:model")} onExecute={() => ()}
      />,
    )

    t->expect(html->String.includes("Execute plan"))->Expect.toBe(true)
  })
})
