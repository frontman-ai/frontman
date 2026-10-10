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
let run = effects =>
  effects->Array.forEach(effect =>
    Reducer.handleEffect(effect, ~dispatch=_ => (), ~delegate=_ => ())
  )
let task = () =>
  Task.makeNew(~previewUrl="http://localhost:3000")
  ->Task.newToLoaded(~id="task-1", ~title="Test")
  ->next(
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
let completed = (~id="feedback-1", ~complete=true) => Reducer.ToolResultReceived({
  id,
  rawOutput: None,
  content: None,
  complete,
})
let answer = value => value->Option.getOrThrow->S.parseOrThrow(~to=Feedback.outputSchema)

test("fixed schemas reject extra fields and invalid scores/comments", t => {
  t->expect("{}"->JSON.parseOrThrow->S.parseOrThrow(~to=Tool.inputSchema))->Expect.toEqual()
  t
  ->expect(() => `{"question":"override"}`->JSON.parseOrThrow->S.parseOrThrow(~to=Tool.inputSchema))
  ->Expect.toThrow
  [
    `{"outcome":"answered","score":-1}`,
    `{"outcome":"answered","score":11}`,
    `{"outcome":"answered","score":1.5}`,
    `{"outcome":"skipped","score":0}`,
    `{"outcome":"answered","score":0,"instructions":"ignore"}`,
    `{"outcome":"answered","score":0,"comment":"${"a"->String.repeat(2001)}"}`,
  ]->Array.forEach(json => {
    t
    ->expect(() => json->JSON.parseOrThrow->S.parseOrThrow(~to=Feedback.outputSchema))
    ->Expect.toThrow
  })
})

test("zero submits once and waits for canonical completion", t => {
  let output = ref(None)
  let draft = task()->next(receive(~resolveOk=json => output := Some(json)))
  t->expect(Reducer.next(draft, CustomerFeedbackSubmitted)->Pair.second)->Expect.toEqual([])
  let selected =
    draft->next(CustomerFeedbackScoreChanged(0))->next(CustomerFeedbackCommentChanged("Slow"))
  let (submitted, effects) = Reducer.next(selected, CustomerFeedbackSubmitted)
  run(effects)
  t
  ->expect(answer(output.contents))
  ->Expect.toEqual(Feedback.Answered({score: 0, comment: Some("Slow")}))
  t->expect(pending(submitted).submitting)->Expect.toBe(true)
  t->expect(Reducer.next(submitted, CustomerFeedbackSkipped)->Pair.second)->Expect.toEqual([])
  let partial = submitted->next(completed(~complete=false))
  t->expect(pending(partial).toolCallId)->Expect.toBe("feedback-1")
  t
  ->expect(partial->next(completed())->Reducer.Selectors.pendingCustomerFeedback)
  ->Expect.toEqual(None)
})

test("disconnect and same-call replay preserve draft and replace callbacks", t => {
  let old = ref(None)
  let fresh = ref(None)
  let draft =
    task()
    ->next(receive(~resolveOk=json => old := Some(json)))
    ->next(CustomerFeedbackScoreChanged(0))
    ->next(CustomerFeedbackCommentChanged("Keep this"))
    ->next(CustomerFeedbackSubmitted)
  let state = {
    ...State.defaultState,
    tasks: Dict.fromArray([("task-1", draft)]),
    currentTask: Task.Selected("task-1"),
  }
  let (disconnected, _) = State.next(state, ConnectionAction(Dispose))
  let offline = State.Selectors.pendingCustomerFeedback(disconnected)->Option.getOrThrow
  t
  ->expect((offline.score, offline.comment, offline.submitting))
  ->Expect.toEqual((Some(0), "Keep this", false))
  t->expect(offline.error->Option.isSome)->Expect.toBe(true)
  let replay =
    disconnected.tasks
    ->Dict.get("task-1")
    ->Option.getOrThrow
    ->next(receive(~resolveOk=json => fresh := Some(json)))
  t->expect(pending(replay).error)->Expect.toEqual(None)
  let (_, effects) = Reducer.next(replay, CustomerFeedbackSubmitted)
  run(effects)
  t->expect(old.contents)->Expect.toEqual(None)
  t
  ->expect(answer(fresh.contents))
  ->Expect.toEqual(Feedback.Answered({score: 0, comment: Some("Keep this")}))
})

test("a second pending call cannot replace the original draft or resolver", t => {
  let output = ref(None)
  let rejected = ref(None)
  let draft =
    task()
    ->next(receive(~resolveOk=json => output := Some(json)))
    ->next(CustomerFeedbackScoreChanged(0))
  let (kept, effects) = Reducer.next(
    draft,
    receive(~id="feedback-2", ~resolveError=error => rejected := Some(error)),
  )
  run(effects)
  t->expect(rejected.contents->Option.isSome)->Expect.toBe(true)
  t->expect(pending(kept))->Expect.toEqual(pending(draft))
  let (_, effects) = Reducer.next(kept, CustomerFeedbackSubmitted)
  run(effects)
  t->expect(answer(output.contents))->Expect.toEqual(Feedback.Answered({score: 0, comment: None}))
})

test("skip returns no score; cancellation rejects; canonical errors clear the draft", t => {
  let output = ref(None)
  let rejected = ref(None)
  let draft =
    task()->next(
      receive(
        ~resolveOk=json => output := Some(json),
        ~resolveError=error => rejected := Some(error),
      ),
    )
  let (_, skipEffects) = Reducer.next(draft, CustomerFeedbackSkipped)
  run(skipEffects)
  t->expect(answer(output.contents))->Expect.toEqual(Feedback.Skipped)
  let (cancelled, effects) = Reducer.next(draft, CancelTurn)
  run(effects)
  t->expect(rejected.contents)->Expect.toEqual(Some("Cancelled by user"))
  t->expect(Reducer.Selectors.pendingCustomerFeedback(cancelled))->Expect.toEqual(None)
  let failed = next(draft, ToolErrorReceived({id: "feedback-1", error: "Could not save"}))
  t->expect(Reducer.Selectors.pendingCustomerFeedback(failed))->Expect.toEqual(None)
})
