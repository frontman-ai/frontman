# Improve Error UX for LLM Streaming Failures

**Issue:** #723
**Date:** 2026-03-31
**Branch:** `issue-723-feat-improve-error-ux`

## Problem

When an LLM stream fails, the user sees a raw `agent_error` interaction with an unhelpful message like `LLM stream error: %Mint.TransportError{reason: :closed}`. There is no retry mechanism, no distinction between transient and permanent errors, and no actionable guidance.

## Goals

- Show human-readable, categorized error messages
- Automatically retry transient errors server-side with exponential backoff + jitter
- Show the user a live countdown during auto-retry with the ability to cancel
- Offer a manual retry button on all errors (even permanent ones, so the user can retry after fixing the root cause)
- Show category-specific guidance for permanent errors
- Record retry events for observability

---

## Architecture

### Retry Strategy

Server-side `RetryCoordinator` GenServer per task. Auto-retry is triggered only for transient errors (`retryable: true`). Max 5 automatic attempts. After exhaustion (or on permanent errors), the error is surfaced to the user with a manual retry button.

Backoff is computed inline — no external dependency:

```elixir
delay = trunc(@base_delay_ms * :math.pow(2, attempt - 1))
jitter = :rand.uniform(div(delay, 4))   # up to 25% jitter
actual_delay = min(delay + jitter, @max_delay_ms)
```

Base delay: 2 000 ms. Max delay: 60 000 ms.

---

## Server-Side Changes

### 1. `AgentError` interaction — new fields

| Field | Type | Description |
|---|---|---|
| `retryable` | `bool` | Whether this error is transient and retriable |
| `category` | `string` | Error category driving the client CTA |
| `auto_retry_attempts` | `integer` | Number of auto-retries that occurred before giving up |

**`category` values:** `"auth"`, `"billing"`, `"rate_limit"`, `"overload"`, `"payload_too_large"`, `"output_truncated"`, `"unknown"`

`llm_client.ex`'s `classify_llm_error/2` is extended to return `{message, category, retryable}`. `execution.ex`'s `humanize_error/1` is updated to thread this through.

### 2. `RetryCoordinator` GenServer

Started on-demand (via `DynamicSupervisor`) when the first transient error hits a task. One coordinator per task, identified by `task_id`.

**State:**
```elixir
%{
  task_id: String.t(),
  scope: term(),
  attempt: integer(),          # current attempt number (1-based)
  max_attempts: 5,
  base_delay_ms: 2_000,
  max_delay_ms: 60_000
}
```

**Flow:**
1. `TaskChannel` calls `RetryCoordinator.handle_error(task_id, error_info)` instead of `handle_turn_error` directly
2. If `retryable: true` and `attempt <= max_attempts`:
   - Compute next delay with backoff + jitter
   - Push `sessionUpdate: "retrying"` ACP event to channel (with `retryAt` ISO8601 timestamp)
   - Schedule `Process.send_after(self(), :retry, delay_ms)`
3. On `:retry`: re-trigger task execution via existing machinery, increment attempt
4. If `retryable: false` OR `attempt > max_attempts`: call `handle_turn_error` — persists `AgentError` (with `auto_retry_attempts` count) and notifies client

**Cancel during countdown:** The existing cancel channel event already stops execution. `RetryCoordinator` subscribes to the same cancel signal and tears down, then falls through to `handle_turn_error` with `kind: "cancelled"`.

**Lifecycle:** `RetryCoordinator` terminates (normal exit) after either handing off to `handle_turn_error` (exhausted or permanent) or after successfully re-triggering execution (the execution pipeline takes over from there). It does not outlive a single retry sequence.

**`isAgentRunning` invariant:** `RetryCoordinator` intercepts the error *before* `AgentError` is persisted for transient errors, so `isAgentRunning` is never set to `false` during the retry countdown. The client keeps the stop button active throughout.

### 3. New ACP event: `sessionUpdate: "retrying"`

```json
{
  "sessionUpdate": "retrying",
  "attempt": 2,
  "maxAttempts": 5,
  "retryAt": "2026-03-31T12:00:05.000Z",
  "error": "The AI provider stopped responding mid-reply."
}
```

