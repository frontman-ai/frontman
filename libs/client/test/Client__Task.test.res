open Vitest

module Task = Client__Task__Types.Task
module Message = Client__Task__Types.Message
module TaskReducer = Client__Task__Reducer

module TestHelpers = {
  let makeLoadedTask = () => {
    Task.makeNew(~previewUrl="http://localhost:3000")
    ->Task.newToLoaded(~id="test-task-1", ~title="Test Task")
    ->Task.updateLoadedData(data => {...data, messages: []})
  }

  let makeUnloadedTask = () => {
    Task.makeUnloaded(
      ~id="test-task-1",
      ~title="Test Task",
      ~createdAt=Date.now(),
      ~updatedAt=Date.now(),
    )
  }

  let makeLoadingTask = () => {
    let unloaded = Task.makeUnloaded(
      ~id="test-task-1",
      ~title="Test Task",
      ~createdAt=Date.now(),
      ~updatedAt=Date.now(),
    )
    TaskReducer.next(unloaded, LoadStarted({previewUrl: "http://localhost:3000"}))->Pair.first
  }

  let acceptUserMessage = (task, ~id="user-1", ~text="Hello", ~annotations=[]) => {
    TaskReducer.next(
      task,
      UserMessageReceived({
        id,
        content: [Client__Task__Types.UserContentPart.Text({text: text})],
        annotations,
        agentId: "executor-id",
      }),
    )->Pair.first
  }

  let getMessages = (task: Task.t): array<Message.t> => {
    TaskReducer.Selectors.messages(task)->Option.getOrThrow(
      ~message="Expected task to have messages (not Unloaded)",
    )
  }
}

describe("Task - Protocol Message Identity", () => {
  let _startAgent = () => {
    let task = TestHelpers.makeLoadedTask()
    let task1 = TestHelpers.acceptUserMessage(task)
    TaskReducer.next(task1, ExecutionStateRunning(None))->Pair.first
  }

  test("TextDeltaReceived appends to streaming message", t => {
    let task = _startAgent()
    let (task2, _) = TaskReducer.next(
      task,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: "Hello",
        agentId: "executor-id",
      }),
    )
    let (task3, _) = TaskReducer.next(
      task2,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: " world",
        agentId: "executor-id",
      }),
    )

    switch TaskReducer.Selectors.streamingMessage(task3) {
    | Some(Message.Streaming({textBuffer, agentId})) => {
        t->expect(textBuffer)->Expect.toBe("Hello world")
        t->expect(agentId)->Expect.toBe("executor-id")
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("staging a queued user message preserves the active assistant stream", t => {
    let task = _startAgent()
    let task = TaskReducer.next(
      task,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: "Hello",
        agentId: "executor-id",
      }),
    )->Pair.first
    let task = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "user-2",
        content: [Client__Task__Types.UserContentPart.Text({text: "Next prompt"})],
        annotations: [],
        agentId: "executor-id",
        model: None,
      }),
    )->Pair.first
    let task = TaskReducer.next(
      task,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: " world",
        agentId: "executor-id",
      }),
    )->Pair.first

    switch TaskReducer.Selectors.streamingMessage(task) {
    | Some(Message.Streaming({textBuffer: "Hello world"})) => ()
    | _ => t->expect("active stream")->Expect.toBe("missing")
    }
  })

  test("ExecutionStateIdle converts streaming to completed", t => {
    let task = _startAgent()
    let (task2, _) = TaskReducer.next(
      task,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: "Hello",
        agentId: "test-agent",
      }),
    )
    let (task3, _) = TaskReducer.next(task2, ExecutionStateIdle)

    let messages = TestHelpers.getMessages(task3)
    t->expect(Array.length(messages))->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(Message.Assistant(Completed({content}))) =>
      t->expect(Array.length(content))->Expect.toBe(1)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("Task - Tool Call Lifecycle", () => {
  let _startAgent = () => {
    let task = TestHelpers.makeLoadedTask()
    let task1 = TestHelpers.acceptUserMessage(task)
    TaskReducer.next(task1, ExecutionStateRunning(None))->Pair.first
  }

  test("tool call progresses: ToolCallReceived -> ToolInputReceived -> ToolResultReceived", t => {
    let task = _startAgent()
    let toolId = "tool-1"

    let toolCall: Message.toolCall = {
      id: toolId,
      toolName: "test_tool",
      state: Message.InputAvailable,
      inputBuffer: "",
      input: Some(JSON.parseOrThrow(`{"key": "value"}`)),
      result: None,
      errorText: None,
      parentAgentId: None,
      spawningToolName: None,
    }
    let (task1, _) = TaskReducer.next(task, ToolCallReceived({toolCall: toolCall}))

    let messages1 = TestHelpers.getMessages(task1)
    switch messages1->Array.get(1) {
    | Some(Message.ToolCall({state: InputAvailable, input: Some(_)})) =>
      t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }

    let (task2, _) = TaskReducer.next(
      task1,
      ToolResultReceived({
        id: toolId,
        rawOutput: Some(JSON.Encode.object(Dict.make())),
        content: None,
        complete: true,
      }),
    )

    let messages2 = TestHelpers.getMessages(task2)
    switch messages2->Array.get(1) {
    | Some(Message.ToolCall({state: OutputAvailable, result: Some(_)})) =>
      t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("tool error sets OutputError state", t => {
    let task = _startAgent()
    let toolId = "tool-1"

    let toolCall: Message.toolCall = {
      id: toolId,
      toolName: "test_tool",
      state: Message.InputAvailable,
      inputBuffer: "",
      input: None,
      result: None,
      errorText: None,
      parentAgentId: None,
      spawningToolName: None,
    }
    let (task1, _) = TaskReducer.next(task, ToolCallReceived({toolCall: toolCall}))
    let (task3, _) = TaskReducer.next(
      task1,
      ToolErrorReceived({id: toolId, error: "Something went wrong"}),
    )

    let messages = TestHelpers.getMessages(task3)
    switch messages->Array.get(1) {
    | Some(Message.ToolCall({state: OutputError, errorText: Some(error)})) =>
      t->expect(error)->Expect.toBe("Something went wrong")
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("Task - Load State Machine", () => {
  test("Unloaded -> Loading transition via LoadStarted", t => {
    let task = TestHelpers.makeUnloadedTask()
    t->expect(Task.isUnloaded(task))->Expect.toBe(true)

    let (loadingTask, _) = TaskReducer.next(
      task,
      LoadStarted({previewUrl: "http://localhost:3000"}),
    )
    t->expect(Task.isLoading(loadingTask))->Expect.toBe(true)
  })

  test("Loading -> Loaded transition via LoadComplete", t => {
    let task = TestHelpers.makeLoadingTask()
    let (loadedTask, _) = TaskReducer.next(task, LoadComplete)

    t->expect(Task.isLoaded(loadedTask))->Expect.toBe(true)
  })

  test("LoadError reverts Loading to Unloaded for retry", t => {
    let task = TestHelpers.makeLoadingTask()
    let (failedTask, _) = TaskReducer.next(task, LoadError({error: "Network error"}))

    t->expect(Task.isUnloaded(failedTask))->Expect.toBe(true)
  })

  test("loading task waits for its session and retains a failed submission", t => {
    let task = TestHelpers.makeLoadingTask()
    let task = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.text("Hello")],
        annotations: [],
        agentId: "executor-id",
        model: None,
      }),
    )->Pair.first
    let (task, effects) = TaskReducer.next(
      task,
      SubmissionPrepared({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.text("Hello")],
      }),
    )
    switch (effects, TaskReducer.Selectors.queuedSubmissions(task)) {
    | ([EnsureTaskSession], [{status: WaitingForSession, _}]) => ()
    | _ => t->expect("loading submission waiting for session")->Expect.toBe("missing")
    }
    let task = TaskReducer.next(task, LoadError({error: "Network error"}))->Pair.first

    t->expect(Task.isLoaded(task))->Expect.toBe(true)
    switch (Task.getSubmissions(task), TaskReducer.Selectors.queuedSubmissions(task)) {
    | ([{id: "user-1", status: Failed("Network error"), _}], []) => ()
    | _ => t->expect("retained failed loading submission")->Expect.toBe("missing")
    }
    switch TestHelpers.getMessages(task) {
    | [Message.User({id: "user-1"}), Message.Error(error)] =>
      t->expect(Message.ErrorMessage.error(error))->Expect.toBe("Network error")
    | _ => t->expect("attempted message and load error")->Expect.toBe("missing")
    }
  })

  test("session failure atomically fails waiting submissions once", t => {
    let submit = (task, id) => {
      task
      ->TaskReducer.next(
        SubmitUserMessage({
          id,
          content: [Client__Task__Types.UserContentPart.text(id)],
          annotations: [],
          agentId: "executor-id",
          model: None,
        }),
      )
      ->Pair.first
      ->TaskReducer.next(
        SubmissionPrepared({id, content: [Client__Task__Types.UserContentPart.text(id)]}),
      )
      ->Pair.first
    }
    let task = TestHelpers.makeLoadedTask()->submit("user-1")->submit("user-2")
    let failed = TaskReducer.next(task, TaskSessionFailed({error: "No ACP connection"}))->Pair.first
    let repeated =
      TaskReducer.next(failed, TaskSessionFailed({error: "No ACP connection"}))->Pair.first
    switch (Task.getSubmissions(repeated), TestHelpers.getMessages(repeated)) {
    | (
        [{status: Failed(_), _}, {status: Failed(_), _}],
        [Message.User(_), Message.Error(_), Message.User(_), Message.Error(_)],
      ) => ()
    | _ => t->expect("two failed submissions with one error each")->Expect.toBe("missing")
    }
  })
})

describe("Task - Session Rehydration (Loading history → LoadComplete)", () => {
  test("in-flight streaming message is finalized to Completed by LoadComplete", t => {
    let task = TestHelpers.makeLoadingTask()

    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: "partial ",
        agentId: "test-agent",
      }),
    )
    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: "response",
        agentId: "test-agent",
      }),
    )

    t->expect(TaskReducer.Selectors.streamingMessage(task)->Option.isSome)->Expect.toBe(true)

    let (loaded, _) = TaskReducer.next(task, LoadComplete)
    t->expect(TaskReducer.Selectors.streamingMessage(loaded))->Expect.toBe(None)

    let messages = TestHelpers.getMessages(loaded)
    switch messages->Array.get(0) {
    | Some(Message.Assistant(Completed({content, _}))) =>
      switch content->Array.get(0) {
      | Some(Message.AssistantContentPart.Text({text})) =>
        t->expect(text)->Expect.toBe("partial response")
      | _ => t->expect("Completed text")->Expect.toBe("missing")
      }
    | _ => t->expect("Completed assistant message")->Expect.toBe("not found")
    }
  })
})

