open Vitest

module Reducer = Client__State__StateReducer
module UserContentPart = Reducer.UserContentPart
module AssistantContentPart = Reducer.AssistantContentPart

module TestHelpers = {
  let makeStateWithTask = (
    ~taskId="test-task-1",
    ~messages=[],
    ~timestamp=1000.0,
    ~previewUrl="http://localhost:3000",
  ) => {
    let task = Reducer.Task.make(~title="Test Task", ~previewUrl)

    // Override generated id and timestamp with test values for consistency
    let taskWithTestValues = {
      ...task,
      id: taskId,
      createdAt: timestamp,
    }

    // Convert array of messages to Dict
    let messagesDict = Dict.make()
    messages->Array.forEach(msg => {
      let id = Reducer.Message.getId(msg)
      messagesDict->Dict.set(id, msg)
    })

    let taskWithMessages = {...taskWithTestValues, messages: messagesDict}

    let tasks = Dict.make()
    tasks->Dict.set(taskId, taskWithMessages)

    (
      {
        tasks,
        currentTaskId: Some(taskId),
        connectionState: Disconnected,
      }: Client__State__Types.state
    )
  }

  let getMessages = Reducer.Selectors.messages
  let getMessage = (state, index) => getMessages(state)->Array.get(index)
  let getTaskCount = (state: Client__State__Types.state) =>
    state.tasks->Dict.valuesToArray->Array.length
}

