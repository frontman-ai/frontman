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
  let createStateWithLoadedTasks = (
    ~taskIds: array<string>,
    ~isAgentRunning,
  ): StateReducer.state => {
    let tasks = Dict.make()
    taskIds->Array.forEach(id => {
      let task =
        Task.makeNew(~previewUrl="http://localhost:3000")
        ->Task.newToLoaded(~id, ~title=`Task ${id}`)
        ->Task.updateLoadedData(data => {...data, isAgentRunning})
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

let textDeltaAction = (~taskId, ~messageId, ~text) => StateReducer.TaskAction({
  target: ForTask(taskId),
  action: TextDeltaReceived({
    messageId,
    text,
    agentId: "test-agent",
  }),
})

describe("Concurrent Tasks Event Routing", () => {
  test("Multiple concurrent tasks streaming simultaneously", t => {
    // Setup: Three tasks
    let taskAId = "task-a"
    let taskBId = "task-b"
    let taskCId = "task-c"
    let state = TestSetup.createStateWithLoadedTasks(
      ~taskIds=[taskAId, taskBId, taskCId],
      ~isAgentRunning=true,
    )

    // Act: Stream to all three tasks
    let (state1, _) = StateReducer.next(
      state,
      textDeltaAction(~taskId=taskAId, ~messageId="assistant-a", ~text="A"),
    )
    let (state2, _) = StateReducer.next(
      state1,
      textDeltaAction(~taskId=taskBId, ~messageId="assistant-b", ~text="B"),
    )
    let (finalState, _) = StateReducer.next(
      state2,
      textDeltaAction(~taskId=taskCId, ~messageId="assistant-c", ~text="C"),
    )

    // Assert: Each task has its own message with correct content
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow
    let taskC = finalState.tasks->Dict.get(taskCId)->Option.getOrThrow

    t->expect(Task.getMessages(taskA)->Array.length)->Expect.toBe(1)
    t->expect(Task.getMessages(taskB)->Array.length)->Expect.toBe(1)
    t->expect(Task.getMessages(taskC)->Array.length)->Expect.toBe(1)

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

  test("ExecutionStateIdle routes to correct task", t => {
    // Setup: Task A with streaming message, Task B is current
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(
      ~taskIds=[taskAId, taskBId],
      ~isAgentRunning=true,
    )

    // Switch to task B
    let (stateWithB, _) = StateReducer.next(state, SwitchTask({taskId: taskBId}))
    t->expect(StateReducer.Selectors.currentTaskId(stateWithB))->Expect.toEqual(Some(taskBId))

    let (stateWithText, _) = StateReducer.next(
      stateWithB,
      textDeltaAction(~taskId=taskAId, ~messageId="assistant-a", ~text="Complete message"),
    )

    // Act: Complete the message in Task A
    let (finalState, _) = StateReducer.next(
      stateWithText,
      TaskAction({target: ForTask(taskAId), action: ExecutionStateIdle}),
    )

    // Assert: Message in Task A should be completed
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    // Find the completed message (there should be exactly one)
    let completedMessages = Task.getMessages(taskA)->Array.filter(
      msg =>
        switch msg {
        | Assistant(Completed(_)) => true
        | _ => false
        },
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

    t->expect(Task.getMessages(taskB)->Array.length)->Expect.toBe(0)
  })

  test("Tool result events route to correct task", t => {
    // Setup: Task A with tool call, Task B is current
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(
      ~taskIds=[taskAId, taskBId],
      ~isAgentRunning=true,
    )

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
      parentAgentId: None,
      spawningToolName: None,
    }
    let (stateWithTool, _) = StateReducer.next(
      stateWithB,
      TaskAction({target: ForTask(taskAId), action: ToolCallReceived({toolCall: toolCall})}),
    )

    // Act: Send tool result to Task A
    let (finalState, _) = StateReducer.next(
      stateWithTool,
      TaskAction({
        target: ForTask(taskAId),
        action: ToolResultReceived({
          id: "tool-1",
          rawOutput: Some(JSON.Encode.object(Dict.make())),
          content: None,
          complete: true,
        }),
      }),
    )

    // Assert: Tool result should be in Task A
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow
    let toolMessage =
      Task.getMessages(taskA)
      ->Array.find(msg => StateReducer.Message.getId(msg) == "tool-1")
      ->Option.getOrThrow

    switch toolMessage {
    | ToolCall({toolName, state: OutputAvailable, result}) =>
      t->expect(toolName)->Expect.toBe("ReadFile")
      t->expect(result->Option.isSome)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
    t->expect(Task.getMessages(taskB)->Array.length)->Expect.toBe(0)
  })

  test("Switching current task mid-stream doesn't affect event routing", t => {
    // Setup: Start with Task A
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(
      ~taskIds=[taskAId, taskBId],
      ~isAgentRunning=true,
    )

    let (stateWithText1, _) = StateReducer.next(
      state,
      textDeltaAction(~taskId=taskAId, ~messageId="assistant-a", ~text="Part 1. "),
    )

    // Switch to Task B mid-stream
    let (stateWithB, _) = StateReducer.next(stateWithText1, SwitchTask({taskId: taskBId}))
    t->expect(StateReducer.Selectors.currentTaskId(stateWithB))->Expect.toEqual(Some(taskBId))

    // Continue receiving text for Task A
    let (finalState, _) = StateReducer.next(
      stateWithB,
      textDeltaAction(~taskId=taskAId, ~messageId="assistant-a", ~text="Part 2."),
    )

    // Assert: All text should be in Task A, Task B should be empty
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    switch Client__Task__Reducer.Selectors.streamingMessage(taskA) {
    | Some(StateReducer.Message.Streaming({textBuffer})) =>
      t->expect(textBuffer)->Expect.toBe("Part 1. Part 2.")
    | _ => t->expect(false)->Expect.toBe(true)
    }

    t->expect(Task.getMessages(taskB)->Array.length)->Expect.toBe(0)
  })
})
