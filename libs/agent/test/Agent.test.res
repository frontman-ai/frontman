// Comprehensive end-to-end tests for sendMessage flow
open Vitest

module Message = Agent__Task__Message
module Test = Agent__Bindings__Vercel__Test
module MockTool = Agent__Test__MockTool

// ============================================================================
// Test Helpers Module
// ============================================================================
module TestHelpers = {
  // Test context that tracks events and task IDs
  type testContext = {
    agent: Agent.t,
    events: ref<array<Agent__EventBus.events>>,
    taskId: ref<option<Agent__Task__Id.t>>,
    unsubscribe: unit => unit,
  }

  // Create a test context with event tracking
  let makeTestContext = (agent: Agent.t): testContext => {
    let events = ref([])
    let taskId = ref(None)

    let unsubscribe = agent->Agent.subscribe(event => {
      events := Array.concat(events.contents, [event])
      switch event {
      | Agent__EventBus.TaskEvent(_, Created({id})) => taskId := Some(id)
      | _ => ()
      }
    })

    {agent, events, taskId, unsubscribe}
  }

  // Wait for context's task to complete
  let waitForContextTask = async (context: testContext): unit => {
    switch context.taskId.contents {
    | Some(id) =>
      await Promise.make((resolve, _reject) => {
        let unsubscribe = ref(None)
        let handler = event => {
          switch event {
          | Agent__EventBus.TaskEvent(task, Completed(_)) if task.id == id => {
              unsubscribe.contents->Option.forEach(unsub => unsub())
              resolve()
            }
          | _ => ()
          }
        }
        unsubscribe := Some(context.agent->Agent.subscribe(handler))
      })
    | None => ()
    }
  }

  // Get task from context (returns None if not found)
  let getTask = (context: testContext): option<Agent__Task.t> => {
    context.taskId.contents->Option.flatMap(id => context.agent.tasks->Agent__Tasks.get(id))
  }

  // Quick helper to create mock tool with JSON output
  let makeMockListFiles = (~output) => {
    MockTool.makeMockTool(
      ~name="listFiles",
      ~description="Mock list files tool",
      ~fixedOutput=output,
    )
  }

  // Run a complete test scenario: setup agent, send message, wait for completion
  let runScenarioWithSingleTool = async (
    ~tool,
    ~toolCallId,
    ~toolName,
    ~args,
    ~userMessage,
  ): testContext => {
    let agent = Agent.make({
      projectRoot: ".",
      apiKey: "test-key",
      model: Test.makeToolCallMock(~toolCallId, ~toolName, ~args),
      toolRegistry: MockTool.makeRegistry([tool]),
    })
    let _unsubscribe = agent->Agent.initialize

    let context = makeTestContext(agent)
    await agent->Agent.sendMessage(Message.User({content: String(userMessage)}))
    await waitForContextTask(context)
    context
  }

  // Run scenario with multiple tool calls
  let runScenarioWithMultipleTools = async (~tool, ~toolCalls, ~userMessage): testContext => {
    let agent = Agent.make({
      projectRoot: ".",
      apiKey: "test-key",
      model: Test.makeMultipleToolCallsMock(~toolCalls),
      toolRegistry: MockTool.makeRegistry([tool]),
    })
    let _unsubscribe = agent->Agent.initialize

    let context = makeTestContext(agent)
    await agent->Agent.sendMessage(Message.User({content: String(userMessage)}))
    await waitForContextTask(context)
    context
  }

  // Simplified assertion helpers
  let assertToolCalled = (t, mock, times) => {
    t->expect(mock.MockTool.executions.contents->Array.length)->Expect.toBe(times)
  }

