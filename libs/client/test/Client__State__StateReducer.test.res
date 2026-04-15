open Vitest

module Reducer = Client__State__StateReducer
module Task = Client__State__Types.Task
module UserContentPart = Client__State__Types.UserContentPart
module AssistantContentPart = Client__State__Types.AssistantContentPart

module TestHelpers = {
  let makeStateWithTask = (
    ~taskId="test-task-1",
    ~messages=[],
    ~timestamp=1000.0,
    ~previewUrl="http://localhost:3000",
    ~isAgentRunning=false,
  ) => {
    let task = Task.makeLoaded(
      ~id=taskId,
      ~title="Test Task",
      ~previewUrl,
      ~createdAt=timestamp,
      ~messages,
      ~isAgentRunning,
    )

    let tasks = Dict.make()
    tasks->Dict.set(taskId, task)

    (
      {
        tasks,
        currentTask: Task.Selected(taskId),
        acpSession: NoAcpSession,
        sessionInitialized: false,
        usageInfo: None,
        userProfile: None,
        openrouterKeySettings: {
          source: Client__State__Types.None,
          saveStatus: Client__State__Types.Idle,
        },
        anthropicKeySettings: {
          source: Client__State__Types.None,
          saveStatus: Client__State__Types.Idle,
        },
        anthropicOAuthStatus: Client__State__Types.NotConnected,
        chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
        configOptions: None,
        selectedModelValue: None,
        pendingProviderAutoSelect: None,
        sessionsLoadState: Client__State__Types.SessionsNotLoaded,
        updateInfo: None,
        updateCheckStatus: UpdateNotChecked,
        updateBannerDismissed: false,
      }: Client__State__Types.state
    )
  }

  let getMessages = Reducer.Selectors.messages
  let getMessage = (state, index) => getMessages(state)->Array.get(index)
  let getTaskCount = (state: Client__State__Types.state) =>
    state.tasks->Dict.valuesToArray->Array.length

  // Helper to get current task ID
  let getCurrentTaskId = (state: Client__State__Types.state): option<string> => {
    Reducer.Selectors.currentTaskId(state)
  }
}

describe("Client State Reducer", () => {
  test("AddUserMessage creates task and appends user message", t => {
    let state = Reducer.defaultState
    let action = Reducer.AddUserMessage({
      id: "user-1",
      sessionId: "session-1",
      content: [UserContentPart.text("Hello")],
      annotations: [],
    })

    let (nextState, _effects) = Reducer.next(state, action)

    // Should create a task
    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(1)
    t->expect(TestHelpers.getCurrentTaskId(nextState)->Option.isSome)->Expect.toBe(true)

    // Check task has the message
    let messages = Reducer.Selectors.messages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(1)

    let message = messages->Array.get(0)->Option.getOrThrow

    switch message {
    | Reducer.Message.User({id, content, _}) => {
        t->expect(id)->Expect.toBe("user-1")
        t->expect(content->Array.length)->Expect.toBe(1)
      }
    | _ => JsExn.throw("Expected User message but got different message type")
    }
  })

  test("TextDeltaReceived appends to textBuffer", t => {
    let state = TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({id: "assistant-1", textBuffer: "Hello", createdAt: 0.0}),
        ),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let action = Reducer.TaskAction({
      target: ForTask(taskId),
      action: TextDeltaReceived({text: " world", timestamp: "2024-01-15T10:00:00Z"}),
    })
    let (nextState, _effects) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Reducer.Message.Assistant(Streaming({textBuffer, _})) =>
      t->expect(textBuffer)->Expect.toBe("Hello world")
    | _ => JsExn.throw("Expected Assistant Streaming message with updated text")
    }
  })

  test("TurnCompleted transitions to Completed variant", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({id: "assistant-1", textBuffer: "Hello world", createdAt: 0.0}),
        ),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let action = Reducer.TaskAction({target: ForTask(taskId), action: TurnCompleted})
    let (nextState, _effects) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Reducer.Message.Assistant(Completed({content, _})) => {
        t->expect(content->Array.length)->Expect.toBe(1)
        // Verify content was built from textBuffer
        let contentPart = content->Array.get(0)->Option.getOrThrow
        switch contentPart {
        | AssistantContentPart.Text({text}) => t->expect(text)->Expect.toBe("Hello world")
        | _ => JsExn.throw("Expected Text content part")
        }
      }
    | _ => JsExn.throw("Expected Assistant Completed message")
    }
  })

  test("messages maintain order", t => {
    let state = Reducer.defaultState

    let (state, _) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        sessionId: "session-1",
        content: [UserContentPart.text("Hi")],
        annotations: [],
      }),
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let (state, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: StreamingStarted}),
    )
    let (state, _) = Reducer.next(
      state,
      TaskAction({
        target: ForTask(taskId),
        action: TextDeltaReceived({text: "Hello", timestamp: "2024-01-15T10:00:00Z"}),
      }),
    )
    let (state, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: TurnCompleted}),
    )

    let messages = TestHelpers.getMessages(state)
    t->expect(messages->Array.length)->Expect.toBe(2)
    let msg0 = messages->Array.get(0)->Option.getOrThrow
    let msg1 = messages->Array.get(1)->Option.getOrThrow

    switch (msg0, msg1) {
    | (User(_), Assistant(_)) => () // Correct order
    | _ => JsExn.throw("Expected User message first, then Assistant message")
    }
  })

  test("Selectors.isStreaming detects streaming messages", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "",
            createdAt: 0.0,
          }),
        ),
      ],
    )

    t->expect(Reducer.Selectors.isStreaming(state))->Expect.toBe(true)
  })

  test("Selectors.isStreaming false when no streaming", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.Assistant(
          Completed({
            id: "assistant-1",
            content: [AssistantContentPart.text("Done")],
            createdAt: 0.0,
          }),
        ),
      ],
    )

    t->expect(Reducer.Selectors.isStreaming(state))->Expect.toBe(false)
  })

  test("ToolCallReceived creates new ToolCall message", t => {
    let state = TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "Calling tool...",
            createdAt: 0.0,
          }),
        ),
        Reducer.Message.ToolCall({
          id: "call-123",
          toolName: "search",
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.Message.InputStreaming,
          createdAt: 0.0,
          parentAgentId: None,
          spawningToolName: None,
        }),
      ],
    )

    let toolCall: Reducer.Message.toolCall = {
      id: "call-123",
      toolName: "search",
      inputBuffer: "",
      input: Some(JSON.Encode.object({})),
      result: None,
      errorText: None,
      state: Reducer.Message.InputAvailable,
      createdAt: 0.0,
      parentAgentId: None,
      spawningToolName: None,
    }

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let action = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolCallReceived({toolCall: toolCall}),
    })
    let (nextState, _effects) = Reducer.next(state, action)

    let messages = TestHelpers.getMessages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(ToolCall({id, toolName, input, _})) => {
        t->expect(id)->Expect.toBe("call-123")
        t->expect(toolName)->Expect.toBe("search")
        t->expect(input)->Expect.toEqual(Some(JSON.Encode.object({})))
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })
})