describe("Client State Reducer", () => {
  test("AddUserMessage creates task and appends user message", t => {
    let state = Reducer.defaultState
    let action = Reducer.AddUserMessage({
      id: "user-1",
      content: [UserContentPart.text("Hello")],
    })

    let (nextState, _effects) = Reducer.next(state, action)

    // Should create a task
    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(1)
    t->expect(nextState.currentTaskId->Option.isSome)->Expect.toBe(true)

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
      ~messages=[
        Reducer.Message.Assistant(
          Streaming({id: "assistant-1", textBuffer: "Hello", createdAt: 0.0}),
        ),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let action = Reducer.TextDeltaReceived({taskId, id: "assistant-1", text: " world"})
    let (nextState, _effects) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Reducer.Message.Assistant(Streaming({textBuffer, _})) =>
      t->expect(textBuffer)->Expect.toBe("Hello world")
    | _ => JsExn.throw("Expected Assistant Streaming message with updated text")
    }
  })

  test("MessageCompleted transitions to Completed variant", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Assistant(Streaming({id: "assistant-1", textBuffer: "Hello world", createdAt: 0.0})),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let action = Reducer.MessageCompleted({taskId, id: "assistant-1"})
    let (nextState, _effects) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Assistant(Completed({content, _})) => {
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

    // Add user message (creates task)
    let (state, _) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        content: [UserContentPart.text("Hi")],
      }),
    )

    // Get taskId after task creation
    let taskId = state.currentTaskId->Option.getOrThrow

    // Start assistant streaming
    let (state, _) = Reducer.next(state, StreamingStarted({taskId, id: "assistant-1"}))

    // Add text delta
    let (state, _) = Reducer.next(
      state,
      TextDeltaReceived({taskId, id: "assistant-1", text: "Hello"}),
    )

    // Complete message
    let (state, _) = Reducer.next(state, MessageCompleted({taskId, id: "assistant-1"}))

    let messages = TestHelpers.getMessages(state)
    t->expect(messages->Array.length)->Expect.toBe(2)

    // Verify order: User first, then Assistant
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
        Assistant(
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
        Assistant(
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
      ~messages=[
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "Calling tool...",
            createdAt: 0.0,
          }),
        ),
        ToolCall({
          id: "call-123",
          toolName: "search",
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.Message.InputStreaming,
          createdAt: 0.0,
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
    }

    let taskId = state.currentTaskId->Option.getOrThrow
    let action = Reducer.ToolCallReceived({taskId, toolCall})
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

describe("Client State Reducer - MessageCompleted Content Conversion", () => {
  test("handles empty textBuffer correctly", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Assistant(
          Streaming({
            id: "msg-2",
            textBuffer: "",
            createdAt: 0.0,
          }),
        ),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let (nextState, _) = Reducer.next(state, MessageCompleted({taskId, id: "msg-2"}))

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Assistant(Completed({content, _})) => t->expect(content->Array.length)->Expect.toBe(0)
    | _ =>
      t
      ->expect("Expected Completed message with empty content")
      ->Expect.toBe("Got wrong message type")
    }
  })

  test("converts toolCalls to ToolCall content parts", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Assistant(
          Streaming({
            id: "msg-3",
            textBuffer: "Listing files",
            createdAt: 0.0,
          }),
        ),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let (nextState, _) = Reducer.next(state, MessageCompleted({taskId, id: "msg-3"}))

    let messages = TestHelpers.getMessages(nextState)
    switch messages->Array.get(0) {
    | Some(Assistant(Completed({content, _}))) => {
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
        Assistant(
          Streaming({
            id: "stable-id-123",
            textBuffer: "Test",
            createdAt: 0.0,
          }),
        ),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let (nextState, _) = Reducer.next(state, MessageCompleted({taskId, id: "stable-id-123"}))

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Assistant(Completed({id, _})) => t->expect(id)->Expect.toBe("stable-id-123")
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
        content: [UserContentPart.text("Hello")],
      }),
    )

    // Get taskId after task creation
    let taskId = state.currentTaskId->Option.getOrThrow

    // 1. Start streaming
    let (state, _) = Reducer.next(state, StreamingStarted({taskId, id: "text-abc"}))

    // 2. Receive text deltas
    let (state, _) = Reducer.next(state, TextDeltaReceived({taskId, id: "text-abc", text: "Hello"}))
    let (state, _) = Reducer.next(
      state,
      TextDeltaReceived({taskId, id: "text-abc", text: " world"}),
    )

    // 3. Complete message
    let (state, _) = Reducer.next(state, MessageCompleted({taskId, id: "text-abc"}))

    // Verify: Message ID stayed stable throughout (check second message, first is user)
    let messages = TestHelpers.getMessages(state)
    switch messages->Array.get(1) {
    | Some(Assistant(Completed({id, content, _}))) => {
        t->expect(id)->Expect.toBe("text-abc")
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
    })

    t->expect(Reducer.Selectors.getMessageId(userMsg))->Expect.toBe("user-1")
    t->expect(Reducer.Selectors.getMessageId(streamingMsg))->Expect.toBe("streaming-1")
    t->expect(Reducer.Selectors.getMessageId(completedMsg))->Expect.toBe("completed-1")
    t->expect(Reducer.Selectors.getMessageId(toolCallMsg))->Expect.toBe("tool-1")
  })
})