describe("Task - Agent Running State", () => {
  test("state updates drive isAgentRunning", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
        agentId: "executor-id",
        model: None,
      }),
    )
    t->expect(TaskReducer.Selectors.isAgentRunning(task2))->Expect.toEqual(Some(false))

    let (task3, _) = TaskReducer.next(task2, ExecutionStateRunning(None))
    t->expect(TaskReducer.Selectors.isAgentRunning(task3))->Expect.toEqual(Some(true))

    let (task4, _) = TaskReducer.next(task3, ExecutionStateIdle)
    t->expect(TaskReducer.Selectors.isAgentRunning(task4))->Expect.toEqual(Some(false))

    let (task5, _) = TaskReducer.next(task3, ExecutionStateRequiresAction)
    t->expect(TaskReducer.Selectors.isAgentRunning(task5))->Expect.toEqual(Some(false))
  })

  test("history user messages stay in transcript while loading", t => {
    let task = TestHelpers.makeLoadingTask()
    let loadedHistory = TestHelpers.acceptUserMessage(task, ~id="history-1", ~text="History")

    let messages = TestHelpers.getMessages(loadedHistory)
    t->expect(messages->Array.length)->Expect.toBe(1)
    switch messages->Array.get(0) {
    | Some(Message.User({id, agentId, _})) => {
        t->expect(id)->Expect.toBe("history-1")
        t->expect(agentId)->Expect.toBe("executor-id")
      }
    | _ => t->expect("History user message")->Expect.toBe("missing")
    }
  })

  test("acknowledgement and execution start advance only their exact submissions", t => {
    let task = TestHelpers.makeLoadedTask()
    let submit = (task, id: string, text: string) =>
      TaskReducer.next(
        task,
        SubmitUserMessage({
          id,
          content: [Client__Task__Types.UserContentPart.text(text)],
          annotations: [],
          agentId: "executor-id",
          model: None,
        }),
      )->Pair.first
    let task = task->submit("queued-1", "Local one")->submit("queued-2", "Local two")
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-1", ~text="Canonical one")

    switch (TestHelpers.getMessages(task), TaskReducer.Selectors.queuedSubmissions(task)) {
    | (
        [
          Message.User({
            id: "queued-1",
            content: [Client__Task__Types.UserContentPart.Text({text: "Canonical one"})],
            _,
          }),
        ],
        [{id: "queued-1", status: Accepted, _}, {id: "queued-2", status: Preparing, _}],
      ) => ()
    | _ => t->expect("canonical accepted submission and pending successor")->Expect.toBe("missing")
    }

    Expect.toThrow(t->expect(() => TaskReducer.next(task, ExecutionStateRunning(Some("missing")))))
    Expect.toThrow(t->expect(() => TaskReducer.next(task, ExecutionStateRunning(Some("queued-2")))))
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-2", ~text="Canonical two")
    let task = TaskReducer.next(task, ExecutionStateRunning(Some("queued-1")))->Pair.first
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-1", ~text="Canonical one")

    switch (Task.getSubmissions(task), TaskReducer.Selectors.queuedSubmissions(task)) {
    | (
        [{id: "queued-1", status: Running, _}, {id: "queued-2", status: Accepted, _}],
        [{id: "queued-2", status: Accepted, _}],
      ) => ()
    | _ => t->expect("later accepted submission remains queued")->Expect.toBe("missing")
    }
  })

  test("late send failure cannot fail an accepted submission", t => {
    let task = TestHelpers.makeLoadedTask()
    let task = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "queued-1",
        content: [Client__Task__Types.UserContentPart.text("Accepted")],
        annotations: [],
        agentId: "executor-id",
        model: None,
      }),
    )->Pair.first
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-1", ~text="Accepted")
    let task =
      TaskReducer.next(
        task,
        UserMessageSendFailed({id: "queued-1", error: "Late timeout"}),
      )->Pair.first

    switch TaskReducer.Selectors.queuedSubmissions(task) {
    | [{id: "queued-1", status: Accepted, _}] => ()
    | _ => t->expect("accepted submission remains accepted")->Expect.toBe("missing")
    }
    t->expect(TestHelpers.getMessages(task)->Array.length)->Expect.toBe(1)
  })

  test("acceptance after send failure removes the stale local error", t => {
    let task = TestHelpers.makeLoadedTask()
    let task = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "queued-1",
        content: [Client__Task__Types.UserContentPart.text("Accepted")],
        annotations: [],
        agentId: "executor-id",
        model: None,
      }),
    )->Pair.first
    let task =
      TaskReducer.next(
        task,
        UserMessageSendFailed({id: "queued-1", error: "Connection failed"}),
      )->Pair.first
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-1", ~text="Canonical")

    switch (Task.getSubmissions(task), TestHelpers.getMessages(task)) {
    | ([{id: "queued-1", status: Accepted, _}], [Message.User({id: "queued-1", _})]) => ()
    | _ => t->expect("accepted submission without stale local error")->Expect.toBe("missing")
    }
  })

  test("failed staged message leaves queue and shows an error", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task, _) = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "queued-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Will fail"})],
        annotations: [],
        agentId: "executor-id",
        model: None,
      }),
    )
    let (task, _) = TaskReducer.next(
      task,
      UserMessageSendFailed({id: "queued-1", error: "Connection failed"}),
    )

    switch (Task.getSubmissions(task), TaskReducer.Selectors.queuedSubmissions(task)) {
    | ([{id: "queued-1", status: Failed("Connection failed"), _}], []) => ()
    | _ => t->expect("failed submission retained outside queue")->Expect.toBe("missing")
    }
    switch TestHelpers.getMessages(task) {
    | [Message.User({id: "queued-1", _}), Message.Error(error)] =>
      t->expect(Message.ErrorMessage.error(error))->Expect.toBe("Connection failed")
    | _ => t->expect("local send error")->Expect.toBe("missing")
    }
    t->expect(TaskReducer.Selectors.turnError(task))->Expect.toEqual(None)
  })

  test("later preparation cannot overtake an earlier submission", t => {
    let submit = (task, id) =>
      TaskReducer.next(
        task,
        SubmitUserMessage({
          id,
          content: [Client__Task__Types.UserContentPart.text(id)],
          annotations: [],
          agentId: "executor-id",
          model: None,
        }),
      )->Pair.first
    let prepare = (task, id) =>
      TaskReducer.next(
        task,
        SubmissionPrepared({id, content: [Client__Task__Types.UserContentPart.text(id)]}),
      )->Pair.first
    let task = TestHelpers.makeLoadedTask()->submit("user-1")->submit("user-2")
    let task = task->prepare("user-2")
    let (_, blockedEffects) = TaskReducer.next(task, TaskSessionReady)
    t->expect(blockedEffects)->Expect.toEqual([])

    let task = task->prepare("user-1")
    switch TaskReducer.next(task, TaskSessionReady)->Pair.second {
    | [SendMessage({id: "user-1"}), SendMessage({id: "user-2"})] => ()
    | _ => t->expect("send effects in submission order")->Expect.toBe("missing")
    }
  })

  test("question submit leaves accepted user messages in transcript", t => {
    let task = TestHelpers.makeLoadedTask()
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-1", ~text="Queued")
    let questions: array<Client__Question__Types.questionItem> = [
      {
        question: "Pick one",
        header: "Test",
        options: [{label: "A", description: "Option A"}],
        multiple: None,
      },
    ]
    let (taskWithQuestion, _) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk: _ => (), resolveError: _ => ()}),
    )
    let (taskWithAnswer, _) = TaskReducer.next(
      taskWithQuestion,
      QuestionOptionToggled({questionIndex: 0, label: "A"}),
    )

    let (finalTask, _) = TaskReducer.next(taskWithAnswer, QuestionSubmitted)

    t->expect(TestHelpers.getMessages(finalTask)->Array.length)->Expect.toBe(1)
  })
})

