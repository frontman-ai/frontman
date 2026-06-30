# Implementation Plan: Queued Message Drawer

## Overview

Move accepted-but-not-processing user messages out of the main transcript into a compact queued drawer. When the server emits a normal `state_update running`, the client reducer moves queued messages into regular `messages`. Question drawer stays closest to the prompt area. Plan stays above queued drawer. Retry and question-resume must not drain the queue.

## Architecture Decisions

- `messages` means visible transcript that is currently processing or already processed.
- `queuedUserMessages` means accepted user messages waiting for the next normal turn.
- Queue drain happens only on normal queued-turn start, not on any `isAgentRunning=true` transition.
- Retry needs explicit reducer state so retry-running does not drain queued messages.
- Question answer/resume does not drain queued messages.
- Plan is independent; no queue coupling.
- UI stack order: messages, plan, queued drawer, question drawer or prompt input.
- Queued drawer is compact by default and expandable if needed.
- Session-load history remains transcript-only for now because client does not receive exact claim metadata.

## Data And Code Path

Server persisted interactions:

```text
UserMessage row
TurnStarted row
Assistant/tool rows
```

Server session-load projects these into ACP updates:

```text
UserMessage    -> session/update user_message
TurnStarted    -> []
Assistant/tool -> session/update agent/tool...
```

Client load/live entry point:

```rescript
// Client__FrontmanProvider.res
| UserMessage({messageId, content}) =>
  Client__TextDeltaBuffer.flush()
  let (content, annotations) = parseUserMessageBlocks(content)
  Client__State.Actions.userMessageReceived(~taskId, ~id=messageId, ~content, ~annotations)
```

Action dispatch:

```rescript
// Client__State.res
let userMessageReceived = (...) =>
  dispatch(TaskAction({
    target: ForTask(taskId),
    action: UserMessageReceived({id, content, annotations, createdAt: Date.now()}),
  }))
```

Current reducer behavior:

```rescript
// Client__Task__Reducer.res
| (Task.Loading(_) | Task.Loaded(_), UserMessageReceived(...)) =>
  let userMessage = Message.User(...)
  (task->Lens.completeStreamingMessage->Lens.insertMessage(userMessage), [])
```

Target reducer split:

```rescript
| (Task.Loading(_), UserMessageReceived(...)) =>
  // History replay: keep canonical transcript behavior.
  insert into messages

| (Task.Loaded(_), UserMessageReceived(...)) =>
  // Live accepted prompt: show as queued until normal turn starts.
  append to queuedUserMessages
```

Why split:

- `Loading` means session-load history replay. Client lacks `TurnStarted`, so exact queued-vs-claimed reconstruction is impossible.
- `Loaded` means live accepted update. If execution is busy, accepted message is queued until next normal `state_update running`.

## Session Load Constraint

On session load, client cannot know whether the last user message is queued or already claimed because `TurnStarted` is not sent.

Example queued after reconnect:

```text
DB:
UserMessage A
TurnStarted [A]
Assistant answer
UserMessage B   <- not claimed yet

Client receives:
user_message A
assistant answer
user_message B
```

Example running but no output yet:

```text
DB:
UserMessage B
TurnStarted [B]

Client receives:
user_message B
```

Client cannot distinguish:

- `B` is queued and not started.
- `B` is claimed/running but has not produced assistant/tool output yet.

Decision for first slice: do not use trailing-message heuristic. During `Task.Loading`, keep all history `user_message` updates in regular transcript. Live `Task.Loaded` updates get queued. Exact reconnect queue display can be added later with server metadata if needed.

## Dependency Graph

```text
Task state shape
  -> reducer transitions
    -> selectors/actions
      -> queued drawer component
        -> Chatbox layout
          -> tests/manual verification
```

## Phase 1: Reducer State Foundation

### Task 1: Add Queued User Message State

**Description:** Add a queued-message collection to loaded task state without changing UI yet.

**Acceptance criteria:**

- [x] `Task.Loaded` stores `queuedUserMessages: array<Message.t>` or narrower `array<queuedUserMessage>`.
- [x] Constructors initialize queue to `[]`.
- [x] `updateLoadedData` preserves queue.
- [x] Selector exposes queued messages for current task.

**Verification:**

- [x] `make test` in `libs/client`.
- [x] Focused task reducer tests cover default empty queue.

**Dependencies:** None

**Files likely touched:**

