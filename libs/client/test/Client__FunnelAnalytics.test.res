open Vitest

module App = Client__State__StateReducer
module Protocol = Client__State__Protocol
module Task = Client__State__Types.Task

@set external setRuntime: (WebAPI.Window.t, Nullable.t<JSON.t>) => unit = "__frontmanRuntime"

beforeEach(() =>
  setRuntime(
    WebAPI.Window.current,
    Nullable.make(JSON.Encode.object(Dict.fromArray([("framework", JSON.Encode.string("vite"))]))),
  )
)
afterEach(() => setRuntime(WebAPI.Window.current, Nullable.null))

let events = effects =>
  effects->Array.filterMap(effect =>
    switch effect {
    | Protocol.TrackAnalyticsEffect(event) => Some(event)
    | _ => None
    }
  )

let loadedState = () => {
  let draft = switch Task.makeNew(~previewUrl="http://localhost", ~clientId="draft") {
  | New(draft) => draft
  | _ => failwith("Expected a draft")
  }
  let task = Task.Loaded(Task.promoteDraft(draft, ~id="task", ~title="Task", ~timestamp=0.))
  {
    ...Client__State__Initialization.defaultState,
    tasks: Dict.fromArray([("task", task)]),
    currentTask: Task.Selected("task"),
  }
}

test("server execution transitions emit once, independent of optimistic running state", t => {
  let action = action => Protocol.TaskAction({target: ForTask("task"), action})
  let initial = loadedState()
  let (optimistic, _) = Client__State__TaskUpdates.Lens.delegateToTask(
    initial,
    ForTask("task"),
    ExecutionStateRunning([]),
  )
  let (running, first) = App.next(optimistic, action(ExecutionStateRunning([])))
  t->expect(events(first))->Expect.toEqual([Client__Analytics.TaskRunStarted("task")])
  let (running, duplicate) = App.next(running, action(ExecutionStateRunning([])))
  t->expect(events(duplicate))->Expect.toEqual([])
  let (paused, _) = App.next(running, action(ExecutionStateRequiresAction))
  let (resumed, resume) = App.next(paused, action(ExecutionStateRunning([])))
  t->expect(events(resume))->Expect.toEqual([])
  let (idle, completed) = App.next(resumed, action(ExecutionStateIdle))
  t->expect(events(completed))->Expect.toEqual([Client__Analytics.TaskRunCompleted("task")])
  let (_, duplicate) = App.next(idle, action(ExecutionStateIdle))
  t->expect(events(duplicate))->Expect.toEqual([])
  let (_, restarted) = App.next(idle, action(ExecutionStateRunning([])))
  t->expect(events(restarted))->Expect.toEqual([Client__Analytics.TaskRunStarted("task")])
})

test("history replay and stale session updates do not emit run events", t => {
  let initial = loadedState()
  let idle = Protocol.TaskAction({target: ForTask("task"), action: ExecutionStateIdle})
  t->expect(App.next(initial, idle)->Pair.second->events)->Expect.toEqual([])
  let (running, _) = App.next(
    initial,
    TaskAction({
      target: ForTask("task"),
      action: ExecutionStateRunning([]),
    }),
  )
  let (disposed, _) = App.next(running, ConnectionAction(Dispose))
  t->expect(App.next(disposed, idle)->Pair.second->events)->Expect.toEqual([])
  let (loading, _) = Client__State__TaskUpdates.Lens.delegateToTask(
    initial,
    ForTask("task"),
    LoadStarted({previewUrl: "http://localhost"}),
  )
  let (_, effects) = App.next(
    loading,
    TaskAction({
      target: ForTask("task"),
      action: ExecutionStateRunning([]),
    }),
  )
  t->expect(events(effects))->Expect.toEqual([])
  let (_, effects) = App.next(
    initial,
    SessionEvent({
      requestId: ref(),
      action: TaskAction({target: ForTask("task"), action: ExecutionStateRunning([])}),
    }),
  )
  t->expect(events(effects))->Expect.toEqual([])
})

test("submission runs real rejection effects without Heap and records only one attempt", t => {
  let result = ref(None)
  let input: Protocol.promptInput = {
    id: Client__Message.UserMessageId.make(),
    timestamp: 0.,
    content: [Text({text: "private text never belongs in analytics"})],
    annotationId: None,
    onComplete: response => result := Some(response),
  }
  let state = Client__State__Initialization.defaultState
  let (updated, effects) = App.next(state, AddUserMessage(input))
  t
  ->expect(events(effects))
  ->Expect.toEqual([
    Client__Analytics.MessageSubmitAttempted(Client__Message.UserMessageId.toString(input.id)),
  ])
  effects->Array.forEach(effect => Client__State__Effects.handleEffect(effect, updated, _ => ()))
  t->expect(result.contents->Option.getOrThrow->Result.isError)->Expect.toBe(true)
  let (_, continued) = App.next(state, SubmitMessage(input))
  t->expect(events(continued))->Expect.toEqual([])
})

