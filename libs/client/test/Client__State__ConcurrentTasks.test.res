open Vitest

/**
 * Tests for concurrent task event routing
 *
 * These tests verify that SSE events are routed to the correct task
 * based on the taskId in the event, not the currently selected task.
 */
module StateReducer = Client__State__StateReducer
module Task = Client__State__Types.Task

// Helper to create a state with multiple loaded tasks
module TestSetup = {
  let createStateWithLoadedTasks = (~taskIds: array<string>, ~isAgentRunning=false): StateReducer.state => {
    let tasks = Dict.make()
    taskIds->Array.forEach(id => {
      let task = Task.makeLoaded(
        ~id,
        ~title=`Task ${id}`,
        ~previewUrl="http://localhost:3000",
        ~createdAt=Date.now(),
        ~isAgentRunning,
      )
      tasks->Dict.set(id, task)
    })

    let currentTask = switch taskIds->Array.get(0) {
    | Some(id) => Task.Selected(id)
    | None => Task.New(Task.makeNew(~previewUrl="http://localhost:3000"))
    }

    {
      ...StateReducer.defaultState,
      tasks,
      currentTask,
    }
  }
}

// Helper to get messages from a task's loadedData
let getTaskMessages = (task: Task.t) => {
  Task.getLoadedData(task)->Option.mapOr([], data => data.messages)
}

// Helper to get current task ID
let getCurrentTaskId = (state: StateReducer.state): option<string> => {
  switch state.currentTask {
  | Task.New(_) => None
  | Task.Selected(id) => Some(id)
  }
}