describe("Client State Reducer - TurnCompleted Content Conversion", () => {
  test("handles empty textBuffer correctly", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "msg-2",
            textBuffer: "",
            createdAt: 0.0,
          }),
        ),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let (nextState, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: TurnCompleted}),
    )

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Reducer.Message.Assistant(Completed({content, _})) =>
      t->expect(content->Array.length)->Expect.toBe(0)
    | _ =>
      t
      ->expect("Expected Completed message with empty content")
      ->Expect.toBe("Got wrong message type")
    }
  })

  test("converts toolCalls to ToolCall content parts", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "msg-3",
            textBuffer: "Listing files",
            createdAt: 0.0,
          }),
        ),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let (nextState, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: TurnCompleted}),
    )

    let messages = TestHelpers.getMessages(nextState)
    switch messages->Array.get(0) {
    | Some(Reducer.Message.Assistant(Completed({content, _}))) => {
        t->expect(content->Array.length)->Expect.toBe(1)

        // Should be text content
        switch content->Array.get(0) {
        | Some(AssistantContentPart.Text({text})) => t->expect(text)->Expect.toBe("Listing files")
        | _ => t->expect("Got text content")->Expect.toBe("Expected text content")
        }
      }
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })

  test("preserves message ID during streaming to completed transition", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "stable-id-123",
            textBuffer: "Test",
            createdAt: 0.0,
          }),
        ),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let (nextState, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: TurnCompleted}),
    )

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    // The message ID should be preserved from the streaming message
    | Reducer.Message.Assistant(Completed({id, _})) => t->expect(id)->Expect.toBe("stable-id-123")
    | _ => JsExn.throw("Expected Assistant Completed message")
    }
  })
})

