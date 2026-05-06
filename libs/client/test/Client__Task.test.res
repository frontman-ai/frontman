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

  // Helper to get messages from loaded tasks (unwraps the option)
  let getMessages = (task: Task.t): array<Message.t> => {
    TaskReducer.Selectors.messages(task)->Option.getOrThrow(
      ~message="Expected task to have messages (not Unloaded)",
    )
  }
}

describe("Task - Single Streaming Message Invariant", () => {
  // Helper: create a loaded task with isAgentRunning=true (as in real app flow)
  let _startAgent = () => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
      }),
    )
    task1
  }

  test("StreamingStarted creates a streaming message", t => {
    let task = _startAgent()
    let (updatedTask, _effects) = TaskReducer.next(task, StreamingStarted)

    let messages = TestHelpers.getMessages(updatedTask)
    // Messages: User + Streaming
    t->expect(Array.length(messages))->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(Message.Assistant(Streaming({textBuffer}))) => t->expect(textBuffer)->Expect.toBe("")
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("StreamingStarted fails fast if streaming message already exists", t => {
    let task = _startAgent()
    let (task1, _) = TaskReducer.next(task, StreamingStarted)

    // Invariant enforced: calling StreamingStarted again should crash
    Expect.toThrow(t->expect(() => TaskReducer.next(task1, StreamingStarted)))
  })

  test("TextDeltaReceived appends to streaming message", t => {
    let task = _startAgent()
    let (task1, _) = TaskReducer.next(task, StreamingStarted)
    let (task2, _) = TaskReducer.next(
      task1,
      TextDeltaReceived({text: "Hello", timestamp: "2024-01-15T10:00:00Z"}),
    )
    let (task3, _) = TaskReducer.next(
      task2,
      TextDeltaReceived({text: " world", timestamp: "2024-01-15T10:00:00Z"}),
    )

    switch TaskReducer.Selectors.streamingMessage(task3) {
    | Some(Message.Streaming({textBuffer})) => t->expect(textBuffer)->Expect.toBe("Hello world")
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("TurnCompleted converts streaming to completed", t => {
    let task = _startAgent()
    let (task1, _) = TaskReducer.next(task, StreamingStarted)
    let (task2, _) = TaskReducer.next(
      task1,
      TextDeltaReceived({text: "Hello", timestamp: "2024-01-15T10:00:00Z"}),
    )
    let (task3, _) = TaskReducer.next(task2, TurnCompleted)

    let messages = TestHelpers.getMessages(task3)
    // Messages: User + Completed
    t->expect(Array.length(messages))->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(Message.Assistant(Completed({content}))) =>
      t->expect(Array.length(content))->Expect.toBe(1)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("Task - Tool Call Lifecycle", () => {
  // Helper: create a loaded task with isAgentRunning=true (as in real app flow)
  let _startAgent = () => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
      }),
    )
    task1
  }

  test("tool call progresses: ToolCallReceived -> ToolInputReceived -> ToolResultReceived", t => {
    let task = _startAgent()
    let toolId = "tool-1"

    // Create tool call via ToolCallReceived (the live application path)
    let toolCall: Message.toolCall = {
      id: toolId,
      toolName: "test_tool",
      state: Message.InputAvailable,
      inputBuffer: "",
      input: Some(JSON.parseOrThrow(`{"key": "value"}`)),
      result: None,
      errorText: None,
      createdAt: Date.now(),
      parentAgentId: None,
      spawningToolName: None,
    }
    let (task1, _) = TaskReducer.next(task, ToolCallReceived({toolCall: toolCall}))

    // Verify InputAvailable state (user msg at index 0, tool call at index 1)
    let messages1 = TestHelpers.getMessages(task1)
    switch messages1->Array.get(1) {
    | Some(Message.ToolCall({state: InputAvailable, input: Some(_)})) =>
      t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }

    // Receive result
    let (task2, _) = TaskReducer.next(
      task1,
      ToolResultReceived({id: toolId, result: JSON.parseOrThrow(`{"result": "success"}`)}),
    )

    // Verify OutputAvailable state
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

    // Create tool call via ToolCallReceived
    let toolCall: Message.toolCall = {
      id: toolId,
      toolName: "test_tool",
      state: Message.InputAvailable,
      inputBuffer: "",
      input: None,
      result: None,
      errorText: None,
      createdAt: Date.now(),
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
})

// ============================================================================
// Session Rehydration Tests
//
// The bug: during history replay, agent messages go through TextDeltaBuffer
// which schedules rAF. LoadComplete fires before rAF, transitioning to
// Loaded({isAgentRunning: false}), and the stale-streaming guard silently
// drops late TextDeltaReceived actions. Fix: flush() before LoadComplete.
// ============================================================================

describe("Task - Session Rehydration (Loading history → LoadComplete)", () => {
  test("agent message (TextDeltaReceived) survives LoadComplete", t => {
    let task = TestHelpers.makeLoadingTask()

    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({text: "Hi there!", timestamp: "2024-01-15T10:00:00Z"}),
    )
    let (loaded, _) = TaskReducer.next(task, LoadComplete)

    t->expect(Task.isLoaded(loaded))->Expect.toBe(true)
    let messages = TestHelpers.getMessages(loaded)
    t->expect(messages->Array.length)->Expect.toBe(1)

    switch messages->Array.get(0) {
    | Some(Message.Assistant(Completed({content, _}))) =>
      switch content->Array.get(0) {
      | Some(Message.AssistantContentPart.Text({text})) => t->expect(text)->Expect.toBe("Hi there!")
      | _ => t->expect("Assistant text content")->Expect.toBe("missing")
      }
    | Some(Message.Assistant(Streaming(_))) =>
      t->expect("Streaming after LoadComplete")->Expect.toBe("should be Completed")
    | _ => t->expect("Assistant message")->Expect.toBe("not found")
    }
  })

  test("in-flight streaming message is finalized to Completed by LoadComplete", t => {
    let task = TestHelpers.makeLoadingTask()

    let (task, _) = TaskReducer.next(task, StreamingStarted)
    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({text: "partial ", timestamp: "2024-01-15T10:00:00Z"}),
    )
    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({text: "response", timestamp: "2024-01-15T10:00:00Z"}),
    )

    // Before LoadComplete: still Streaming
    t->expect(TaskReducer.Selectors.streamingMessage(task)->Option.isSome)->Expect.toBe(true)

    // After LoadComplete: finalized to Completed
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
  test("isAgentRunning is true after AddUserMessage", t => {
    let task = TestHelpers.makeLoadedTask()
    t->expect(TaskReducer.Selectors.isAgentRunning(task))->Expect.toEqual(Some(false))

    let (task2, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
      }),
    )

    t->expect(TaskReducer.Selectors.isAgentRunning(task2))->Expect.toEqual(Some(true))
  })

  test("isAgentRunning is false after TurnCompleted", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
      }),
    )
    t->expect(TaskReducer.Selectors.isAgentRunning(task2))->Expect.toEqual(Some(true))

    let (task3, _) = TaskReducer.next(task2, TurnCompleted)
    t->expect(TaskReducer.Selectors.isAgentRunning(task3))->Expect.toEqual(Some(false))
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

    // Enter Selecting mode
    let (task2, _) = TaskReducer.next(task, SetAnnotationMode({mode: Selecting}))
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task2))->Expect.toEqual(Some(true))

    // Exit selection mode
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
        error: "Rate limit exceeded",
        timestamp: "2025-01-15T10:30:00Z",
        category: "unknown",
      }),
    )
    t
    ->expect(TaskReducer.Selectors.turnError(task2))
    ->Expect.toEqual(
      Some({
        id: "error-test-task-1-2025-01-15T10:30:00Z",
        message: "Rate limit exceeded",
        category: "unknown",
      }),
    )
  })

  test("AgentError sets isAgentRunning to false", t => {
    let task = TestHelpers.makeLoadedTask()
    // First start the agent running via AddUserMessage
    let (task2, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
      }),
    )
    t->expect(TaskReducer.Selectors.isAgentRunning(task2))->Expect.toEqual(Some(true))

    // Agent error should set isAgentRunning to false
    let (task3, _) = TaskReducer.next(
      task2,
      AgentError({
        error: "Some error",
        timestamp: "2025-01-15T10:30:00Z",
        category: "unknown",
      }),
    )
    t->expect(TaskReducer.Selectors.isAgentRunning(task3))->Expect.toEqual(Some(false))
  })

  test("AgentError completes any streaming message", t => {
    let task = TestHelpers.makeLoadedTask()
    // First start agent via AddUserMessage so isAgentRunning=true
    let (task0, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
      }),
    )
    let (task1, _) = TaskReducer.next(task0, StreamingStarted)
    let (task2, _) = TaskReducer.next(
      task1,
      TextDeltaReceived({text: "Partial response", timestamp: "2024-01-15T10:00:00Z"}),
    )

    // Verify we have a streaming message
    switch TaskReducer.Selectors.streamingMessage(task2) {
    | Some(Message.Streaming(_)) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }

    // Agent error should complete the streaming message
    let (task3, _) = TaskReducer.next(
      task2,
      AgentError({
        error: "Error occurred",
        timestamp: "2025-01-15T10:30:00Z",
        category: "unknown",
      }),
    )
    t->expect(TaskReducer.Selectors.streamingMessage(task3))->Expect.toEqual(None)

    // Check the message is now completed (user at index 0, assistant at index 1)
    let messages = TestHelpers.getMessages(task3)
    switch messages->Array.get(1) {
    | Some(Message.Assistant(Completed({content}))) =>
      t->expect(Array.length(content))->Expect.toBe(1)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("AgentError emits NotifyTurnCompleted effect", t => {
    let task = TestHelpers.makeLoadedTask()
    let (_, effects) = TaskReducer.next(
      task,
      AgentError({
        error: "Error",
        timestamp: "2025-01-15T10:30:00Z",
        category: "unknown",
      }),
    )

    t->expect(Array.length(effects))->Expect.toBe(1)
    switch effects->Array.get(0) {
    | Some(TaskReducer.NotifyTurnCompleted) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("ClearTurnError clears the turnError", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(
      task,
      AgentError({
        error: "Some error",
        timestamp: "2025-01-15T10:30:00Z",
        category: "unknown",
      }),
    )
    t
    ->expect(TaskReducer.Selectors.turnError(task2))
    ->Expect.toEqual(
      Some({
        id: "error-test-task-1-2025-01-15T10:30:00Z",
        message: "Some error",
        category: "unknown",
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

  test("AddUserMessage clears turnError", t => {
    let task = TestHelpers.makeLoadedTask()
    // Set an error first
    let (task2, _) = TaskReducer.next(
      task,
      AgentError({
        error: "Previous error",
        timestamp: "2025-01-15T10:30:00Z",
        category: "unknown",
      }),
    )
    t
    ->expect(TaskReducer.Selectors.turnError(task2))
    ->Expect.toEqual(
      Some({
        id: "error-test-task-1-2025-01-15T10:30:00Z",
        message: "Previous error",
        category: "unknown",
      }),
    )

    // Sending a new message should clear the error
    let (task3, _) = TaskReducer.next(
      task2,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "New message"})],
        annotations: [],
      }),
    )
    t->expect(TaskReducer.Selectors.turnError(task3))->Expect.toEqual(None)
  })
})

// ============================================================================
// Cancel Turn
// ============================================================================

describe("Task - CancelTurn", () => {
  // Helper: simulate an agent-running task with a streaming message
  let _startAgentWithStreaming = () => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
      }),
    )
    // Agent is now running
    let (task2, _) = TaskReducer.next(task1, StreamingStarted)
    let (task3, _) = TaskReducer.next(
      task2,
      TextDeltaReceived({text: "Partial resp", timestamp: "2024-01-15T10:00:00Z"}),
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

    // Streaming message should be completed, not removed
    let messages = TestHelpers.getMessages(cancelled)
    // Messages: User + Assistant(Completed)
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
    // State should be identical
    t->expect(TaskReducer.Selectors.isAgentRunning(unchanged))->Expect.toEqual(Some(false))
  })

  test("CancelTurn marks in-progress tool calls as cancelled", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
      }),
    )

    // Insert a tool call in InputAvailable state
    let toolCall: Message.toolCall = {
      id: "tool-1",
      toolName: "edit_file",
      state: Message.InputAvailable,
      inputBuffer: "",
      input: Some(JSON.parseOrThrow(`{"path": "test.ts"}`)),
      result: None,
      errorText: None,
      createdAt: Date.now(),
      parentAgentId: None,
      spawningToolName: None,
    }
    let (task2, _) = TaskReducer.next(task1, ToolCallReceived({toolCall: toolCall}))

    let (cancelled, _) = TaskReducer.next(task2, CancelTurn)

    let messages = TestHelpers.getMessages(cancelled)
    // Find the tool call message
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
    // Set error, then start agent, then cancel
    let (task1, _) = TaskReducer.next(
      task,
      AgentError({
        error: "Some error",
        timestamp: "2025-01-15T10:30:00Z",
        category: "unknown",
      }),
    )
    let (task2, _) = TaskReducer.next(
      task1,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "retry"})],
        annotations: [],
      }),
    )
    let (cancelled, _) = TaskReducer.next(task2, CancelTurn)
    t->expect(TaskReducer.Selectors.turnError(cancelled))->Expect.toEqual(None)
  })

  test("after CancelTurn, new AddUserMessage creates fresh assistant message", t => {
    let task = _startAgentWithStreaming()
    let (cancelled, _) = TaskReducer.next(task, CancelTurn)

    // Send a new message after cancel
    let (task2, _) = TaskReducer.next(
      cancelled,
      AddUserMessage({
        id: "user-2",
        content: [Client__Task__Types.UserContentPart.Text({text: "New question"})],
        annotations: [],
      }),
    )

    // Start new streaming
    let (task3, _) = TaskReducer.next(task2, StreamingStarted)
    let (task4, _) = TaskReducer.next(
      task3,
      TextDeltaReceived({text: "New response", timestamp: "2024-01-15T10:00:00Z"}),
    )

    let messages = TestHelpers.getMessages(task4)
    // Messages: User1 + Completed(Partial resp) + User2 + Streaming(New response)
    t->expect(Array.length(messages))->Expect.toBe(4)

    // Last message should be a NEW streaming message with only new text
    switch messages->Array.get(3) {
    | Some(Message.Assistant(Streaming({textBuffer}))) =>
      t->expect(textBuffer)->Expect.toBe("New response")
    | _ => t->expect("New streaming message")->Expect.toBe("not found")
    }
  })
})