describe("Task - Annotation Mode", () => {
  test("SetAnnotationMode toggles selection mode", t => {
    let task = TestHelpers.makeLoadedTask()
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task))->Expect.toEqual(Some(false))

    let (task2, _) = TaskReducer.next(task, SetAnnotationMode({mode: Selecting}))
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task2))->Expect.toEqual(Some(true))

    let (task3, _) = TaskReducer.next(task2, SetAnnotationMode({mode: Off}))
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task3))->Expect.toEqual(Some(false))
  })

  test("ToggleAnnotationMode toggles Off to Selecting and back", t => {
    let task = TestHelpers.makeLoadedTask()
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task))->Expect.toEqual(Some(false))

    let (task2, _) = TaskReducer.next(task, ToggleAnnotationMode)
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task2))->Expect.toEqual(Some(true))

    let (task3, _) = TaskReducer.next(task2, ToggleAnnotationMode)
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task3))->Expect.toEqual(Some(false))
  })

  test("SetAnnotationMode Off leaves annotations intact", t => {
    let task = TestHelpers.makeLoadedTask()

    let (task2, _) = TaskReducer.next(task, SetAnnotationMode({mode: Selecting}))
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task2))->Expect.toEqual(Some(true))

    let (task3, _) = TaskReducer.next(task2, SetAnnotationMode({mode: Off}))
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task3))->Expect.toEqual(Some(false))
  })
})