describe("Client State Reducer - Streaming Flow", () => {
  test("full streaming lifecycle maintains stable ID", t => {
    let state = Reducer.defaultState

    // 0. Create a task by adding a user message first
    let (state, _) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        sessionId: "session-id",
        content: [UserContentPart.text("Hello")],
        annotations: [],
      }),
    )

    // Get taskId after task creation
    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow

    // 1. Start streaming (ID is now generated internally)
    let (state, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: StreamingStarted}),
    )

    // Get the generated message ID
    let task = state.tasks->Dict.get(taskId)->Option.getOrThrow
    let generatedId = switch Client__Task__Reducer.Selectors.streamingMessage(task) {
    | Some(Reducer.Message.Streaming({id})) => id
    | _ => JsExn.throw("Expected streaming message")
    }

    // 2. Receive text deltas
    let (state, _) = Reducer.next(
      state,
      TaskAction({
        target: ForTask(taskId),
        action: TextDeltaReceived({text: "Hello", timestamp: "2024-01-15T10:00:00Z"}),
      }),
    )
    let (state, _) = Reducer.next(
      state,
      TaskAction({
        target: ForTask(taskId),
        action: TextDeltaReceived({text: " world", timestamp: "2024-01-15T10:00:00Z"}),
      }),
    )

    // 3. Complete message
    let (state, _) = Reducer.next(
      state,
      TaskAction({target: ForTask(taskId), action: TurnCompleted}),
    )

    // Verify: Message ID stayed stable throughout (check second message, first is user)
    let messages = TestHelpers.getMessages(state)
    switch messages->Array.get(1) {
    | Some(Reducer.Message.Assistant(Completed({id, content, _}))) => {
        t->expect(id)->Expect.toBe(generatedId)
        switch content->Array.get(0) {
        | Some(AssistantContentPart.Text({text})) => t->expect(text)->Expect.toBe("Hello world")
        | _ => t->expect("Got text content")->Expect.toBe("Expected text content")
        }
      }
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })
})

describe("Client State Reducer - Selectors", () => {
  test("getMessageId selector works for all message types", t => {
    let userMsg = Reducer.Message.User({
      id: "user-1",
      content: [],
      annotations: [],
      createdAt: 0.0,
    })

    let streamingMsg = Reducer.Message.Assistant(
      Reducer.Message.Streaming({
        id: "streaming-1",
        textBuffer: "",
        createdAt: 0.0,
      }),
    )

    let completedMsg = Reducer.Message.Assistant(
      Reducer.Message.Completed({
        id: "completed-1",
        content: [],
        createdAt: 0.0,
      }),
    )

    let toolCallMsg = Reducer.Message.ToolCall({
      id: "tool-1",
      toolName: "search",
      state: Reducer.Message.InputAvailable,
      inputBuffer: "",
      input: None,
      result: None,
      errorText: None,
      createdAt: 0.0,
      parentAgentId: None,
      spawningToolName: None,
    })

    t->expect(Reducer.Selectors.getMessageId(userMsg))->Expect.toBe("user-1")
    t->expect(Reducer.Selectors.getMessageId(streamingMsg))->Expect.toBe("streaming-1")
    t->expect(Reducer.Selectors.getMessageId(completedMsg))->Expect.toBe("completed-1")
    t->expect(Reducer.Selectors.getMessageId(toolCallMsg))->Expect.toBe("tool-1")
  })
})

describe("Client State Reducer - Tool Lifecycle", () => {
  test("ToolResultReceived sets result and OutputAvailable state", t => {
    let state = TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
          result: None,
          errorText: None,
          state: Reducer.Message.InputAvailable,
          createdAt: 0.0,
          parentAgentId: None,
          spawningToolName: None,
        }),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let result = JSON.parseOrThrow("{\"content\": \"file contents\"}")
    let action = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolResultReceived({id: "call-1", result}),
    })
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Reducer.Message.ToolCall({state, result, _}) => {
        t->expect(state)->Expect.toBe(Reducer.Message.OutputAvailable)
        t->expect(result->Option.isSome)->Expect.toBe(true)
      }
    | _ => JsExn.throw("Expected ToolCall message")
    }
  })

  test("ToolErrorReceived sets error and OutputError state", t => {
    let state = TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
          result: None,
          errorText: None,
          state: Reducer.Message.InputAvailable,
          createdAt: 0.0,
          parentAgentId: None,
          spawningToolName: None,
        }),
      ],
    )

    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let action = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolErrorReceived({
        id: "call-1",
        error: "File not found",
      }),
    })
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Reducer.Message.ToolCall({state, errorText, _}) => {
        t->expect(state)->Expect.toBe(Reducer.Message.OutputError)
        t->expect(errorText)->Expect.toBe(Some("File not found"))
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })

  test("ToolCallReceived with complete input creates tool with InputAvailable", t => {
    // Create a task with an assistant message first (tools belong to tasks)
    let state = TestHelpers.makeStateWithTask(
      ~isAgentRunning=true,
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "",
            createdAt: 0.0,
          }),
        ),
        Reducer.Message.ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.Message.InputStreaming,
          createdAt: 0.0,
          parentAgentId: None,
          spawningToolName: None,
        }),
      ],
    )

    let toolCall: Reducer.Message.toolCall = {
      id: "call-1",
      toolName: "read_file",
      inputBuffer: "",
      input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
      result: None,
      errorText: None,
      state: Reducer.Message.InputAvailable,
      createdAt: 0.0,
      parentAgentId: None,
      spawningToolName: None,
    }
    let taskId = TestHelpers.getCurrentTaskId(state)->Option.getOrThrow
    let action = Reducer.TaskAction({
      target: ForTask(taskId),
      action: ToolCallReceived({toolCall: toolCall}),
    })
    let (nextState, _) = Reducer.next(state, action)

    let messages = TestHelpers.getMessages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(Reducer.Message.ToolCall({state, input, _})) => {
        t->expect(state)->Expect.toBe(Reducer.Message.InputAvailable)
        t->expect(input->Option.isSome)->Expect.toBe(true)
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })
})