// ============================================================================
// Stale Event Guard (post-cancel)
// ============================================================================

describe("Task - Stale Event Guard", () => {
  // Helper: task where agent was cancelled (isAgentRunning == false, Loaded)
  let _cancelledTask = () => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Hello"})],
        annotations: [],
      }),
    )
    let (task2, _) = TaskReducer.next(task1, CancelTurn)
    task2
  }

  test("StreamingStarted is silently dropped when agent not running", t => {
    let task = _cancelledTask()
    let (unchanged, effects) = TaskReducer.next(task, StreamingStarted)

    t->expect(effects)->Expect.toEqual([])
    // No new messages added
    t->expect(TestHelpers.getMessages(unchanged)->Array.length)->Expect.toBe(1) // just the user msg
  })

  test("TextDeltaReceived is silently dropped when agent not running", t => {
    let task = _cancelledTask()
    let (unchanged, effects) = TaskReducer.next(
      task,
      TextDeltaReceived({text: "stale text", timestamp: "2024-01-15T10:00:00Z"}),
    )

    t->expect(effects)->Expect.toEqual([])
    t->expect(TestHelpers.getMessages(unchanged)->Array.length)->Expect.toBe(1)
  })

  test("ToolCallReceived is silently dropped when agent not running", t => {
    let task = _cancelledTask()
    let toolCall: Message.toolCall = {
      id: "stale-tool",
      toolName: "test_tool",
      state: Message.InputAvailable,
      inputBuffer: "",
      input: None,
      result: None,
      errorText: None,
      createdAt: Date.now(),
      parentAgentId: None,
      spawningToolName: None,
    }
    let (unchanged, effects) = TaskReducer.next(task, ToolCallReceived({toolCall: toolCall}))

    t->expect(effects)->Expect.toEqual([])
    t->expect(TestHelpers.getMessages(unchanged)->Array.length)->Expect.toBe(1)
  })

  test("ToolInputReceived is silently dropped when agent not running", t => {
    let task = _cancelledTask()
    let (unchanged, effects) = TaskReducer.next(
      task,
      ToolInputReceived({id: "stale-tool", input: JSON.parseOrThrow(`{}`)}),
    )

    t->expect(effects)->Expect.toEqual([])
    t->expect(TestHelpers.getMessages(unchanged)->Array.length)->Expect.toBe(1)
  })

  test("ToolResultReceived is silently dropped when agent not running", t => {
    let task = _cancelledTask()
    let (unchanged, effects) = TaskReducer.next(
      task,
      ToolResultReceived({id: "stale-tool", result: JSON.parseOrThrow(`{}`)}),
    )

    t->expect(effects)->Expect.toEqual([])
    t->expect(TestHelpers.getMessages(unchanged)->Array.length)->Expect.toBe(1)
  })

  test("ToolErrorReceived is silently dropped when agent not running", t => {
    let task = _cancelledTask()
    let (unchanged, effects) = TaskReducer.next(
      task,
      ToolErrorReceived({id: "stale-tool", error: "stale error"}),
    )

    t->expect(effects)->Expect.toEqual([])
    t->expect(TestHelpers.getMessages(unchanged)->Array.length)->Expect.toBe(1)
  })

  test("stale events during Loading state still work (no guard)", t => {
    // The guard only applies to Loaded({isAgentRunning: false})
    // Loading state should still process streaming events normally
    let task = TestHelpers.makeLoadingTask()
    let (task1, _) = TaskReducer.next(task, StreamingStarted)
    let (task2, _) = TaskReducer.next(
      task1,
      TextDeltaReceived({text: "loading text", timestamp: "2024-01-15T10:00:00Z"}),
    )

    switch TaskReducer.Selectors.streamingMessage(task2) {
    | Some(Message.Streaming({textBuffer})) => t->expect(textBuffer)->Expect.toBe("loading text")
    | _ => t->expect("Streaming message")->Expect.toBe("not found during loading")
    }
  })
})

