// Integration test: multi-turn history replay message ordering
//
// Simulates the actual replay flow that happens when loading a saved session:
// Server pushes notifications in order → client processes them →
// user messages go through UserMessageReceived (synchronous),
// agent messages go through TextDeltaBuffer (deferred) →
// buffer.flush() → LoadComplete → messages should be interleaved correctly.
//
// This is the integration gap that allowed the "merged agent messages" bug:
// individual pieces were unit-tested, but the composed behavior was not.

open Vitest

module Task = Client__Task__Types.Task
module Message = Client__Task__Types.Message
module UserContentPart = Client__Message.UserContentPart
module TaskReducer = Client__Task__Reducer
module Buffer = Client__TextDeltaBuffer

// Helper: build a text-only UserMessageReceived action
let _userMsg = (~id, ~text, ~timestamp) => TaskReducer.UserMessageReceived({
  id,
  content: [UserContentPart.text(text)],
  annotations: [],
  timestamp,
})

module TestHelpers = {
  let makeLoadingTask = (~id="test-task-1") => {
    let unloaded = Task.makeUnloaded(
      ~id,
      ~title="Test Task",
      ~createdAt=Date.now(),
      ~updatedAt=Date.now(),
    )
    TaskReducer.next(unloaded, LoadStarted({previewUrl: "http://localhost:3000"}))->Pair.first
  }

  let getMessages = (task: Task.t): array<Message.t> => {
    TaskReducer.Selectors.messages(task)->Option.getOrThrow(
      ~message="Expected task to have messages (not Unloaded)",
    )
  }

  // Helper to extract text from a message regardless of type
  let getMessageText = (msg: Message.t): string =>
    switch msg {
    | Message.User({content}) =>
      content
      ->Array.filterMap(part =>
        switch part {
        | Client__Task__Types.UserContentPart.Text({text}) => Some(text)
        | _ => None
        }
      )
      ->Array.join("")
    | Message.Assistant(Streaming({textBuffer})) => textBuffer
    | Message.Assistant(Completed({content})) =>
      content
      ->Array.filterMap(part =>
        switch part {
        | Message.AssistantContentPart.Text({text}) => Some(text)
        | _ => None
        }
      )
      ->Array.join("")
    | Message.ToolCall(_) => "(tool call)"
    | Message.Error(err) => Message.ErrorMessage.error(err)
    }

  let getMessageRole = (msg: Message.t): string =>
    switch msg {
    | Message.User(_) => "user"
    | Message.Assistant(_) => "assistant"
    | Message.ToolCall(_) => "tool"
    | Message.Error(_) => "error"
    }
}

// ============================================================================
// Baseline: Reducer-level tests (TextDeltaReceived dispatched directly)
//
// These test the reducer in isolation — what it SHOULD see if the buffer
// correctly separates agent messages. They verify the reducer's own logic
// for interleaving user and agent messages during history replay.
// ============================================================================