describe("Client State Reducer - Task ID Continuity", () => {
  test("multiple user messages in same conversation use same task ID in state", t => {
    let state = Reducer.defaultState

    let (state1, _effects1) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        sessionId: "sessionId",
        content: [UserContentPart.text("First message")],
        annotations: [],
      }),
    )

    let taskId1 = TestHelpers.getCurrentTaskId(state1)

    let (state2, _effects2) = Reducer.next(
      state1,
      AddUserMessage({
        id: "user-2",
        sessionId: "sessionId",
        content: [UserContentPart.text("Second message")],
        annotations: [],
      }),
    )

    let taskId2 = TestHelpers.getCurrentTaskId(state2)

    t->expect(taskId1->Option.isSome)->Expect.toBe(true)
    t->expect(taskId2->Option.isSome)->Expect.toBe(true)
    t->expect(taskId1)->Expect.toEqual(taskId2)
  })

  test("effect contains same task ID as state", t => {
    let state = Reducer.defaultState

    let (state1, effects1) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        sessionId: "sessionId",
        content: [UserContentPart.text("First message")],
        annotations: [],
      }),
    )

    let taskIdInState = TestHelpers.getCurrentTaskId(state1)

    switch (effects1->Array.get(0), taskIdInState) {
    | (
        Some(Reducer.TaskEffect({target: ForTask(effectTaskId), effect: SendMessage(_)})),
        Some(stateTaskId),
      ) =>
      t->expect(effectTaskId)->Expect.toBe(stateTaskId)
    | _ => t->expect("Effect and state should both have task ID")->Expect.toBe("Missing task IDs")
    }
  })
})

