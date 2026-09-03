open Vitest

module Task = Client__Task__Types.Task
module Message = Client__Task__Types.Message
module TaskReducer = Client__Task__Reducer
module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module UserMessageId = Client__Message.UserMessageId
let testUserMessageId = UserMessageId.make()

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
    TaskReducer.next(
      makeUnloadedTask(),
      LoadStarted({previewUrl: "http://localhost:3000"}),
    )->Pair.first
  }

  let acceptUserMessage = (
    task,
    ~id="user-1",
    ~text="Hello",
    ~annotations=[],
    ~agentId="executor-id",
  ) => {
    TaskReducer.next(
      task,
      UserMessageReceived({
        id,
        content: [Client__Task__Types.UserContentPart.Text({text: text})],
        annotations,
        agentId,
      }),
    )->Pair.first
  }

  let getMessages = (task: Task.t): array<Message.t> => {
    TaskReducer.Selectors.messages(task)->Option.getOrThrow(
      ~message="Expected task to have messages (not Unloaded)",
    )
  }

  let getQueuedUserMessages = (task: Task.t): array<Message.t> => {
    TaskReducer.Selectors.queuedUserMessages(task)->Option.getOrThrow(
      ~message="Expected loaded task with queued user messages",
    )
  }
}

describe("Task - Protocol Message Identity", () => {
  let _startAgent = () => {
    let task = TestHelpers.makeLoadedTask()
    let task1 = TestHelpers.acceptUserMessage(task)
    TaskReducer.next(task1, ExecutionStateRunning)->Pair.first
  }

  test("text deltas append before idle completes the message", t => {
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
    let (completed, _) = TaskReducer.next(task3, ExecutionStateIdle)

    let messages = TestHelpers.getMessages(completed)
    t->expect(Array.length(messages))->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(Message.Assistant(Completed({content, agentId}))) => {
        t->expect(agentId)->Expect.toBe("executor-id")
        switch content->Array.get(0) {
        | Some(Message.AssistantContentPart.Text({text})) =>
          t->expect(text)->Expect.toBe("Hello world")
        | _ => t->expect("completed text")->Expect.toBe("missing")
        }
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("Task - Load State Machine", () => {
  test("LoadStarted and LoadComplete transition Unloaded through Loading to Loaded", t => {
    let task = TestHelpers.makeUnloadedTask()
    t->expect(Task.isUnloaded(task))->Expect.toBe(true)

    let (loadingTask, _) = TaskReducer.next(
      task,
      LoadStarted({previewUrl: "http://localhost:3000"}),
    )
    t->expect(Task.isLoading(loadingTask))->Expect.toBe(true)
    let (loadedTask, _) = TaskReducer.next(loadingTask, LoadComplete)

    t->expect(Task.isLoaded(loadedTask))->Expect.toBe(true)
  })

  test("LoadError reverts Loading to Unloaded for retry", t => {
    let task = TestHelpers.makeLoadingTask()
    let (failedTask, _) = TaskReducer.next(task, LoadError({error: "Network error"}))

    t->expect(Task.isUnloaded(failedTask))->Expect.toBe(true)
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
  test("submitted message stays queued until its accepted turn starts", t => {
    let task = TestHelpers.makeLoadedTask()
    let (submitted, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: testUserMessageId,
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
        agentId: "executor-id",
      }),
    )

    let queued = TestHelpers.getQueuedUserMessages(submitted)
    t->expect(queued->Array.length)->Expect.toBe(1)
    t->expect(TestHelpers.getMessages(submitted)->Array.length)->Expect.toBe(0)

    let (prematurelyRunning, _) = TaskReducer.next(submitted, ExecutionStateRunning)
    t->expect(TestHelpers.getMessages(prematurelyRunning)->Array.length)->Expect.toBe(0)

    let accepted = TestHelpers.acceptUserMessage(
      prematurelyRunning,
      ~id=testUserMessageId->UserMessageId.toString,
    )
    t->expect(TestHelpers.getQueuedUserMessages(accepted)->Array.length)->Expect.toBe(1)

    let (running, _) = TaskReducer.next(accepted, ExecutionStateRunning)
    let messages = TestHelpers.getMessages(running)
    t->expect(TestHelpers.getQueuedUserMessages(running)->Array.length)->Expect.toBe(0)
    switch messages->Array.get(0) {
    | Some(Message.User({content, _})) => t->expect(content->Array.length)->Expect.toBe(1)
    | _ => t->expect("User message")->Expect.toBe("missing")
    }
  })

  test("state updates drive isAgentRunning", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: testUserMessageId,
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
        agentId: "executor-id",
      }),
    )
    t->expect(TaskReducer.Selectors.isAgentRunning(task2))->Expect.toEqual(Some(false))

    let (task3, _) = TaskReducer.next(task2, ExecutionStateRunning)
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

  test("running drains only the queued same-agent prefix into transcript", t => {
    let task = TestHelpers.makeLoadedTask()
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-1", ~text="One")
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-2", ~text="Two")
    let task = TestHelpers.acceptUserMessage(
      task,
      ~id="queued-3",
      ~text="Three",
      ~agentId="planner-id",
    )

    let (runningTask, _) = TaskReducer.next(task, ExecutionStateRunning)

    let queued = TestHelpers.getQueuedUserMessages(runningTask)
    t->expect(queued->Array.length)->Expect.toBe(1)
    switch queued->Array.get(0) {
    | Some(Message.User({id, _})) => t->expect(id)->Expect.toBe("queued-3")
    | _ => t->expect("Planner message")->Expect.toBe("missing")
    }
    let messages = TestHelpers.getMessages(runningTask)
    t->expect(messages->Array.length)->Expect.toBe(2)
    switch (messages->Array.get(0), messages->Array.get(1)) {
    | (Some(Message.User({id: firstId, _})), Some(Message.User({id: secondId, _}))) =>
      t->expect(firstId)->Expect.toBe("queued-1")
      t->expect(secondId)->Expect.toBe("queued-2")
    | _ => t->expect("Queued messages in order")->Expect.toBe("missing")
    }
  })

  test("unqueue keeps the queued message until confirmation", t => {
    let task = TestHelpers.makeLoadedTask()
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-1", ~text="One")
    let task = TestHelpers.acceptUserMessage(task, ~id="queued-2", ~text="Two")

    let (updated, effects) = TaskReducer.next(task, UnqueueMessage({messageId: "queued-1"}))

    let queued = TestHelpers.getQueuedUserMessages(updated)
    t->expect(queued->Array.length)->Expect.toBe(2)
    switch effects->Array.get(0) {
    | Some(TaskReducer.SessionCommand(ACP.UnqueueMessage(messageId))) =>
      t->expect(messageId)->Expect.toBe("queued-1")
    | _ => t->expect("UnqueueMessage command")->Expect.toBe("missing")
    }

    let (confirmed, noEffects) = TaskReducer.next(updated, MessageUnqueued({messageId: "queued-1"}))
    t->expect(TestHelpers.getQueuedUserMessages(confirmed)->Array.length)->Expect.toBe(1)
    t->expect(noEffects->Array.length)->Expect.toBe(0)
  })

  test("question submit leaves queued user messages queued", t => {
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

    t->expect(TestHelpers.getMessages(finalTask)->Array.length)->Expect.toBe(0)
    t->expect(TestHelpers.getQueuedUserMessages(finalTask)->Array.length)->Expect.toBe(1)
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
})

describe("Task - Plan Entries", () => {
  test("PlanReceived updates plan entries", t => {
    let task = TestHelpers.makeLoadedTask()
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
  test("UserMessageSendFailed removes a pending optimistic message and exposes the error", t => {
    let task = TestHelpers.makeLoadedTask()
    let (pending, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: testUserMessageId,
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
        agentId: "executor-id",
      }),
    )
    let messageId = testUserMessageId->UserMessageId.toString
    let (failed, effects) = TaskReducer.next(
      pending,
      UserMessageSendFailed({id: testUserMessageId, error: "Connection lost"}),
    )

    t->expect(TestHelpers.getQueuedUserMessages(failed))->Expect.toEqual([])
    t
    ->expect(TaskReducer.Selectors.turnError(failed))
    ->Expect.toEqual(
      Some({id: messageId, message: "Connection lost", category: #unknown, retryErrorId: None}),
    )
    t->expect(effects)->Expect.toEqual([])
  })

  test("UserMessageSendFailed preserves a message already accepted by the server", t => {
    let task = TestHelpers.makeLoadedTask()
    let (pending, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: testUserMessageId,
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
        agentId: "executor-id",
      }),
    )
    let accepted = TestHelpers.acceptUserMessage(
      pending,
      ~id=testUserMessageId->UserMessageId.toString,
    )
    let (unchanged, _) = TaskReducer.next(
      accepted,
      UserMessageSendFailed({id: testUserMessageId, error: "Connection lost"}),
    )

    t->expect(TestHelpers.getQueuedUserMessages(unchanged)->Array.length)->Expect.toBe(1)
    t->expect(TaskReducer.Selectors.turnError(unchanged))->Expect.toEqual(None)
  })

  test("AgentError completes output, persists error, stops running, and emits no effects", t => {
    let task = TestHelpers.makeLoadedTask()
    let task = TestHelpers.acceptUserMessage(task)
    let (running, _) = TaskReducer.next(task, ExecutionStateRunning)
    let (streaming, _) = TaskReducer.next(
      running,
      TextDeltaReceived({
        messageId: "assistant-1",
        text: "Partial response",
        agentId: "test-agent",
      }),
    )
    let (failed, effects) = TaskReducer.next(
      streaming,
      AgentError({id: "agent-error-1", error: "Quota exhausted", category: #quota}),
    )

    t
    ->expect(TaskReducer.Selectors.turnError(failed))
    ->Expect.toEqual(
      Some({
        id: "agent-error-1",
        message: "Quota exhausted",
        category: #quota,
        retryErrorId: Some("agent-error-1"),
      }),
    )
    t->expect(TaskReducer.Selectors.isAgentRunning(failed))->Expect.toEqual(Some(false))
    t->expect(TaskReducer.Selectors.streamingMessage(failed))->Expect.toEqual(None)
    t->expect(effects)->Expect.toEqual([])

    let messages = TestHelpers.getMessages(failed)
    switch messages->Array.get(1) {
    | Some(Message.Assistant(Completed({content}))) =>
      switch content->Array.get(0) {
      | Some(Message.AssistantContentPart.Text({text})) =>
        t->expect(text)->Expect.toBe("Partial response")
      | _ => t->expect("completed partial response")->Expect.toBe("missing")
      }
    | _ => t->expect("completed assistant message")->Expect.toBe("missing")
    }
    switch messages->Array.get(2) {
    | Some(Message.Error(error)) =>
      t->expect(Message.ErrorMessage.error(error))->Expect.toBe("Quota exhausted")
    | _ => t->expect("persistent error message")->Expect.toBe("missing")
    }
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
        retryErrorId: Some("agent-error-1"),
      }),
    )

    let (task3, _) = TaskReducer.next(task2, ClearTurnError)
    t->expect(TaskReducer.Selectors.turnError(task3))->Expect.toEqual(None)
  })

  test("AddUserMessage clears turnError", t => {
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
        retryErrorId: Some("agent-error-1"),
      }),
    )

    let (task3, _) = TaskReducer.next(
      task2,
      AddUserMessage({
        id: testUserMessageId,
        content: [Client__Task__Types.UserContentPart.Text({text: "New message"})],
        annotations: [],
        agentId: "executor-id",
      }),
    )
    t->expect(TaskReducer.Selectors.turnError(task3))->Expect.toEqual(None)
  })
})

describe("Task - CancelTurn", () => {
  let _startAgentWithStreaming = () => {
    let task = TestHelpers.makeLoadedTask()
    let task1 = TestHelpers.acceptUserMessage(task)
    let (runningTask, _) = TaskReducer.next(task1, ExecutionStateRunning)
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

  test("CancelTurn stops running, preserves text, cancels tools, and emits a cancel command", t => {
    let task = _startAgentWithStreaming()
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
    let (withTool, _) = TaskReducer.next(task, ToolCallReceived({toolCall: toolCall}))
    let (cancelled, effects) = TaskReducer.next(withTool, CancelTurn)

    t->expect(TaskReducer.Selectors.isAgentRunning(cancelled))->Expect.toEqual(Some(false))
    t->expect(effects)->Expect.toEqual([TaskReducer.SessionCommand(ACP.Cancel)])
    let messages = TestHelpers.getMessages(cancelled)
    switch messages->Array.get(1) {
    | Some(Message.Assistant(Completed({content}))) =>
      switch content->Array.get(0) {
      | Some(Client__Task__Types.AssistantContentPart.Text({text})) =>
        t->expect(text)->Expect.toBe("Partial resp")
      | _ => t->expect("Text content")->Expect.toBe("not found")
      }
    | _ => t->expect("Completed assistant")->Expect.toBe("not found")
    }
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

  test("CancelTurn is no-op when agent is not running", t => {
    let task = TestHelpers.makeLoadedTask()
    let (unchanged, effects) = TaskReducer.next(task, CancelTurn)

    t->expect(unchanged)->Expect.toEqual(task)
    t->expect(effects)->Expect.toEqual([])
  })

  test("after CancelTurn, new AddUserMessage creates fresh assistant message", t => {
    let task = _startAgentWithStreaming()
    let (cancelled, _) = TaskReducer.next(task, CancelTurn)
    let messageId = UserMessageId.make()
    let (submitted, _) = TaskReducer.next(
      cancelled,
      AddUserMessage({
        id: messageId,
        content: [Client__Task__Types.UserContentPart.Text({text: "New question"})],
        annotations: [],
        agentId: "executor-id",
      }),
    )
    let accepted = TestHelpers.acceptUserMessage(
      submitted,
      ~id=messageId->UserMessageId.toString,
      ~text="New question",
    )
    let (runningTask, _) = TaskReducer.next(accepted, ExecutionStateRunning)
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

  test("AddUserMessage clears annotation UI state and sends annotations", t => {
    let task = _taskWithAnnotations()
    t
    ->expect(TaskReducer.Selectors.annotations(task)->Option.getOr([])->Array.length)
    ->Expect.toBe(2)
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task))->Expect.toEqual(Some(true))
    t
    ->expect(TaskReducer.Selectors.activePopupAnnotationId(task)->Option.getOr(None)->Option.isSome)
    ->Expect.toBe(true)

    let (updated, effects) = TaskReducer.next(
      task,
      AddUserMessage({
        id: testUserMessageId,
        content: [Client__Task__Types.UserContentPart.Text({text: "Fix this"})],
        annotations: _sampleMessageAnnotations,
        agentId: "executor-id",
      }),
    )

    t
    ->expect(TaskReducer.Selectors.annotations(updated)->Option.getOr([])->Array.length)
    ->Expect.toBe(0)
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(updated))->Expect.toEqual(Some(false))
    t
    ->expect(
      TaskReducer.Selectors.activePopupAnnotationId(updated)->Option.getOr(None)->Option.isNone,
    )
    ->Expect.toBe(true)

    switch effects->Array.get(0) {
    | Some(SendMessage({id, annotations, agentId})) => {
        t
        ->expect(id->UserMessageId.toString)
        ->Expect.toBe(testUserMessageId->UserMessageId.toString)
        t->expect(annotations->Array.length)->Expect.toBe(2)
        t->expect(agentId)->Expect.toBe("executor-id")
      }
    | _ => t->expect("SendMessage effect")->Expect.toBe("not found")
    }
  })

  test("Annotations are stored on the message itself", t => {
    let task = TestHelpers.makeLoadedTask()

    let task2 = TestHelpers.acceptUserMessage(
      task,
      ~text="Check these",
      ~annotations=_sampleMessageAnnotations,
    )

    let messages = TestHelpers.getQueuedUserMessages(task2)
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
})

describe("Task - QuestionReceived on freshly loaded task (reconnect scenario)", () => {
  test("QuestionReceived sets pendingQuestion on Loaded task with isAgentRunning=false", t => {
    let task = TestHelpers.makeLoadedTask()

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
      QuestionReceived({
        questions,
        toolCallId: "tc_1",
        resolveOk: _ => (),
        resolveError: _ => (),
      }),
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

  test("QuestionSubmitted emits and executes ResolveQuestionToolEffect", t => {
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

    let (finalTask, effects) = TaskReducer.next(taskWithAnswer, QuestionSubmitted)

    let pq = TaskReducer.Selectors.pendingQuestion(finalTask)
    t->expect(pq->Option.isNone)->Expect.toBe(true)

    switch effects->Array.get(0) {
    | Some(ResolveQuestionToolEffect({resolveOk, answerJson})) => resolveOk(answerJson)
    | other =>
      t
      ->expect(
        `Expected ResolveQuestionToolEffect, got ${other->Option.mapOr("None", _ => "other")}`,
      )
      ->Expect.toBe("ResolveQuestionToolEffect")
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
  })

  test("skipping the last question auto-submits via resolveQuestion", t => {
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
    ]

    let (taskWithQ, _) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk, resolveError}),
    )

    let (afterSkip, effects) = TaskReducer.next(
      taskWithQ,
      QuestionPerQuestionSkipped({questionIndex: 0}),
    )

    t
    ->expect(TaskReducer.Selectors.pendingQuestion(afterSkip)->Option.isNone)
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

  test("ToggleAnnotation enriches async fields and clears enriching status", t => {
    let (task, effects) = _taskWithEnrichingAnnotation()
    let ann = _getAnnotation(task, 0)

    t->expect(ann.enrichmentStatus)->Expect.toEqual(Annotation.Enriching)
    t->expect(ann.selector)->Expect.toEqual(Ok(None))
    t->expect(ann.screenshot)->Expect.toEqual(Ok(None))
    t->expect(ann.sourceLocation)->Expect.toEqual(Ok(None))
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(task))->Expect.toEqual(Some(true))

    let id = _getAnnotationIdFromEffect(effects)
    let (resolved, _) = TaskReducer.next(
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
    let enriched = _getAnnotation(resolved, 0)
    t->expect(enriched.enrichmentStatus)->Expect.toEqual(Annotation.Enriched)
    t->expect(enriched.selector)->Expect.toEqual(Ok(Some(".btn-submit")))
    t->expect(enriched.elementContext)->Expect.toEqual(Ok(Some(`selected tag="button"`)))
    t->expect(enriched.screenshot)->Expect.toEqual(Ok(Some("data:image/jpeg;base64,abc")))
    t->expect(enriched.cssClasses)->Expect.toEqual(Some("btn-submit"))
    t->expect(enriched.nearbyText)->Expect.toEqual(Some("Submit"))
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(resolved))->Expect.toEqual(Some(false))
    switch enriched.boundingBox {
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
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(task2))->Expect.toEqual(Some(false))
  })

  test("AnnotationDetailsResolved on Unloaded task is silently discarded", t => {
    let task = TestHelpers.makeUnloadedTask()
    let (task2, effects) = TaskReducer.next(task, _makeResolved(~id="stale-ann-id"))
    t->expect(effects)->Expect.toEqual([])
    t->expect(Task.getAnnotations(task2)->Array.length)->Expect.toBe(0)
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

    let id = _getAnnotationIdFromEffect(effects1)
    let (task4, _) = TaskReducer.next(task3, _makeResolved(~id))
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(task4))->Expect.toEqual(Some(true))
  })
})