describe("Client State Reducer - Tool Lifecycle", () => {
  test("ToolInputStartReceived creates tool with InputStreaming state", t => {
    // Create a task with an assistant message first (tools belong to tasks)
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "",
            createdAt: 0.0,
          }),
        ),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let action = Reducer.ToolInputStartReceived({
      taskId,
      id: "call-1",
      toolName: "read_file",
    })
    let (nextState, _) = Reducer.next(state, action)

    let messages = TestHelpers.getMessages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(ToolCall({id, toolName, state, input, _})) => {
        t->expect(id)->Expect.toBe("call-1")
        t->expect(toolName)->Expect.toBe("read_file")
        t->expect(state)->Expect.toBe(Reducer.Message.InputStreaming)
        t->expect(input)->Expect.toBe(None)
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })

  test("ToolInputDeltaReceived accumulates input buffer", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Reducer.Message.ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "{\"path",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.Message.InputStreaming,
          createdAt: 0.0,
        }),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let action = Reducer.ToolInputDeltaReceived({
      taskId,
      id: "call-1",
      delta: "\": \"test.res\"}",
    })
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | ToolCall({inputBuffer, _}) => t->expect(inputBuffer)->Expect.toBe("{\"path\": \"test.res\"}")
    | _ => JsExn.throw("Expected ToolCall message")
    }
  })

  test("ToolInputEndReceived parses input and transitions to InputAvailable", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "{\"path\": \"test.res\"}",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.Message.InputStreaming,
          createdAt: 0.0,
        }),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let action = Reducer.ToolInputEndReceived({taskId, id: "call-1"})
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | ToolCall({state, input, _}) => {
        t->expect(state)->Expect.toBe(Reducer.Message.InputAvailable)
        t->expect(input->Option.isSome)->Expect.toBe(true)
      }
    | _ => JsExn.throw("Expected ToolCall message")
    }
  })

  test("ToolResultReceived sets result and OutputAvailable state", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
          result: None,
          errorText: None,
          state: Reducer.Message.InputAvailable,
          createdAt: 0.0,
        }),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let result = JSON.parseOrThrow("{\"content\": \"file contents\"}")
    let action = Reducer.ToolResultReceived({taskId, id: "call-1", result})
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | ToolCall({state, result, _}) => {
        t->expect(state)->Expect.toBe(Reducer.Message.OutputAvailable)
        t->expect(result->Option.isSome)->Expect.toBe(true)
      }
    | _ => JsExn.throw("Expected ToolCall message")
    }
  })

  test("ToolErrorReceived sets error and OutputError state", t => {
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: Some(JSON.parseOrThrow("{\"path\": \"test.res\"}")),
          result: None,
          errorText: None,
          state: Reducer.Message.InputAvailable,
          createdAt: 0.0,
        }),
      ],
    )

    let taskId = state.currentTaskId->Option.getOrThrow
    let action = Reducer.ToolErrorReceived({
      taskId,
      id: "call-1",
      error: "File not found",
    })
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | ToolCall({state, errorText, _}) => {
        t->expect(state)->Expect.toBe(Reducer.Message.OutputError)
        t->expect(errorText)->Expect.toBe(Some("File not found"))
      }
    | _ => t->expect("Got ToolCall message")->Expect.toBe("Expected ToolCall message")
    }
  })

  test("ToolCallReceived with complete input creates tool with InputAvailable", t => {
    // Create a task with an assistant message first (tools belong to tasks)
    let state = TestHelpers.makeStateWithTask(
      ~messages=[
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "",
            createdAt: 0.0,
          }),
        ),
        ToolCall({
          id: "call-1",
          toolName: "read_file",
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: Reducer.Message.InputStreaming,
          createdAt: 0.0,
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
    }
    let taskId = state.currentTaskId->Option.getOrThrow
    let action = Reducer.ToolCallReceived({taskId, toolCall})
    let (nextState, _) = Reducer.next(state, action)

    let messages = TestHelpers.getMessages(nextState)
    t->expect(messages->Array.length)->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(ToolCall({state, input, _})) => {
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
        content: [UserContentPart.text("First message")],
      }),
    )

    let taskId1 = state1.currentTaskId

    let (state2, _effects2) = Reducer.next(
      state1,
      AddUserMessage({
        id: "user-2",
        content: [UserContentPart.text("Second message")],
      }),
    )

    let taskId2 = state2.currentTaskId

    t->expect(taskId1->Option.isSome)->Expect.toBe(true)
    t->expect(taskId2->Option.isSome)->Expect.toBe(true)
    t->expect(taskId1)->Expect.toBe(taskId2)
  })

  test("effect contains same task ID as state", t => {
    let state = Reducer.defaultState

    let (state1, effects1) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        content: [UserContentPart.text("First message")],
      }),
    )

    let taskIdInState = state1.currentTaskId

    switch (effects1->Array.get(0), taskIdInState) {
    | (Some(Reducer.SendMessageToAPI({taskId: effectTaskId, _})), Some(stateTaskId)) =>
      t->expect(effectTaskId)->Expect.toBe(stateTaskId)
    | _ => t->expect("Effect and state should both have task ID")->Expect.toBe("Missing task IDs")
    }
  })
})