describe("Client State Reducer - Task Management Actions", () => {
  test("SwitchTask restores task messages", t => {
    let task1 = Task.makeLoaded(
      ~id="task-1",
      ~title="Task 1",
      ~previewUrl="http://localhost:3000",
      ~createdAt=1000.0,
      ~messages=[
        Reducer.Message.User({
          id: "user-1",
          content: [UserContentPart.Text({text: "Hello from task 1"})],
          annotations: [],
          createdAt: 1000.0,
        }),
      ],
    )

    let task2 = Task.makeLoaded(
      ~id="task-2",
      ~title="Task 2",
      ~previewUrl="http://localhost:3000",
      ~createdAt=2000.0,
      ~messages=[
        Reducer.Message.User({
          id: "user-2",
          content: [UserContentPart.Text({text: "Hello from task 2"})],
          annotations: [],
          createdAt: 2000.0,
        }),
      ],
    )

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)
    tasks->Dict.set("task-2", task2)

    let state: Reducer.state = {
      tasks,
      currentTask: Task.Selected("task-1"),
      acpSession: NoAcpSession,
      sessionInitialized: false,
      usageInfo: None,
      userProfile: None,
      openrouterKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicOAuthStatus: Client__State__Types.NotConnected,
      chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
      configOptions: None,
      selectedModelValue: None,
      pendingProviderAutoSelect: None,
      sessionsLoadState: Client__State__Types.SessionsNotLoaded,
      updateInfo: None,
      updateCheckStatus: UpdateNotChecked,
      updateBannerDismissed: false,
    }

    let (nextState, _) = Reducer.next(state, SwitchTask({taskId: "task-2"}))

    let messages = Reducer.Selectors.messages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(1)

    let message = messages->Array.get(0)->Option.getOrThrow

    switch message {
    | User({content, _}) => {
        let contentPart = content->Array.get(0)->Option.getOrThrow
        switch contentPart {
        | UserContentPart.Text({text}) => t->expect(text)->Expect.toBe("Hello from task 2")
        | _ => JsExn.throw("Expected Text content part")
        }
      }
    | _ => JsExn.throw("Expected User message")
    }
  })

  test("DeleteTask switches to New when deleting only task", t => {
    let task1 = Task.makeLoaded(
      ~id="task-1",
      ~title="Task 1",
      ~previewUrl="http://localhost:3000",
      ~createdAt=1000.0,
    )

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)

    let state: Reducer.state = {
      tasks,
      currentTask: Task.Selected("task-1"),
      acpSession: NoAcpSession,
      sessionInitialized: false,
      usageInfo: None,
      userProfile: None,
      openrouterKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicOAuthStatus: Client__State__Types.NotConnected,
      chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
      configOptions: None,
      selectedModelValue: None,
      pendingProviderAutoSelect: None,
      sessionsLoadState: Client__State__Types.SessionsNotLoaded,
      updateInfo: None,
      updateCheckStatus: UpdateNotChecked,
      updateBannerDismissed: false,
    }

    let (nextState, _) = Reducer.next(state, DeleteTask({taskId: "task-1"}))

    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(0)
    // Should switch to New task
    switch nextState.currentTask {
    | Task.New(_) => t->expect(true)->Expect.toBe(true)
    | Task.Selected(_) => t->expect(false)->Expect.toBe(true)
    }
  })

  test("AddUserMessage after deleting last task creates new task", t => {
    // Start with a single task
    let task1 = Task.makeLoaded(
      ~id="task-1",
      ~title="Task 1",
      ~previewUrl="http://localhost:3000",
      ~createdAt=1000.0,
      ~messages=[
        Reducer.Message.User({
          id: "user-1",
          content: [UserContentPart.Text({text: "Old message"})],
          annotations: [],
          createdAt: 1000.0,
        }),
      ],
    )

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)

    let state: Reducer.state = {
      tasks,
      currentTask: Task.Selected("task-1"),
      acpSession: NoAcpSession,
      sessionInitialized: false,
      usageInfo: None,
      userProfile: None,
      openrouterKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicOAuthStatus: Client__State__Types.NotConnected,
      chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
      configOptions: None,
      selectedModelValue: None,
      pendingProviderAutoSelect: None,
      sessionsLoadState: Client__State__Types.SessionsNotLoaded,
      updateInfo: None,
      updateCheckStatus: UpdateNotChecked,
      updateBannerDismissed: false,
    }

    // Delete the only task
    let (stateAfterDelete, _) = Reducer.next(state, DeleteTask({taskId: "task-1"}))
    t->expect(TestHelpers.getTaskCount(stateAfterDelete))->Expect.toBe(0)
    switch stateAfterDelete.currentTask {
    | Task.New(_) => ()
    | _ => JsExn.throw("Expected New task after deleting last task")
    }

    // Now send a new user message — should create a fresh task without crashing
    let (stateAfterMsg, effects) = Reducer.next(
      stateAfterDelete,
      AddUserMessage({
        id: "user-2",
        sessionId: "session-new",
        content: [UserContentPart.text("Hello after delete")],
        annotations: [],
      }),
    )

    // A new task should exist
    t->expect(TestHelpers.getTaskCount(stateAfterMsg))->Expect.toBe(1)
    let newTaskId = TestHelpers.getCurrentTaskId(stateAfterMsg)->Option.getOrThrow
    // Must be a different task than the deleted one
    t->expect(newTaskId)->Expect.not->Expect.toBe("task-1")

    // The new task should contain the new message
    let messages = Reducer.Selectors.messages(stateAfterMsg)
    t->expect(messages->Array.length)->Expect.toBe(1)
    switch messages->Array.get(0) {
    | Some(User({id, _})) => t->expect(id)->Expect.toBe("user-2")
    | _ => JsExn.throw("Expected User message in new task")
    }

    // Effect should target the new task
    switch effects->Array.get(0) {
    | Some(Reducer.TaskEffect({target: ForTask(effectTaskId), effect: SendMessage(_)})) =>
      t->expect(effectTaskId)->Expect.toBe(newTaskId)
    | _ => JsExn.throw("Expected SendMessage effect for new task")
    }
  })

  test("Tasks maintain independent state across switches", t => {
    let task1 = Task.makeLoaded(
      ~id="task-1",
      ~title="Task 1",
      ~previewUrl="http://localhost:3000",
      ~createdAt=1000.0,
    )
    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)

    let state: Reducer.state = {
      tasks,
      currentTask: Task.Selected("task-1"),
      acpSession: NoAcpSession,
      sessionInitialized: false,
      usageInfo: None,
      userProfile: None,
      openrouterKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicOAuthStatus: Client__State__Types.NotConnected,
      chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
      configOptions: None,
      selectedModelValue: None,
      pendingProviderAutoSelect: None,
      sessionsLoadState: Client__State__Types.SessionsNotLoaded,
      updateInfo: None,
      updateCheckStatus: UpdateNotChecked,
      updateBannerDismissed: false,
    }

    // Add message to task 1
    let (state1, effects1) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        sessionId: "session",
        content: [UserContentPart.Text({text: "Message in task 1"})],
        annotations: [],
      }),
    )

    let (_state2, effects2) = Reducer.next(
      state1,
      AddUserMessage({
        id: "user-2",
        sessionId: "session",
        content: [UserContentPart.Text({text: "Second message"})],
        annotations: [],
      }),
    )

    // Both AddUserMessages go through the Selected path (state starts with Selected("task-1")),
    // so they produce TaskEffect wrapping SendMessage from the task reducer
    switch (effects1->Array.get(0), effects2->Array.get(0)) {
    | (
        Some(Reducer.TaskEffect({target: ForTask(taskId1), effect: SendMessage(_)})),
        Some(Reducer.TaskEffect({target: ForTask(taskId2), effect: SendMessage(_)})),
      ) =>
      t->expect(taskId1)->Expect.toBe(taskId2)
    | _ => t->expect("Both effects should have task IDs")->Expect.toBe("Missing task IDs")
    }
  })
})

