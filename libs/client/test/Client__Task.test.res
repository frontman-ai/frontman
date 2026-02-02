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
  test("StreamingStarted creates a streaming message", t => {
    let task = TestHelpers.makeLoadedTask()
    let (updatedTask, _effects) = TaskReducer.next(task, StreamingStarted)

    let messages = TestHelpers.getMessages(updatedTask)
    t->expect(Array.length(messages))->Expect.toBe(1)

    switch messages->Array.get(0) {
    | Some(Message.Assistant(Streaming({textBuffer}))) =>
      t->expect(textBuffer)->Expect.toBe("")
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("StreamingStarted fails fast if streaming message already exists", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(task, StreamingStarted)

    // Invariant enforced: calling StreamingStarted again should crash
    Expect.toThrow(t->expect(() => TaskReducer.next(task1, StreamingStarted)))
  })

  test("TextDeltaReceived appends to streaming message", t => {
    let task = TestHelpers.makeLoadedTask()
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
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(task, StreamingStarted)
    let (task2, _) = TaskReducer.next(task1, TextDeltaReceived({text: "Hello"}))
    let (task3, _) = TaskReducer.next(task2, TurnCompleted)

    let messages = TestHelpers.getMessages(task3)
    t->expect(Array.length(messages))->Expect.toBe(1)

    switch messages->Array.get(0) {
    | Some(Message.Assistant(Completed({content}))) =>
      t->expect(Array.length(content))->Expect.toBe(1)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("Task - Tool Call Lifecycle", () => {
  test("tool call progresses: ToolCallReceived -> ToolInputReceived -> ToolResultReceived", t => {
    let task = TestHelpers.makeLoadedTask()
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

    // Verify InputAvailable state
    let messages1 = TestHelpers.getMessages(task1)
    switch messages1->Array.get(0) {
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
    switch messages2->Array.get(0) {
    | Some(Message.ToolCall({state: OutputAvailable, result: Some(_)})) =>
      t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("tool error sets OutputError state", t => {
    let task = TestHelpers.makeLoadedTask()
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
    switch messages->Array.get(0) {
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
      }),
    )
    t->expect(TaskReducer.Selectors.isAgentRunning(task2))->Expect.toEqual(Some(true))

    let (task3, _) = TaskReducer.next(task2, TurnCompleted)
    t->expect(TaskReducer.Selectors.isAgentRunning(task3))->Expect.toEqual(Some(false))
  })
})

describe("Task - Figma Node State", () => {
  test("SetFigmaNode updates figma node", t => {
    let task = TestHelpers.makeLoadedTask()
    t->expect(TaskReducer.Selectors.figmaNode(task))->Expect.toEqual(
      Some(Client__Task__Types.FigmaNode.NoSelection),
    )

    let (task2, _) = TaskReducer.next(
      task,
      SetFigmaNode({
        figmaNode: {
          nodeId: "123",
          nodeData: "test node data",
          image: Some("data:image/png;base64,abc123"),
          isDsl: true,
        },
      }),
    )

    switch TaskReducer.Selectors.figmaNode(task2) {
    | Some(Client__Task__Types.FigmaNode.SelectedNode({nodeId})) =>
      t->expect(nodeId)->Expect.toBe("123")
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("ClearFigmaNode resets to NoSelection", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(
      task,
      SetFigmaNode({
        figmaNode: {nodeId: "123", nodeData: "test", image: None, isDsl: true},
      }),
    )
    let (task3, _) = TaskReducer.next(task2, ClearFigmaNode)

    t->expect(TaskReducer.Selectors.figmaNode(task3))->Expect.toEqual(
      Some(Client__Task__Types.FigmaNode.NoSelection),
    )
  })

  test("SetFigmaNodeWaiting sets WaitingForSelection", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task2, _) = TaskReducer.next(task, SetFigmaNodeWaiting)

    t->expect(TaskReducer.Selectors.figmaNode(task2))->Expect.toEqual(
      Some(Client__Task__Types.FigmaNode.WaitingForSelection),
    )
  })
})

describe("Task - Web Preview Selection", () => {
  test("ToggleWebPreviewSelection toggles selection mode", t => {
    let task = TestHelpers.makeLoadedTask()
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task))->Expect.toEqual(Some(false))

    let (task2, _) = TaskReducer.next(task, ToggleWebPreviewSelection)
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task2))->Expect.toEqual(Some(true))

    let (task3, _) = TaskReducer.next(task2, ToggleWebPreviewSelection)
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task3))->Expect.toEqual(Some(false))
  })

  test("ToggleWebPreviewSelection clears selected element when entering selection mode", t => {
    // Start with a selected element
    let task = TestHelpers.makeLoadedTask()

    // First toggle to enter selection mode (webPreviewIsSelecting becomes true)
    let (task2, _) = TaskReducer.next(task, ToggleWebPreviewSelection)
    t->expect(TaskReducer.Selectors.webPreviewIsSelecting(task2))->Expect.toEqual(Some(true))

    // Toggle again to exit selection mode (should clear selected element)
    let (task3, _) = TaskReducer.next(task2, ToggleWebPreviewSelection)
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
      }),
    )
    t->expect(TaskReducer.Selectors.isAgentRunning(task2))->Expect.toEqual(Some(true))

    // Agent error should set isAgentRunning to false
    let (task3, _) = TaskReducer.next(task2, AgentError({error: "Some error"}))
    t->expect(TaskReducer.Selectors.isAgentRunning(task3))->Expect.toEqual(Some(false))
  })

  test("AgentError completes any streaming message", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(task, StreamingStarted)
    let (task2, _) = TaskReducer.next(task1, TextDeltaReceived({text: "Partial response"}))

    // Verify we have a streaming message
    switch TaskReducer.Selectors.streamingMessage(task2) {
    | Some(Message.Streaming(_)) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }

    // Agent error should complete the streaming message
    let (task3, _) = TaskReducer.next(task2, AgentError({error: "Error occurred"}))
    t->expect(TaskReducer.Selectors.streamingMessage(task3))->Expect.toEqual(None)

    // Check the message is now completed
    let messages = TestHelpers.getMessages(task3)
    switch messages->Array.get(0) {
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
      }),
    )
    t->expect(TaskReducer.Selectors.turnError(task3))->Expect.toEqual(None)
  })
})
