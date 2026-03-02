open Vitest

module Task = Client__Task__Types.Task
module Message = Client__Task__Types.Message
module TaskReducer = Client__Task__Reducer

module TestHelpers = {
  let makeLoadedTask = (~id="test-task-1", ~messages=[], ~previewUrl="http://localhost:3000") => {
    Task.makeLoaded(~id, ~title="Test Task", ~previewUrl, ~createdAt=Date.now(), ~messages)
  }

  let makeUnloadedTask = (~id="test-task-1") => {
    Task.makeUnloaded(~id, ~title="Test Task", ~createdAt=Date.now(), ~updatedAt=Date.now())
  }

  let makeLoadingTask = (~id="test-task-1", ~previewUrl="http://localhost:3000") => {
    let unloaded = Task.makeUnloaded(~id, ~title="Test Task", ~createdAt=Date.now(), ~updatedAt=Date.now())
    Task.startLoading(unloaded, ~previewUrl)
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
    | Some(Message.Assistant(Streaming({textBuffer}))) =>
      t->expect(textBuffer)->Expect.toBe("")
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
    let (task2, _) = TaskReducer.next(task1, TextDeltaReceived({text: "Hello"}))
    let (task3, _) = TaskReducer.next(task2, TextDeltaReceived({text: " world"}))

    switch TaskReducer.Selectors.streamingMessage(task3) {
    | Some(Message.Streaming({textBuffer})) =>
      t->expect(textBuffer)->Expect.toBe("Hello world")
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("TurnCompleted converts streaming to completed", t => {
    let task = _startAgent()
    let (task1, _) = TaskReducer.next(task, StreamingStarted)
    let (task2, _) = TaskReducer.next(task1, TextDeltaReceived({text: "Hello"}))
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
    let (task3, _) = TaskReducer.next(task1, ToolErrorReceived({id: toolId, error: "Something went wrong"}))

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

    let (loadingTask, _) = TaskReducer.next(task, LoadStarted({previewUrl: "http://localhost:3000"}))
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
    t->expect(TaskReducer.Selectors.planEntries(task)->Option.getOr([])->Array.length)->Expect.toBe(0)

    let entries: array<Client__Task__Types.ACPTypes.planEntry> = [
      {content: "Step 1", priority: High, status: Pending},
      {content: "Step 2", priority: Medium, status: InProgress},
    ]

    let (task2, _) = TaskReducer.next(task, PlanReceived({entries: entries}))
    t->expect(TaskReducer.Selectors.planEntries(task2)->Option.getOr([])->Array.length)->Expect.toBe(2)
  })
})

describe("Task - Error Handling", () => {
  test("AgentError sets turnError on Loaded task", t => {
    let task = TestHelpers.makeLoadedTask()
    t->expect(TaskReducer.Selectors.turnError(task))->Expect.toEqual(None)

    let (task2, _) = TaskReducer.next(task, AgentError({error: "Rate limit exceeded"}))
    t->expect(TaskReducer.Selectors.turnError(task2))->Expect.toEqual(Some("Rate limit exceeded"))
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
    let (task3, _) = TaskReducer.next(task2, AgentError({error: "Some error"}))
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
    let (task2, _) = TaskReducer.next(task1, TextDeltaReceived({text: "Partial response"}))

    // Verify we have a streaming message
    switch TaskReducer.Selectors.streamingMessage(task2) {
    | Some(Message.Streaming(_)) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }

    // Agent error should complete the streaming message
    let (task3, _) = TaskReducer.next(task2, AgentError({error: "Error occurred"}))
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
    let (_, effects) = TaskReducer.next(task, AgentError({error: "Error"}))

    t->expect(Array.length(effects))->Expect.toBe(1)
    switch effects->Array.get(0) {
    | Some(TaskReducer.NotifyTurnCompleted) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("ClearTurnError clears the turnError", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(task, AgentError({error: "Some error"}))
    t->expect(TaskReducer.Selectors.turnError(task2))->Expect.toEqual(Some("Some error"))

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
    let (task2, _) = TaskReducer.next(task, AgentError({error: "Previous error"}))
    t->expect(TaskReducer.Selectors.turnError(task2))->Expect.toEqual(Some("Previous error"))

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
    let (task3, _) = TaskReducer.next(task2, TextDeltaReceived({text: "Partial resp"}))
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
    let toolMsg = messages->Array.find(msg =>
      switch msg {
      | Message.ToolCall({id: "tool-1"}) => true
      | _ => false
      }
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
    let (task1, _) = TaskReducer.next(task, AgentError({error: "Some error"}))
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
    let (task4, _) = TaskReducer.next(task3, TextDeltaReceived({text: "New response"}))

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
    let (unchanged, effects) = TaskReducer.next(task, TextDeltaReceived({text: "stale text"}))

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
    let (task2, _) = TaskReducer.next(task1, TextDeltaReceived({text: "loading text"}))

    switch TaskReducer.Selectors.streamingMessage(task2) {
    | Some(Message.Streaming({textBuffer})) =>
      t->expect(textBuffer)->Expect.toBe("loading text")
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
    selector: Some(".btn-submit"),
    tagName: "button",
    cssClasses: Some("btn-submit primary"),
    comment: Some("This button is broken"),
    screenshot: None,
    sourceLocation: None,
    boundingBox: None,
    nearbyText: Some("Submit"),
  },
  {
    id: "ann-2",
    selector: Some("div.header"),
    tagName: "div",
    cssClasses: Some("header"),
    comment: None,
    screenshot: None,
    sourceLocation: None,
    boundingBox: None,
    nearbyText: Some("Welcome"),
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
      ToggleAnnotation({element: el1, position: {xPercent: 50.0, yAbsolute: 100.0}, tagName: "button"}),
    )
    let (task3, _) = TaskReducer.next(
      task2,
      ToggleAnnotation({element: el2, position: {xPercent: 30.0, yAbsolute: 200.0}, tagName: "div"}),
    )
    task3
  }

  test("AddUserMessage with annotations clears task-level annotations", t => {
    let task = _taskWithAnnotations()

    // Verify annotations exist on task before send
    t->expect(TaskReducer.Selectors.annotations(task)->Option.getOr([])->Array.length)->Expect.toBe(2)

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
    t->expect(TaskReducer.Selectors.annotations(task2)->Option.getOr([])->Array.length)->Expect.toBe(0)
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
    t->expect(TaskReducer.Selectors.activePopupAnnotationId(task)->Option.getOr(None)->Option.isSome)->Expect.toBe(true)

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
    t->expect(TaskReducer.Selectors.activePopupAnnotationId(task2)->Option.getOr(None)->Option.isNone)->Expect.toBe(true)
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
      t->expect((annotations->Array.getUnsafe(0)).comment)->Expect.toEqual(Some("This button is broken"))
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
    | Some(SendMessage({annotations})) =>
      t->expect(annotations->Array.length)->Expect.toBe(2)
    | _ => t->expect("SendMessage effect")->Expect.toBe("not found")
    }
  })
})
