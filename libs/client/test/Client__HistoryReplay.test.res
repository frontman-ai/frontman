open Vitest

module Task = Client__Task__Types.Task
module Message = Client__Task__Types.Message
module UserContentPart = Client__Message.UserContentPart
module TaskReducer = Client__Task__Reducer
module Buffer = Client__TextDeltaBuffer

let makeLoadingTask = () =>
  Task.makeUnloaded(~id="task-1", ~title="Test", ~createdAt=0.0, ~updatedAt=0.0)
  ->TaskReducer.next(LoadStarted({previewUrl: "http://localhost:3000"}))
  ->Pair.first

let apply = (task, action) => TaskReducer.next(task, action)->Pair.first

let user = (~id, ~text): TaskReducer.action => TaskReducer.UserMessageReceived({
  id,
  content: [UserContentPart.text(text)],
  annotations: [],
  agentId: "executor-id",
})

let delta = (
  ~id,
  ~text,
  ~agentId="executor-id",
): TaskReducer.action => TaskReducer.TextDeltaReceived({
  messageId: id,
  text,
  agentId,
})

let tool = (id): TaskReducer.action => TaskReducer.ToolCallReceived({
  toolCall: {
    id,
    toolName: "read",
    state: Message.InputAvailable,
    inputBuffer: "",
    input: None,
    result: None,
    errorText: None,
    parentAgentId: None,
    spawningToolName: None,
  },
})

let text = message =>
  switch message {
  | Message.User({content}) =>
    content
    ->Array.filterMap(part =>
      switch part {
      | UserContentPart.Text({text}) => Some(text)
      | _ => None
      }
    )
    ->Array.join("")
  | Message.Assistant(Streaming({textBuffer})) => textBuffer
  | Message.Assistant(Completed({content})) =>
    content
    ->Array.filterMap(part =>
      switch part {
      | Message.AssistantContentPart.Text({text}) => Some(text)
      | Message.AssistantContentPart.ToolCall(_) => None
      }
    )
    ->Array.join("")
  | Message.ToolCall(_) => "tool"
  | Message.Error(error) => Message.ErrorMessage.error(error)
  }

let summary = task =>
  Task.getMessages(task)->Array.map(message => (Message.getId(message), text(message)))

let replay = actions => {
  let task = ref(makeLoadingTask())
  let buffer = Buffer.make(
    ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~agentId as _) => (),
    ~onFlush=(~taskId as _, ~messageId, ~text, ~agentId) =>
      task := task.contents->apply(TextDeltaReceived({messageId, text, agentId})),
  )
  actions->Array.forEach(action =>
    switch action {
    | #User(id, value) => {
        buffer.flush()
        task := task.contents->apply(user(~id, ~text=value))
      }
    | #Agent(id, value) =>
      buffer.add(~taskId="task-1", ~messageId=id, ~text=value, ~agentId="executor-id")
    | #Tool(id) => {
        buffer.flush()
        task := task.contents->apply(tool(id))
      }
    }
  )
  buffer.flush()
  task.contents->apply(LoadComplete)
}

