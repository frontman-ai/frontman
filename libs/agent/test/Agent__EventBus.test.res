// EventBus emission tests without LLM calls
// These tests verify event emission behavior.
//
// For tests that mock LLM responses, see Agent__Mocking.test.res

open Vitest

describe("EventBus emission", () => {
  testAsync("TaskCreated event is emitted when Create command succeeds", async t => {
    let agent = await Agent.make({projectRoot: ".", apiKey: "test-api-key"})
    let receivedEvents: ref<array<Agent__EventBus.events>> = ref([])

    // Subscribe to events (subscribers now return unit)
    let _unsubscribe = agent->Agent.subscribe(
      event => {
        receivedEvents := Array.concat(receivedEvents.contents, [event])
      },
    )

    // Create a task
    let message = Agent.TaskMessage.User({
      taskId: Agent.TaskId.make(),
      content: String("test message"),
      selectedElementSourceLocation: None,
    })
    agent->Agent.sendMessage(message)->ignore

    // Wait for async operations to complete
    await Promise.resolve()

    // Verify both Created and ProcessingStarted events were emitted
    t->expect(receivedEvents.contents->Array.length)->Expect.toBe(2)

    // First event should be Created
    switch receivedEvents.contents->Array.at(0) {
    | Some(TaskEvent(_, Created(_))) => () // Success
    | _ => t->expect(false)->Expect.toBe(true) // Fail the test
    }

    // Second event should be ProcessingStarted
    switch receivedEvents.contents->Array.at(1) {
    | Some(TaskEvent(_, ProcessingStarted(_))) => () // Success
    | _ => t->expect(false)->Expect.toBe(true) // Fail the test
    }
  })

  testAsync("Events are emitted through complete message flow", async t => {
    let agent = await Agent.make({projectRoot: ".", apiKey: "test-api-key"})
    let receivedEvents: ref<array<Agent__EventBus.events>> = ref([])

    // Subscribe to events
    let _unsubscribe = agent->Agent.subscribe(
      event => {
        receivedEvents := Array.concat(receivedEvents.contents, [event])
      },
    )

    // Create a task
    let message = Agent.TaskMessage.User({
      taskId: Agent.TaskId.make(),
      content: String("test message"),
      selectedElementSourceLocation: None,
    })
    agent->Agent.sendMessage(message)->ignore

    // Wait for async operations
    await Promise.resolve()

    // Should have at least Created event
    t->expect(receivedEvents.contents->Array.length >= 1)->Expect.toBe(true)

    // First event should be Created
    switch receivedEvents.contents->Array.at(0) {
    | Some(TaskEvent(_, Created(_))) => () // Success
    | _ => t->expect(false)->Expect.toBe(true) // Fail
    }
  })
})

describe("EventBus serialization", () => {
  test("StreamEvent with Start - create using ReScript types", t => {
    // Create the task ID
    let taskId = "0ed58ac2-d443-411f-bb9a-c81005fb2040"

    // Create System message
    let systemMessage = Agent__Task__Message.System({
      taskId,
      content: ``,
    })

    // Create User message
    let userMessage = Agent__Task__Message.User({
      taskId: "0c938b43-b1ca-4636-b6c7-bc4116e2231e",
      content: String("test"),
      selectedElementSourceLocation: None,
    })

    // Create the task
    let task: Agent__Task.t = {
      id: taskId,
      status: Agent__Task.Status.Working,
      history: [systemMessage, userMessage],
      artifacts: [],
    }

    let streamEvent: Agent__EventBus.streamEvent = Start({})
    let event: Agent__EventBus.events = StreamEvent(task.id, streamEvent)
    let obj = event->S.reverseConvertOrThrow(Agent__EventBus.eventsSchema)
    let jsonString = JSON.stringifyAny(obj)->Option.getOrThrow
    Js.log2("Serialized StreamEvent:", jsonString)

    let parsed = JSON.parseOrThrow(jsonString)
    let deserialized = parsed->S.parseOrThrow(Agent__EventBus.eventsSchema)

    switch deserialized {
    | StreamEvent(id, streamEvt) => {
        t->expect(id)->Expect.toBe(taskId)
        switch streamEvt {
        | Start(_) => t->expect(true)->Expect.toBe(true)
        | _ => t->expect(false)->Expect.toBe(true) // Should be Start
        }
      }
    | _ => t->expect(false)->Expect.toBe(true) // Should be StreamEvent
    }
  })
})
