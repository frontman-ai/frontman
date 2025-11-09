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
    let task = Reducer.createDefaultTask(~id=taskId, ~title="Test Task", ~timestamp, ~previewUrl)

    // Convert array of messages to Dict
    let messagesDict = Dict.make()
    messages->Array.forEach(msg => {
      let id = Reducer.Message.getId(msg)
      messagesDict->Dict.set(id, msg)
    })

    let taskWithMessages = {...task, messages: messagesDict}

    let tasks = Dict.make()
    tasks->Dict.set(taskId, taskWithMessages)

    {
      Reducer.tasks,
      currentTaskId: Some(taskId),
    }
  }

  let getMessages = Reducer.Selectors.messages
  let getMessage = (state, index) => getMessages(state)->Array.get(index)
  let getTaskCount = state => state.Reducer.tasks->Dict.valuesToArray->Array.length
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

    let action = Reducer.TextDeltaReceived({id: "assistant-1", text: " world"})
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

    let action = Reducer.MessageCompleted({id: "assistant-1"})
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

    // Start assistant streaming
    let (state, _) = Reducer.next(state, StreamingStarted({id: "assistant-1"}))

    // Add text delta
    let (state, _) = Reducer.next(state, TextDeltaReceived({id: "assistant-1", text: "Hello"}))

    // Complete message
    let (state, _) = Reducer.next(state, MessageCompleted({id: "assistant-1"}))

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

    let (nextState, _) = Reducer.next(state, MessageCompleted({id: "msg-2"}))

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Assistant(Completed({content, _})) => t->expect(content->Array.length)->Expect.toBe(0)
    | _ => JsExn.throw("Expected Assistant Completed message")
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

    let (nextState, _) = Reducer.next(state, MessageCompleted({id: "stable-id-123"}))

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | Assistant(Completed({id, _})) => t->expect(id)->Expect.toBe("stable-id-123")
    | _ => JsExn.throw("Expected Assistant Completed message")
    }
  })
})

describe("Client State Reducer - Tool Lifecycle", () => {
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
          state: Reducer.InputStreaming,
          createdAt: 0.0,
        }),
      ],
    )

    let action = Reducer.ToolInputDeltaReceived({
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
          state: Reducer.InputStreaming,
          createdAt: 0.0,
        }),
      ],
    )

    let action = Reducer.ToolInputEndReceived({id: "call-1"})
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | ToolCall({state, input, _}) => {
        t->expect(state)->Expect.toBe(Reducer.InputAvailable)
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
          state: Reducer.InputAvailable,
          createdAt: 0.0,
        }),
      ],
    )

    let result = JSON.parseOrThrow("{\"content\": \"file contents\"}")
    let action = Reducer.ToolResultReceived({id: "call-1", result})
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | ToolCall({state, result, _}) => {
        t->expect(state)->Expect.toBe(Reducer.OutputAvailable)
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
          state: Reducer.InputAvailable,
          createdAt: 0.0,
        }),
      ],
    )

    let action = Reducer.ToolErrorReceived({
      id: "call-1",
      error: "File not found",
    })
    let (nextState, _) = Reducer.next(state, action)

    let message = TestHelpers.getMessage(nextState, 0)->Option.getOrThrow

    switch message {
    | ToolCall({state, errorText, _}) => {
        t->expect(state)->Expect.toBe(Reducer.OutputError)
        t->expect(errorText)->Expect.toBe(Some("File not found"))
      }
    | _ => JsExn.throw("Expected ToolCall message")
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
    let task1 = Reducer.createDefaultTask(
      ~id="task-1",
      ~title="Task 1",
      ~timestamp=1000.0,
      ~previewUrl="http://localhost:3000",
    )
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

    let task2 = Reducer.createDefaultTask(
      ~id="task-2",
      ~title="Task 2",
      ~timestamp=2000.0,
      ~previewUrl="http://localhost:3000",
    )
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

    let state = {
      Reducer.tasks,
      currentTaskId: Some("task-1"),
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
    let task1 = Reducer.createDefaultTask(
      ~id="task-1",
      ~title="Task 1",
      ~timestamp=1000.0,
      ~previewUrl="http://localhost:3000",
    )
    let task1Modified = {...task1, webPreviewIsSelecting: true}

    let task2 = Reducer.createDefaultTask(
      ~id="task-2",
      ~title="Task 2",
      ~timestamp=2000.0,
      ~previewUrl="http://localhost:4000",
    )

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1Modified)
    tasks->Dict.set("task-2", task2)

    let state = {
      Reducer.tasks,
      currentTaskId: Some("task-1"),
    }

    t->expect(Reducer.Selectors.webPreviewIsSelecting(state))->Expect.toBe(true)
    t->expect(Reducer.Selectors.previewUrl(state))->Expect.toBe("http://localhost:3000")

    let (nextState, _) = Reducer.next(state, SwitchTask({taskId: "task-2"}))

    t->expect(Reducer.Selectors.webPreviewIsSelecting(nextState))->Expect.toBe(false)
    t->expect(Reducer.Selectors.previewUrl(nextState))->Expect.toBe("http://localhost:4000")
  })

  test("DeleteTask clears currentTaskId when deleting current task", t => {
    let task1 = Reducer.createDefaultTask(
      ~id="task-1",
      ~title="Task 1",
      ~timestamp=1000.0,
      ~previewUrl="http://localhost:3000",
    )

    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)

    let state = {
      Reducer.tasks,
      currentTaskId: Some("task-1"),
    }

    let (nextState, _) = Reducer.next(state, DeleteTask({taskId: "task-1"}))

    t->expect(TestHelpers.getTaskCount(nextState))->Expect.toBe(0)
    t->expect(nextState.currentTaskId)->Expect.toBe(None)
  })

  test("Tasks maintain independent state across switches", t => {
    let task1 = Reducer.createDefaultTask(
      ~id="task-1",
      ~title="Task 1",
      ~timestamp=1000.0,
      ~previewUrl="http://localhost:3000",
    )
    let tasks = Dict.make()
    tasks->Dict.set("task-1", task1)

    let state = {
      Reducer.tasks,
      currentTaskId: Some("task-1"),
    }

    // Add message to task 1
    let (state, _) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        content: [UserContentPart.Text({text: "Message in task 1"})],
      }),
    )

    // Enable selection in task 1
    let (state, _) = Reducer.next(state, ToggleWebPreviewSelection)

    // Create task 2 and switch to it
    let (state, _) = Reducer.next(
      state,
      CreateTask({id: "task-2", title: "Task 2", timestamp: 2000.0}),
    )

    // Task 2 should have no messages and selection disabled
    t->expect(Reducer.Selectors.messages(state)->Array.length)->Expect.toBe(0)
    t->expect(Reducer.Selectors.webPreviewIsSelecting(state))->Expect.toBe(false)

    // Switch back to task 1
    let (state, _) = Reducer.next(state, SwitchTask({taskId: "task-1"}))

    // Task 1 should still have its message and selection enabled
    t->expect(Reducer.Selectors.messages(state)->Array.length)->Expect.toBe(1)
    t->expect(Reducer.Selectors.webPreviewIsSelecting(state))->Expect.toBe(true)
  })
})