describe("ACP message identity", () => {
  test("load results reject stale requests, flush history, and preserve cached tasks", t => {
    module App = Client__State__StateReducer
    module Connection = Client__ConnectionReducer
    module Helpers = Client__ConnectionTestHelpers
    Buffer.reset()
    let initial = {...App.defaultState, tasks: Dict.fromArray([("task-1", makeLoadingTask())])}
    let getTask = (state: App.state) => state.tasks->Dict.get("task-1")->Option.getOrThrow
    [
      App.SwitchTask({taskId: "task-1"}),
      TaskLoadFinished({taskId: "task-1", result: Ok(ref())}),
    ]->Array.forEach(
      action =>
        t
        ->expect(App.next(initial, action)->Pair.first->getTask->Task.isLoading)
        ->Expect.toBe(false),
    )
    let requests: array<Connection.sessionRequestId> = []
    let operations = []
    let store = Helpers.makeStore(
      {...initial, connection: Helpers.ready()},
      (effect, state, dispatch) =>
        switch effect {
        | ConnectionEffect(ActivateSessionEffect({requestId, operation: #load("task-1")})) =>
          operations->Array.push(#load("task-1"))
          requests->Array.push(requestId)
        | ConnectionEffect(FetchSessionsEffect(_)) => ()
        | _ => App.handleEffect(effect, state, dispatch)
        },
    )
    let dispatch = action => store->StateStore.dispatch(action)
    let switchTask = () => dispatch(SwitchTask({taskId: "task-1"}))
    let finish = index => {
      let requestId = requests->Array.get(index)->Option.getOrThrow
      dispatch(
        SessionEvent({
          requestId,
          action: TaskAction({
            target: ForTask("task-1"),
            action: LoadStarted({previewUrl: "about:blank"}),
          }),
        }),
      )
      dispatch(
        SessionEvent({
          requestId,
          action: AcpSessionUpdateReceived({
            taskId: "task-1",
            update: AgentMessageChunk({
              messageId: "assistant-1",
              content: TextContent({text: "History", _meta: None, annotations: None}),
              _meta: {agentId: "executor-id", timestamp: "2026-01-01T00:00:00Z"},
            }),
          }),
        }),
      )
      dispatch(
        ConnectionAction(
          SessionResultReceived({
            requestId,
            sessionId: "task-1",
            result: Ok((Helpers.session("task-1"), None)),
          }),
        ),
      )
    }
    switchTask()
    switchTask()
    t->expect(store->StateStore.getState->App.Selectors.isSubmitting)->Expect.toBe(true)
    finish(0)
    t->expect(store->StateStore.getState->App.Selectors.isSubmitting)->Expect.toBe(true)
    finish(1)
    let loaded = store->StateStore.getState->getTask
    t->expect(Task.isLoaded(loaded))->Expect.toBe(true)
    t->expect(summary(loaded))->Expect.toEqual([("assistant-1", "History")])
    switch Task.getMessages(loaded)->Array.get(0) {
    | Some(Assistant(Completed(_))) => ()
    | _ => failwith("History must flush before LoadComplete")
    }
    switchTask()
    t->expect(requests->Array.length)->Expect.toBe(2)
    dispatch(ClearCurrentTask)
    switchTask()
    finish(2)
    t->expect(operations)->Expect.toEqual([#load("task-1"), #load("task-1"), #load("task-1")])
    t->expect(store->StateStore.getState->getTask)->Expect.toEqual(loaded)
    Buffer.reset()
  })

  test("replay execution state survives LoadComplete", t => {
    let running = makeLoadingTask()->apply(ExecutionStateRunning)->apply(LoadComplete)
    t->expect(TaskReducer.Selectors.isAgentRunning(running))->Expect.toEqual(Some(true))

    let paused = makeLoadingTask()->apply(ExecutionStateRequiresAction)->apply(LoadComplete)
    t->expect(TaskReducer.Selectors.isAgentRunning(paused))->Expect.toEqual(Some(false))
  })

  test("live and replay paths assemble identical message identities", t => {
    let actions = [
      #User("user-1", "Hello "),
      #User("user-1", "world"),
      #Agent("assistant-1", "First "),
      #Agent("assistant-1", "answer"),
      #User("user-2", "Next"),
      #Agent("assistant-2", "Second"),
      #Agent("assistant-3", "Third"),
    ]
    let replayed = replay(actions)
    let live =
      makeLoadingTask()
      ->apply(user(~id="user-1", ~text="Hello "))
      ->apply(user(~id="user-1", ~text="world"))
      ->apply(delta(~id="assistant-1", ~text="First "))
      ->apply(delta(~id="assistant-1", ~text="answer"))
      ->apply(user(~id="user-2", ~text="Next"))
      ->apply(delta(~id="assistant-2", ~text="Second"))
      ->apply(delta(~id="assistant-3", ~text="Third"))
      ->apply(LoadComplete)

    t->expect(summary(replayed))->Expect.toEqual(summary(live))
    t
    ->expect(summary(replayed))
    ->Expect.toEqual([
      ("user-1", "Hello world"),
      ("assistant-1", "First answer"),
      ("user-2", "Next"),
      ("assistant-2", "Second"),
      ("assistant-3", "Third"),
    ])
  })

  test("tool-separated assistant IDs remain distinct", t => {
    let task = replay([
      #User("user-1", "Run"),
      #Agent("assistant-1", "Before"),
      #Tool("tool-1"),
      #Agent("assistant-2", "After"),
    ])

    t
    ->expect(summary(task))
    ->Expect.toEqual([
      ("user-1", "Run"),
      ("assistant-1", "Before"),
      ("tool-1", "tool"),
      ("assistant-2", "After"),
    ])
  })

  test("message role and agent are immutable", t => {
    let userTask = makeLoadingTask()->apply(user(~id="message-1", ~text="Hello"))
    let agentTask = makeLoadingTask()->apply(delta(~id="message-2", ~text="Hello"))

    Expect.toThrow(t->expect(() => userTask->apply(delta(~id="message-1", ~text="wrong role"))))
    Expect.toThrow(
      t->expect(
        () => agentTask->apply(delta(~id="message-2", ~text="wrong agent", ~agentId="planner-id")),
      ),
    )
  })

  test("completed assistant identity cannot be appended", t => {
    let completed =
      makeLoadingTask()
      ->apply(delta(~id="assistant-1", ~text="Answer"))
      ->apply(LoadComplete)

    Expect.toThrow(t->expect(() => completed->apply(delta(~id="assistant-1", ~text="Answer"))))
  })
})
