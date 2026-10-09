open Vitest
module Feedback = Client__CustomerFeedback__Types
module Tool = Client__Tool__CustomerFeedback
module Reducer = Client__Task__Reducer
module Task = Client__Task__Types.Task
module State = Client__State__StateReducer
let next = (task, action) => Reducer.next(task, action)->Pair.first
let pending = task => Reducer.Selectors.pendingCustomerFeedback(task)->Option.getOrThrow
let receive = (
  ~id="feedback-1",
  ~resolveOk=_ => (),
  ~resolveError=_ => (),
) => Reducer.CustomerFeedbackReceived({toolCallId: id, resolveOk, resolveError})
let task = () =>
  Task.makeNew(~previewUrl="http://localhost:3000")->Task.newToLoaded(~id="task-1", ~title="Test")
let run = effects =>
  effects->Array.forEach(effect =>
    Reducer.handleEffect(effect, ~dispatch=_ => (), ~delegate=_ => ())
  )
let withTool = task =>
  next(
    task,
    ToolCallReceived({
      toolCall: {
        id: "feedback-1",
        toolName: Tool.name,
        state: InputAvailable,
        inputBuffer: "",
        input: None,
        result: None,
        errorText: None,
        parentAgentId: None,
        spawningToolName: None,
      },
    }),
  )