describe("Task - Plan Entries", () => {
  test("PlanReceived updates plan entries", t => {
    let task = TestHelpers.makeLoadedTask()
    t
    ->expect(TaskReducer.Selectors.planEntries(task)->Option.getOr([])->Array.length)
    ->Expect.toBe(0)

    let entries: array<Client__Task__Types.ACPTypes.planEntry> = [
      {content: "Step 1", priority: High, status: Pending},
      {content: "Step 2", priority: Medium, status: InProgress},
    ]

    let (task2, _) = TaskReducer.next(task, PlanReceived({entries: entries}))
    t
    ->expect(TaskReducer.Selectors.planEntries(task2)->Option.getOr([])->Array.length)
    ->Expect.toBe(2)
  })
})

describe("Task - Error Handling", () => {
  test("AgentError sets turnError on Loaded task", t => {
    let task = TestHelpers.makeLoadedTask()
    t->expect(TaskReducer.Selectors.turnError(task))->Expect.toEqual(None)

    let (task2, _) = TaskReducer.next(
      task,
      AgentError({
        id: "agent-error-1",
        error: "Quota exhausted",
        category: #quota,
      }),
    )
    t
    ->expect(TaskReducer.Selectors.turnError(task2))
    ->Expect.toEqual(
      Some({
        id: "agent-error-1",
        message: "Quota exhausted",
        category: #quota,
      }),
    )

    switch TestHelpers.getMessages(task2)->Array.get(0) {
    | Some(Message.Error(error)) =>
      t->expect(Message.ErrorMessage.error(error))->Expect.toBe("Quota exhausted")
    | _ => t->expect("persistent error message")->Expect.toBe("missing")
    }
  })

  test("AgentError sets isAgentRunning to false", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(task, ExecutionStateRunning(None))
    t->expect(TaskReducer.Selectors.isAgentRunning(task2))->Expect.toEqual(Some(true))

    let (task3, _) = TaskReducer.next(
      task2,
      AgentError({
        id: "agent-error-1",
        error: "Some error",
        category: #unknown,
      }),
    )
    t->expect(TaskReducer.Selectors.isAgentRunning(task3))->Expect.toEqual(Some(false))
  })

  test("AgentError completes any streaming message", t => {
    let task = TestHelpers.makeLoadedTask()
    let task0 = TestHelpers.acceptUserMessage(task)
    let (runningTask, _) = TaskReducer.next(task0, ExecutionStateRunning(None))
    let (task2, _) = TaskReducer.next(
      runningTask,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: "Partial response",
        agentId: "test-agent",
      }),
    )

    switch TaskReducer.Selectors.streamingMessage(task2) {
    | Some(Message.Streaming(_)) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }

    let (task3, _) = TaskReducer.next(
      task2,
      AgentError({
        id: "agent-error-1",
        error: "Error occurred",
        category: #unknown,
      }),
    )
    t->expect(TaskReducer.Selectors.streamingMessage(task3))->Expect.toEqual(None)

    let messages = TestHelpers.getMessages(task3)
    switch messages->Array.get(1) {
    | Some(Message.Assistant(Completed({content}))) =>
      t->expect(Array.length(content))->Expect.toBe(1)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("AgentError emits no effects", t => {
    let task = TestHelpers.makeLoadedTask()
    let (_, effects) = TaskReducer.next(
      task,
      AgentError({
        id: "agent-error-1",
        error: "Error",
        category: #unknown,
      }),
    )

    t->expect(Array.length(effects))->Expect.toBe(0)
  })

  test("ClearTurnError clears the turnError", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(
      task,
      AgentError({
        id: "agent-error-1",
        error: "Some error",
        category: #unknown,
      }),
    )
    t
    ->expect(TaskReducer.Selectors.turnError(task2))
    ->Expect.toEqual(
      Some({
        id: "agent-error-1",
        message: "Some error",
        category: #unknown,
      }),
    )

    let (task3, _) = TaskReducer.next(task2, ClearTurnError)
    t->expect(TaskReducer.Selectors.turnError(task3))->Expect.toEqual(None)
  })

  test("ClearTurnError is idempotent", t => {
    let task = TestHelpers.makeLoadedTask()
    t->expect(TaskReducer.Selectors.turnError(task))->Expect.toEqual(None)

    let (task2, _) = TaskReducer.next(task, ClearTurnError)
    t->expect(TaskReducer.Selectors.turnError(task2))->Expect.toEqual(None)
  })

  test("SubmitUserMessage clears turnError", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(
      task,
      AgentError({
        id: "agent-error-1",
        error: "Previous error",
        category: #unknown,
      }),
    )
    t
    ->expect(TaskReducer.Selectors.turnError(task2))
    ->Expect.toEqual(
      Some({
        id: "agent-error-1",
        message: "Previous error",
        category: #unknown,
      }),
    )

    let (task3, _) = TaskReducer.next(
      task2,
      SubmitUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "New message"})],
        annotations: [],
        agentId: "executor-id",
        model: None,
      }),
    )
    t->expect(TaskReducer.Selectors.turnError(task3))->Expect.toEqual(None)
  })
})

