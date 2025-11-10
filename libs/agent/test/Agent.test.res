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
          | Agent__EventBus.TaskEvent(taskId, Completed(_)) if taskId == id => {
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
    await agent->Agent.sendMessage(
      Message.User({
        taskId: Agent.TaskId.make(),
        content: String(userMessage),
        selectedElementSourceLocation: None,
      }),
    )
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
    await agent->Agent.sendMessage(
      Message.User({
        taskId: Agent.TaskId.make(),
        content: String(userMessage),
        selectedElementSourceLocation: None,
      }),
    )
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
      | (
        Agent__EventBus.TaskEvent(_, MessageAdded({message: Message.Tool(_)})),
        #ToolResult,
      ) => true
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

  // Stream event helpers
  let assertHasStreamEvent = (t, context, eventType) => {
    let hasStreamEvent = context.events.contents->Array.some(event =>
      switch (event, eventType) {
      | (Agent__EventBus.StreamEvent(_, Start(_)), #Start)
      | (Agent__EventBus.StreamEvent(_, TextStart(_)), #TextStart)
      | (Agent__EventBus.StreamEvent(_, TextDelta(_)), #TextDelta)
      | (Agent__EventBus.StreamEvent(_, TextEnd(_)), #TextEnd)
      | (Agent__EventBus.StreamEvent(_, ToolCall(_)), #ToolCall)
      | (Agent__EventBus.StreamEvent(_, Finish(_)), #Finish) => true
      | _ => false
      }
    )
    t->expect(hasStreamEvent)->Expect.toBe(true)
  }

  let countStreamEvents = (context, eventType) => {
    context.events.contents->Array.reduce(0, (count, event) =>
      switch (event, eventType) {
      | (Agent__EventBus.StreamEvent(_, TextDelta(_)), #TextDelta) => count + 1
      | (Agent__EventBus.StreamEvent(_, ToolCall(_)), #ToolCall) => count + 1
      | _ => count
      }
    )
  }

  // Helper to track all task events for a specific task
  let getTaskEvents = (context, taskId) => {
    context.events.contents->Array.filterMap(event =>
      switch event {
      | Agent__EventBus.TaskEvent(id, evt) if id == taskId => Some(evt)
      | _ => None
      }
    )
  }

  // Helper to count completed tasks
  let countCompletedTasks = context => {
    context.events.contents->Array.reduce(0, (count, event) =>
      switch event {
      | Agent__EventBus.TaskEvent(_, Completed(_)) => count + 1
      | _ => count
      }
    )
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

    testAsync(
      "resumes completed task when user sends follow-up message",
      async t => {
        // Setup: Create mock tool that will complete task on first run
        let mockTool = makeMockListFiles(
          ~output=JSON.parseOrThrow(`[{"name": "test.txt", "path": "./test.txt"}]`),
        )

        // Create agent with tool call mock (completes after one iteration)
        let agent = Agent.make({
          projectRoot: ".",
          apiKey: "test-key",
          model: Test.makeToolCallMock(
            ~toolCallId="call_1",
            ~toolName="listFiles",
            ~args=JSON.parseOrThrow(`{"relative_dir": "."}`),
          ),
          toolRegistry: MockTool.makeRegistry([mockTool]),
        })
        let _unsubscribe = agent->Agent.initialize

        let context = makeTestContext(agent)

        // Send initial message (taskId will be generated by agent)
        await agent->Agent.sendMessage(
          Message.User({
            taskId: Agent.TaskId.make(),
            content: String("List files"),
            selectedElementSourceLocation: None,
          }),
        )
        await waitForContextTask(context)

        // Verify task completed and get the taskId
        let taskId = switch context.taskId.contents {
        | Some(id) => id
        | None => {
            t->expect(false)->Expect.toBe(true)
            Agent.TaskId.make() // fallback, won't be reached
          }
        }

        switch context->getTask {
        | Some(task) => t->expect(task.status)->Expect.toBe(Agent__Task.Status.Completed)
        | None => t->expect(false)->Expect.toBe(true)
        }

        // Send follow-up message to completed task using the actual taskId
        await agent->Agent.sendMessage(
          Message.User({
            taskId,
            content: String("Can you explain the results?"),
            selectedElementSourceLocation: None,
          }),
        )

        // Wait for task to complete again (after resume)
        await waitForContextTask(context)

        // Verify task was resumed and processed follow-up
        switch context->getTask {
        | Some(task) => {
            // Should be completed again
            t->expect(task.status)->Expect.toBe(Agent__Task.Status.Completed)

            // Should have both user messages in history
            let userMessages = task.history->Array.filter(
              msg =>
                switch msg {
                | Message.User(_) => true
                | _ => false
                },
            )
            t->expect(userMessages->Array.length)->Expect.toBe(2)

            // Should have processed the follow-up (multiple assistant messages)
            // Initial: 1 with tool call + 1 completion = 2, Follow-up: 1 completion = 3 total
            let assistantMessages = task.history->Array.filter(
              msg =>
                switch msg {
                | Message.Assistant(_) => true
                | _ => false
                },
            )
            t->expect(assistantMessages->Array.length)->Expect.toBe(3)
          }
        | None => t->expect(false)->Expect.toBe(true)
        }

        // Verify we have exactly 2 Completed events (initial + after resume)
        let completedCount = countCompletedTasks(context)
        t->expect(completedCount)->Expect.toBe(2)
      },
    )

    testAsync(
      "handles multiple rapid follow-up messages to completed task",
      async t => {
        // Setup: Create mock tool that will complete task quickly
        let mockTool = makeMockListFiles(
          ~output=JSON.parseOrThrow(`[{"name": "test.txt", "path": "./test.txt"}]`),
        )

        // Create agent
        let agent = Agent.make({
          projectRoot: ".",
          apiKey: "test-key",
          model: Test.makeToolCallMock(
            ~toolCallId="call_1",
            ~toolName="listFiles",
            ~args=JSON.parseOrThrow(`{"relative_dir": "."}`),
          ),
          toolRegistry: MockTool.makeRegistry([mockTool]),
        })
        let _unsubscribe = agent->Agent.initialize

        let context = makeTestContext(agent)

        // Send initial message
        await agent->Agent.sendMessage(
          Message.User({
            taskId: Agent.TaskId.make(),
            content: String("List files"),
            selectedElementSourceLocation: None,
          }),
        )
        await waitForContextTask(context)

        // Get the actual taskId from the created task
        let taskId = switch context.taskId.contents {
        | Some(id) => id
        | None => {
            t->expect(false)->Expect.toBe(true)
            Agent.TaskId.make() // fallback
          }
        }

        // Send THREE rapid follow-up messages sequentially
        // These will be queued in FIFO order
        await agent->Agent.sendMessage(
          Message.User({
            taskId,
            content: String("Follow-up 1"),
            selectedElementSourceLocation: None,
          }),
        )
        await waitForContextTask(context)

        await agent->Agent.sendMessage(
          Message.User({
            taskId,
            content: String("Follow-up 2"),
            selectedElementSourceLocation: None,
          }),
        )
        await waitForContextTask(context)

        await agent->Agent.sendMessage(
          Message.User({
            taskId,
            content: String("Follow-up 3"),
            selectedElementSourceLocation: None,
          }),
        )
        await waitForContextTask(context)

        // Verify task processed all messages
        switch context->getTask {
        | Some(task) => {
            // Should be completed
            t->expect(task.status)->Expect.toBe(Agent__Task.Status.Completed)

            // Should have all 4 user messages
            let userMessages = task.history->Array.filter(
              msg =>
                switch msg {
                | Message.User(_) => true
                | _ => false
                },
            )
            t->expect(userMessages->Array.length)->Expect.toBe(4)

            // Should have multiple assistant responses
            // Initial: 2 (tool call + completion), Follow-up 1-3: 3 completions = 5 total
            let assistantMessages = task.history->Array.filter(
              msg =>
                switch msg {
                | Message.Assistant(_) => true
                | _ => false
                },
            )
            t->expect(assistantMessages->Array.length)->Expect.toBe(5)
          }
        | None => t->expect(false)->Expect.toBe(true)
        }

        // Verify correct number of Completed events (initial + 3 follow-ups)
        let completedCount = countCompletedTasks(context)
        t->expect(completedCount)->Expect.toBe(4)
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

  describe("Streaming Events", () => {
    testAsync(
      "emits streaming events during LLM response",
      async t => {
        let mockTool = makeMockListFiles(
          ~output=JSON.parseOrThrow(`[{"name": "test.txt", "path": "./test.txt"}]`),
        )

        let context = await runScenarioWithSingleTool(
          ~tool=mockTool,
          ~toolCallId="call_1",
          ~toolName="listFiles",
          ~args=JSON.parseOrThrow(`{"relative_dir": "."}`),
          ~userMessage="List files",
        )

        // Verify we got stream events
        assertHasStreamEvent(t, context, #Start)
        assertHasStreamEvent(t, context, #TextStart)
        assertHasStreamEvent(t, context, #TextDelta)
        assertHasStreamEvent(t, context, #TextEnd)
        assertHasStreamEvent(t, context, #ToolCall)
        assertHasStreamEvent(t, context, #Finish)

        // Verify we got at least one TextDelta event
        let textDeltaCount = countStreamEvents(context, #TextDelta)
        t->expect(textDeltaCount > 0)->Expect.toBe(true)
      },
    )

    // TODO: These tests expose a limitation in the current implementation:
    // When a user sends a follow-up message while the agent is streaming,
    // the behavior is not well-defined. The task may complete before the
    // queued message is processed, and we currently can't add messages to
    // completed tasks. This needs to be addressed in future work.

    // testAsync(
    //   "queues user message sent during streaming without processing it immediately",
    //   async t => {
    //     // Create agent with tool that will trigger streaming
    //     let mockTool = makeMockListFiles(
    //       ~output=JSON.parseOrThrow(`[{"name": "test.txt", "path": "./test.txt"}]`),
    //     )

    //     let agent = Agent.make({
    //       projectRoot: ".",
    //       apiKey: "test-key",
    //       model: Test.makeToolCallMock(
    //         ~toolCallId="call_1",
    //         ~toolName="listFiles",
    //         ~args=JSON.parseOrThrow(`{"relative_dir": "."}`),
    //       ),
    //       toolRegistry: MockTool.makeRegistry([mockTool]),
    //     })
    //     let _unsubscribe = agent->Agent.initialize

    //     let context = makeTestContext(agent)

    //     // Track when first streaming starts
    //     let firstStreamStarted = ref(false)
    //     let secondMessageSent = ref(false)
    //     let secondTaskId = ref(None)

    //     let _streamSub = agent->Agent.subscribe(event => {
    //       switch event {
    //       | Agent__EventBus.StreamEvent(_, Start(_)) if !firstStreamStarted.contents => {
    //           firstStreamStarted := true
    //           // Send second message WHILE first is streaming
    //           if !secondMessageSent.contents {
    //             secondMessageSent := true
    //             agent
    //             ->Agent.sendMessage(
    //               Message.User({
    //                 taskId: ?context.taskId.contents,
    //                 content: String("Second message while streaming"),
    //               }),
    //             )
    //             ->ignore
    //           }
    //         }
    //       | Agent__EventBus.TaskEvent(_, Created({id})) if secondMessageSent.contents =>
    //         // This should not happen - second message should not create a new task
    //         // It should be added to the existing task
    //         secondTaskId := Some(id)
    //       | _ => ()
    //       }
    //     })

    //     // Send first message
    //     await agent->Agent.sendMessage(Message.User({content: String("First message")}))
    //     await waitForContextTask(context)

    //     // Wait a bit for queued message to be processed
    //     await Promise.make((resolve, _reject) => {
    //       let _ = setTimeout(() => resolve(), 50)
    //     })

    //     // Verify the second message was queued and processed AFTER the first task completed
    //     // We should have exactly 1 completed task (the original one)
    //     let completedCount = countCompletedTasks(context)
    //     t->expect(completedCount)->Expect.toBe(1)

    //     // Verify second message did not create a new task
    //     t->expect(secondTaskId.contents)->Expect.toBe(None)

    //     // Verify the task has multiple user messages in history
    //     switch context->getTask {
    //     | Some(task) => {
    //         let history = task->Agent__Task.getHistory
    //         let userMessageCount =
    //           history
    //           ->Array.filter(msg =>
    //             switch msg {
    //             | Message.User(_) => true
    //             | _ => false
    //             }
    //           )
    //           ->Array.length
    //         // Should have both user messages
    //         t->expect(userMessageCount)->Expect.toBe(2)
    //       }
    //     | None => t->expect(false)->Expect.toBe(true)
    //     }
    //   },
    // )

    // testAsync(
    //   "processes queued user message after tool call completes",
    //   async t => {
    //     // Create agent that will:
    //     // 1. First LLM call -> requests a tool call
    //     // 2. User sends second message while tool is being called
    //     // 3. Tool completes
    //     // 4. Second LLM call -> processes tool result + second user message

    //     let mockTool = makeMockListFiles(
    //       ~output=JSON.parseOrThrow(`[{"name": "test.txt", "path": "./test.txt"}]`),
    //     )

    //     let agent = Agent.make({
    //       projectRoot: ".",
    //       apiKey: "test-key",
    //       model: Test.makeToolCallMock(
    //         ~toolCallId="call_1",
    //         ~toolName="listFiles",
    //         ~args=JSON.parseOrThrow(`{"relative_dir": "."}`),
    //       ),
    //       toolRegistry: MockTool.makeRegistry([mockTool]),
    //     })
    //     let _unsubscribe = agent->Agent.initialize

    //     let context = makeTestContext(agent)

    //     // Track events for timing analysis
    //     let toolCallReceived = ref(false)
    //     let secondMessageSent = ref(false)

    //     let _sub = agent->Agent.subscribe(event => {
    //       switch event {
    //       // When we receive the ToolCall stream event, send second user message
    //       | Agent__EventBus.StreamEvent(_, ToolCall(_)) if !toolCallReceived.contents => {
    //           toolCallReceived := true
    //           if !secondMessageSent.contents {
    //             secondMessageSent := true
    //             agent
    //             ->Agent.sendMessage(
    //               Message.User({
    //                 taskId: ?context.taskId.contents,
    //                 content: String("Follow-up question while tool is executing"),
    //               }),
    //             )
    //             ->ignore
    //           }
    //         }
    //       | _ => ()
    //       }
    //     })

    //     // Send first message
    //     await agent->Agent.sendMessage(Message.User({content: String("Initial request")}))
    //     await waitForContextTask(context)

    //     // Verify second message was sent
    //     t->expect(secondMessageSent.contents)->Expect.toBe(true)

    //     // Get task events in order
    //     let taskId = context.taskId.contents->Option.getExn
    //     let taskEvents = getTaskEvents(context, taskId)

    //     // Verify event sequence:
    //     // 1. Created
    //     // 2. ProcessingStarted
    //     // 3. MessageAdded (assistant with tool call)
    //     // 4. MessageAdded (tool result)
    //     // 5. MessageAdded (second user message) <- This is queued
    //     // 6. MessageAdded (final assistant response)
    //     // 7. Completed

    //     let messageAddedCount =
    //       taskEvents
    //       ->Array.filter(evt =>
    //         switch evt {
    //         | Agent__Task.MessageAdded(_) => true
    //         | _ => false
    //         }
    //       )
    //       ->Array.length

    //     // Should have 4 MessageAdded events:
    //     // 1. Assistant message with tool call
    //     // 2. Tool result
    //     // 3. Second user message (queued)
    //     // 4. Final assistant response
    //     t->expect(messageAddedCount)->Expect.toBe(4)

    //     // Verify task history has both user messages
    //     switch context->getTask {
    //     | Some(task) => {
    //         let history = task->Agent__Task.getHistory
    //         let userMessages =
    //           history->Array.filter(msg =>
    //             switch msg {
    //             | Message.User(_) => true
    //             | _ => false
    //             }
    //           )
    //         // Initial user message + follow-up question
    //         t->expect(userMessages->Array.length)->Expect.toBe(2)

    //         // Verify tool was executed
    //         assertHasMessage(t, task, #Tool)
    //       }
    //     | None => t->expect(false)->Expect.toBe(true)
    //     }
    //   },
    // )
  })
})