- `libs/client/src/state/Client__Task__Types.res`
- `libs/client/src/state/Client__Task__Reducer.res`
- `libs/client/src/state/Client__State__StateReducer.res`

**Estimated scope:** M

### Task 2: Enqueue Accepted Messages

**Description:** Change loaded-task `UserMessageReceived` behavior so accepted live messages enter queue instead of normal transcript.

**Acceptance criteria:**

- [x] `UserMessageReceived` on `Task.Loaded` appends to `queuedUserMessages`.
- [x] `UserMessageReceived` on `Task.Loading` keeps old history behavior and inserts into `messages`.
- [x] Existing session-load tests still pass without queued reconstruction.

**Verification:**

- [x] Test: loaded task receives accepted user message, `messages` unchanged, queue has message.
- [x] Test: loading task receives accepted user message, message appears in history.

**Dependencies:** Task 1

**Files likely touched:**

- `libs/client/src/state/Client__Task__Reducer.res`
- `libs/client/test/Client__Task.test.res`

**Estimated scope:** S

## Phase 2: Correct Drain Semantics

### Task 3: Drain Queue On Normal Running

**Description:** Move queued messages into transcript when a normal queued turn starts.

**Acceptance criteria:**

- [x] `ExecutionStateRunning` drains `queuedUserMessages` into `messages`.
- [x] Drain preserves queued acceptance order.
- [x] Queue clears after drain.
- [x] `turnError` and `retryStatus` still clear as today.

**Verification:**

- [x] Test: two queued user messages drain into `messages` on `ExecutionStateRunning`.
- [x] Test: queued messages appear before following assistant streaming/tool updates.

**Dependencies:** Task 2

**Files likely touched:**

- `libs/client/src/state/Client__Task__Reducer.res`
- `libs/client/test/Client__Task.test.res`

**Estimated scope:** S

### Task 4: Protect Retry Flow

**Description:** Add explicit retry execution state so retry-running does not drain queued messages.

**Acceptance criteria:**

- [x] `RetryTurn` marks retry active and sets running as today.
- [x] `RetryingUpdate` marks retry active.
- [x] `ExecutionStateRunning` does not drain queue when retry active.
- [x] `ExecutionStateIdle`, `AgentError`, and cancel clear retry-active state.
- [x] Existing retry status behavior remains unchanged.

**Verification:**

- [x] Test: queued message remains queued when `RetryTurn` runs.
- [x] Test: queued message remains queued through retry `ExecutionStateRunning`.
- [x] Test: retry idle clears retry-active state.

**Dependencies:** Task 3

**Files likely touched:**

- `libs/client/src/state/Client__Task__Types.res`
- `libs/client/src/state/Client__Task__Reducer.res`
- `libs/client/test/Client__Task.test.res`

**Estimated scope:** M

### Task 5: Protect Question Resume

**Description:** Ensure answering a question resumes current turn without draining queued messages.

**Acceptance criteria:**

- [x] `QuestionSubmitted`, `QuestionAllSkipped`, and final `QuestionPerQuestionSkipped` keep queued messages queued.
- [x] `pendingQuestion` still clears and resolver effects still fire.
- [x] `isAgentRunning` behavior remains compatible with current question flow.
- [x] Normal later `ExecutionStateRunning` drains queue after current turn reaches idle and server starts next turn.

**Verification:**

- [x] Test: with pending question and queued message, `QuestionSubmitted` clears question but queue remains.
- [x] Test: `QuestionCancelled` clears question and queue remains.

**Dependencies:** Task 3

**Files likely touched:**

- `libs/client/src/state/Client__Task__Reducer.res`
- `libs/client/test/Client__Task.test.res`

**Estimated scope:** S

## Checkpoint: Reducer Correctness

- [x] `make test` in `libs/client` passes.
- [x] Queue drain only happens on eligible normal `ExecutionStateRunning`.
- [x] Retry and question resume do not move queued messages.
- [x] Plan actions leave queue untouched.

## Phase 3: Queued Drawer UI

### Task 6: Add Queued Messages Drawer Component

**Description:** Create compact drawer matching existing question/plan visual language.

**Acceptance criteria:**

- [x] Drawer renders count: `Queued (N)`.
- [x] Compact view shows latest queued message preview.
- [x] Expanded view lists all queued messages in accepted order.
- [x] Handles text, image/file indicator, and annotations enough to avoid blank rows.
- [x] No actions needed; passive display only.