describe("Task - CancelTurn", () => {
  let _startAgentWithStreaming = () => {
    let task = TestHelpers.makeLoadedTask()
    let task1 = TestHelpers.acceptUserMessage(task)
    let (runningTask, _) = TaskReducer.next(task1, ExecutionStateRunning(None))
    let (task3, _) = TaskReducer.next(
      runningTask,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: "Partial resp",
        agentId: "test-agent",
      }),
    )
    task3
  }

  test("CancelTurn when agent running: sets isAgentRunning to false", t => {
    let task = _startAgentWithStreaming()
    t->expect(TaskReducer.Selectors.isAgentRunning(task))->Expect.toEqual(Some(true))

    let (cancelled, _) = TaskReducer.next(task, CancelTurn)
    t->expect(TaskReducer.Selectors.isAgentRunning(cancelled))->Expect.toEqual(Some(false))
  })

  test("CancelTurn preserves partial text as completed message", t => {
    let task = _startAgentWithStreaming()
    let (cancelled, _) = TaskReducer.next(task, CancelTurn)

    let messages = TestHelpers.getMessages(cancelled)
    t->expect(Array.length(messages))->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(Message.Assistant(Completed({content}))) =>
      switch content->Array.get(0) {
      | Some(Client__Task__Types.AssistantContentPart.Text({text})) =>
        t->expect(text)->Expect.toBe("Partial resp")
      | _ => t->expect("Text content")->Expect.toBe("not found")
      }
    | _ => t->expect("Completed assistant")->Expect.toBe("not found")
    }
  })

  test("CancelTurn emits CancelPrompt effect", t => {
    let task = _startAgentWithStreaming()
    let (_, effects) = TaskReducer.next(task, CancelTurn)

    t->expect(Array.length(effects))->Expect.toBe(1)
    switch effects->Array.get(0) {
    | Some(TaskReducer.CancelPrompt) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("CancelPrompt effect")->Expect.toBe("not found")
    }
  })

  test("CancelTurn is no-op when agent is not running", t => {
    let task = TestHelpers.makeLoadedTask()
    t->expect(TaskReducer.Selectors.isAgentRunning(task))->Expect.toEqual(Some(false))

    let (unchanged, effects) = TaskReducer.next(task, CancelTurn)
    t->expect(effects)->Expect.toEqual([])
    t->expect(TaskReducer.Selectors.isAgentRunning(unchanged))->Expect.toEqual(Some(false))
  })

  test("CancelTurn marks in-progress tool calls as cancelled", t => {
    let task = TestHelpers.makeLoadedTask()
    let task1 = TestHelpers.acceptUserMessage(task)
    let (runningTask, _) = TaskReducer.next(task1, ExecutionStateRunning(None))

    let toolCall: Message.toolCall = {
      id: "tool-1",
      toolName: "edit_file",
      state: Message.InputAvailable,
      inputBuffer: "",
      input: Some(JSON.parseOrThrow(`{"path": "test.ts"}`)),
      result: None,
      errorText: None,
      parentAgentId: None,
      spawningToolName: None,
    }
    let (task2, _) = TaskReducer.next(runningTask, ToolCallReceived({toolCall: toolCall}))

    let (cancelled, _) = TaskReducer.next(task2, CancelTurn)

    let messages = TestHelpers.getMessages(cancelled)
    let toolMsg = messages->Array.find(
      msg =>
        switch msg {
        | Message.ToolCall({id: "tool-1"}) => true
        | _ => false
        },
    )
    switch toolMsg {
    | Some(Message.ToolCall({state: OutputError, errorText: Some(err)})) =>
      t->expect(err)->Expect.toBe("Cancelled")
    | _ => t->expect("Cancelled tool call")->Expect.toBe("not found")
    }
  })

  test("CancelTurn clears turnError", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(
      task,
      AgentError({
        id: "agent-error-1",
        error: "Some error",
        category: #unknown,
      }),
    )
    let task2 = TestHelpers.acceptUserMessage(task1, ~text="retry")
    let (runningTask, _) = TaskReducer.next(task2, ExecutionStateRunning(None))
    let (cancelled, _) = TaskReducer.next(runningTask, CancelTurn)
    t->expect(TaskReducer.Selectors.turnError(cancelled))->Expect.toEqual(None)
  })

  test("after CancelTurn, new submission preserves completed assistant message", t => {
    let task = _startAgentWithStreaming()
    let (cancelled, _) = TaskReducer.next(task, CancelTurn)

    let task2 = TestHelpers.acceptUserMessage(cancelled, ~id="user-2", ~text="New question")

    let (runningTask, _) = TaskReducer.next(task2, ExecutionStateRunning(None))
    let (task4, _) = TaskReducer.next(
      runningTask,
      TextDeltaReceived({
        messageId: "assistant-2",
        text: "New response",
        agentId: "test-agent",
      }),
    )

    let messages = TestHelpers.getMessages(task4)
    t->expect(Array.length(messages))->Expect.toBe(4)

    switch messages->Array.get(3) {
    | Some(Message.Assistant(Streaming({textBuffer}))) =>
      t->expect(textBuffer)->Expect.toBe("New response")
    | _ => t->expect("New streaming message")->Expect.toBe("not found")
    }
  })
})

describe("Task - Running-independent streamed events", () => {
  test("TextDeltaReceived creates streaming message even when local running state is false", t => {
    let task = TestHelpers.makeLoadedTask()
    let (updated, effects) = TaskReducer.next(
      task,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: "stream text",
        agentId: "test-agent",
      }),
    )

    t->expect(effects)->Expect.toEqual([])
    switch TaskReducer.Selectors.streamingMessage(updated) {
    | Some(Message.Streaming({textBuffer})) => t->expect(textBuffer)->Expect.toBe("stream text")
    | _ => t->expect("Streaming message")->Expect.toBe("not found")
    }
  })

  test("ToolCallReceived creates tool call even when local running state is false", t => {
    let task = TestHelpers.makeLoadedTask()
    let toolCall: Message.toolCall = {
      id: "tool-1",
      toolName: "test_tool",
      state: Message.InputAvailable,
      inputBuffer: "",
      input: None,
      result: None,
      errorText: None,
      parentAgentId: None,
      spawningToolName: None,
    }
    let (updated, effects) = TaskReducer.next(task, ToolCallReceived({toolCall: toolCall}))

    t->expect(effects)->Expect.toEqual([])
    let messages = TestHelpers.getMessages(updated)
    switch messages->Array.get(0) {
    | Some(Message.ToolCall({id: "tool-1"})) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("Tool call")->Expect.toBe("not found")
    }
  })
})

module Annotation = Client__Annotation__Types
module MessageAnnotation = Client__Message.MessageAnnotation

let _makeMockElement: unit => WebAPI.DomTypes.element = %raw(`
  function() { return { tagName: "DIV" }; }
`)

let _sampleMessageAnnotations: array<MessageAnnotation.t> = [
  {
    id: "ann-1",
    selector: Ok(Some(".btn-submit")),
    elementContext: Ok(None),
    tagName: "button",
    cssClasses: Some("btn-submit primary"),
    comment: Some("This button is broken"),
    screenshot: Ok(None),
    sourceLocation: Ok(None),
    boundingBox: None,
    nearbyText: Some("Submit"),
    elementorContext: None,
  },
  {
    id: "ann-2",
    selector: Ok(Some("div.header")),
    elementContext: Ok(None),
    tagName: "div",
    cssClasses: Some("header"),
    comment: None,
    screenshot: Ok(None),
    sourceLocation: Ok(None),
    boundingBox: None,
    nearbyText: Some("Welcome"),
    elementorContext: None,
  },
]

