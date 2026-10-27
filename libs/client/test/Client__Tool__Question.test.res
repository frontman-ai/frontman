open Vitest

module Question = Client__Tool__Question
module Store = Client__State__Store
module Reducer = Client__State__StateReducer
module Task = Client__Task__Types.Task

testAsync("request abort stops only its question and cannot cancel a newer question", async t => {
  let tasks = Dict.make()
  ["task-1", "task-2"]->Array.forEach(id =>
    tasks->Dict.set(id, Task.makeNew(~previewUrl="/")->Task.newToLoaded(~id, ~title=id))
  )
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Store.store,
    {...Reducer.defaultState, tasks},
  )
  FrontmanBindings.Bindings__Test__Vitest.onTestFinished(() => {
    ["task-1", "task-2"]->Array.forEach(taskId => Client__State.Actions.questionAllSkipped(~taskId))
    StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
      Store.store,
      Reducer.defaultState,
    )
  })
  let pending = taskId =>
    StateStore.getState(Store.store).tasks
    ->Dict.get(taskId)
    ->Option.getOrThrow
    ->Client__Task__Reducer.Selectors.pendingQuestion
  let controller = WebAPI.AbortController.make()
  let first = Question.execute(
    {questions: []},
    ~taskId="task-1",
    ~toolCallId="first",
    ~signal=controller.signal,
  )
  let other = Question.execute({questions: []}, ~taskId="task-2", ~toolCallId="other")
  WebAPI.AbortController.abort(controller)
  t->expect(pending("task-1"))->Expect.toEqual(None)
  t->expect(pending("task-2")->Option.isSome)->Expect.toBe(true)
  let result =
    (await first)
    ->S.decodeOrThrow(~from=Question.Tool.MCP.CallToolResult.schema, ~to=S.json)
    ->S.parseOrThrow(~to=S.object(s => s.field("structuredContent", Question.outputSchema)))
  t->expect(result.cancelled)->Expect.toBe(true)
  let newer = Question.execute({questions: []}, ~taskId="task-1", ~toolCallId="newer")
  WebAPI.AbortController.abort(controller)
  let alreadyCancelled = Question.execute(
    {questions: []},
    ~taskId="task-1",
    ~toolCallId="old",
    ~signal=controller.signal,
  )
  t->expect((pending("task-1")->Option.getOrThrow).toolCallId)->Expect.toBe("newer")
  (await alreadyCancelled)->ignore
  ["task-1", "task-2"]->Array.forEach(taskId => Client__State.Actions.questionAllSkipped(~taskId))
  let _ = await Promise.all([newer, other])
})