describe("Client State Reducer - Task Management Actions", () => {
  test("SwitchTask restores task messages", t => {
    let task1 = Reducer.Task.make(~title="Task 1", ~previewUrl="http://localhost:3000")
    let task1 = {...task1, id: "task-1", createdAt: 1000.0}
    let messagesDict1 = Dict.make()
    messagesDict1->Dict.set(
      "user-1",
      Reducer.Message.User({
        id: "user-1",
        content: [UserContentPart.Text({text: "Hello from task 1"})],
        createdAt: 1000.0,
      }),
    )
    let task1WithMessages = {
      ...task1,
      messages: messagesDict1,
    }

    let task2 = Reducer.Task.make(~title="Task 2", ~previewUrl="http://localhost:3000")
    let task2 = {...task2, id: "task-2", createdAt: 2000.0}
    let messagesDict2 = Dict.make()
    messagesDict2->Dict.set(
      "user-2",
      Reducer.Message.User({
        id: "user-2",
        content: [UserContentPart.Text({text: "Hello from task 2"})],
        createdAt: 2000.0,
      }),
    )
    let task2WithMessages = {
      ...task2,
      messages: messagesDict2,
    }

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1WithMessages)
    tasks->Dict.set("task-2", task2WithMessages)

    let state: Reducer.state = {
      tasks,
      currentTaskId: Some("task-1"),
      connectionState: Disconnected,
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

  test("SwitchTask restores webPreview state", t => {
    let task1 = Reducer.Task.make(~title="Task 1", ~previewUrl="http://localhost:3000")
    let task1 = {...task1, id: "task-1", createdAt: 1000.0}
    let task1Modified = {...task1, webPreviewIsSelecting: true}

    let task2 = Reducer.Task.make(~title="Task 2", ~previewUrl="http://localhost:4000")
    let task2 = {...task2, id: "task-2", createdAt: 2000.0}

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1Modified)
    tasks->Dict.set("task-2", task2)

    let state: Reducer.state = {
      tasks,
      currentTaskId: Some("task-1"),
      connectionState: Disconnected,
    }

    t->expect(Reducer.Selectors.webPreviewIsSelecting(state))->Expect.toBe(true)
    t->expect(Reducer.Selectors.previewUrl(state))->Expect.toBe("http://localhost:3000")

    let (nextState, _) = Reducer.next(state, SwitchTask({taskId: "task-2"}))

    t->expect(Reducer.Selectors.webPreviewIsSelecting(nextState))->Expect.toBe(false)
    t->expect(Reducer.Selectors.previewUrl(nextState))->Expect.toBe("http://localhost:4000")
  })

  test("DeleteTask clears currentTaskId when deleting current task", t => {
    let task1 = Reducer.Task.make(~title="Task 1", ~previewUrl="http://localhost:3000")
    let task1 = {...task1, id: "task-1", createdAt: 1000.0}

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)

    let state: Reducer.state = {
      tasks,
      currentTaskId: Some("task-1"),
      connectionState: Disconnected,
    }

    let (nextState, _) = Reducer.next(state, DeleteTask({taskId: "task-1"}))

    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(0)
    t->expect(nextState.currentTaskId)->Expect.toBe(None)
  })

  test("Tasks maintain independent state across switches", t => {
    let task1 = Reducer.Task.make(~title="Task 1", ~previewUrl="http://localhost:3000")
    let task1 = {...task1, id: "task-1", createdAt: 1000.0}
    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)

    let state: Reducer.state = {
      tasks,
      currentTaskId: Some("task-1"),
      connectionState: Disconnected,
    }

    // Add message to task 1
    let (state1, effects1) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        content: [UserContentPart.Text({text: "Message in task 1"})],
      }),
    )

    let (_state2, effects2) = Reducer.next(
      state1,
      AddUserMessage({
        id: "user-2",
        content: [UserContentPart.Text({text: "Second message"})],
      }),
    )

    switch (effects1->Array.get(0), effects2->Array.get(0)) {
    | (
        Some(Reducer.SendMessageToAPI({taskId: taskId1, _})),
        Some(Reducer.SendMessageToAPI({taskId: taskId2, _})),
      ) =>
      t->expect(taskId1)->Expect.toBe(taskId2)
    | _ => t->expect("Both effects should have task IDs")->Expect.toBe("Missing task IDs")
    }
  })
})