describe("Task - Annotations Cleared on Send (Issue #466)", () => {
  let _taskWithAnnotations = () => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(task, SetAnnotationMode({mode: Selecting}))
    let el1 = _makeMockElement()
    let el2 = _makeMockElement()
    let (task2, _) = TaskReducer.next(
      task1,
      ToggleAnnotation({
        element: el1,
        tagName: "button",
      }),
    )
    let (task3, _) = TaskReducer.next(
      task2,
      ToggleAnnotation({
        element: el2,
        tagName: "div",
      }),
    )
    task3
  }

  test("SubmitUserMessage with annotations clears task-level annotations", t => {
    let task = _taskWithAnnotations()

    t
    ->expect(TaskReducer.Selectors.annotations(task)->Option.getOr([])->Array.length)
    ->Expect.toBe(2)

    let (task2, _) = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Fix this"})],
        annotations: _sampleMessageAnnotations,
        agentId: "executor-id",
        model: None,
      }),
    )

    t
    ->expect(TaskReducer.Selectors.annotations(task2)->Option.getOr([])->Array.length)
    ->Expect.toBe(0)
  })

  test("SubmitUserMessage resets annotationMode to Off", t => {
    let task = _taskWithAnnotations()

    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task))->Expect.toEqual(Some(true))

    let (task2, _) = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Fix this"})],
        annotations: _sampleMessageAnnotations,
        agentId: "executor-id",
        model: None,
      }),
    )

    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task2))->Expect.toEqual(Some(false))
  })

  test("SubmitUserMessage clears activePopupAnnotationId", t => {
    let task = _taskWithAnnotations()

    t
    ->expect(TaskReducer.Selectors.activePopupAnnotationId(task)->Option.getOr(None)->Option.isSome)
    ->Expect.toBe(true)

    let (task2, _) = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "user-1",
        content: [],
        annotations: _sampleMessageAnnotations,
        agentId: "executor-id",
        model: None,
      }),
    )

    t
    ->expect(
      TaskReducer.Selectors.activePopupAnnotationId(task2)->Option.getOr(None)->Option.isNone,
    )
    ->Expect.toBe(true)
  })

  test("Annotations are stored on the message itself", t => {
    let task = TestHelpers.makeLoadedTask()

    let task2 = TestHelpers.acceptUserMessage(
      task,
      ~text="Check these",
      ~annotations=_sampleMessageAnnotations,
    )

    let messages = TestHelpers.getMessages(task2)
    t->expect(messages->Array.length)->Expect.toBe(1)

    switch messages->Array.get(0) {
    | Some(Message.User({annotations, _})) =>
      t->expect(annotations->Array.length)->Expect.toBe(2)
      t->expect((annotations->Array.getUnsafe(0)).id)->Expect.toBe("ann-1")
      t
      ->expect((annotations->Array.getUnsafe(0)).comment)
      ->Expect.toEqual(Some("This button is broken"))
      t->expect((annotations->Array.getUnsafe(1)).id)->Expect.toBe("ann-2")
      t->expect((annotations->Array.getUnsafe(1)).comment)->Expect.toEqual(None)
    | _ => t->expect("User message")->Expect.toBe("not found")
    }
  })

  test("SendMessage effect carries annotations", t => {
    let task = TestHelpers.makeLoadedTask()

    let (task, _) = TaskReducer.next(
      task,
      SubmitUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Fix"})],
        annotations: _sampleMessageAnnotations,
        agentId: "executor-id",
        model: None,
      }),
    )
    let (task, _) = TaskReducer.next(
      task,
      SubmissionPrepared({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Fix"})],
      }),
    )
    let (_task2, effects) = TaskReducer.next(task, TaskSessionReady)

    switch effects->Array.get(0) {
    | Some(SendMessage({annotations, agentId})) => {
        t->expect(annotations->Array.length)->Expect.toBe(2)
        t->expect(agentId)->Expect.toBe("executor-id")
      }
    | _ => t->expect("SendMessage effect")->Expect.toBe("not found")
    }
  })
})

describe("Task - QuestionReceived on freshly loaded task (reconnect scenario)", () => {
  test("QuestionReceived sets pendingQuestion on Loaded task with isAgentRunning=false", t => {
    let task = TestHelpers.makeLoadedTask()

    let resolvedOk = ref(None)
    let resolvedError = ref(None)
    let resolveOk = (json: JSON.t) => resolvedOk := Some(json)
    let resolveError = (msg: string) => resolvedError := Some(msg)

    let questions: array<Client__Question__Types.questionItem> = [
      {
        question: "Pick one",
        header: "Test",
        options: [{label: "A", description: "Option A"}, {label: "B", description: "Option B"}],
        multiple: None,
      },
    ]

    let (nextTask, effects) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk, resolveError}),
    )

    let pq = TaskReducer.Selectors.pendingQuestion(nextTask)
    t->expect(pq->Option.isSome)->Expect.toBe(true)
    t->expect(effects->Array.length)->Expect.toBe(0)

    switch pq {
    | Some(pq) =>
      t->expect(pq.questions->Array.length)->Expect.toBe(1)
      t->expect(pq.toolCallId)->Expect.toBe("tc_1")
      t->expect(pq.currentStep)->Expect.toBe(0)
    | None => t->expect("pendingQuestion")->Expect.toBe("to be Some")
    }
  })

  test("QuestionSubmitted resolves the tool promise and emits ResolveQuestionToolEffect", t => {
    let task = TestHelpers.makeLoadedTask()

    let resolvedOk = ref(None)
    let resolveOk = (json: JSON.t) => resolvedOk := Some(json)
    let resolveError = (_msg: string) => ()

    let questions: array<Client__Question__Types.questionItem> = [
      {
        question: "Pick one",
        header: "Test",
        options: [{label: "A", description: "Option A"}],
        multiple: None,
      },
    ]

    let (taskWithQuestion, _) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk, resolveError}),
    )
    let (cancelledTask, _) = TaskReducer.next(taskWithQuestion, QuestionCancelled)
    t->expect(Task.getCompletedFileChanges(cancelledTask).revision)->Expect.toBe(1)

    let (taskWithAnswer, _) = TaskReducer.next(
      taskWithQuestion,
      QuestionOptionToggled({questionIndex: 0, label: "A"}),
    )

    let (finalTask, effects) = TaskReducer.next(taskWithAnswer, QuestionSubmitted)

    let pq = TaskReducer.Selectors.pendingQuestion(finalTask)
    t->expect(pq->Option.isNone)->Expect.toBe(true)

    switch effects->Array.get(0) {
    | Some(ResolveQuestionToolEffect(_)) => t->expect(true)->Expect.toBe(true)
    | other =>
      t
      ->expect(
        `Expected ResolveQuestionToolEffect, got ${other->Option.mapOr("None", _ => "other")}`,
      )
      ->Expect.toBe("ResolveQuestionToolEffect")
    }
  })

  test("resolveOk callback is called when ResolveQuestionToolEffect is executed", t => {
    let task = TestHelpers.makeLoadedTask()

    let resolvedOk = ref(None)
    let resolveOk = (json: JSON.t) => resolvedOk := Some(json)
    let resolveError = (_msg: string) => ()

    let questions: array<Client__Question__Types.questionItem> = [
      {
        question: "Pick one",
        header: "Test",
        options: [{label: "A", description: "Option A"}],
        multiple: None,
      },
    ]

    let (taskWithQuestion, _) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk, resolveError}),
    )
    let (taskWithAnswer, _) = TaskReducer.next(
      taskWithQuestion,
      QuestionOptionToggled({questionIndex: 0, label: "A"}),
    )
    let (_finalTask, effects) = TaskReducer.next(taskWithAnswer, QuestionSubmitted)

    switch effects->Array.get(0) {
    | Some(ResolveQuestionToolEffect({resolveOk, answerJson})) => resolveOk(answerJson)
    | _ => ()
    }

    t->expect(resolvedOk.contents->Option.isSome)->Expect.toBe(true)
  })
})