test("message acceptance follows live server echo once, not prompt completion", t => {
  let id = Client__Message.UserMessageId.make()
  let messageId = Client__Message.UserMessageId.toString(id)
  let (pending, _) = App.next(
    loadedState(),
    TaskAction({
      target: ForTask("task"),
      action: AddUserMessage({
        id,
        timestamp: 0.,
        content: [Text({text: "hello"})],
        annotations: [],
        agentId: "agent",
      }),
    }),
  )
  let echo = Protocol.TaskAction({
    target: ForTask("task"),
    action: UserMessageReceived({
      id: messageId,
      content: [Text({text: "hello"})],
      annotations: [],
      agentId: "agent",
    }),
  })
  let (accepted, effects) = App.next(pending, echo)
  t->expect(events(effects))->Expect.toEqual([Client__Analytics.MessageAccepted(messageId)])
  t->expect(App.next(accepted, echo)->Pair.second->events)->Expect.toEqual([])
  let (_, failed) = App.next(
    accepted,
    PromptFailed({
      requestId: ref(),
      taskId: "task",
      id,
      error: Client__ConnectionReducer.ACP.requestErrorFromMessage("timeout"),
    }),
  )
  t->expect(events(failed))->Expect.toEqual([])
  let (loading, _) = App.next(
    pending,
    TaskAction({target: ForTask("task"), action: LoadStarted({previewUrl: "http://localhost"})}),
  )
  t->expect(App.next(loading, echo)->Pair.second->events)->Expect.toEqual([])
})

test("switching away and restoring history releases the previous observed run", t => {
  let state = loadedState()
  let tasks = state.tasks->Dict.copy
  tasks->Dict.set(
    "other",
    Task.makeUnloaded(~id="other", ~title="Other", ~createdAt=0., ~updatedAt=0.),
  )
  let (running, _) = App.next(
    {...state, tasks},
    TaskAction({target: ForTask("task"), action: ExecutionStateRunning([])}),
  )
  let (away, _) = App.next(running, SwitchTask({taskId: "other"}))
  t->expect(away.analyticsRunningTasks)->Expect.toEqual([])
  let (loading, _) = App.next(away, SwitchTask({taskId: "task"}))
  // No transport is installed in this reducer test. Drive the real replay
  // transition explicitly after the no-connection load rejection.
  let (loading, _) = App.next(
    loading,
    TaskAction({
      target: ForTask("task"),
      action: LoadStarted({previewUrl: "http://localhost"}),
    }),
  )
  let (idle, effects) = App.next(
    loading,
    TaskAction({target: ForTask("task"), action: ExecutionStateIdle}),
  )
  t->expect(events(effects))->Expect.toEqual([])
  let (loaded, _) = App.next(idle, TaskAction({target: ForTask("task"), action: LoadComplete}))
  let (_, started) = App.next(
    loaded,
    TaskAction({target: ForTask("task"), action: ExecutionStateRunning([])}),
  )
  t->expect(events(started))->Expect.toEqual([Client__Analytics.TaskRunStarted("task")])
})

test("OpenAI polling outcomes only count for the current device authorization", t => {
  let state = {
    ...loadedState(),
    openaiOAuthStatus: Client__State__Types.OpenAIShowingCode({
      deviceAuthId: "current",
      userCode: "code",
      verificationUrl: "https://example.com",
    }),
  }
  let success = id => Protocol.OpenAIOAuthConnected({
    deviceAuthId: id,
    expiresAt: "2030-01-01T00:00:00Z",
  })
  let failure = id => Protocol.OpenAIOAuthError({deviceAuthId: Some(id), error: "denied"})
  t->expect(App.next(state, success("old"))->Pair.second->events)->Expect.toEqual([])
  t->expect(App.next(state, failure("old"))->Pair.second->events)->Expect.toEqual([])
  let (connected, completed) = App.next(state, success("current"))
  t
  ->expect(events(completed))
  ->Expect.toEqual([Client__Analytics.ProviderConnectionCompleted(OpenAI)])
  t->expect(App.next(connected, success("current"))->Pair.second->events)->Expect.toEqual([])
  t->expect(App.next(connected, failure("current"))->Pair.second->events)->Expect.toEqual([])
  t
  ->expect(App.next(state, failure("current"))->Pair.second->events)
  ->Expect.toEqual([Client__Analytics.ProviderConnectionFailed(OpenAI)])
})

test("event encoding only contains allowlisted categorical properties and correlation IDs", t => {
  let properties = Client__Analytics.eventProperties(MessageRejected("message", PromptFailed))
  t
  ->expect(properties->Dict.keysToArray->Array.toSorted(String.compare))
  ->Expect.toEqual(["event_source", "framework", "message_id", "reason_code"])
  t
  ->expect(properties->Dict.get("reason_code"))
  ->Expect.toEqual(Some(JSON.Encode.string("prompt_failed")))
  t
  ->expect(Client__Analytics.eventProperties(TaskRunCompleted("task"))->Dict.get("outcome"))
  ->Expect.toEqual(Some(JSON.Encode.string("idle")))
  t
  ->expect(Client__Analytics.eventName(EditorHandoffCompleted))
  ->Expect.toBe("editor_handoff_completed")
  // The real absent transport is optional, not replaced with a test double.
  Client__Heap.identify("test-user")
  Client__Analytics.track(EditorReady)
})
