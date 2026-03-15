open Vitest

module Conn = Client__ConnectionReducer
module State = Client__State__StateReducer
module Task = Client__State__Types.Task

module Mock = {
  let session = id => Obj.magic({"sessionId": id, "channel": null})
  let conn = () => Obj.magic({"socket": null, "channel": null})
  let server = () => Obj.magic({"tools": []})
}

describe("Load Session Then Stream", () => {
  test("streaming works after loading a task", t => {
    let taskId = "loaded-task-123"

    // 1. Connection: session becomes active after load
    let connState = {
      ...Conn.initialState,
      acp: Conn.ACPConnected(Mock.conn()),
      relay: Conn.RelayConnected,
      mcpServer: Some(Mock.server()),
      session: Conn.NoSession,
    }
    let (connAfterLoad, _) = Conn.reduce(connState, SessionCreateSuccess(Mock.session(taskId)))

    // Session should be active (this is where the bug is - currently stays NoSession)
    t->expect(Conn.Selectors.getSession(connAfterLoad)->Option.map(s => s.sessionId))->Expect.toBe(Some(taskId))

    // 2. State: create a loaded task directly (simulates task creation via AddUserMessage)
    let loadedTask = Task.makeLoaded(
      ~id=taskId,
      ~title="Loaded Task",
      ~previewUrl="http://localhost:3000",
      ~createdAt=Date.now(),
      ~isAgentRunning=true,
    )
    let tasks = Dict.make()
    tasks->Dict.set(taskId, loadedTask)
    let appState: State.state = {
      ...State.defaultState,
      tasks,
      currentTask: Task.Selected(taskId),
    }

    // 3. Streaming arrives and routes to task
    let (stateAfterStream, _) = State.next(appState, TaskAction({target: ForTask(taskId), action: StreamingStarted}))
    let (finalState, _) = State.next(stateAfterStream, TaskAction({target: ForTask(taskId), action: TextDeltaReceived({text: "Hello", timestamp: "2024-01-15T10:00:00Z"})}))

    let task = finalState.tasks->Dict.get(taskId)->Option.getOrThrow
    let messages = Task.getLoadedData(task)->Option.mapOr([], d => d.messages)
    t->expect(messages->Array.length)->Expect.toBe(1)
  })
})
