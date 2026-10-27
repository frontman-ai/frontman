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
  pending: false,
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
    ~onUserFlush=(~taskId as _, ~messageId as _, ~blocks as _, ~agentId as _, ~pending as _) => (),
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
  test("wire replay restores server queue, exact claims, running state and removals", t => {
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
    let userChunk = (id, pending, text) =>
      receive(
        `{"sessionUpdate":"user_message_chunk","messageId":"${id}","pending":${Bool.toString(
            pending,
          )},"content":{"type":"text","text":"${text}"},"_meta":{"frontman.dev/agentId":"executor-id","frontman.dev/timestamp":"2026-07-14T12:30:01Z"}}`,
      )
    userChunk("claimed", false, "Current turn")
    userChunk("queued", true, "Follow-up")
    receive(`{"sessionUpdate":"state_update","state":"running"}`)
    receive(`{"sessionUpdate":"plan","entries":[{"content":"Server plan","priority":"high","status":"in_progress"}]}`)
    dispatch(TaskAction({target: ForTask("task-1"), action: LoadComplete}))
    let task = () => (store->StateStore.getState).tasks->Dict.get("task-1")->Option.getOrThrow
    t->expect(task()->summary)->Expect.toEqual([("claimed", "Current turn")])
    t->expect(TaskReducer.Selectors.isAgentRunning(task()))->Expect.toEqual(Some(true))
    t
    ->expect(TaskReducer.Selectors.planEntries(task())->Option.getOrThrow->Array.length)
    ->Expect.toBe(1)
    t
    ->expect(
      TaskReducer.Selectors.queuedUserMessages(task())->Option.getOrThrow->Array.map(Message.getId),
    )
    ->Expect.toEqual(["queued"])
    let (_, effects) = TaskReducer.next(task(), UnqueueMessage({messageId: "queued"}))
    t
    ->expect(effects)
    ->Expect.toEqual([
      TaskReducer.SessionCommand(
        FrontmanAiFrontmanClient.FrontmanClient__ACP.UnqueueMessage("queued"),
      ),
    ])
    userChunk("later", true, "Keep queued")
    receive(`{"sessionUpdate":"state_update","state":"running","claimedMessageIds":["queued"]}`)
    t
    ->expect(task()->summary)
    ->Expect.toEqual([("claimed", "Current turn"), ("queued", "Follow-up")])
    receive(`{"sessionUpdate":"message_unqueued","messageId":"later"}`)
    t->expect(TaskReducer.Selectors.queuedUserMessages(task()))->Expect.toEqual(Some([]))
    userChunk("removed-before-flush", true, "Remove immediately")
    receive(`{"sessionUpdate":"message_unqueued","messageId":"removed-before-flush"}`)
    t->expect(TaskReducer.Selectors.queuedUserMessages(task()))->Expect.toEqual(Some([]))
    receive(`{"sessionUpdate":"state_update","state":"idle"}`)
    t->expect(TaskReducer.Selectors.isAgentRunning(task()))->Expect.toEqual(Some(false))
    Buffer.reset()
  })

  test("load results reject abandoned requests", t => {
    module App = Client__State__StateReducer
    module Connection = Client__ConnectionReducer
    let initial = {...App.defaultState, tasks: Dict.fromArray([("task-1", makeLoadingTask())])}
    let getTask = (state: App.state) => state.tasks->Dict.get("task-1")->Option.getOrThrow
    let rejected = App.next(initial, SwitchTask({taskId: "task-1"}))->Pair.first
    t->expect(getTask(rejected)->Task.isLoading)->Expect.toBe(false)
    let cancelled =
      App.next(initial, TaskLoadFinished({taskId: "task-1", result: Ok(ref())}))->Pair.first
    t->expect(getTask(cancelled)->Task.isLoading)->Expect.toBe(false)
    let (loading, effects) = App.next(
      {...initial, connection: Client__ConnectionTestHelpers.ready()},
      SwitchTask({taskId: "task-1"}),
    )
    t->expect(getTask(loading)->Task.isLoading)->Expect.toBe(true)
    t->expect(effects->Array.some(effect =>
      switch effect {
      | ConnectionEffect(ActivateSessionEffect({operation: #load("task-1")})) => true
      | _ => false
      }
    ))->Expect.toBe(true)
    let released = App.next(loading, ClearCurrentTask)->Pair.first
    let retried = App.next(released, SwitchTask({taskId: "task-1"}))->Pair.first
    let oldId = effects->Array.findMap(effect =>
      switch effect {
      | ConnectionEffect(ActivateSessionEffect({requestId})) => Some(requestId)
      | _ => None
      }
    )->Option.getOrThrow
    let stale = App.next(retried, ConnectionAction(SessionResultReceived({
      requestId: oldId,
      sessionId: "task-1",
      result: Error(Connection.ACP.requestErrorFromMessage("Abandoned load")),
    })))->Pair.first
    t->expect(stale)->Expect.toEqual(retried)
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

  test("a replayed pending tool accepts its result after loading", t => {
    let loaded = makeLoadingTask()->apply(tool("preview-1"))->apply(LoadComplete)
    let completed = loaded->apply(
      ToolResultReceived({
        id: "preview-1",
        rawOutput: None,
        content: None,
        complete: true,
      }),
    )
    switch Task.getMessages(completed)->Array.get(0) {
    | Some(ToolCall({state})) => t->expect(state)->Expect.toBe(OutputAvailable)
    | _ => failwith("Replayed tool must complete")
    }
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
