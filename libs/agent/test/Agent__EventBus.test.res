// EventBus emission tests without LLM calls
// These tests verify event emission behavior.
//
// For tests that mock LLM responses, see Agent__Mocking.test.res

open Vitest

describe("EventBus emission", () => {
  testAsync("TaskCreated event is emitted when Create command succeeds", async t => {
    let agent = Agent.make({projectRoot: ".", apiKey: "test-api-key"})
    let receivedEvents: ref<array<Agent__EventBus.events>> = ref([])

    // Subscribe to events (subscribers now return unit)
    let _unsubscribe = agent->Agent.subscribe(
      event => {
        receivedEvents := Array.concat(receivedEvents.contents, [event])
      },
    )

    // Create a task
    let message = Agent.TaskMessage.User({
      content: String("test message"),
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
    let agent = Agent.make({projectRoot: ".", apiKey: "test-api-key"})
    let receivedEvents: ref<array<Agent__EventBus.events>> = ref([])

    // Subscribe to events
    let _unsubscribe = agent->Agent.subscribe(
      event => {
        receivedEvents := Array.concat(receivedEvents.contents, [event])
      },
    )

    // Create a task
    let message = Agent.TaskMessage.User({
      content: String("test message"),
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