describe("Concurrent Tasks Event Routing", () => {
  test("StreamingStarted event routes to correct task, not current task", t => {
    // Setup: Create state with two loaded tasks (isAgentRunning=true to accept streaming events)
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(~taskIds=[taskAId, taskBId], ~isAgentRunning=true)

    // Switch current task to B
    let (stateWithB, _) = StateReducer.next(state, SwitchTask({taskId: taskBId}))
    t->expect(getCurrentTaskId(stateWithB))->Expect.toEqual(Some(taskBId))

    // Act: Receive StreamingStarted event for Task A (not current task)
    let (finalState, _) = StateReducer.next(
      stateWithB,
      TaskAction({target: ForTask(taskAId), action: StreamingStarted}),
    )

    // Assert: Message should be in Task A, not Task B
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    t->expect(getTaskMessages(taskA)->Array.length)->Expect.toBe(1)
    t->expect(getTaskMessages(taskB)->Array.length)->Expect.toBe(0)
  })

  test("TextDeltaReceived event routes to correct task", t => {
    // Setup: Two tasks, A has a streaming message
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(~taskIds=[taskAId, taskBId], ~isAgentRunning=true)

    // Switch to task B
    let (stateWithB, _) = StateReducer.next(state, SwitchTask({taskId: taskBId}))

    // Add streaming message to Task A
    let (stateWithMessage, _) = StateReducer.next(
      stateWithB,
      TaskAction({target: ForTask(taskAId), action: StreamingStarted}),
    )

    // Current task is still B
    t->expect(getCurrentTaskId(stateWithMessage))->Expect.toEqual(Some(taskBId))

    // Act: Receive text delta for Task A
    let (finalState, _) = StateReducer.next(
      stateWithMessage,
      TaskAction({target: ForTask(taskAId), action: TextDeltaReceived({text: "Hello from Task A"})}),
    )

    // Assert: Text should be in Task A's message, not Task B
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    switch Client__Task__Reducer.Selectors.streamingMessage(taskA) {
    | Some(StateReducer.Message.Streaming({textBuffer})) =>
      t->expect(textBuffer)->Expect.toBe("Hello from Task A")
    | _ => t->expect(false)->Expect.toBe(true)
    }

    t->expect(getTaskMessages(taskB)->Array.length)->Expect.toBe(0)
  })

  test("ToolCallReceived event routes to correct task", t => {
    // Setup: Two tasks
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(~taskIds=[taskAId, taskBId], ~isAgentRunning=true)

    // Switch to task B
    let (stateWithB, _) = StateReducer.next(state, SwitchTask({taskId: taskBId}))

    // Act: Receive tool call for Task A while Task B is current
    let toolCall: StateReducer.Message.toolCall = {
      id: "tool-1",
      toolName: "ReadFile",
      state: StateReducer.Message.InputAvailable,
      inputBuffer: "",
      input: Some(JSON.parseOrThrow(`{"path": "file.txt"}`)),
      result: None,
      errorText: None,
      createdAt: Date.now(),
      parentAgentId: None,
      spawningToolName: None,
    }
    let (finalState, _) = StateReducer.next(
      stateWithB,
      TaskAction({
        target: ForTask(taskAId),
        action: ToolCallReceived({toolCall: toolCall}),
      }),
    )

    // Assert: Tool call should be in Task A
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    t->expect(getTaskMessages(taskA)->Array.length)->Expect.toBe(1)
    t->expect(getTaskMessages(taskB)->Array.length)->Expect.toBe(0)

    let toolMessage =
      getTaskMessages(taskA)
      ->Array.find(msg => StateReducer.Message.getId(msg) == "tool-1")
      ->Option.getOrThrow
    switch toolMessage {
    | ToolCall({toolName}) => t->expect(toolName)->Expect.toBe("ReadFile")
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("Multiple concurrent tasks streaming simultaneously", t => {
    // Setup: Three tasks
    let taskAId = "task-a"
    let taskBId = "task-b"
    let taskCId = "task-c"
    let state = TestSetup.createStateWithLoadedTasks(~taskIds=[taskAId, taskBId, taskCId], ~isAgentRunning=true)

    // Act: Start streaming in all three tasks
    let (state1, _) = StateReducer.next(state, TaskAction({target: ForTask(taskAId), action: StreamingStarted}))
    let (state2, _) = StateReducer.next(state1, TaskAction({target: ForTask(taskBId), action: StreamingStarted}))
    let (state3, _) = StateReducer.next(state2, TaskAction({target: ForTask(taskCId), action: StreamingStarted}))

    // Send text deltas to each task
    let (state4, _) = StateReducer.next(state3, TaskAction({target: ForTask(taskAId), action: TextDeltaReceived({text: "A"})}))
    let (state5, _) = StateReducer.next(state4, TaskAction({target: ForTask(taskBId), action: TextDeltaReceived({text: "B"})}))
    let (finalState, _) = StateReducer.next(state5, TaskAction({target: ForTask(taskCId), action: TextDeltaReceived({text: "C"})}))

    // Assert: Each task has its own message with correct content
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow
    let taskC = finalState.tasks->Dict.get(taskCId)->Option.getOrThrow

    t->expect(getTaskMessages(taskA)->Array.length)->Expect.toBe(1)
    t->expect(getTaskMessages(taskB)->Array.length)->Expect.toBe(1)
    t->expect(getTaskMessages(taskC)->Array.length)->Expect.toBe(1)

    let getStreamingText = (task: StateReducer.Task.t) => {
      switch Client__Task__Reducer.Selectors.streamingMessage(task) {
      | Some(StateReducer.Message.Streaming({textBuffer})) => textBuffer
      | _ => ""
      }
    }

    t->expect(getStreamingText(taskA))->Expect.toBe("A")
    t->expect(getStreamingText(taskB))->Expect.toBe("B")
    t->expect(getStreamingText(taskC))->Expect.toBe("C")
  })

  test("TurnCompleted event routes to correct task", t => {
    // Setup: Task A with streaming message, Task B is current
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(~taskIds=[taskAId, taskBId], ~isAgentRunning=true)

    // Switch to task B
    let (stateWithB, _) = StateReducer.next(state, SwitchTask({taskId: taskBId}))

    // Start streaming in Task A
    let (stateWithStream, _) = StateReducer.next(
      stateWithB,
      TaskAction({target: ForTask(taskAId), action: StreamingStarted}),
    )
    let (stateWithText, _) = StateReducer.next(
      stateWithStream,
      TaskAction({target: ForTask(taskAId), action: TextDeltaReceived({text: "Complete message"})}),
    )

    // Act: Complete the message in Task A
    let (finalState, _) = StateReducer.next(stateWithText, TaskAction({target: ForTask(taskAId), action: TurnCompleted}))

    // Assert: Message in Task A should be completed
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    // Find the completed message (there should be exactly one)
    let completedMessages =
      getTaskMessages(taskA)->Array.filter(msg =>
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

    t->expect(getTaskMessages(taskB)->Array.length)->Expect.toBe(0)
  })

  test("Tool result events route to correct task", t => {
    // Setup: Task A with tool call, Task B is current
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(~taskIds=[taskAId, taskBId], ~isAgentRunning=true)

    // Switch to task B
    let (stateWithB, _) = StateReducer.next(state, SwitchTask({taskId: taskBId}))

    // Create tool call in Task A via ToolCallReceived
    let toolCall: StateReducer.Message.toolCall = {
      id: "tool-1",
      toolName: "ReadFile",
      state: StateReducer.Message.InputAvailable,
      inputBuffer: "",
      input: Some(JSON.parseOrThrow(`{"path": "file.txt"}`)),
      result: None,
      errorText: None,
      createdAt: Date.now(),
      parentAgentId: None,
      spawningToolName: None,
    }
    let (stateWithTool, _) = StateReducer.next(
      stateWithB,
      TaskAction({target: ForTask(taskAId), action: ToolCallReceived({toolCall: toolCall})}),
    )

    // Act: Send tool result to Task A
    let resultJson = JSON.parseOrThrow(`{"content": "file contents"}`)
    let (finalState, _) = StateReducer.next(
      stateWithTool,
      TaskAction({target: ForTask(taskAId), action: ToolResultReceived({id: "tool-1", result: resultJson})}),
    )

    // Assert: Tool result should be in Task A
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let toolMessage =
      getTaskMessages(taskA)
      ->Array.find(msg => StateReducer.Message.getId(msg) == "tool-1")
      ->Option.getOrThrow

    switch toolMessage {
    | ToolCall({state: OutputAvailable, result}) =>
      t->expect(result->Option.isSome)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("Switching current task mid-stream doesn't affect event routing", t => {
    // Setup: Start with Task A
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(~taskIds=[taskAId, taskBId], ~isAgentRunning=true)

    // Start streaming in Task A
    let (stateWithStream, _) = StateReducer.next(state, TaskAction({target: ForTask(taskAId), action: StreamingStarted}))
    let (stateWithText1, _) = StateReducer.next(
      stateWithStream,
      TaskAction({target: ForTask(taskAId), action: TextDeltaReceived({text: "Part 1. "})}),
    )

    // Switch to Task B mid-stream
    let (stateWithB, _) = StateReducer.next(stateWithText1, SwitchTask({taskId: taskBId}))
    t->expect(getCurrentTaskId(stateWithB))->Expect.toEqual(Some(taskBId))

    // Continue receiving text for Task A
    let (finalState, _) = StateReducer.next(
      stateWithB,
      TaskAction({target: ForTask(taskAId), action: TextDeltaReceived({text: "Part 2."})}),
    )

    // Assert: All text should be in Task A, Task B should be empty
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    switch Client__Task__Reducer.Selectors.streamingMessage(taskA) {
    | Some(StateReducer.Message.Streaming({textBuffer})) =>
      t->expect(textBuffer)->Expect.toBe("Part 1. Part 2.")
    | _ => t->expect(false)->Expect.toBe(true)
    }

    t->expect(getTaskMessages(taskB)->Array.length)->Expect.toBe(0)
  })
})