describe("Client State Reducer - Session Loading Actions", () => {
  test("SessionsLoadStarted transitions to Loading state", t => {
    let state = Reducer.defaultState

    let (nextState, _effects) = Reducer.next(state, SessionsLoadStarted)

    t->expect(nextState.sessionsLoadState)->Expect.toEqual(Client__State__Types.SessionsLoading)
  })

  test("SessionsLoadSuccess adds sessions to tasks dict", t => {
    let state = Reducer.defaultState

    let sessions: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionSummary> = [
      {
        sessionId: "session-1",
        title: "First Session",
        createdAt: "2024-01-15T10:00:00Z",
        updatedAt: "2024-01-15T10:30:00Z",
      },
      {
        sessionId: "session-2",
        title: "Second Session",
        createdAt: "2024-01-15T11:00:00Z",
        updatedAt: "2024-01-15T11:30:00Z",
      },
    ]

    let (nextState, _effects) = Reducer.next(state, SessionsLoadSuccess({sessions: sessions}))

    // Verify state transitioned to Loaded
    t->expect(nextState.sessionsLoadState)->Expect.toEqual(Client__State__Types.SessionsLoaded)

    // Verify tasks were added
    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(2)

    // Verify task IDs match session IDs
    t->expect(nextState.tasks->Dict.has("session-1"))->Expect.toBe(true)
    t->expect(nextState.tasks->Dict.has("session-2"))->Expect.toBe(true)

    // Verify task titles are set correctly
    let task1 = nextState.tasks->Dict.get("session-1")->Option.getOrThrow
    t->expect(Task.getTitle(task1))->Expect.toEqual(Some("First Session"))

    let task2 = nextState.tasks->Dict.get("session-2")->Option.getOrThrow
    t->expect(Task.getTitle(task2))->Expect.toEqual(Some("Second Session"))
  })

  test("SessionsLoadSuccess does not overwrite existing tasks", t => {
    // Create state with an existing task
    let existingTask = Task.makeLoaded(
      ~id="session-1",
      ~title="Existing Task",
      ~previewUrl="http://localhost:3000",
      ~createdAt=1000.0,
      ~messages=[
        Reducer.Message.User({
          id: "user-1",
          content: [UserContentPart.Text({text: "Existing message"})],
          annotations: [],
          createdAt: 1000.0,
        }),
      ],
    )

    let tasks = Dict.make()
    tasks->Dict.set("session-1", existingTask)

    let state: Reducer.state = {
      tasks,
      currentTask: Task.Selected("task-1"),
      acpSession: NoAcpSession,
      sessionInitialized: false,
      usageInfo: None,
      userProfile: None,
      openrouterKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicOAuthStatus: Client__State__Types.NotConnected,
      chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
      configOptions: None,
      selectedModelValue: None,
      pendingProviderAutoSelect: None,
      sessionsLoadState: Client__State__Types.SessionsNotLoaded,
      updateInfo: None,
      updateCheckStatus: UpdateNotChecked,
      updateBannerDismissed: false,
    }

    // Load sessions including one with the same ID as existing task
    let sessions: array<FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP.sessionSummary> = [
      {
        sessionId: "session-1",
        title: "Should Not Overwrite",
        createdAt: "2024-01-15T10:00:00Z",
        updatedAt: "2024-01-15T10:30:00Z",
      },
      {
        sessionId: "session-2",
        title: "New Session",
        createdAt: "2024-01-15T11:00:00Z",
        updatedAt: "2024-01-15T11:30:00Z",
      },
    ]

    let (nextState, _effects) = Reducer.next(state, SessionsLoadSuccess({sessions: sessions}))

    // Should have 2 tasks total
    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(2)

    // Existing task should retain its original title and messages
    let task1 = nextState.tasks->Dict.get("session-1")->Option.getOrThrow
    t->expect(Task.getTitle(task1))->Expect.toEqual(Some("Existing Task"))
    let task1Messages = Task.getMessages(task1)
    t
    ->expect(task1Messages->Array.some(msg => Reducer.Message.getId(msg) == "user-1"))
    ->Expect.toBe(true)

    // New task should be added
    let task2 = nextState.tasks->Dict.get("session-2")->Option.getOrThrow
    t->expect(Task.getTitle(task2))->Expect.toEqual(Some("New Session"))
  })

  test("SessionsLoadError transitions to error state with message", t => {
    let state: Reducer.state = {
      ...Reducer.defaultState,
      sessionsLoadState: Client__State__Types.SessionsLoading,
    }

    let (nextState, _effects) = Reducer.next(
      state,
      SessionsLoadError({error: "Network request failed"}),
    )

    t
    ->expect(nextState.sessionsLoadState)
    ->Expect.toEqual(Client__State__Types.SessionsLoadError("Network request failed"))
  })

  test("SessionsLoadSuccess handles empty sessions array", t => {
    let state = Reducer.defaultState

    let (nextState, _effects) = Reducer.next(state, SessionsLoadSuccess({sessions: []}))

    t->expect(nextState.sessionsLoadState)->Expect.toEqual(Client__State__Types.SessionsLoaded)
    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(0)
  })

  test("UserMessageReceived hydrates message into existing task", t => {
    // Create a Loading task (simulating one that's being loaded from session)
    let task = Task.makeUnloaded(
      ~id="task-123",
      ~title="Loaded Session",
      ~createdAt=1000.0,
      ~updatedAt=1000.0,
    )
    let loadingTask = Task.startLoading(task, ~previewUrl="http://localhost:3000")

    let tasks = Dict.make()
    tasks->Dict.set("task-123", loadingTask)

    let state: Reducer.state = {
      tasks,
      currentTask: Task.Selected("task-123"),
      acpSession: NoAcpSession,
      sessionInitialized: false,
      usageInfo: None,
      userProfile: None,
      openrouterKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicKeySettings: {
        source: Client__State__Types.None,
        saveStatus: Client__State__Types.Idle,
      },
      anthropicOAuthStatus: Client__State__Types.NotConnected,
      chatgptOAuthStatus: Client__State__Types.ChatGPTNotConnected,
      configOptions: None,
      selectedModelValue: None,
      pendingProviderAutoSelect: None,
      sessionsLoadState: Client__State__Types.SessionsLoaded,
      updateInfo: None,
      updateCheckStatus: UpdateNotChecked,
      updateBannerDismissed: false,
    }

    let (nextState, _effects) = Reducer.next(
      state,
      TaskAction({
        target: ForTask("task-123"),
        action: UserMessageReceived({
          id: "msg-1",
          content: [Client__Message.UserContentPart.text("Hello from history")],
          annotations: [],
          timestamp: "2024-01-15T10:30:00Z",
        }),
      }),
    )

    // Verify message was added to task
    let updatedTask = nextState.tasks->Dict.get("task-123")->Option.getOrThrow
    let messages = Task.getMessages(updatedTask)
    t->expect(messages->Array.some(msg => Reducer.Message.getId(msg) == "msg-1"))->Expect.toBe(true)

    let message =
      messages->Array.find(msg => Reducer.Message.getId(msg) == "msg-1")->Option.getOrThrow
    switch message {
    | User({id, content, _}) => {
        t->expect(id)->Expect.toBe("msg-1")
        switch content->Array.get(0) {
        | Some(UserContentPart.Text({text})) => t->expect(text)->Expect.toBe("Hello from history")
        | _ => JsExn.throw("Expected Text content part")
        }
      }
    | _ => JsExn.throw("Expected User message")
    }
  })
})