describe("Task - QuestionPerQuestionSkipped", () => {
  test("skipping a non-last question advances currentStep without submitting", t => {
    let task = TestHelpers.makeLoadedTask()

    let resolveOk = (_json: JSON.t) => ()
    let resolveError = (_msg: string) => ()

    let questions: array<Client__Question__Types.questionItem> = [
      {
        question: "Q1",
        header: "H1",
        options: [{label: "A", description: "a"}],
        multiple: None,
      },
      {
        question: "Q2",
        header: "H2",
        options: [{label: "B", description: "b"}],
        multiple: None,
      },
      {
        question: "Q3",
        header: "H3",
        options: [{label: "C", description: "c"}],
        multiple: None,
      },
    ]

    let (taskWithQ, _) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk, resolveError}),
    )

    let (afterSkip, effects) = TaskReducer.next(
      taskWithQ,
      QuestionPerQuestionSkipped({questionIndex: 0}),
    )

    switch TaskReducer.Selectors.pendingQuestion(afterSkip) {
    | Some(pq) =>
      t->expect(pq.currentStep)->Expect.toBe(1)
      t
      ->expect(pq.answers->Dict.get("0") == Some(Client__Question__Types.Skipped))
      ->Expect.toBe(true)
    | None => t->expect("pendingQuestion")->Expect.toBe("to be Some")
    }

    t->expect(effects->Array.length)->Expect.toBe(0)

    t
    ->expect(TaskReducer.Selectors.pendingQuestion(afterSkip)->Option.isSome)
    ->Expect.toBe(true)
  })

  test("skipping the last question auto-submits via resolveQuestion", t => {
    let task = TestHelpers.makeLoadedTask()

    let resolvedOk = ref(None)
    let resolveOk = (json: JSON.t) => resolvedOk := Some(json)
    let resolveError = (_msg: string) => ()

    let questions: array<Client__Question__Types.questionItem> = [
      {
        question: "Q1",
        header: "H1",
        options: [{label: "A", description: "a"}],
        multiple: None,
      },
      {
        question: "Q2",
        header: "H2",
        options: [{label: "B", description: "b"}],
        multiple: None,
      },
    ]

    let (taskWithQ, _) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk, resolveError}),
    )

    let (afterSkip0, _) = TaskReducer.next(
      taskWithQ,
      QuestionPerQuestionSkipped({questionIndex: 0}),
    )

    let (afterSkip1, effects) = TaskReducer.next(
      afterSkip0,
      QuestionPerQuestionSkipped({questionIndex: 1}),
    )

    t
    ->expect(TaskReducer.Selectors.pendingQuestion(afterSkip1)->Option.isNone)
    ->Expect.toBe(true)

    switch effects->Array.get(0) {
    | Some(ResolveQuestionToolEffect(_)) => t->expect(true)->Expect.toBe(true)
    | other =>
      t
      ->expect(
        `Expected ResolveQuestionToolEffect, got ${other->Option.mapOr("None", _ => "other")}`,
      )
      ->Expect.toBe("ResolveQuestionToolEffect")
    }
  })
})