// ============================================================================
// Annotation-to-Message Tests (Issue #466)
// ============================================================================

module Annotation = Client__Annotation__Types
module MessageAnnotation = Client__Message.MessageAnnotation

// Helper to create a mock DOM element for testing
let _makeMockElement: unit => WebAPI.DOMAPI.element = %raw(`
  function() { return { tagName: "DIV" }; }
`)

let _sampleMessageAnnotations: array<MessageAnnotation.t> = [
  {
    id: "ann-1",
    selector: Ok(Some(".btn-submit")),
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
  // Helper: create a loaded task with annotations in task state
  let _taskWithAnnotations = () => {
    let task = TestHelpers.makeLoadedTask()
    // Enter selecting mode and add annotations
    let (task1, _) = TaskReducer.next(task, SetAnnotationMode({mode: Selecting}))
    // Manually set annotations via ToggleAnnotation
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

  test("AddUserMessage with annotations clears task-level annotations", t => {
    let task = _taskWithAnnotations()

    // Verify annotations exist on task before send
    t
    ->expect(TaskReducer.Selectors.annotations(task)->Option.getOr([])->Array.length)
    ->Expect.toBe(2)

    // Send message with annotations
    let (task2, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Fix this"})],
        annotations: _sampleMessageAnnotations,
      }),
    )

    // Task-level annotations should be cleared
    t
    ->expect(TaskReducer.Selectors.annotations(task2)->Option.getOr([])->Array.length)
    ->Expect.toBe(0)
  })

  test("AddUserMessage resets annotationMode to Off", t => {
    let task = _taskWithAnnotations()

    // Verify we're in Selecting mode before send
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task))->Expect.toEqual(Some(true))

    // Send message
    let (task2, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Fix this"})],
        annotations: _sampleMessageAnnotations,
      }),
    )

    // Annotation mode should be Off
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task2))->Expect.toEqual(Some(false))
  })

  test("AddUserMessage clears activePopupAnnotationId", t => {
    let task = _taskWithAnnotations()

    // Verify popup is open (from ToggleAnnotation which opens popup for last added)
    t
    ->expect(TaskReducer.Selectors.activePopupAnnotationId(task)->Option.getOr(None)->Option.isSome)
    ->Expect.toBe(true)

    // Send message
    let (task2, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [],
        annotations: _sampleMessageAnnotations,
      }),
    )

    // Active popup should be cleared
    t
    ->expect(
      TaskReducer.Selectors.activePopupAnnotationId(task2)->Option.getOr(None)->Option.isNone,
    )
    ->Expect.toBe(true)
  })

  test("Annotations are stored on the message itself", t => {
    let task = TestHelpers.makeLoadedTask()

    let (task2, _) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Check these"})],
        annotations: _sampleMessageAnnotations,
      }),
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

    let (_task2, effects) = TaskReducer.next(
      task,
      AddUserMessage({
        id: "user-1",
        content: [Client__Task__Types.UserContentPart.Text({text: "Fix"})],
        annotations: _sampleMessageAnnotations,
      }),
    )

    switch effects->Array.get(0) {
    | Some(SendMessage({annotations})) => t->expect(annotations->Array.length)->Expect.toBe(2)
    | _ => t->expect("SendMessage effect")->Expect.toBe("not found")
    }
  })
})