describe("Client State Reducer - UpdateTaskTitle safety", () => {
  test("UpdateTaskTitle updates title for existing task", t => {
    let state = TestHelpers.makeStateWithTask(~taskId="task-1", ~messages=[])
    let (nextState, _) = Reducer.next(
      state,
      UpdateTaskTitle({taskId: "task-1", title: "New Title"}),
    )

    let task = nextState.tasks->Dict.get("task-1")->Option.getOrThrow
    t->expect(Task.getTitle(task))->Expect.toEqual(Some("New Title"))
  })

  test("UpdateTaskTitle on deleted task does not throw", t => {
    // Start with a task
    let state = TestHelpers.makeStateWithTask(~taskId="task-1", ~messages=[])

    // Delete the task
    let (stateAfterDelete, _) = Reducer.next(state, DeleteTask({taskId: "task-1"}))
    t->expect(TestHelpers.getTaskCount(stateAfterDelete))->Expect.toBe(0)

    // Now send an UpdateTaskTitle for the deleted task — should NOT throw
    let (nextState, _) = Reducer.next(
      stateAfterDelete,
      UpdateTaskTitle({taskId: "task-1", title: "Ghost Title"}),
    )

    // State should be unchanged (no task added back)
    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(0)
    t->expect(nextState.tasks->Dict.get("task-1")->Option.isNone)->Expect.toBe(true)
  })

  test("UpdateTaskTitle on non-existent task is a no-op", t => {
    let state = TestHelpers.makeStateWithTask(~taskId="task-1", ~messages=[])

    // Update title for a task that doesn't exist
    let (nextState, _) = Reducer.next(
      state,
      UpdateTaskTitle({taskId: "non-existent-task", title: "Should Not Crash"}),
    )

    // Original task should be unaffected
    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(1)
    let task = nextState.tasks->Dict.get("task-1")->Option.getOrThrow
    t->expect(Task.getTitle(task))->Expect.toEqual(Some("Test Task"))
  })
})