describe("Task - Annotation Enrichment Lifecycle (Issue #582)", () => {
  let _getAnnotation = (task: Task.t, index: int): Annotation.t => {
    Task.getAnnotations(task)
    ->Array.get(index)
    ->Option.getOrThrow(~message=`Expected annotation at index ${Int.toString(index)}`)
  }

  let _taskWithEnrichingAnnotation = () => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(task, SetAnnotationMode({mode: Selecting}))
    let el = _makeMockElement()
    let (task2, effects) = TaskReducer.next(
      task1,
      ToggleAnnotation({
        element: el,
        tagName: "button",
      }),
    )
    (task2, effects)
  }

  let _getAnnotationIdFromEffect = (effects: array<TaskReducer.effect>): string => {
    switch effects->Array.get(0) {
    | Some(FetchAnnotationDetails({id})) => id
    | _ => failwith("Expected FetchAnnotationDetails effect")
    }
  }

  let _makeResolved = (
    ~id: string,
    ~selector: result<option<string>, string>=Ok(None),
    ~elementContext: result<option<string>, string>=Ok(None),
    ~screenshot: result<option<string>, string>=Ok(None),
    ~sourceLocation: result<option<Client__Types.SourceLocation.t>, string>=Ok(None),
    ~cssClasses: option<string>=?,
    ~nearbyText: option<string>=?,
    ~boundingBox: option<Annotation.boundingBox>=?,
    ~enrichmentStatus: Annotation.enrichmentStatus=Enriched,
  ): TaskReducer.action => AnnotationDetailsResolved({
    id,
    selector,
    elementContext,
    screenshot,
    sourceLocation,
    cssClasses,
    nearbyText,
    boundingBox,
    elementorContext: None,
    enrichmentStatus,
  })

  let _resolveAnnotation = (task, effects, ~enrichmentStatus=Annotation.Enriched) => {
    let id = _getAnnotationIdFromEffect(effects)
    let (resolved, _) = TaskReducer.next(task, _makeResolved(~id, ~enrichmentStatus))
    resolved
  }

  test("ToggleAnnotation creates annotation with Enriching status and Ok(None) async fields", t => {
    let (task, effects) = _taskWithEnrichingAnnotation()
    let ann = _getAnnotation(task, 0)

    t->expect(ann.enrichmentStatus)->Expect.toEqual(Annotation.Enriching)
    t->expect(ann.selector)->Expect.toEqual(Ok(None))
    t->expect(ann.screenshot)->Expect.toEqual(Ok(None))
    t->expect(ann.sourceLocation)->Expect.toEqual(Ok(None))

    switch effects->Array.get(0) {
    | Some(FetchAnnotationDetails(_)) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("FetchAnnotationDetails effect")->Expect.toBe("not found")
    }
  })

  test("AnnotationDetailsResolved writes all enrichment fields and sets Enriched", t => {
    let (task, effects) = _taskWithEnrichingAnnotation()
    let id = _getAnnotationIdFromEffect(effects)
    let (task2, _) = TaskReducer.next(
      task,
      _makeResolved(
        ~id,
        ~selector=Ok(Some(".btn-submit")),
        ~elementContext=Ok(Some(`selected tag="button"`)),
        ~screenshot=Ok(Some("data:image/jpeg;base64,abc")),
        ~cssClasses="btn-submit",
        ~nearbyText="Submit",
        ~boundingBox={x: 10.0, y: 20.0, width: 100.0, height: 50.0},
      ),
    )
    let ann = _getAnnotation(task2, 0)
    t->expect(ann.enrichmentStatus)->Expect.toEqual(Annotation.Enriched)
    t->expect(ann.selector)->Expect.toEqual(Ok(Some(".btn-submit")))
    t->expect(ann.elementContext)->Expect.toEqual(Ok(Some(`selected tag="button"`)))
    t->expect(ann.screenshot)->Expect.toEqual(Ok(Some("data:image/jpeg;base64,abc")))
    t->expect(ann.cssClasses)->Expect.toEqual(Some("btn-submit"))
    t->expect(ann.nearbyText)->Expect.toEqual(Some("Submit"))
    switch ann.boundingBox {
    | Some(bb) =>
      t->expect(bb.x)->Expect.toBe(10.0)
      t->expect(bb.width)->Expect.toBe(100.0)
    | None => t->expect("boundingBox")->Expect.toBe("should be Some")
    }
  })

  test("Per-field errors are stored while enrichmentStatus stays Enriched", t => {
    let (task, effects) = _taskWithEnrichingAnnotation()
    let id = _getAnnotationIdFromEffect(effects)
    let (task2, _) = TaskReducer.next(
      task,
      _makeResolved(
        ~id,
        ~selector=Error("No unique selector found"),
        ~screenshot=Error("Canvas tainted by cross-origin data"),
        ~sourceLocation=Error("CORS error on source map URL"),
      ),
    )
    let ann = _getAnnotation(task2, 0)
    t->expect(ann.enrichmentStatus)->Expect.toEqual(Annotation.Enriched)
    t->expect(ann.selector)->Expect.toEqual(Error("No unique selector found"))
    t->expect(ann.screenshot)->Expect.toEqual(Error("Canvas tainted by cross-origin data"))
    t->expect(ann.sourceLocation)->Expect.toEqual(Error("CORS error on source map URL"))
  })

  test("AnnotationDetailsResolved Failed stores error string on all fields", t => {
    let (task, effects) = _taskWithEnrichingAnnotation()
    let id = _getAnnotationIdFromEffect(effects)
    let errorMsg = "Promise.all3 chain exploded"
    let (task2, _) = TaskReducer.next(
      task,
      _makeResolved(
        ~id,
        ~selector=Error(errorMsg),
        ~screenshot=Error(errorMsg),
        ~sourceLocation=Error(errorMsg),
        ~enrichmentStatus=Failed({error: errorMsg}),
      ),
    )
    let ann = _getAnnotation(task2, 0)
    t->expect(ann.enrichmentStatus)->Expect.toEqual(Annotation.Failed({error: errorMsg}))
    t->expect(ann.selector)->Expect.toEqual(Error(errorMsg))
    t->expect(ann.screenshot)->Expect.toEqual(Error(errorMsg))
    t->expect(ann.sourceLocation)->Expect.toEqual(Error(errorMsg))
  })

  test("AnnotationDetailsResolved on Unloaded task is silently discarded", t => {
    let task = TestHelpers.makeUnloadedTask()
    let (task2, effects) = TaskReducer.next(task, _makeResolved(~id="stale-ann-id"))
    t->expect(effects)->Expect.toEqual([])
    t->expect(Task.getAnnotations(task2)->Array.length)->Expect.toBe(0)
  })

  test("hasEnrichingAnnotations is true while Enriching, false after Enriched", t => {
    let (task, effects) = _taskWithEnrichingAnnotation()
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(task))->Expect.toEqual(Some(true))

    let resolved = _resolveAnnotation(task, effects)
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(resolved))->Expect.toEqual(Some(false))
  })

  test("hasEnrichingAnnotations is false after Failed", t => {
    let (task, effects) = _taskWithEnrichingAnnotation()
    let resolved = _resolveAnnotation(task, effects, ~enrichmentStatus=Failed({error: "boom"}))
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(resolved))->Expect.toEqual(Some(false))
  })

  test("hasEnrichingAnnotations is None for Unloaded task", t => {
    let task = TestHelpers.makeUnloadedTask()
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(task))->Expect.toEqual(None)
  })

  test("hasEnrichingAnnotations with mixed statuses — true if any is Enriching", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(task, SetAnnotationMode({mode: Selecting}))
    let el1 = _makeMockElement()
    let el2 = _makeMockElement()
    let (task2, effects1) = TaskReducer.next(
      task1,
      ToggleAnnotation({
        element: el1,
        tagName: "button",
      }),
    )
    let (task3, _effects2) = TaskReducer.next(
      task2,
      ToggleAnnotation({
        element: el2,
        tagName: "div",
      }),
    )
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(task3))->Expect.toEqual(Some(true))

    let task4 = _resolveAnnotation(task3, effects1)
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(task4))->Expect.toEqual(Some(true))
  })
})