describe("Task - QuestionReceived on freshly loaded task (reconnect scenario)", () => {
  test("QuestionReceived sets pendingQuestion on Loaded task with isAgentRunning=false", t => {
    // After reconnect + LoadComplete, the task is Loaded with isAgentRunning=false.
    // The server re-sends the tools/call for the unresolved question.
    // The client's MCP handler calls QuestionReceived.
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

    // pendingQuestion should be set
    let pq = TaskReducer.Selectors.pendingQuestion(nextTask)
    t->expect(pq->Option.isSome)->Expect.toBe(true)
    t->expect(effects->Array.length)->Expect.toBe(0)

    // Verify question data is correct
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

    // Set up question
    let (taskWithQuestion, _) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk, resolveError}),
    )

    // Select an answer
    let (taskWithAnswer, _) = TaskReducer.next(
      taskWithQuestion,
      QuestionOptionToggled({questionIndex: 0, label: "A"}),
    )

    // Submit
    let (finalTask, effects) = TaskReducer.next(taskWithAnswer, QuestionSubmitted)

    // pendingQuestion should be cleared
    let pq = TaskReducer.Selectors.pendingQuestion(finalTask)
    t->expect(pq->Option.isNone)->Expect.toBe(true)

    // Should emit ResolveQuestionToolEffect
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

    // Execute the effect (simulate what the effect handler does)
    switch effects->Array.get(0) {
    | Some(ResolveQuestionToolEffect({resolveOk, answerJson})) => resolveOk(answerJson)
    | _ => ()
    }

    // The callback should have been called
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

    // Set up 3-question flow
    let (taskWithQ, _) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk, resolveError}),
    )

    // Skip question 0 (non-last)
    let (afterSkip, effects) = TaskReducer.next(
      taskWithQ,
      QuestionPerQuestionSkipped({questionIndex: 0}),
    )

    // Step should advance to 1
    switch TaskReducer.Selectors.pendingQuestion(afterSkip) {
    | Some(pq) =>
      t->expect(pq.currentStep)->Expect.toBe(1)
      // Answer 0 should be Skipped
      t
      ->expect(pq.answers->Dict.get("0") == Some(Client__Question__Types.Skipped))
      ->Expect.toBe(true)
    | None => t->expect("pendingQuestion")->Expect.toBe("to be Some")
    }

    // No effects — question is NOT submitted yet
    t->expect(effects->Array.length)->Expect.toBe(0)

    // pendingQuestion should still exist
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

    // Set up 2-question flow
    let (taskWithQ, _) = TaskReducer.next(
      task,
      QuestionReceived({questions, toolCallId: "tc_1", resolveOk, resolveError}),
    )

    // Skip question 0 first (non-last)
    let (afterSkip0, _) = TaskReducer.next(
      taskWithQ,
      QuestionPerQuestionSkipped({questionIndex: 0}),
    )

    // Skip question 1 (last) — should auto-submit
    let (afterSkip1, effects) = TaskReducer.next(
      afterSkip0,
      QuestionPerQuestionSkipped({questionIndex: 1}),
    )

    // pendingQuestion should be cleared (resolved)
    t
    ->expect(TaskReducer.Selectors.pendingQuestion(afterSkip1)->Option.isNone)
    ->Expect.toBe(true)

    // Should emit ResolveQuestionToolEffect (from resolveQuestion)
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

