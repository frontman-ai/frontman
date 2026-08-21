open Vitest

/**
 * Tests for concurrent task event routing
 *
 * These tests verify that SSE events are routed to the correct task
 * based on the taskId in the event, not the currently selected task.
 */
module StateReducer = Client__State__StateReducer
module Task = Client__State__Types.Task

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
    let taskAId = "task-a"
    let taskBId = "task-b"
    let taskCId = "task-c"
    let state = TestSetup.createStateWithLoadedTasks(
      ~taskIds=[taskAId, taskBId, taskCId],
      ~isAgentRunning=true,
    )

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
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(
      ~taskIds=[taskAId, taskBId],
      ~isAgentRunning=true,
    )

    let (stateWithB, _) = StateReducer.next(state, SwitchTask({taskId: taskBId}))
    t->expect(StateReducer.Selectors.currentTaskId(stateWithB))->Expect.toEqual(Some(taskBId))

    let (stateWithText, _) = StateReducer.next(
      stateWithB,
      textDeltaAction(~taskId=taskAId, ~messageId="assistant-a", ~text="Complete message"),
    )

    let (finalState, _) = StateReducer.next(
      stateWithText,
      TaskAction({target: ForTask(taskAId), action: ExecutionStateIdle}),
    )

    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

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
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(
      ~taskIds=[taskAId, taskBId],
      ~isAgentRunning=true,
    )

    let (stateWithB, _) = StateReducer.next(state, SwitchTask({taskId: taskBId}))

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

    let (stateWithB, _) = StateReducer.next(stateWithText1, SwitchTask({taskId: taskBId}))
    t->expect(StateReducer.Selectors.currentTaskId(stateWithB))->Expect.toEqual(Some(taskBId))

    let (finalState, _) = StateReducer.next(
      stateWithB,
      textDeltaAction(~taskId=taskAId, ~messageId="assistant-a", ~text="Part 2."),
    )

    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    switch Client__Task__Reducer.Selectors.streamingMessage(taskA) {
    | Some(StateReducer.Message.Streaming({textBuffer})) =>
      t->expect(textBuffer)->Expect.toBe("Part 1. Part 2.")
    | _ => t->expect(false)->Expect.toBe(true)
    }

    t->expect(Task.getMessages(taskB)->Array.length)->Expect.toBe(0)
  })

  test("Preview events remain attached to their client after switching tasks", t => {
    let taskAId = "task-a"
    let taskBId = "task-b"
    let state = TestSetup.createStateWithLoadedTasks(
      ~taskIds=[taskAId, taskBId],
      ~isAgentRunning=false,
    )
    let taskAClientId = state.tasks->Dict.get(taskAId)->Option.getOrThrow->Task.getClientId
    let (stateWithB, _) = StateReducer.next(state, SwitchTask({taskId: taskBId}))
    t
    ->expect(StateReducer.targetIsCurrent(stateWithB, ForClient(taskAClientId)))
    ->Expect.toBe(false)

    let (finalState, effects) = StateReducer.next(
      stateWithB,
      TaskAction({
        target: ForClient(taskAClientId),
        action: SetPreviewUrl({url: "http://localhost:3000/task-a-preview"}),
      }),
    )
    let taskA = finalState.tasks->Dict.get(taskAId)->Option.getOrThrow
    let taskB = finalState.tasks->Dict.get(taskBId)->Option.getOrThrow

    t
    ->expect(Task.getPreviewFrame(taskA, ~defaultUrl="").url)
    ->Expect.toBe("http://localhost:3000/task-a-preview")
    t
    ->expect(Task.getPreviewFrame(taskB, ~defaultUrl="").url)
    ->Expect.toBe("http://localhost:3000")
    switch effects->Array.get(0) {
    | Some(StateReducer.TaskEffect({
        target: ForTask(effectTaskId),
        effect: SyncBrowserUrl(url),
      })) => {
        t->expect(effectTaskId)->Expect.toBe(taskAId)
        t->expect(url)->Expect.toBe("http://localhost:3000/task-a-preview")
      }
    | _ => JsExn.throw("Expected task-targeted browser URL sync effect")
    }
  })

  test("New task preview effects retain client identity after promotion", t => {
    let newTask = Task.makeNew(~previewUrl="http://localhost:3000")
    let clientId = Task.getClientId(newTask)
    let state = {...StateReducer.defaultState, currentTask: Task.New(newTask)}
    let (updatedState, effects) = StateReducer.next(
      state,
      TaskAction({
        target: ForClient(clientId),
        action: SetPreviewUrl({url: "http://localhost:3000/new-preview"}),
      }),
    )
    let updatedTask = switch updatedState.currentTask {
    | Task.New(task) => task
    | _ => JsExn.throw("Expected a new task")
    }
    let promotedTask = updatedTask->Task.newToLoaded(~id="promoted-task", ~title="Promoted")
    let tasks = Dict.make()
    tasks->Dict.set("promoted-task", promotedTask)
    let promotedState = {
      ...updatedState,
      tasks,
      currentTask: Task.Selected("promoted-task"),
    }

    t
    ->expect(StateReducer.targetIsCurrent(promotedState, ForClient(clientId)))
    ->Expect.toBe(true)
    switch effects->Array.get(0) {
    | Some(StateReducer.TaskEffect({target: ForClient(effectClientId)})) =>
      t->expect(effectClientId)->Expect.toBe(clientId)
    | _ => JsExn.throw("Expected client-targeted new task effect")
    }
  })
})
