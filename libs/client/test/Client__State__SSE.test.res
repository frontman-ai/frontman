open Vitest

module AgentEventBus = AskTheLlmAgent.Agent__EventBus
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel
module Reducer = Client__State__StateReducer

// Helper to create mock task
let makeMockTask = (): AskTheLlmAgent.Agent__Task.t => {
  id: "task-123",
  status: Working,
  history: [],
  artifacts: [],
}

describe("SSE Integration - Text Streaming", () => {
  test("TextStart creates streaming message", t => {
    let state = ref(Reducer.defaultState)
    let task = makeMockTask()

    // First add a user message to create a task
    let (nextState, _) = Reducer.next(
      state.contents,
      AddUserMessage({
        id: "user-1",
        content: [Reducer.UserContentPart.text("Hello")],
      }),
    )
    state := nextState

    // Get the task ID that was created
    let taskId = state.contents.currentTaskId->Option.getOr("unknown")

    // Simulate TextStart event
    let _event = AgentEventBus.StreamEvent(task.id, Vercel.TextStart({id: "text-abc"}))

    // Process event (simulating mapper logic)
    let (nextState, _) = Reducer.next(state.contents, StreamingStarted({taskId, id: "text-abc"}))
    state := nextState

    // Verify streaming message created (should have user message + streaming message)
    let messages = Reducer.Selectors.messages(state.contents)
    t->expect(messages->Array.length)->Expect.toBe(2)

    switch messages->Array.get(1) {
    | Some(Reducer.Message.Assistant(Streaming({id, textBuffer, _}))) => {
        t->expect(id)->Expect.toBe("text-abc")
        t->expect(textBuffer)->Expect.toBe("")
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("full streaming session produces correct completed message", t => {
    // Create initial state with a task
    let initialTask = Reducer.Task.make(
      ~title="Test Task",
      ~previewUrl="http://localhost:3000",
    )
    let tasks = Dict.make()
    tasks->Dict.set(initialTask.id, initialTask)

    let state = ref({
      Reducer.tasks,
      currentTaskId: Some(initialTask.id),
    })
    let task = makeMockTask()

    // Simulate event sequence
    let events = [
      AgentEventBus.StreamEvent(task.id, Vercel.TextStart({id: "text-123"})),
      AgentEventBus.StreamEvent(task.id, Vercel.TextDelta({id: "text-123", text: "Hello"})),
      AgentEventBus.StreamEvent(task.id, Vercel.TextDelta({id: "text-123", text: " "})),
      AgentEventBus.StreamEvent(task.id, Vercel.TextDelta({id: "text-123", text: "world"})),
      AgentEventBus.StreamEvent(task.id, Vercel.TextEnd({id: "text-123"})),
    ]

    // Process events
    events->Array.forEach(
      event => {
        let action = switch event {
        | StreamEvent(taskId, TextStart({id})) => Some(Reducer.StreamingStarted({taskId, id}))
        | StreamEvent(taskId, TextDelta({id, text})) =>
          Some(Reducer.TextDeltaReceived({taskId, id, text}))
        | StreamEvent(taskId, TextEnd({id})) => Some(Reducer.MessageCompleted({taskId, id}))
        | _ => None
        }

        action->Option.forEach(
          act => {
            let (nextState, _) = Reducer.next(state.contents, act)
            state := nextState
          },
        )
      },
    )

    // Verify final state
    let messages = Reducer.Selectors.messages(state.contents)
    t->expect(messages->Array.length)->Expect.toBe(1)

    switch messages->Array.get(0) {
    | Some(Reducer.Message.Assistant(Completed({id, content, _}))) => {
        t->expect(id)->Expect.toBe("text-123")
        t->expect(content->Array.length)->Expect.toBe(1)

        switch content->Array.get(0) {
        | Some(Reducer.AssistantContentPart.Text({text})) =>
          t->expect(text)->Expect.toBe("Hello world")
        | _ => t->expect(false)->Expect.toBe(true)
        }
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("message ID remains stable throughout streaming lifecycle", t => {
    // Create initial state with a task
    let initialTask = Reducer.Task.make(
      ~title="Test Task",
      ~previewUrl="http://localhost:3000",
    )
    let tasks = Dict.make()
    tasks->Dict.set(initialTask.id, initialTask)

    let state = ref({
      Reducer.tasks,
      currentTaskId: Some(initialTask.id),
    })
    let stableId = "text-stable-id"
    let taskId = initialTask.id

    // Start streaming
    let (nextState, _) = Reducer.next(state.contents, StreamingStarted({taskId, id: stableId}))
    state := nextState

    let id1 =
      Reducer.Selectors.messages(state.contents)
      ->Array.get(0)
      ->Option.map(Reducer.Selectors.getMessageId)

    // Add text
    let (nextState, _) = Reducer.next(
      state.contents,
      TextDeltaReceived({taskId, id: stableId, text: "Test"}),
    )
    state := nextState

    let id2 =
      Reducer.Selectors.messages(state.contents)
      ->Array.get(0)
      ->Option.map(Reducer.Selectors.getMessageId)

    // Complete
    let (nextState, _) = Reducer.next(state.contents, MessageCompleted({taskId, id: stableId}))
    state := nextState

    let id3 =
      Reducer.Selectors.messages(state.contents)
      ->Array.get(0)
      ->Option.map(Reducer.Selectors.getMessageId)

    // All IDs should be the same
    t->expect(id1)->Expect.toEqual(Some(stableId))
    t->expect(id2)->Expect.toEqual(Some(stableId))
    t->expect(id3)->Expect.toEqual(Some(stableId))
  })

  test("ignores irrelevant stream events", t => {
    let state = ref(Reducer.defaultState)
    let task = makeMockTask()

    // These events should be ignored
    let ignoredEvents = [
      AgentEventBus.StreamEvent(task.id, Vercel.Start({})),
      AgentEventBus.StreamEvent(task.id, Vercel.ReasoningStart({id: "reasoning-1"})),
      AgentEventBus.StreamEvent(task.id, Vercel.ReasoningDelta({id: "reasoning-1", text: "..."})),
      AgentEventBus.TaskEvent(
        task.id,
        AskTheLlmAgent.Agent__Task.Event.Created({
          id: task.id,
          initialMessage: AskTheLlmAgent.Agent__Task__Message.System({
            taskId: task.id,
            content: "",
          }),
        }),
      ),
    ]

    // Process events (mapper returns None for these)
    ignoredEvents->Array.forEach(
      event => {
        let action = switch event {
        | StreamEvent(_, Start({})) => None
        | StreamEvent(_, ReasoningStart(_)) => None
        | StreamEvent(_, ReasoningDelta(_)) => None
        | TaskEvent(_, _) => None
        | _ => None
        }

        action->Option.forEach(
          act => {
            let (nextState, _) = Reducer.next(state.contents, act)
            state := nextState
          },
        )
      },
    )

    // State should remain unchanged
    t->expect(Reducer.Selectors.messages(state.contents)->Array.length)->Expect.toBe(0)
  })
})
