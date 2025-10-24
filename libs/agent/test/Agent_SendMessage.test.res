// Comprehensive end-to-end tests for sendMessage flow
open Vitest

module Message = Agent__Task__Message
module Test = Agent__Bindings__Vercel__Test

// Helper to wait for task to reach terminal state
let waitForTaskCompletion = (agent: Agent.t, taskId: Agent__Task__Id.t): promise<unit> => {
  Promise.make((resolve, _reject) => {
    let unsubscribe = ref(None)

    let handler = event => {
      switch event {
      | Agent.EventBus.TaskEvent(task, Completed(_)) if task.id == taskId => {
          unsubscribe.contents->Option.forEach(unsub => unsub())
          resolve()
        }
      | Agent.EventBus.TaskEvent(task, Failed(_)) if task.id == taskId => {
          unsubscribe.contents->Option.forEach(unsub => unsub())
          resolve()
        }
      | Agent.EventBus.TaskEvent(task, Canceled(_)) if task.id == taskId => {
          unsubscribe.contents->Option.forEach(unsub => unsub())
          resolve()
        }
      | Agent.EventBus.TaskEvent(task, Rejected(_)) if task.id == taskId => {
          unsubscribe.contents->Option.forEach(unsub => unsub())
          resolve()
        }
      | _ => ()
      }
    }

    unsubscribe := Some(agent.eventBus->Agent.EventBus.on(handler))
  })
}

describe("sendMessage flow - new task creation with tool calls", () => {
  testAsync("creates new task and executes tool call flow", async t => {
    // Setup agent with mock model that returns tool call then completion
    let mockModel = Test.makeToolCallMock(
      ~toolCallId="call_1",
      ~toolName="listFiles",
      ~args=JSON.parseOrThrow(`{"relative_dir": "."}`),
    )

    let agent = Agent.make({
      projectRoot: ".",
      apiKey: "test-key",
      model: mockModel,
    })
    let _unsubscribe = agent->Agent.initialize

    let receivedEvents: ref<array<Agent.EventBus.events>> = ref([])
    let taskId: ref<option<Agent__Task__Id.t>> = ref(None)

    agent.eventBus
    ->Agent.EventBus.on(
      event => {
        receivedEvents := Array.concat(receivedEvents.contents, [event])
        // Capture task ID from Created event
        switch event {
        | Agent.EventBus.TaskEvent(_, Created({id})) => taskId := Some(id)
        | _ => ()
        }
      },
    )
    ->ignore

    // Send initial user message without taskId
    let userMessage = Message.User({
      content: String("Please list files"),
    })
    await agent->Agent.sendMessage(userMessage)

    // Wait for task to complete
    switch taskId.contents {
    | Some(id) => await waitForTaskCompletion(agent, id)
    | None => ()
    }

    // Verify events emitted
    let events = receivedEvents.contents

    // Should have multiple events (Created, ProcessingStarted, Messages, Completed)
    t->expect(events->Array.length >= 4)->Expect.toBe(true)

    // Verify we got a Created event
    let createdEvent = events->Array.find(
      event =>
        switch event {
        | TaskEvent(_, Created(_)) => true
        | _ => false
        },
    )
    t->expect(createdEvent->Option.isSome)->Expect.toBe(true)

    // Verify we have a tool result message
    let toolResultEvent = events->Array.find(
      event =>
        switch event {
        | TaskEvent(_, MessageAdded({message: Tool(_)})) => true
        | _ => false
        },
    )
    t->expect(toolResultEvent->Option.isSome)->Expect.toBe(true)

    // Verify task completed
    let completedEvent = events->Array.find(
      event =>
        switch event {
        | TaskEvent(_, Completed(_)) => true
        | _ => false
        },
    )
    t->expect(completedEvent->Option.isSome)->Expect.toBe(true)
  })
})