**Verification:**

- [ ] Component renders with one message.
- [ ] Component renders with multiple messages.
- [x] Keyboard-accessible expand/collapse button.

**Dependencies:** Task 1

**Files likely touched:**

- `libs/client/src/components/frontman/Client__QueuedMessagesDrawer.res`

**Estimated scope:** M

### Task 7: Wire Drawer Into Chatbox Layout

**Description:** Render queued drawer in correct stack location.

**Acceptance criteria:**

- [x] Stack order: scroll messages, `PlanList`, queued drawer, question drawer or prompt input.
- [x] Queued drawer visible when queue non-empty.
- [x] Question drawer remains closest to bottom when open.
- [x] Prompt input hidden only by question drawer, not by queued drawer.
- [x] Queued drawer has constrained height so it cannot crowd question drawer too much.

**Verification:**

- [ ] Manual check: plan only.
- [ ] Manual check: queue only.
- [ ] Manual check: plan + queue.
- [ ] Manual check: plan + queue + question.
- [ ] Manual check at narrow/mobile width.

**Dependencies:** Task 6

**Files likely touched:**

- `libs/client/src/Client__Chatbox.res`

**Estimated scope:** S

## Phase 4: Session Load Stability

### Task 8: Keep History Replay Stable

**Description:** Avoid breaking session-load history, since server does not project `TurnStarted` to client.

**Acceptance criteria:**

- [x] During `Task.Loading`, accepted user messages continue going into `messages`.
- [x] `LoadComplete` does not attempt exact queue reconstruction.
- [x] No processed historical user messages disappear into queue.

**Verification:**

- [x] Existing load-session tests pass.
- [x] Test: loading history with user + assistant remains regular transcript.

**Dependencies:** Task 2

**Files likely touched:**

- `libs/client/src/state/Client__Task__Reducer.res`
- `libs/client/test/Client__Task.test.res`
- possibly `libs/client/test/Client__LoadSessionFlow.test.res`

**Estimated scope:** S

## Phase 5: End-To-End Tests

### Task 9: Add Reducer Integration Tests

**Description:** Cover important combinations in reducer tests.

**Acceptance criteria:**

- [x] Multiple live accepted messages queue.
- [x] Normal running drains all queued messages.
- [x] Retry running leaves queued messages queued.
- [x] Question drawer open leaves queued messages queued.
- [x] Plan update leaves queued messages queued.
- [x] Idle does not drain queued messages.

**Verification:**

- [x] `make test` in `libs/client`.

**Dependencies:** Tasks 1-5

**Files likely touched:**

- `libs/client/test/Client__Task.test.res`
- `libs/client/test/Client__State__StateReducer.test.res`

**Estimated scope:** M

### Task 10: Manual Browser Verification

**Description:** Verify real UI behavior with live client.

**Acceptance criteria:**

- [ ] Send message while agent is running: appears in queued drawer.
- [ ] When next normal turn starts: queued message moves into transcript.
- [ ] With question open: queued drawer appears above question, question remains actionable.
- [ ] With plan open: plan stays above queued drawer.
- [ ] Retry does not move queued message into transcript prematurely.

**Verification:**

- [ ] Run app and check browser.
- [ ] Inspect console for errors.

**Dependencies:** Tasks 6-9

**Files likely touched:** None

**Estimated scope:** S

## Risks And Mitigations

| Risk | Impact | Mitigation |
|---|---:|---|
| Retry emits same `state_update running` as normal turn | High | Add retry-active reducer flag; do not drain during retry. |
| Question answer sets `isAgentRunning=true` locally | Medium | Drain only in eligible `ExecutionStateRunning`, not question actions. |
| Reconnect cannot know exact queued state | Medium | Keep history replay unchanged; add server metadata later if exact reconnect queue display matters. |
| Drawer stack gets cramped | Medium | Make queued drawer compact/collapsible with max height. |
| Message type reuse causes styling mismatch | Low | Store queued as `Message.User` but render with dedicated compact row. |

## Deferred Exact Reconnect Support

If exact queued display after reconnect becomes necessary, server should project claim metadata or another non-chat state update during session load. Example shape:

```json
{
  "sessionUpdate": "turn_started",
  "userMessageIds": ["..."]
}
```

Then client can split exactly:

- Claimed user messages stay in transcript.
- Unclaimed accepted messages go to queued drawer.

Do not implement this in the first client-only slice.