Client derives the countdown from `retryAt` locally — no server tick required.

### 4. `AgentRetry` interaction (observability)

Persisted only for **user-initiated** retries. Auto-retries are recorded via `auto_retry_attempts` on the final `AgentError`.

```elixir
%Interaction.AgentRetry{
  id: String.t(),
  sequence: integer(),
  timestamp: DateTime.t(),
  retried_error_id: String.t()   # ID of the AgentError being retried
}
```

### 5. New channel event: `retry_turn`

Received from client. `TaskChannel` creates an `AgentRetry` interaction (with `retried_error_id`) and re-triggers execution. The channel rejects this event (no-op) if execution is already running.

---

## Client-Side Changes

### 1. New state field: `retryStatus`

Added to the loaded task state in `Client__Task__Types`:

```rescript
type retryStatus = {
  attempt: int,
  maxAttempts: int,
  retryAt: float,   // JS timestamp in ms
  error: string,
}
```

Set on `RetryingUpdate` action, cleared on `AgentError` or `AddUserMessage`.

### 2. `ErrorMessage` type — new fields

`retryable: bool` and `category: string` passed through from `AgentError`.

### 3. `RetryBanner` component (new)

Shown at the bottom of the chat (same slot as `turnError`) while `retryStatus` is set.

Displays:
- The error that triggered the retry
- Live countdown: "Retrying in 8s (attempt 2 of 5)" — ticks client-side from `retryAt`
- The existing stop button remains active (driven by `isAgentRunning: true` during retry countdown), allowing the user to cancel the retry via the normal cancel flow

### 4. `ErrorBanner` updates

Always shows a **"Retry"** button (dispatches `RetryTurn`).

Category-specific guidance shown below the error message for permanent errors:

| `category` | Guidance |
|---|---|
| `auth` | "Your API key may be invalid — check Settings" (links to settings) |
| `billing` | "There may be a billing issue — check Settings" (links to settings) |
| `rate_limit` | "The provider is rate-limiting you — wait a moment before retrying" |
| `payload_too_large` | "Try with a shorter message or smaller files" |
| `output_truncated` | "Try asking for a shorter response" |
| `overload` / `unknown` | No extra line |

### 5. StateReducer changes

**New actions:**
- `RetryingUpdate({attempt, maxAttempts, retryAt, error})` → sets `retryStatus`, keeps `isAgentRunning: true`
- `RetryTurn` → pushes `retry_turn` channel event, clears `turnError`

**Updated handling:**
- `AgentError` → clears `retryStatus`
- `AddUserMessage` → clears both `turnError` and `retryStatus`

---

## Data Flow (end-to-end)

```
LLM stream error
  → llm_client classifies: {message, category, retryable}
  → execution.ex humanizes and propagates
  → SwarmDispatcher fires {:agent_error, error_info}
  → TaskChannel calls RetryCoordinator.handle_error/2

  [if retryable, attempt <= 5]
    → RetryCoordinator schedules Process.send_after
    → Pushes sessionUpdate:"retrying" to client
    → Client sets retryStatus, keeps stop button active, shows RetryBanner countdown
    → On timer: re-trigger execution
    → [repeat or exhaust]

  [if permanent OR exhausted]
    → handle_turn_error persists AgentError (with auto_retry_attempts)
    → Client clears retryStatus, shows ErrorBanner with retry button + category CTA

  [user clicks Retry]
    → Dispatches RetryTurn → sends retry_turn channel event
    → Server creates AgentRetry interaction, re-triggers execution

  [user clicks Stop during countdown]
    → Existing cancel flow → RetryCoordinator tears down → AgentError kind:"cancelled"
```

---

## Testing

- Unit tests for `RetryCoordinator`: backoff math, max attempts, cancel, non-retryable passthrough
- Unit tests for `classify_llm_error/2`: all HTTP status codes produce correct `{category, retryable}`
- Integration test: transient error → auto-retries → eventual success
- Integration test: transient error → auto-retries → exhaustion → user retry
- Client unit tests: `RetryBanner` countdown rendering, `ErrorBanner` CTA variants by category, `RetryTurn` action dispatching