describe("History Replay - Reducer level (direct dispatch)", () => {
  test("multi-turn replay produces correctly interleaved messages", t => {
    // Simulate: User1 → Agent1 → User2 → Agent2 → User3 → Agent3
    // All dispatched directly to the reducer (bypassing buffer)
    let task = TestHelpers.makeLoadingTask()

    // Turn 1
    let (task, _) = TaskReducer.next(
      task,
      _userMsg(~id="user-1", ~text="what is your name?", ~timestamp="2026-03-12T09:01:25Z"),
    )
    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({text: "I'm Claude Code", timestamp: "2026-03-12T09:01:28Z"}),
    )

    // Turn 2: UserMessageReceived should finalize the previous agent message
    let (task, _) = TaskReducer.next(
      task,
      _userMsg(~id="user-2", ~text="what is my name?", ~timestamp="2026-03-15T08:54:49Z"),
    )
    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({text: "BlueHotDog", timestamp: "2026-03-15T08:54:52Z"}),
    )

    // Turn 3
    let (task, _) = TaskReducer.next(
      task,
      _userMsg(~id="user-3", ~text="what is my name?", ~timestamp="2026-03-15T10:25:21Z"),
    )
    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({text: "Still BlueHotDog", timestamp: "2026-03-15T10:25:24Z"}),
    )

    // LoadComplete finalizes everything
    let (loaded, _) = TaskReducer.next(task, LoadComplete)

    let messages = TestHelpers.getMessages(loaded)

    // Should be 6 separate messages, interleaved
    t->expect(Array.length(messages))->Expect.toBe(6)

    // Verify order: User, Assistant, User, Assistant, User, Assistant
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(0)))->Expect.toBe("user")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(1)))->Expect.toBe("assistant")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(2)))->Expect.toBe("user")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(3)))->Expect.toBe("assistant")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(4)))->Expect.toBe("user")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(5)))->Expect.toBe("assistant")

    // Verify content
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(0)))
    ->Expect.toBe("what is your name?")
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(1)))
    ->Expect.toBe("I'm Claude Code")
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(2)))
    ->Expect.toBe("what is my name?")
    t->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(3)))->Expect.toBe("BlueHotDog")
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(4)))
    ->Expect.toBe("what is my name?")
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(5)))
    ->Expect.toBe("Still BlueHotDog")
  })

  test("all agent messages are Completed (not Streaming) after LoadComplete", t => {
    let task = TestHelpers.makeLoadingTask()

    let (task, _) = TaskReducer.next(
      task,
      _userMsg(~id="u1", ~text="hi", ~timestamp="2026-01-01T10:00:00Z"),
    )
    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({text: "hello", timestamp: "2026-01-01T10:00:01Z"}),
    )
    let (task, _) = TaskReducer.next(
      task,
      _userMsg(~id="u2", ~text="bye", ~timestamp="2026-01-01T10:01:00Z"),
    )
    let (task, _) = TaskReducer.next(
      task,
      TextDeltaReceived({text: "goodbye", timestamp: "2026-01-01T10:01:01Z"}),
    )
    let (loaded, _) = TaskReducer.next(task, LoadComplete)

    let messages = TestHelpers.getMessages(loaded)
    messages->Array.forEach(
      msg =>
        switch msg {
        | Message.Assistant(Streaming(_)) =>
          t->expect("Streaming after LoadComplete")->Expect.toBe("should be Completed")
        | _ => ()
        },
    )
    // All assistant messages should exist
    let assistantCount =
      messages->Array.filter(m => TestHelpers.getMessageRole(m) == "assistant")->Array.length
    t->expect(assistantCount)->Expect.toBe(2)
  })
})

// ============================================================================
// Integration: Buffer + Reducer (simulates the actual replay path)
//
// This is the real scenario: agent messages go through TextDeltaBuffer.add()
// (which accumulates by taskId). The fix: flush the buffer before each
// UserMessageReceived so each agent response is dispatched as a separate
// TextDeltaReceived before the next user message finalizes it via
// completeStreamingMessage.
// ============================================================================