  let assertToolHasArg = (t, mock, index, argName) => {
    switch mock.MockTool.executions.contents[index] {
    | Some({input: Object(dict)}) =>
      t->expect(dict->Dict.get(argName)->Option.isSome)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  }

  let assertHasMessage = (t, task, messageType) => {
    let history = task->Agent__Task.getHistory
    let hasMessage = history->Array.some(msg =>
      switch (msg, messageType) {
      | (Message.User(_), #User)
      | (Message.Assistant(_), #Assistant)
      | (Message.Tool(_), #Tool)
      | (Message.System(_), #System) => true
      | _ => false
      }
    )
    t->expect(hasMessage)->Expect.toBe(true)
  }

  let assertHasToolCall = (t, task) => {
    let history = task->Agent__Task.getHistory
    let hasToolCall = history->Array.some(msg => Message.hasToolCalls(msg))
    t->expect(hasToolCall)->Expect.toBe(true)
  }

  let assertToolResultCount = (t, task, count) => {
    let history = task->Agent__Task.getHistory
    switch history->Array.find(msg =>
      switch msg {
      | Message.Tool(_) => true
      | _ => false
      }
    ) {
    | Some(Message.Tool({content})) => t->expect(content->Array.length)->Expect.toBe(count)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  }

  let assertHasEvent = (t, context, eventType) => {
    let hasEvent = context.events.contents->Array.some(event =>
      switch (event, eventType) {
      | (Agent__EventBus.TaskEvent(_, Created(_)), #Created)
      | (Agent__EventBus.TaskEvent(_, Completed(_)), #Completed)
      | (Agent__EventBus.TaskEvent(_, MessageAdded({message: Message.Tool(_)})), #ToolResult) => true
      | _ => false
      }
    )
    t->expect(hasEvent)->Expect.toBe(true)
  }

  let assertEventOrder = (t, context, first, second) => {
    let types = context.events.contents->Array.map(e =>
      switch e {
      | Agent__EventBus.TaskEvent(_, Created(_)) => #Created
      | Agent__EventBus.TaskEvent(_, Completed(_)) => #Completed
      | _ => #Other
      }
    )
    let i1 = types->Array.findIndex(t => t == first)
    let i2 = types->Array.findIndex(t => t == second)
    t->expect(i1 >= 0 && i2 >= 0 && i1 < i2)->Expect.toBe(true)
  }
}

// ============================================================================
// Test Suites
// ============================================================================

describe("Agent.sendMessage", () => {
  open TestHelpers

  describe("Task Creation", () => {
    testAsync(
      "creates new task and executes tool call flow",
      async t => {
        let mockTool = makeMockListFiles(
          ~output=JSON.parseOrThrow(`[
          {"name": "file1.txt", "path": "./file1.txt", "isFile": true, "isDirectory": false},
          {"name": "dir1", "path": "./dir1", "isFile": false, "isDirectory": true}
        ]`),
        )

        let context = await runScenarioWithSingleTool(
          ~tool=mockTool,
          ~toolCallId="call_1",
          ~toolName="listFiles",
          ~args=JSON.parseOrThrow(`{"relative_dir": "."}`),
          ~userMessage="Please list files",
        )

        // Assert tool execution
        assertToolCalled(t, mockTool, 1)
        assertToolHasArg(t, mockTool, 0, "relative_dir")

        // Assert task and messages
        switch context->getTask {
        | Some(task) => {
            assertHasMessage(t, task, #User)
            assertHasMessage(t, task, #Tool)
            assertHasToolCall(t, task)
          }
        | None => t->expect(false)->Expect.toBe(true)
        }

        // Assert events
        assertHasEvent(t, context, #Created)
        assertHasEvent(t, context, #Completed)
        assertHasEvent(t, context, #ToolResult)
        assertEventOrder(t, context, #Created, #Completed)
      },
    )
  })

  describe("Single Tool Call", () => {
    testAsync(
      "executes tool and adds result to message history",
      async t => {
        let mockTool = makeMockListFiles(
          ~output=JSON.parseOrThrow(`[
          {"name": "test.txt", "path": "./test.txt", "isFile": true, "isDirectory": false}
        ]`),
        )

        let context = await runScenarioWithSingleTool(
          ~tool=mockTool,
          ~toolCallId="call_1",
          ~toolName="listFiles",
          ~args=JSON.parseOrThrow(`{"relative_dir": "."}`),
          ~userMessage="List files in current dir",
        )

        assertToolCalled(t, mockTool, 1)

        switch context->getTask {
        | Some(task) => {
            assertHasMessage(t, task, #User)
            assertHasMessage(t, task, #Tool)
          }
        | None => t->expect(false)->Expect.toBe(true)
        }

        assertHasEvent(t, context, #ToolResult)
        assertHasEvent(t, context, #Completed)
      },
    )
  })

  describe("Multiple Tool Calls", () => {
    testAsync(
      "executes all tools and aggregates results",
      async t => {
        let mockTool = MockTool.makeStatefulMockTool(
          ~name="listFiles",
          ~description="Mock list files tool",
          ~outputs=[
            JSON.parseOrThrow(`[
            {"name": "root.txt", "path": "./root.txt", "isFile": true, "isDirectory": false}
          ]`),
            JSON.parseOrThrow(`[
            {"name": "main.res", "path": "./src/main.res", "isFile": true, "isDirectory": false}
          ]`),
          ],
        )

        let context = await runScenarioWithMultipleTools(
          ~tool=mockTool,
          ~toolCalls=[
            ("call_1", "listFiles", JSON.parseOrThrow(`{"relative_dir": "."}`)),
            ("call_2", "listFiles", JSON.parseOrThrow(`{"relative_dir": "./src"}`)),
          ],
          ~userMessage="List files in current and src directories",
        )

        assertToolCalled(t, mockTool, 2)

        switch context->getTask {
        | Some(task) => assertToolResultCount(t, task, 2)
        | None => t->expect(false)->Expect.toBe(true)
        }

        assertHasEvent(t, context, #ToolResult)
        assertHasEvent(t, context, #Completed)
      },
    )
  })
})