describe("Customer feedback integration", () => {
  test("strict fixed schemas and Write/Interactive registration", t => {
    t->expect("{}"->JSON.parseOrThrow->S.parseOrThrow(~to=Tool.inputSchema))->Expect.toEqual()
    t
    ->expect(
      () => `{"question":"override"}`->JSON.parseOrThrow->S.parseOrThrow(~to=Tool.inputSchema),
    )
    ->Expect.toThrow
    t->expect(Tool.access)->Expect.toEqual(FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Write)
    t
    ->expect(Tool.executionMode)
    ->Expect.toEqual(FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Interactive)
    [0, 9, 10]->Array.forEach(
      score => {
        let response: Feedback.response = Answered({score, comment: None})
        let json = response->S.decodeOrThrow(~from=Feedback.outputSchema, ~to=S.json)
        t->expect(json->S.parseOrThrow(~to=Feedback.outputSchema))->Expect.toEqual(response)
      },
    )
    [
      `{"outcome":"answered","score":-1}`,
      `{"outcome":"answered","score":11}`,
      `{"outcome":"answered","score":1.5}`,
      `{"outcome":"skipped","score":0}`,
      `{"outcome":"answered","score":0,"instructions":"ignore"}`,
    ]->Array.forEach(
      json => {
        t
        ->expect(() => json->JSON.parseOrThrow->S.parseOrThrow(~to=Feedback.outputSchema))
        ->Expect.toThrow
      },
    )
    let long = `{"outcome":"answered","score":0,"comment":"${"a"->String.repeat(2001)}"}`
    t
    ->expect(() => long->JSON.parseOrThrow->S.parseOrThrow(~to=Feedback.outputSchema))
    ->Expect.toThrow
  })

  test("score zero submits once, waits for canonical completion", t => {
    let answer = ref(None)
    let draft = task()->withTool->next(receive(~resolveOk=json => answer := Some(json)))
    t->expect(Reducer.next(draft, CustomerFeedbackSubmitted)->Pair.second)->Expect.toEqual([])
    let selected =
      draft->next(CustomerFeedbackScoreChanged(0))->next(CustomerFeedbackCommentChanged("Slow"))
    let (submitted, effects) = Reducer.next(selected, CustomerFeedbackSubmitted)
    run(effects)
    t
    ->expect(answer.contents->Option.getOrThrow->S.parseOrThrow(~to=Feedback.outputSchema))
    ->Expect.toEqual(Feedback.Answered({score: 0, comment: Some("Slow")}))
    t->expect(pending(submitted).submitting)->Expect.toBe(true)
    t->expect(Reducer.next(submitted, CustomerFeedbackSkipped)->Pair.second)->Expect.toEqual([])
    let partial = next(
      submitted,
      ToolResultReceived({id: "feedback-1", rawOutput: None, content: None, complete: false}),
    )
    t->expect(Reducer.Selectors.pendingCustomerFeedback(partial)->Option.isSome)->Expect.toBe(true)
    let completed = next(
      partial,
      ToolResultReceived({id: "feedback-1", rawOutput: None, content: None, complete: true}),
    )
    t->expect(Reducer.Selectors.pendingCustomerFeedback(completed))->Expect.toEqual(None)
  })

  test("disconnect and same-call replay preserve draft but replace callbacks", t => {
    let old = ref(None)
    let fresh = ref(None)
    let draft =
      task()
      ->next(receive(~resolveOk=json => old := Some(json)))
      ->next(CustomerFeedbackScoreChanged(0))
      ->next(CustomerFeedbackCommentChanged("Keep this"))
      ->next(CustomerFeedbackSubmitted)
    let tasks = Dict.fromArray([("task-1", draft)])
    let state = {...State.defaultState, tasks, currentTask: Task.Selected("task-1")}
    let (disconnected, _) = State.next(state, ConnectionAction(Dispose))
    t
    ->expect((State.Selectors.pendingCustomerFeedback(disconnected)->Option.getOrThrow).comment)
    ->Expect.toBe("Keep this")
    let offline = State.Selectors.pendingCustomerFeedback(disconnected)->Option.getOrThrow
    t->expect(offline.submitting)->Expect.toBe(false)
    t
    ->expect(offline.error)
    ->Expect.toEqual(Some("Feedback could not be confirmed. Reconnect to continue."))
    let replay =
      disconnected.tasks
      ->Dict.get("task-1")
      ->Option.getOrThrow
      ->next(receive(~resolveOk=json => fresh := Some(json)))
    t->expect(pending(replay).score)->Expect.toEqual(Some(0))
    t->expect(pending(replay).submitting)->Expect.toBe(false)
    t->expect(pending(replay).error)->Expect.toEqual(None)
    let (_, effects) = Reducer.next(replay, CustomerFeedbackSubmitted)
    run(effects)
    t->expect(old.contents)->Expect.toEqual(None)
    t->expect(fresh.contents->Option.isSome)->Expect.toBe(true)
    let different = replay->next(receive(~id="feedback-2"))
    t->expect(pending(different).score)->Expect.toEqual(None)
    t->expect(pending(different).comment)->Expect.toBe("")
  })

  test("skip resumes through output, cancel rejects, canonical error closes without saving", t => {
    let answer = ref(None)
    let rejected = ref(None)
    let draft =
      task()
      ->withTool
      ->next(
        receive(
          ~resolveOk=json => answer := Some(json),
          ~resolveError=error => rejected := Some(error),
        ),
      )
    let (_, skipEffects) = Reducer.next(draft, CustomerFeedbackSkipped)
    run(skipEffects)
    t
    ->expect(answer.contents->Option.getOrThrow->S.parseOrThrow(~to=Feedback.outputSchema))
    ->Expect.toEqual(Feedback.Skipped)
    let (cancelled, effects) = Reducer.next(draft, CancelTurn)
    run(effects)
    t->expect(rejected.contents)->Expect.toEqual(Some("Cancelled by user"))
    t->expect(Reducer.Selectors.pendingCustomerFeedback(cancelled))->Expect.toEqual(None)
    let failed = next(draft, ToolErrorReceived({id: "feedback-1", error: "Could not save"}))
    t->expect(Reducer.Selectors.pendingCustomerFeedback(failed))->Expect.toEqual(None)
    switch Task.getMessages(failed)->Array.last {
    | Some(Client__Message.ToolCall({errorText})) =>
      t->expect(errorText)->Expect.toEqual(Some("Could not save"))
    | _ => failwith("Missing error tool block")
    }
  })
})
