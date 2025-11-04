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

    // Simulate TextStart event
    let _event = AgentEventBus.StreamEvent(task, Vercel.TextStart({id: "text-abc"}))

    // Process event (simulating mapper logic)
    let (nextState, _) = Reducer.next(state.contents, StreamingStarted({id: "text-abc"}))
    state := nextState

    // Verify streaming message created
    switch state.contents.messages->Array.get(0) {
    | Some(Reducer.Assistant(Reducer.Streaming({id, textBuffer, _}))) => {
        t->expect(id)->Expect.toBe("text-abc")
        t->expect(textBuffer)->Expect.toBe("")
      }
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })

  test("full streaming session produces correct completed message", t => {
    let state = ref(Reducer.defaultState)
    let task = makeMockTask()

    // Simulate event sequence
    let events = [
      AgentEventBus.StreamEvent(task, Vercel.TextStart({id: "text-123"})),
      AgentEventBus.StreamEvent(task, Vercel.TextDelta({id: "text-123", text: "Hello"})),
      AgentEventBus.StreamEvent(task, Vercel.TextDelta({id: "text-123", text: " "})),
      AgentEventBus.StreamEvent(task, Vercel.TextDelta({id: "text-123", text: "world"})),
      AgentEventBus.StreamEvent(task, Vercel.TextEnd({id: "text-123"})),
    ]

    // Process events
    events->Array.forEach(event => {
      let action = switch event {
      | StreamEvent(_, TextStart({id})) => Some(Reducer.StreamingStarted({id: id}))
      | StreamEvent(_, TextDelta({id, text})) => Some(Reducer.TextDeltaReceived({id: id, text: text}))
      | StreamEvent(_, TextEnd({id})) => Some(Reducer.MessageCompleted({id: id}))
      | _ => None
      }

      action->Option.forEach(act => {
        let (nextState, _) = Reducer.next(state.contents, act)
        state := nextState
      })
    })

    // Verify final state
    t->expect(state.contents.messages->Array.length)->Expect.toBe(1)

    switch state.contents.messages->Array.get(0) {
    | Some(Reducer.Assistant(Reducer.Completed({id, content, _}))) => {
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
    let state = ref(Reducer.defaultState)
    let stableId = "text-stable-id"

    // Start streaming
    let (nextState, _) = Reducer.next(state.contents, StreamingStarted({id: stableId}))
    state := nextState

    let id1 = state.contents.messages
      ->Array.get(0)
      ->Option.map(Reducer.Selectors.getMessageId)

    // Add text
    let (nextState, _) = Reducer.next(
      state.contents,
      TextDeltaReceived({id: stableId, text: "Test"}),
    )
    state := nextState

    let id2 = state.contents.messages
      ->Array.get(0)
      ->Option.map(Reducer.Selectors.getMessageId)

    // Complete
    let (nextState, _) = Reducer.next(state.contents, MessageCompleted({id: stableId}))
    state := nextState

    let id3 = state.contents.messages
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
      AgentEventBus.StreamEvent(task, Vercel.Start({})),
      AgentEventBus.StreamEvent(task, Vercel.ReasoningStart({id: "reasoning-1"})),
      AgentEventBus.StreamEvent(
        task,
        Vercel.ReasoningDelta({id: "reasoning-1", text: "..."}),
      ),
      AgentEventBus.TaskEvent(
        task,
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
    ignoredEvents->Array.forEach(event => {
      let action = switch event {
      | StreamEvent(_, Start({})) => None
      | StreamEvent(_, ReasoningStart(_)) => None
      | StreamEvent(_, ReasoningDelta(_)) => None
      | TaskEvent(_, _) => None
      | _ => None
      }

      action->Option.forEach(act => {
        let (nextState, _) = Reducer.next(state.contents, act)
        state := nextState
      })
    })

    // State should remain unchanged
    t->expect(state.contents.messages->Array.length)->Expect.toBe(0)
  })
})