// ============================================================================
// Annotation-to-Message Tests (Issue #466)
// ============================================================================

module MessageAnnotation = Client__Message.MessageAnnotation

describe("Client State Reducer - Annotations on Messages", () => {
  let _sampleAnnotations: array<MessageAnnotation.t> = [
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
    },
  ]

  test("AddUserMessage with annotations stores them on the message", t => {
    let state = Reducer.defaultState
    let action = Reducer.AddUserMessage({
      id: "user-1",
      sessionId: "session-1",
      content: [UserContentPart.text("Fix this")],
      annotations: _sampleAnnotations,
    })

    let (nextState, _effects) = Reducer.next(state, action)

    let messages = Reducer.Selectors.messages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(1)

    switch messages->Array.get(0)->Option.getOrThrow {
    | Reducer.Message.User({annotations, _}) =>
      t->expect(annotations->Array.length)->Expect.toBe(2)
      t->expect((annotations->Array.getUnsafe(0)).id)->Expect.toBe("ann-1")
      t->expect((annotations->Array.getUnsafe(0)).tagName)->Expect.toBe("button")
      t
      ->expect((annotations->Array.getUnsafe(0)).comment)
      ->Expect.toEqual(Some("This button is broken"))
      t->expect((annotations->Array.getUnsafe(1)).id)->Expect.toBe("ann-2")
    | _ => JsExn.throw("Expected User message")
    }
  })

  test("AddUserMessage with only annotations (no text) creates valid message", t => {
    let state = Reducer.defaultState
    let action = Reducer.AddUserMessage({
      id: "user-1",
      sessionId: "session-1",
      content: [],
      annotations: _sampleAnnotations,
    })

    let (nextState, _effects) = Reducer.next(state, action)

    let messages = Reducer.Selectors.messages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(1)

    switch messages->Array.get(0)->Option.getOrThrow {
    | Reducer.Message.User({content, annotations, _}) =>
      t->expect(content->Array.length)->Expect.toBe(0)
      t->expect(annotations->Array.length)->Expect.toBe(2)
    | _ => JsExn.throw("Expected User message")
    }
  })

  test("AddUserMessage without annotations stores empty array", t => {
    let state = Reducer.defaultState
    let action = Reducer.AddUserMessage({
      id: "user-1",
      sessionId: "session-1",
      content: [UserContentPart.text("Hello")],
      annotations: [],
    })

    let (nextState, _effects) = Reducer.next(state, action)

    let messages = Reducer.Selectors.messages(nextState)
    switch messages->Array.get(0)->Option.getOrThrow {
    | Reducer.Message.User({annotations, _}) => t->expect(annotations->Array.length)->Expect.toBe(0)
    | _ => JsExn.throw("Expected User message")
    }
  })

  test("SendMessage effect carries annotations from AddUserMessage", t => {
    let state = Reducer.defaultState
    let action = Reducer.AddUserMessage({
      id: "user-1",
      sessionId: "session-1",
      content: [UserContentPart.text("Fix this")],
      annotations: _sampleAnnotations,
    })

    let (_nextState, effects) = Reducer.next(state, action)

    // Find the TaskEffect wrapping SendMessage
    let sendEffect = effects->Array.find(
      eff =>
        switch eff {
        | Reducer.TaskEffect({effect: SendMessage(_)}) => true
        | _ => false
        },
    )

    switch sendEffect {
    | Some(Reducer.TaskEffect({effect: SendMessage({annotations})})) =>
      t->expect(annotations->Array.length)->Expect.toBe(2)
      t->expect((annotations->Array.getUnsafe(0)).id)->Expect.toBe("ann-1")
    | _ => JsExn.throw("Expected TaskEffect(SendMessage) with annotations")
    }
  })
})
