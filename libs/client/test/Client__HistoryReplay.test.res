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
    | #Turn(ids) => {
        buffer.flush()
        task := task.contents->apply(ExecutionStateRunning(ids))
      }
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
  test("wire replay restores queue, plan and exact claims after an early live claim", t => {
    module App = Client__State__StateReducer
    module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
    Buffer.reset()
    let loading = makeLoadingTask()
    let store = StateStore.make(
      module(App),
      {
        ...App.defaultState,
        tasks: Dict.fromArray([("task-1", loading)]),
        currentTask: Task.Selected("task-1"),
      },
    )
    let dispatch = action => store->StateStore.dispatch(action)
    let receive = update => {
      let notification =
        JSON.parseOrThrow(
          `{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"task-1","update":${update}}}`,
        )->S.parseOrThrow(~to=ACP.sessionUpdateNotificationSchema)
      dispatch(
        AcpSessionUpdateReceived({
          taskId: notification.params.sessionId,
          update: notification.params.update,
        }),
      )
    }
    let userChunk = (id, text) =>
      receive(
        `{"sessionUpdate":"user_message_chunk","messageId":"${id}","content":{"type":"text","text":"${text}"},"_meta":{"frontman.dev/agentId":"executor-id","frontman.dev/timestamp":"2026-07-14T12:30:01Z"}}`,
      )
    receive(`{"sessionUpdate":"session_info_update","title":"Unrelated","_meta":{"other.vendor/trace":true}}`)
    t
    ->expect(
      TaskReducer.Selectors.isAgentRunning(
        (store->StateStore.getState).tasks->Dict.get("task-1")->Option.getOrThrow,
      ),
    )
    ->Expect.toEqual(TaskReducer.Selectors.isAgentRunning(loading))
    userChunk("loading-queued", "Claimed while loading")
    receive(`{"sessionUpdate":"session_info_update","_meta":{"frontman.dev/turnMessageIds":["claimed","loading-queued","loading-queued"]}}`)
    userChunk("claimed", "Current turn")
    userChunk("queued", "Follow-up")
    receive(`{"sessionUpdate":"session_info_update","_meta":{"frontman.dev/turnMessageIds":["claimed","loading-queued"]}}`)
    receive(`{"sessionUpdate":"state_update","state":"running"}`)
    receive(`{"sessionUpdate":"plan","entries":[{"content":"Server plan","priority":"high","status":"in_progress"}]}`)
    dispatch(TaskAction({target: ForTask("task-1"), action: LoadComplete}))
    let task = () => (store->StateStore.getState).tasks->Dict.get("task-1")->Option.getOrThrow
    let claimed = [("loading-queued", "Claimed while loading"), ("claimed", "Current turn")]
    t->expect(task()->summary)->Expect.toEqual(claimed)
    t->expect(TaskReducer.Selectors.isAgentRunning(task()))->Expect.toEqual(Some(true))
    t
    ->expect(TaskReducer.Selectors.planEntries(task())->Option.getOrThrow->Array.length)
    ->Expect.toBe(1)
    t
    ->expect(
      TaskReducer.Selectors.queuedUserMessages(task())
      ->Option.getOrThrow
      ->Array.map(Message.getId),
    )
    ->Expect.toEqual(["queued"])
    userChunk("later", "Keep queued")
    receive(`{"sessionUpdate":"session_info_update","_meta":{"frontman.dev/turnMessageIds":["queued","queued"]}}`)
    t
    ->expect(task()->summary)
    ->Expect.toEqual(Array.concat(claimed, [("queued", "Follow-up")]))
    Expect.toThrow(
      t->expect(
        () =>
          receive(`{"sessionUpdate":"session_info_update","_meta":{"frontman.dev/turnMessageIds":["unknown"]}}`),
      ),
    )
    receive(`{"sessionUpdate":"message_unqueued","messageId":"later"}`)
    t->expect(TaskReducer.Selectors.queuedUserMessages(task()))->Expect.toEqual(Some([]))
    userChunk("removed-before-flush", "Remove immediately")
    receive(`{"sessionUpdate":"message_unqueued","messageId":"removed-before-flush"}`)
    t->expect(TaskReducer.Selectors.queuedUserMessages(task()))->Expect.toEqual(Some([]))
    receive(`{"sessionUpdate":"state_update","state":"idle"}`)
    t->expect(TaskReducer.Selectors.isAgentRunning(task()))->Expect.toEqual(Some(false))
    Buffer.reset()
  })

  test("load results reject stale requests, flush history, and preserve cached tasks", t => {
    module App = Client__State__StateReducer
    module Store = StateStore
    module Connection = Client__ConnectionReducer
    Buffer.reset()
    let requests: array<Connection.action> = []
    let operations = []
    let initial = {...App.defaultState, tasks: Dict.fromArray([("task-1", makeLoadingTask())])}
    let getTask = (state: App.state) => state.tasks->Dict.get("task-1")->Option.getOrThrow
    let rejected = App.next(initial, SwitchTask({taskId: "task-1"}))->Pair.first
    t->expect(getTask(rejected)->Task.isLoading)->Expect.toBe(false)
    let cancelled =
      App.next(initial, TaskLoadFinished({taskId: "task-1", result: Ok(ref())}))->Pair.first
    t->expect(getTask(cancelled)->Task.isLoading)->Expect.toBe(false)
    let store = Client__ConnectionTestHelpers.makeStore(
      {...initial, connection: Client__ConnectionTestHelpers.ready()},
      (effect, state, dispatch) =>
        switch effect {
        | ConnectionEffect(ActivateSessionEffect({
            requestId,
            operation: (#load(sessionId) | #join(sessionId)) as operation,
          })) =>
          operations->Array.push(operation)
          requests->Array.push(
            Connection.SessionResultReceived({
              requestId,
              sessionId,
              result: Ok((Client__ConnectionTestHelpers.session(sessionId), None)),
            }),
          )
        | _ => App.handleEffect(effect, state, dispatch)
        },
    )
    let switchTask = () => store->Store.dispatch(SwitchTask({taskId: "task-1"}))
    let finish = index =>
      store->Store.dispatch(ConnectionAction(requests->Array.get(index)->Option.getOrThrow))
    switchTask()
    switchTask()
    t->expect(store->Store.getState->getTask->Task.isLoading)->Expect.toBe(true)
    finish(0)
    t->expect(store->Store.getState->getTask->Task.isLoading)->Expect.toBe(true)
    let dispatch = action => store->Store.dispatch(action)
    App.getSessionTextBuffer(dispatch).add(
      ~taskId="task-1",
      ~messageId="assistant-1",
      ~text="History",
      ~agentId="executor-id",
    )
    finish(1)
    let loaded = store->Store.getState->getTask
    t->expect(Task.isLoaded(loaded))->Expect.toBe(true)
    t->expect(summary(loaded))->Expect.toEqual([("assistant-1", "History")])
    switch Task.getMessages(loaded)->Array.get(0) {
    | Some(Assistant(Completed(_))) => ()
    | _ => failwith("History must flush before LoadComplete")
    }
    switchTask()
    t->expect(requests->Array.length)->Expect.toBe(2)
    store->Store.dispatch(ClearCurrentTask)
    switchTask()
    finish(2)
    t->expect(operations)->Expect.toEqual([#load("task-1"), #load("task-1"), #join("task-1")])
    t->expect(store->Store.getState->getTask)->Expect.toBe(loaded)
    Buffer.reset()
  })

  test("replay execution state survives LoadComplete", t => {
    let running = makeLoadingTask()->apply(ExecutionStateRunning([]))->apply(LoadComplete)
    t->expect(TaskReducer.Selectors.isAgentRunning(running))->Expect.toEqual(Some(true))

    let paused = makeLoadingTask()->apply(ExecutionStateRequiresAction)->apply(LoadComplete)
    t->expect(TaskReducer.Selectors.isAgentRunning(paused))->Expect.toEqual(Some(false))
    let idle = makeLoadingTask()->apply(ExecutionStateRunning([]))->apply(ExecutionStateIdle)->apply(LoadComplete)
    t->expect(TaskReducer.Selectors.isAgentRunning(idle))->Expect.toEqual(Some(false))
    let failed = makeLoadingTask()->apply(ExecutionStateRunning([]))->apply(AgentError({id: None, error: "Failed", category: #unknown}))
    t->expect(TaskReducer.Selectors.isAgentRunning(failed->apply(LoadComplete)))->Expect.toEqual(Some(false))
    let retry = failed->apply(ExecutionStateRunning([]))->apply(LoadComplete)
    t->expect(TaskReducer.Selectors.isAgentRunning(retry))->Expect.toEqual(Some(true))
  })

  test("live and replay paths assemble identical message identities", t => {
    let actions = [
      #User("user-1", "Hello "),
      #User("user-1", "world"),
      #User("user-2", "Next"),
      #Turn(["user-1"]),
      #Agent("assistant-1", "First "),
      #Agent("assistant-1", "answer"),
      #Turn(["user-2"]),
      #Agent("assistant-2", "Second"),
      #Agent("assistant-3", "Third"),
    ]
    let replayed = replay(actions)
    let live =
      makeLoadingTask()
      ->apply(user(~id="user-1", ~text="Hello "))
      ->apply(user(~id="user-1", ~text="world"))
      ->apply(ExecutionStateRunning(["user-1"]))
      ->apply(delta(~id="assistant-1", ~text="First "))
      ->apply(delta(~id="assistant-1", ~text="answer"))
      ->apply(user(~id="user-2", ~text="Next"))
      ->apply(ExecutionStateRunning(["user-2"]))
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
      #Turn(["user-1"]),
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
    let userTask = makeLoadingTask()->apply(user(~id="message-1", ~text="Hello"))->apply(ExecutionStateRunning(["message-1"]))
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
