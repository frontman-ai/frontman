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
    ~onUserFlush=(~taskId as _, ~messageId, ~blocks, ~agentId) => {
      let (content, annotations) = Client__ACP__MessageCodec.parseUserMessageBlocks(blocks)
      task :=
        task.contents->apply(UserMessageReceived({id: messageId, content, annotations, agentId}))
    },
    ~onFlush=(~taskId as _, ~messageId, ~text, ~agentId) =>
      task := task.contents->apply(TextDeltaReceived({messageId, text, agentId})),
  )
  actions->Array.forEach(action =>
    switch action {
    | #User(id, value) =>
      buffer.addUserBlock(
        ~taskId="task-1",
        ~messageId=id,
        ~block=FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.TextContent({
          text: value,
          annotations: None,
          _meta: None,
        }),
        ~agentId="executor-id",
      )
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
  test("replay execution state survives LoadComplete", t => {
    let running = makeLoadingTask()->apply(ExecutionStateRunning(None))->apply(LoadComplete)
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
      ->apply(user(~id="user-1", ~text="Hello world"))
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
