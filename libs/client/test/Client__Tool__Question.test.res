open Vitest

module Question = Client__Tool__Question
module Store = Client__State__Store
module Reducer = Client__State__StateReducer
module Task = Client__Task__Types.Task

testAsync("request abort stops only its question and cannot cancel a newer question", async t => {
  let tasks = Dict.make()
  ["task-1"]->Array.forEach(id =>
    tasks->Dict.set(id, Task.makeNew(~previewUrl="/")->Task.newToLoaded(~id, ~title=id))
  )
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Store.store,
    {...Reducer.defaultState, tasks},
  )
  FrontmanBindings.Bindings__Test__Vitest.onTestFinished(() => {
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
  let nextController = WebAPI.AbortController.make()
  let newer = Question.execute(
    {questions: []},
    ~taskId="task-1",
    ~toolCallId="first",
    ~signal=nextController.signal,
  )
  let current = pending("task-1")
  WebAPI.AbortController.abort(controller)
  t->expect(pending("task-1"))->Expect.toEqual(current)
  let result =
    (await first)
    ->S.decodeOrThrow(~from=Question.Tool.MCP.CallToolResult.schema, ~to=S.json)
    ->S.parseOrThrow(~to=S.object(s => s.field("structuredContent", Question.outputSchema)))
  t->expect(result.cancelled)->Expect.toBe(true)
  let alreadyCancelled = Question.execute(
    {questions: []},
    ~taskId="task-1",
    ~toolCallId="old",
    ~signal=controller.signal,
  )
  t->expect(pending("task-1"))->Expect.toEqual(current)
  (await alreadyCancelled)->ignore
  WebAPI.AbortController.abort(nextController)
  t->expect(pending("task-1"))->Expect.toEqual(None)
  (await newer)->ignore
  let teardown = WebAPI.AbortController.make()
  let deleted = Question.execute(
    {questions: []},
    ~taskId="task-1",
    ~toolCallId="deleted",
    ~signal=teardown.signal,
  )
  Store.dispatch(DeleteTask({taskId: "task-1"}))
  WebAPI.AbortController.abort(teardown)
  (await deleted)->ignore
})