describe("sendMessage flow - single tool call", () => {
  testAsync(
    "handles assistant message with single tool call → execution → completion",
    async t => {
      let mockModel = Test.makeToolCallMock(
        ~toolCallId="call_1",
        ~toolName="listFiles",
        ~args=JSON.parseOrThrow(`{"relative_dir": "."}`),
      )

      let agent = Agent.make({
        projectRoot: ".",
        apiKey: "test-key",
        model: mockModel,
      })
      let _unsubscribe = agent->Agent.initialize

      let receivedEvents: ref<array<Agent.EventBus.events>> = ref([])
      let taskId: ref<option<Agent__Task__Id.t>> = ref(None)

      agent.eventBus
      ->Agent.EventBus.on(
        event => {
          receivedEvents := Array.concat(receivedEvents.contents, [event])
          switch event {
          | Agent.EventBus.TaskEvent(_, Created({id})) => taskId := Some(id)
          | _ => ()
          }
        },
      )
      ->ignore

      // Send user message
      let userMessage = Message.User({
        content: String("List files in current dir"),
      })
      await agent->Agent.sendMessage(userMessage)

      // Wait for task to complete
      switch taskId.contents {
      | Some(id) => await waitForTaskCompletion(agent, id)
      | None => ()
      }

      let events = receivedEvents.contents

      // Verify tool was executed
      let toolResultEvent = events->Array.find(
        event =>
          switch event {
          | TaskEvent(_, MessageAdded({message: Tool(_)})) => true
          | _ => false
          },
      )
      t->expect(toolResultEvent->Option.isSome)->Expect.toBe(true)

      // Verify task completed
      let completedEvent = events->Array.find(
        event =>
          switch event {
          | TaskEvent(_, Completed(_)) => true
          | _ => false
          },
      )
      t->expect(completedEvent->Option.isSome)->Expect.toBe(true)
    },
  )
})

describe("sendMessage flow - multiple tool calls", () => {
  testAsync("handles assistant message with multiple tool calls in single response", async t => {
    let mockModel = Test.makeMultipleToolCallsMock(
      ~toolCalls=[
        ("call_1", "listFiles", JSON.parseOrThrow(`{"relative_dir": "."}`)),
        ("call_2", "readFile", JSON.parseOrThrow(`{"file_path": "./README.md"}`)),
      ],
    )

    let agent = Agent.make({
      projectRoot: ".",
      apiKey: "test-key",
      model: mockModel,
    })
    let _unsubscribe = agent->Agent.initialize

    let receivedEvents: ref<array<Agent.EventBus.events>> = ref([])
    let taskId: ref<option<Agent__Task__Id.t>> = ref(None)

    agent.eventBus
    ->Agent.EventBus.on(
      event => {
        receivedEvents := Array.concat(receivedEvents.contents, [event])
        switch event {
        | Agent.EventBus.TaskEvent(_, Created({id})) => taskId := Some(id)
        | _ => ()
        }
      },
    )
    ->ignore

    // Send user message
    let userMessage = Message.User({
      content: String("Check the directory and README"),
    })
    await agent->Agent.sendMessage(userMessage)

    // Wait for task to complete
    switch taskId.contents {
    | Some(id) => await waitForTaskCompletion(agent, id)
    | None => ()
    }

    let events = receivedEvents.contents

    // Verify tool result message contains multiple results
    let toolResultEvent = events->Array.find(
      event =>
        switch event {
        | TaskEvent(_, MessageAdded({message: Tool({content})})) =>
          // Should have 2 tool results
          content->Array.length == 2
        | _ => false
        },
    )
    t->expect(toolResultEvent->Option.isSome)->Expect.toBe(true)

    // Verify completion
    let completedEvent = events->Array.find(
      event =>
        switch event {
        | TaskEvent(_, Completed(_)) => true
        | _ => false
        },
    )
    t->expect(completedEvent->Option.isSome)->Expect.toBe(true)
  })
})