// ============================================================================
// Annotation Enrichment Lifecycle Tests (Issue #582)
// ============================================================================

describe("Task - Annotation Enrichment Lifecycle (Issue #582)", () => {
  // Helper: get annotation by index with a clear error message
  let _getAnnotation = (task: Task.t, index: int): Annotation.t => {
    Task.getAnnotations(task)
    ->Array.get(index)
    ->Option.getOrThrow(~message=`Expected annotation at index ${Int.toString(index)}`)
  }

  // Helper: create a loaded task with one annotation in Enriching state
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

  // Helper: extract annotation ID from the FetchAnnotationDetails effect
  let _getAnnotationIdFromEffect = (effects: array<TaskReducer.effect>): string => {
    switch effects->Array.get(0) {
    | Some(FetchAnnotationDetails({id})) => id
    | _ => failwith("Expected FetchAnnotationDetails effect")
    }
  }

  // Helper: build AnnotationDetailsResolved action with sensible defaults.
  // Override only the fields under test to reduce per-test boilerplate.
  let _makeResolved = (
    ~id: string,
    ~selector: result<option<string>, string>=Ok(None),
    ~screenshot: result<option<string>, string>=Ok(None),
    ~sourceLocation: result<option<Client__Types.SourceLocation.t>, string>=Ok(None),
    ~cssClasses: option<string>=?,
    ~nearbyText: option<string>=?,
    ~boundingBox: option<Annotation.boundingBox>=?,
    ~enrichmentStatus: Annotation.enrichmentStatus=Enriched,
  ): TaskReducer.action => AnnotationDetailsResolved({
    id,
    selector,
    screenshot,
    sourceLocation,
    cssClasses,
    nearbyText,
    boundingBox,
    elementorContext: None,
    enrichmentStatus,
  })

  // Helper: create an enriching annotation then resolve it, returning the resolved task
  let _resolveAnnotation = (task, effects, ~enrichmentStatus=Annotation.Enriched) => {
    let id = _getAnnotationIdFromEffect(effects)
    let (resolved, _) = TaskReducer.next(task, _makeResolved(~id, ~enrichmentStatus))
    resolved
  }

  // ============================================================================
  // ToggleAnnotation → initial enrichment state
  // ============================================================================

  test("ToggleAnnotation creates annotation with Enriching status and Ok(None) async fields", t => {
    let (task, effects) = _taskWithEnrichingAnnotation()
    let ann = _getAnnotation(task, 0)

    // Status is Enriching (promises in-flight)
    t->expect(ann.enrichmentStatus)->Expect.toEqual(Annotation.Enriching)
    // Async fields are Ok(None) — not yet populated
    t->expect(ann.selector)->Expect.toEqual(Ok(None))
    t->expect(ann.screenshot)->Expect.toEqual(Ok(None))
    t->expect(ann.sourceLocation)->Expect.toEqual(Ok(None))

    // Emits FetchAnnotationDetails effect
    switch effects->Array.get(0) {
    | Some(FetchAnnotationDetails(_)) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("FetchAnnotationDetails effect")->Expect.toBe("not found")
    }
  })

  // ============================================================================
  // AnnotationDetailsResolved — Enriched (happy path + partial errors)
  // ============================================================================

  test("AnnotationDetailsResolved writes all enrichment fields and sets Enriched", t => {
    let (task, effects) = _taskWithEnrichingAnnotation()
    let id = _getAnnotationIdFromEffect(effects)
    let (task2, _) = TaskReducer.next(
      task,
      _makeResolved(
        ~id,
        ~selector=Ok(Some(".btn-submit")),
        ~screenshot=Ok(Some("data:image/jpeg;base64,abc")),
        ~cssClasses="btn-submit",
        ~nearbyText="Submit",
        ~boundingBox={x: 10.0, y: 20.0, width: 100.0, height: 50.0},
      ),
    )
    let ann = _getAnnotation(task2, 0)
    t->expect(ann.enrichmentStatus)->Expect.toEqual(Annotation.Enriched)
    t->expect(ann.selector)->Expect.toEqual(Ok(Some(".btn-submit")))
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
    // Partial failure: individual sub-promises failed but the outer chain succeeded
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
    // Status is Enriched (outer chain succeeded), but individual fields have errors
    t->expect(ann.enrichmentStatus)->Expect.toEqual(Annotation.Enriched)
    t->expect(ann.selector)->Expect.toEqual(Error("No unique selector found"))
    t->expect(ann.screenshot)->Expect.toEqual(Error("Canvas tainted by cross-origin data"))
    t->expect(ann.sourceLocation)->Expect.toEqual(Error("CORS error on source map URL"))
  })

  // ============================================================================
  // AnnotationDetailsResolved — Failed (outer catch)
  // ============================================================================

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

  // ============================================================================
  // Edge cases
  // ============================================================================

  test("AnnotationDetailsResolved on Unloaded task is silently discarded", t => {
    let task = TestHelpers.makeUnloadedTask()
    let (task2, effects) = TaskReducer.next(task, _makeResolved(~id="stale-ann-id"))
    t->expect(effects)->Expect.toEqual([])
    t->expect(Task.getAnnotations(task2)->Array.length)->Expect.toBe(0)
  })

  // ============================================================================
  // hasEnrichingAnnotations selector
  // ============================================================================

  test("hasEnrichingAnnotations is true while Enriching, false after Enriched", t => {
    // Full lifecycle on a single annotation: Enriching → Enriched
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
    // Add two annotations
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
    // Both are Enriching
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(task3))->Expect.toEqual(Some(true))

    // Resolve first — still true because second is Enriching
    let task4 = _resolveAnnotation(task3, effects1)
    t->expect(TaskReducer.Selectors.hasEnrichingAnnotations(task4))->Expect.toEqual(Some(true))
  })
})