describe("History Replay - Integration (Buffer + Reducer)", () => {
  test("multi-turn replay through TextDeltaBuffer produces separate agent messages", t => {
    let taskId = "test-task-1"
    let task = ref(TestHelpers.makeLoadingTask(~id=taskId))

    // Create a buffer that dispatches TextDeltaReceived to our task
    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~text, ~timestamp) => {
        let (updated, _) = TaskReducer.next(task.contents, TextDeltaReceived({text, timestamp}))
        task := updated
      },
    )

    // Simulate server pushing notifications in order.
    // This mirrors the actual handleSessionUpdate flow:
    // - user_message_chunk → flush buffer, then dispatch UserMessageReceived
    // - agent_message_chunk → buffer.add() (deferred)

    // Turn 1: user message (flush + sync), then agent message (buffered)
    buffer.flush() // flush before user message (nothing to flush on first call)
    let (updated, _) = TaskReducer.next(
      task.contents,
      _userMsg(~id="user-1", ~text="what is your name?", ~timestamp="2026-03-12T09:01:25Z"),
    )
    task := updated
    buffer.add(~taskId, ~text="I'm Claude Code", ~timestamp="2026-03-12T09:01:28Z")

    // Turn 2: flush agent1 before user2
    buffer.flush()
    let (updated, _) = TaskReducer.next(
      task.contents,
      _userMsg(~id="user-2", ~text="what is my name?", ~timestamp="2026-03-15T08:54:49Z"),
    )
    task := updated
    buffer.add(~taskId, ~text="BlueHotDog", ~timestamp="2026-03-15T08:54:52Z")

    // Turn 3: flush agent2 before user3
    buffer.flush()
    let (updated, _) = TaskReducer.next(
      task.contents,
      _userMsg(~id="user-3", ~text="what is my name?", ~timestamp="2026-03-15T10:25:21Z"),
    )
    task := updated
    buffer.add(~taskId, ~text="Still BlueHotDog", ~timestamp="2026-03-15T10:25:24Z")

    // Final flush before LoadComplete (dispatches agent3)
    buffer.flush()

    // LoadComplete finalizes everything
    let (loaded, _) = TaskReducer.next(task.contents, LoadComplete)

    let messages = TestHelpers.getMessages(loaded)

    // 6 separate messages, interleaved
    t->expect(Array.length(messages))->Expect.toBe(6)

    // Verify order: User, Assistant, User, Assistant, User, Assistant
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(0)))->Expect.toBe("user")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(1)))->Expect.toBe("assistant")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(2)))->Expect.toBe("user")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(3)))->Expect.toBe("assistant")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(4)))->Expect.toBe("user")
    t->expect(TestHelpers.getMessageRole(messages->Array.getUnsafe(5)))->Expect.toBe("assistant")

    // Verify each agent message has distinct content (not merged)
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(1)))
    ->Expect.toBe("I'm Claude Code")
    t->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(3)))->Expect.toBe("BlueHotDog")
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(5)))
    ->Expect.toBe("Still BlueHotDog")
  })

  test("replay with tool calls preserves correct interleaving", t => {
    // Simulates: User → Agent("") → ToolCall → ToolResult → Agent("response")
    // The fix: flush buffer before ToolCall so the empty agent response is dispatched
    // separately, and the second agent response doesn't merge with it.
    let taskId = "test-task-1"
    let task = ref(TestHelpers.makeLoadingTask(~id=taskId))

    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~text, ~timestamp) => {
        let (updated, _) = TaskReducer.next(task.contents, TextDeltaReceived({text, timestamp}))
        task := updated
      },
    )

    // 1. User message
    buffer.flush()
    let (updated, _) = TaskReducer.next(
      task.contents,
      _userMsg(~id="user-1", ~text="ask me 3 random questions", ~timestamp="2026-03-15T14:53:29Z"),
    )
    task := updated

    // 2. Agent response (empty — tool call only). Buffer gets "" with agent's timestamp.
    buffer.add(~taskId, ~text="", ~timestamp="2026-03-15T14:53:39Z")

    // 3. ToolCall arrives — flush buffer first (the fix)
    buffer.flush()
    let (updated, _) = TaskReducer.next(
      task.contents,
      ToolCallReceived({
        toolCall: {
          id: "tool-1",
          toolName: "question",
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: Message.InputStreaming,
          createdAt: Date.fromString("2026-03-15T14:53:39Z")->Date.getTime,
          parentAgentId: None,
          spawningToolName: None,
        },
      }),
    )
    task := updated

    // 4. Tool input (pending)
    let questionInput = JSON.parseOrThrow(`{"questions":[{"question":"test?","header":"Q","options":[]}]}`)
    let (updated, _) = TaskReducer.next(
      task.contents,
      ToolInputReceived({id: "tool-1", input: questionInput}),
    )
    task := updated

    // 5. Tool result (completed)
    let toolResult = JSON.parseOrThrow(`{"answers":[{"question":"test?","answer":["yes"]}],"skippedAll":false,"cancelled":false}`)
    let (updated, _) = TaskReducer.next(
      task.contents,
      ToolResultReceived({id: "tool-1", result: toolResult}),
    )
    task := updated

    // 6. Agent response with actual content (fresh buffer entry after flush)
    buffer.add(~taskId, ~text="Solid answers, BlueHotDog!", ~timestamp="2026-03-15T14:54:05Z")

    // Final flush + LoadComplete
    buffer.flush()
    let (loaded, _) = TaskReducer.next(task.contents, LoadComplete)

    let messages = TestHelpers.getMessages(loaded)

    // Find the tool call and "Solid answers" agent message
    let toolIdx = messages->Array.findIndex(
      m =>
        switch m {
        | Message.ToolCall(_) => true
        | _ => false
        },
    )
    let solidAnswersIdx =
      messages->Array.findIndex(
        m => TestHelpers.getMessageText(m)->String.includes("Solid answers"),
      )

    // The agent response MUST come after the tool call
    t->expect(toolIdx >= 0)->Expect.toBe(true)
    t->expect(solidAnswersIdx >= 0)->Expect.toBe(true)
    t->expect(solidAnswersIdx > toolIdx)->Expect.toBe(true)

    // User message should be first
    let roles = messages->Array.map(TestHelpers.getMessageRole)
    t->expect(roles->Array.get(0))->Expect.toBe(Some("user"))
  })

  test("buffer merges consecutive agent chunks within a single turn (correct behavior)", t => {
    // This tests that streaming chunks within ONE turn are correctly merged.
    // The buffer SHOULD merge these — that's its intended purpose.
    let taskId = "test-task-1"
    let task = ref(TestHelpers.makeLoadingTask(~id=taskId))

    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~text, ~timestamp) => {
        let (updated, _) = TaskReducer.next(task.contents, TextDeltaReceived({text, timestamp}))
        task := updated
      },
    )

    // User sends a message
    let (updated, _) = TaskReducer.next(
      task.contents,
      _userMsg(~id="user-1", ~text="tell me a story", ~timestamp="2026-01-01T10:00:00Z"),
    )
    task := updated

    // Agent responds in multiple streaming chunks (same turn, same timestamp)
    buffer.add(~taskId, ~text="Once upon ", ~timestamp="2026-01-01T10:00:01Z")
    buffer.add(~taskId, ~text="a time...", ~timestamp="2026-01-01T10:00:01Z")

    buffer.flush()
    let (loaded, _) = TaskReducer.next(task.contents, LoadComplete)

    let messages = TestHelpers.getMessages(loaded)

    // Should be 2 messages: 1 user + 1 agent (chunks correctly merged)
    t->expect(Array.length(messages))->Expect.toBe(2)
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(0)))
    ->Expect.toBe("tell me a story")
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(1)))
    ->Expect.toBe("Once upon a time...")
  })

  test("error messages sort by server timestamp, not wall-clock time (issue #635)", t => {
    // Simulates: User → Agent → Error → User2 → Agent2
    // The error's timestamp is between the first agent response and the second user message.
    // Before the fix, Error used Date.now() which sorted it to the very end.
    let taskId = "test-task-1"
    let task = ref(TestHelpers.makeLoadingTask(~id=taskId))

    let buffer = Buffer.make(
      ~onFlush=(~taskId as _, ~text, ~timestamp) => {
        let (updated, _) = TaskReducer.next(task.contents, TextDeltaReceived({text, timestamp}))
        task := updated
      },
    )

    // Turn 1: user message, then agent response
    buffer.flush()
    let (updated, _) = TaskReducer.next(
      task.contents,
      _userMsg(~id="user-1", ~text="do something", ~timestamp="2025-01-10T10:00:00Z"),
    )
    task := updated
    buffer.add(~taskId, ~text="Working on it", ~timestamp="2025-01-10T10:00:05Z")
    buffer.flush()

    // Error occurs mid-conversation with server timestamp
    let (updated, _) = TaskReducer.next(
      task.contents,
      AgentError({
        error: "Rate limit exceeded",
        timestamp: "2025-01-10T10:00:10Z",
        category: "unknown",
      }),
    )
    task := updated

    // Turn 2: user retries, agent succeeds
    let (updated, _) = TaskReducer.next(
      task.contents,
      _userMsg(~id="user-2", ~text="try again", ~timestamp="2025-01-10T10:01:00Z"),
    )
    task := updated
    buffer.add(~taskId, ~text="Done!", ~timestamp="2025-01-10T10:01:05Z")
    buffer.flush()

    // LoadComplete sorts by createdAt
    let (loaded, _) = TaskReducer.next(task.contents, LoadComplete)
    let messages = TestHelpers.getMessages(loaded)

    // Should be 5 messages: user, assistant, error, user, assistant
    t->expect(Array.length(messages))->Expect.toBe(5)

    let roles = messages->Array.map(TestHelpers.getMessageRole)
    t->expect(roles)->Expect.toEqual(["user", "assistant", "error", "user", "assistant"])

    // The error should be in chronological position, not at the end
    t
    ->expect(TestHelpers.getMessageText(messages->Array.getUnsafe(2)))
    ->Expect.toBe("Rate limit exceeded")
  })
})
