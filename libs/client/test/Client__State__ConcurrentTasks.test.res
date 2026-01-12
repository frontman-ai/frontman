open Vitest

/**
 * Tests for concurrent task event routing
 *
 * These tests verify that SSE events are routed to the correct task
 * based on the taskId in the event, not the currently selected task.
 */
module StateReducer = Client__State__StateReducer

describe("Concurrent Tasks Event Routing", () => {
  test("StreamingStarted event routes to correct task, not current task", t => {
    // Setup: Create two tasks
    let state = StateReducer.defaultState
    let (stateWithTaskA, _) = StateReducer.next(state, CreateTask({title: "Task A"}))
    let taskAId = stateWithTaskA.currentTaskId->Option.getOrThrow

    let (stateWithBothTasks, _) = StateReducer.next(stateWithTaskA, CreateTask({title: "Task B"}))
    let taskBId = stateWithBothTasks.currentTaskId->Option.getOrThrow

    // Current task is B
    t->expect(stateWithBothTasks.currentTaskId)->Expect.toBe(Some(taskBId))

    // Act: Receive StreamingStarted event for Task A (not current task)
    let (finalState, _) = StateReducer.next(
      stateWithBothTasks,
      StreamingStarted({taskId: taskAId}),
    )

    // Assert: Message should be in Task A, not Task B
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    t->expect(taskA.messages->Dict.size)->Expect.toBe(1)
    t->expect(taskB.messages->Dict.size)->Expect.toBe(0)
  })

  test("TextDeltaReceived event routes to correct task", t => {
    // Setup: Two tasks, A has a streaming message
    let state = StateReducer.defaultState
    let (stateWithTaskA, _) = StateReducer.next(state, CreateTask({title: "Task A"}))
    let taskAId = stateWithTaskA.currentTaskId->Option.getOrThrow

    let (stateWithBothTasks, _) = StateReducer.next(stateWithTaskA, CreateTask({title: "Task B"}))
    let taskBId = stateWithBothTasks.currentTaskId->Option.getOrThrow

    // Add streaming message to Task A
    let (stateWithMessage, _) = StateReducer.next(
      stateWithBothTasks,
      StreamingStarted({taskId: taskAId}),
    )

    // Current task is still B
    t->expect(stateWithMessage.currentTaskId)->Expect.toBe(Some(taskBId))

    // Act: Receive text delta for Task A
    let (finalState, _) = StateReducer.next(
      stateWithMessage,
      TextDeltaReceived({taskId: taskAId, text: "Hello from Task A"}),
    )

    // Assert: Text should be in Task A's message, not Task B
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    switch StateReducer.Lens.getStreamingMessage(taskA) {
    | Some(StateReducer.Message.Streaming({textBuffer})) =>
      t->expect(textBuffer)->Expect.toBe("Hello from Task A")
    | _ => t->expect(false)->Expect.toBe(true)
    }

    t->expect(taskB.messages->Dict.size)->Expect.toBe(0)
  })

  test("ToolInputStartReceived event routes to correct task", t => {
    // Setup: Two tasks
    let state = StateReducer.defaultState
    let (stateWithTaskA, _) = StateReducer.next(state, CreateTask({title: "Task A"}))
    let taskAId = stateWithTaskA.currentTaskId->Option.getOrThrow

    let (stateWithBothTasks, _) = StateReducer.next(stateWithTaskA, CreateTask({title: "Task B"}))
    let taskBId = stateWithBothTasks.currentTaskId->Option.getOrThrow

    // Act: Receive tool call for Task A while Task B is current
    let (finalState, _) = StateReducer.next(
      stateWithBothTasks,
      ToolInputStartReceived({taskId: taskAId, id: "tool-1", toolName: "ReadFile", parentAgentId: None, spawningToolName: None}),
    )

    // Assert: Tool call should be in Task A
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    t->expect(taskA.messages->Dict.size)->Expect.toBe(1)
    t->expect(taskB.messages->Dict.size)->Expect.toBe(0)

    let toolMessage = taskA.messages->Dict.get("tool-1")->Option.getOrThrow
    switch toolMessage {
    | ToolCall({toolName}) => t->expect(toolName)->Expect.toBe("ReadFile")
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("Multiple concurrent tasks streaming simultaneously", t => {
    // Setup: Three tasks
    let state = StateReducer.defaultState
    let (stateWithTaskA, _) = StateReducer.next(state, CreateTask({title: "Task A"}))
    let taskAId = stateWithTaskA.currentTaskId->Option.getOrThrow

    let (stateWithTaskB, _) = StateReducer.next(stateWithTaskA, CreateTask({title: "Task B"}))
    let taskBId = stateWithTaskB.currentTaskId->Option.getOrThrow

    let (stateWithAllTasks, _) = StateReducer.next(stateWithTaskB, CreateTask({title: "Task C"}))
    let taskCId = stateWithAllTasks.currentTaskId->Option.getOrThrow

    // Act: Start streaming in all three tasks
    let (state1, _) = StateReducer.next(stateWithAllTasks, StreamingStarted({taskId: taskAId}))
    let (state2, _) = StateReducer.next(state1, StreamingStarted({taskId: taskBId}))
    let (state3, _) = StateReducer.next(state2, StreamingStarted({taskId: taskCId}))

    // Send text deltas to each task
    let (state4, _) = StateReducer.next(state3, TextDeltaReceived({taskId: taskAId, text: "A"}))
    let (state5, _) = StateReducer.next(state4, TextDeltaReceived({taskId: taskBId, text: "B"}))
    let (finalState, _) = StateReducer.next(state5, TextDeltaReceived({taskId: taskCId, text: "C"}))

    // Assert: Each task has its own message with correct content
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow
    let taskC = finalState.tasks->Dict.get(taskCId)->Option.getOrThrow

    t->expect(taskA.messages->Dict.size)->Expect.toBe(1)
    t->expect(taskB.messages->Dict.size)->Expect.toBe(1)
    t->expect(taskC.messages->Dict.size)->Expect.toBe(1)

    let getStreamingText = (task: StateReducer.Task.t) => {
      switch StateReducer.Lens.getStreamingMessage(task) {
      | Some(StateReducer.Message.Streaming({textBuffer})) => textBuffer
      | _ => ""
      }
    }

    t->expect(getStreamingText(taskA))->Expect.toBe("A")
    t->expect(getStreamingText(taskB))->Expect.toBe("B")
    t->expect(getStreamingText(taskC))->Expect.toBe("C")
  })

  test("MessageCompleted event routes to correct task", t => {
    // Setup: Task A with streaming message, Task B is current
    let state = StateReducer.defaultState
    let (stateWithTaskA, _) = StateReducer.next(state, CreateTask({title: "Task A"}))
    let taskAId = stateWithTaskA.currentTaskId->Option.getOrThrow

    let (stateWithBothTasks, _) = StateReducer.next(stateWithTaskA, CreateTask({title: "Task B"}))
    let taskBId = stateWithBothTasks.currentTaskId->Option.getOrThrow

    // Start streaming in Task A
    let (stateWithStream, _) = StateReducer.next(
      stateWithBothTasks,
      StreamingStarted({taskId: taskAId}),
    )
    let (stateWithText, _) = StateReducer.next(
      stateWithStream,
      TextDeltaReceived({taskId: taskAId, text: "Complete message"}),
    )

    // Act: Complete the message in Task A
    let (finalState, _) = StateReducer.next(stateWithText, MessageCompleted({taskId: taskAId}))

    // Assert: Message in Task A should be completed
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    // Find the completed message (there should be exactly one)
    let completedMessages =
      taskA.messages
      ->Dict.valuesToArray
      ->Array.filter(msg =>
        switch msg {
        | Assistant(Completed(_)) => true
        | _ => false
        }
      )

    t->expect(Array.length(completedMessages))->Expect.toBe(1)
    switch completedMessages[0] {
    | Some(Assistant(Completed({content}))) => {
        t->expect(Array.length(content))->Expect.toBe(1)
        switch content[0] {
        | Some(Text({text})) => t->expect(text)->Expect.toBe("Complete message")
        | _ => t->expect(false)->Expect.toBe(true)
        }
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }

    t->expect(taskB.messages->Dict.size)->Expect.toBe(0)
  })

  test("Tool result events route to correct task", t => {
    // Setup: Task A with tool call, Task B is current
    let state = StateReducer.defaultState
    let (stateWithTaskA, _) = StateReducer.next(state, CreateTask({title: "Task A"}))
    let taskAId = stateWithTaskA.currentTaskId->Option.getOrThrow

    let (stateWithBothTasks, _) = StateReducer.next(stateWithTaskA, CreateTask({title: "Task B"}))
    let _taskBId = stateWithBothTasks.currentTaskId->Option.getOrThrow

    // Create tool call in Task A
    let (stateWithTool, _) = StateReducer.next(
      stateWithBothTasks,
      ToolInputStartReceived({taskId: taskAId, id: "tool-1", toolName: "ReadFile", parentAgentId: None, spawningToolName: None}),
    )
    let (stateWithInput, _) = StateReducer.next(
      stateWithTool,
      ToolInputDeltaReceived({taskId: taskAId, id: "tool-1", delta: `{"path": "file.txt"}`}),
    )
    let (stateWithInputEnd, _) = StateReducer.next(
      stateWithInput,
      ToolInputEndReceived({taskId: taskAId, id: "tool-1"}),
    )

    // Act: Send tool result to Task A
    let resultJson = JSON.parseOrThrow(`{"content": "file contents"}`)
    let (finalState, _) = StateReducer.next(
      stateWithInputEnd,
      ToolResultReceived({taskId: taskAId, id: "tool-1", result: resultJson}),
    )

    // Assert: Tool result should be in Task A
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let toolMessage = taskA.messages->Dict.get("tool-1")->Option.getOrThrow

    switch toolMessage {
    | ToolCall({state: OutputAvailable, result}) =>
      t->expect(result->Option.isSome)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("Switching current task mid-stream doesn't affect event routing", t => {
    // Setup: Start with Task A
    let state = StateReducer.defaultState
    let (stateWithTaskA, _) = StateReducer.next(state, CreateTask({title: "Task A"}))
    let taskAId = stateWithTaskA.currentTaskId->Option.getOrThrow

    // Start streaming in Task A
    let (stateWithStream, _) = StateReducer.next(stateWithTaskA, StreamingStarted({taskId: taskAId}))
    let (stateWithText1, _) = StateReducer.next(
      stateWithStream,
      TextDeltaReceived({taskId: taskAId, text: "Part 1. "}),
    )

    // Switch to Task B mid-stream
    let (stateWithTaskB, _) = StateReducer.next(stateWithText1, CreateTask({title: "Task B"}))
    let taskBId = stateWithTaskB.currentTaskId->Option.getOrThrow

    // Continue receiving text for Task A
    let (finalState, _) = StateReducer.next(
      stateWithTaskB,
      TextDeltaReceived({taskId: taskAId, text: "Part 2."}),
    )

    // Assert: All text should be in Task A, Task B should be empty
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    switch StateReducer.Lens.getStreamingMessage(taskA) {
    | Some(StateReducer.Message.Streaming({textBuffer})) =>
      t->expect(textBuffer)->Expect.toBe("Part 1. Part 2.")
    | _ => t->expect(false)->Expect.toBe(true)
    }

    t->expect(taskB.messages->Dict.size)->Expect.toBe(0)
  })
})
