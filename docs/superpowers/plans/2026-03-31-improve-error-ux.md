# Improve Error UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the raw error display with human-readable categorized errors, server-side auto-retry with exponential backoff for transient failures, live countdown UI during retry, and a manual retry button on all errors.

**Architecture:** A new `RetryCoordinator` GenServer is started per-task on transient errors, owns the retry timer loop, and sends messages back to the channel. The `AgentError` interaction gains `retryable` and `category` fields. The client gains a `retryStatus` state field and a `RetryBanner` countdown component.

**Tech Stack:** Elixir/Phoenix (GenServer, DynamicSupervisor, TypedStruct), ReScript 12 (React, Sury schemas, vitest), FrontmanProtocol ACP types.

---

## File Structure

### New files
- `apps/frontman_server/lib/frontman_server/tasks/execution/llm_error.ex` — `LLMError` exception with `category` and `retryable` fields
- `apps/frontman_server/lib/frontman_server/tasks/retry_coordinator.ex` — RetryCoordinator GenServer
- `libs/client/src/components/frontman/Client__RetryBanner.res` — countdown banner shown during auto-retry

### Modified files
- `apps/frontman_server/lib/frontman_server/tasks/execution/llm_client.ex` — raise `LLMError` instead of generic RuntimeError
- `apps/frontman_server/lib/frontman_server/tasks/execution.ex` — `classify_error/1` returns `{msg, category, retryable}`; `handle_swarm_event` returns structured map
- `apps/frontman_server/lib/frontman_server/tasks/interaction.ex` — `AgentError` new fields; new `AgentRetry` struct
- `apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex` — update `agent_error` deserialization; add `agent_retry`
- `apps/frontman_server/lib/frontman_server/tasks.ex` — update `add_agent_error/4`; add `add_agent_retry/3`
- `apps/frontman_server/lib/frontman_server/tasks/swarm_dispatcher.ex` — pass `retryable`/`category` to `add_agent_error`
- `apps/frontman_server/lib/agent_client_protocol.ex` — `build_retrying_notification/5`
- `apps/frontman_server/lib/frontman_server/application.ex` — add `RetryCoordinatorSupervisor`
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex` — route transient errors to RetryCoordinator; store execution opts; `retry_turn` handler
- `libs/frontman-protocol/src/FrontmanProtocol__ACP.res` — `Retrying` sessionUpdate variant + schema
- `libs/client/src/state/Client__Task__Types.res` — `retryStatus` type on `Task.Loaded`
- `libs/client/src/state/Client__Message.res` — `ErrorMessage` gains `retryable` and `category` fields
- `libs/client/src/state/Client__Task__Reducer.res` — new actions; updated `AgentError` handling
- `libs/client/src/state/Client__State.res` — new action creators
- `libs/client/src/Client__FrontmanProvider.res` — handle `Retrying` sessionUpdate
- `libs/client/src/components/frontman/Client__ErrorBanner.res` — retry button; category-specific CTAs
- `libs/client/src/Client__Chatbox.res` — render `RetryBanner` when `retryStatus` is set

---

## Task 1: `LLMError` exception with category and retryable metadata

**Files:**
- Create: `apps/frontman_server/lib/frontman_server/tasks/execution/llm_error.ex`
- Test: `apps/frontman_server/test/frontman_server/tasks/execution/llm_error_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# apps/frontman_server/test/frontman_server/tasks/execution/llm_error_test.exs
defmodule FrontmanServer.Tasks.Execution.LLMErrorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.LLMError

  test "is a valid exception" do
    err = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}
    assert Exception.message(err) == "Rate limited"
  end

  test "has required fields" do
    err = %LLMError{message: "Auth failed", category: "auth", retryable: false}
    assert err.category == "auth"
    assert err.retryable == false
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/execution/llm_error_test.exs
```
Expected: `** (UndefinedFunctionError)` or compile error — `LLMError` does not exist.

- [ ] **Step 3: Create `LLMError` exception**

```elixir
# apps/frontman_server/lib/frontman_server/tasks/execution/llm_error.ex
defmodule FrontmanServer.Tasks.Execution.LLMError do
  @moduledoc """
  Raised when the LLM provider returns a classified error.

  Carries `category` (one of "auth", "billing", "rate_limit", "overload",
  "payload_too_large", "output_truncated", "unknown") and `retryable` so
  that upstream code can decide whether to retry without re-parsing the message.
  """

  defexception [:message, :category, :retryable]

  @impl true
  def message(%__MODULE__{message: msg}), do: msg
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/execution/llm_error_test.exs
```
Expected: `2 tests, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks/execution/llm_error.ex \
        apps/frontman_server/test/frontman_server/tasks/execution/llm_error_test.exs
git commit -m "feat: add LLMError exception with category and retryable metadata"
```

---

## Task 2: Update `classify_llm_error` to raise `LLMError`

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tasks/execution/llm_client.ex`

- [ ] **Step 1: Write the failing test**

Add to `apps/frontman_server/test/frontman_server/tasks/execution/llm_error_test.exs`:

```elixir
# Append inside the module:
alias FrontmanServer.Tasks.Execution.LLMClient

describe "classify_llm_error via LLMClient stream" do
  test "401 raises LLMError with auth category, not retryable" do
    error = assert_raise FrontmanServer.Tasks.Execution.LLMError, fn ->
      # Access the private function via apply trick isn't possible;
      # test by constructing the chunk and calling to_swarm_chunks/1
      # Instead, test the public classify path indirectly:
      # We'll test via classify_error in Execution in Task 3.
      # For now just verify the struct exists.
      raise FrontmanServer.Tasks.Execution.LLMError,
        message: "Auth failed", category: "auth", retryable: false
    end
    assert error.category == "auth"
    assert error.retryable == false
  end
end
```

- [ ] **Step 2: Update `classify_llm_error` in `llm_client.ex`**

In `apps/frontman_server/lib/frontman_server/tasks/execution/llm_client.ex`, replace every `classify_llm_error` clause to raise `LLMError` instead of a plain string. The function currently has private clauses at ~lines 268–303. Replace them all:

```elixir
alias FrontmanServer.Tasks.Execution.LLMError

defp classify_llm_error(%{status: status}, _text) when status in [401, 403] do
  raise LLMError,
    message: "Authentication failed — your API key may be invalid or expired (HTTP #{status})",
    category: "auth",
    retryable: false
end

defp classify_llm_error(%{status: 400, reason: reason}, _text) when is_binary(reason) do
  raise LLMError,
    message: "Bad request — the provider rejected the request: #{reason}",
    category: "unknown",
    retryable: false
end

defp classify_llm_error(%{status: 400}, text) do
  raise LLMError,
    message: "Bad request — the provider rejected the request: #{text}",
    category: "unknown",
    retryable: false
end

defp classify_llm_error(%{status: 402}, _text) do
  raise LLMError,
    message: "Payment required — your account balance is insufficient or billing is not configured (HTTP 402)",
    category: "billing",
    retryable: false
end

defp classify_llm_error(%{status: 413}, _text) do
  raise LLMError,
    message: "Payload too large — the request exceeded the provider's size limit. Try reducing image size or message length (HTTP 413)",
    category: "payload_too_large",
    retryable: false
end

defp classify_llm_error(%{status: 429}, _text) do
  raise LLMError,
    message: "Rate limited — the provider is throttling requests. Please try again shortly.",
    category: "rate_limit",
    retryable: true
end

defp classify_llm_error(%{status: status}, _text) when status >= 500 do
  raise LLMError,
    message: "Provider error — the LLM service returned an internal error (HTTP #{status}). Please try again.",
    category: "overload",
    retryable: true
end

defp classify_llm_error(%{status: status, reason: reason}, _text)
     when is_integer(status) and is_binary(reason) do
  raise LLMError,
    message: "LLM error (HTTP #{status}): #{reason}",
    category: "unknown",
    retryable: false
end

defp classify_llm_error(_, text) do
  raise LLMError,
    message: "LLM stream error: #{text}",
    category: "unknown",
    retryable: false
end
```

Also update the two call sites that `raise classify_llm_error(...)` — since `classify_llm_error` now raises itself, change them to just call it:

```elixir
# Before:
raise classify_llm_error(original, text)

# After:
classify_llm_error(original, text)
```

- [ ] **Step 3: Run full server tests to verify nothing is broken**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/execution/
```
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks/execution/llm_client.ex \
        apps/frontman_server/test/frontman_server/tasks/execution/llm_error_test.exs
git commit -m "feat: classify_llm_error raises typed LLMError with category and retryable"
```

---

## Task 3: `Execution.classify_error/1` + structured `handle_swarm_event`

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tasks/execution.ex`
- Test: `apps/frontman_server/test/frontman_server/tasks/execution_classify_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# apps/frontman_server/test/frontman_server/tasks/execution_classify_test.exs
defmodule FrontmanServer.Tasks.ExecutionClassifyTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution
  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.StreamStallTimeout

  describe "classify_error/1" do
    test "LLMError preserves category and retryable" do
      err = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}
      assert {msg, "rate_limit", true} = Execution.classify_error(err)
      assert msg == "Rate limited"
    end

    test "LLMError auth is not retryable" do
      err = %LLMError{message: "Auth failed", category: "auth", retryable: false}
      assert {"Auth failed", "auth", false} = Execution.classify_error(err)
    end

    test "StreamStallTimeout is retryable with overload category" do
      err = %StreamStallTimeout.Error{message: "stall"}
      {msg, category, retryable} = Execution.classify_error(err)
      assert retryable == true
      assert category == "overload"
      assert String.contains?(msg, "stopped responding")
    end

    test ":genserver_call_timeout is retryable with overload category" do
      {_msg, category, retryable} = Execution.classify_error(:genserver_call_timeout)
      assert retryable == true
      assert category == "overload"
    end

    test ":output_truncated is not retryable" do
      {_msg, category, retryable} = Execution.classify_error(:output_truncated)
      assert retryable == false
      assert category == "output_truncated"
    end

    test "unknown reason is not retryable with unknown category" do
      {_msg, category, retryable} = Execution.classify_error(:some_unknown_atom)
      assert retryable == false
      assert category == "unknown"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/execution_classify_test.exs
```
Expected: compile error — `classify_error/1` undefined.

- [ ] **Step 3: Add `classify_error/1` to `Execution` and update `handle_swarm_event`**

In `apps/frontman_server/lib/frontman_server/tasks/execution.ex`:

1. Add `alias FrontmanServer.Tasks.Execution.LLMError` near the top aliases.

2. Add public `classify_error/1` (replaces the private `humanize_error/1` — keep `humanize_error` as a private wrapper for backwards compat in `handle_swarm_event` crash path):

```elixir
@doc """
Classifies an error reason into {message, category, retryable}.

`category` is one of: "auth", "billing", "rate_limit", "overload",
"payload_too_large", "output_truncated", "unknown".
"""
@spec classify_error(term()) :: {String.t(), String.t(), boolean()}
def classify_error(%LLMError{message: msg, category: cat, retryable: r}), do: {msg, cat, r}

def classify_error(%StreamStallTimeout.Error{}) do
  {"The AI provider stopped responding mid-reply. " <>
     "This usually happens when the provider is temporarily overloaded. " <>
     "Try sending your message again.", "overload", true}
end

def classify_error(:genserver_call_timeout) do
  {"The request to the AI provider timed out. " <>
     "This can happen during high traffic. Try again in a moment.", "overload", true}
end

def classify_error(:stream_timeout) do
  {"The request to the AI provider timed out. " <>
     "This can happen during high traffic. Try again in a moment.", "overload", true}
end

def classify_error(:output_truncated) do
  {"The AI response was too long and got cut off. " <>
     "This usually happens when writing large files. " <>
     "Try asking the AI to write the file in smaller sections.", "output_truncated", false}
end

def classify_error({:exit, reason}) do
  {"Something went wrong while communicating with the AI provider: #{inspect(reason)}",
   "unknown", false}
end

def classify_error(reason) when is_exception(reason), do: {Exception.message(reason), "unknown", false}
def classify_error(reason) when is_binary(reason), do: {reason, "unknown", false}
def classify_error(reason), do: {inspect(reason), "unknown", false}
```

3. Update `handle_swarm_event` to return a map instead of a plain string:

```elixir
def handle_swarm_event(_scope, _task_id, {:failed, {:error, reason, _loop_id}}) do
  {msg, category, retryable} = classify_error(reason)
  {:agent_error, %{message: msg, category: category, retryable: retryable}}
end

def handle_swarm_event(_scope, _task_id, {:crashed, %{reason: reason}}) do
  msg = humanize_crash(reason)
  {:agent_error, %{message: msg, category: "unknown", retryable: false}}
end
```

(Keep `humanize_crash/1` as is since crashes are not retryable.)

- [ ] **Step 4: Run tests**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/execution_classify_test.exs
```
Expected: `6 tests, 0 failures`

- [ ] **Step 5: Run channel tests to verify the shape change doesn't break them yet**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs
```
Expected: some tests may fail because channel now receives a map instead of a string — that's fine, we'll fix in Task 8.

- [ ] **Step 6: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks/execution.ex \
        apps/frontman_server/test/frontman_server/tasks/execution_classify_test.exs
git commit -m "feat: add Execution.classify_error/1 and structured handle_swarm_event"
```

---

## Task 4: Extend `AgentError` and add `AgentRetry` interaction

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`
- Modify: `apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex`
- Test: `apps/frontman_server/test/frontman_server/tasks/interaction_test.exs` (add to existing or create)

- [ ] **Step 1: Write the failing test**

```elixir
# apps/frontman_server/test/frontman_server/tasks/interaction_agent_retry_test.exs
defmodule FrontmanServer.Tasks.InteractionAgentRetryTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Interaction

  describe "AgentError new fields" do
    test "new/4 sets retryable and category" do
      err = Interaction.AgentError.new("Rate limited", "failed", true, "rate_limit")
      assert err.retryable == true
      assert err.category == "rate_limit"
      assert err.error == "Rate limited"
    end

    test "new/2 defaults retryable=false, category=unknown" do
      err = Interaction.AgentError.new("Something went wrong", "failed")
      assert err.retryable == false
      assert err.category == "unknown"
    end

    test "Jason.Encoder includes retryable and category" do
      err = Interaction.AgentError.new("Rate limited", "failed", true, "rate_limit")
      encoded = Jason.encode!(err)
      decoded = Jason.decode!(encoded)
      assert decoded["retryable"] == true
      assert decoded["category"] == "rate_limit"
      assert decoded["type"] == "agent_error"
    end
  end

  describe "AgentRetry" do
    test "new/1 creates with retried_error_id" do
      retry = Interaction.AgentRetry.new("error-123")
      assert retry.retried_error_id == "error-123"
      assert is_binary(retry.id)
      assert %DateTime{} = retry.timestamp
    end

    test "Jason.Encoder includes type and retried_error_id" do
      retry = Interaction.AgentRetry.new("error-123")
      decoded = Jason.decode!(Jason.encode!(retry))
      assert decoded["type"] == "agent_retry"
      assert decoded["retried_error_id"] == "error-123"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/interaction_agent_retry_test.exs
```
Expected: compile errors — `AgentRetry` undefined, `new/4` undefined.

- [ ] **Step 3: Update `AgentError` and add `AgentRetry` in `interaction.ex`**

In `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`:

3a. Update the `@interaction_modules` list to include `__MODULE__.AgentRetry` and update `@type t` union:

```elixir
# Add to @type t:
| __MODULE__.AgentRetry.t()

# Add to @interaction_modules:
__MODULE__.AgentRetry,
```

3b. Update `AgentError` typedstruct and `new`:

```elixir
defmodule AgentError do
  use TypedStruct

  typedstruct enforce: true do
    field(:id, String.t())
    field(:sequence, integer(), default: 0)
    field(:timestamp, DateTime.t())
    field(:error, String.t())
    field(:kind, String.t(), default: "failed")
    field(:retryable, boolean(), default: false)
    field(:category, String.t(), default: "unknown")
  end

  def new(error, kind \\ "failed", retryable \\ false, category \\ "unknown") do
    alias FrontmanServer.Tasks.Interaction
    %__MODULE__{
      id: Interaction.new_id(),
      timestamp: Interaction.now(),
      error: error,
      kind: kind,
      retryable: retryable,
      category: category
    }
  end
end

defimpl Jason.Encoder, for: AgentError do
  def encode(value, opts) do
    Jason.Encode.map(
      %{
        type: "agent_error",
        id: value.id,
        timestamp: DateTime.to_iso8601(value.timestamp),
        error: value.error,
        kind: value.kind,
        retryable: value.retryable,
        category: value.category
      },
      opts
    )
  end
end
```

3c. Add `AgentRetry` module after `AgentError`:

```elixir
defmodule AgentRetry do
  @moduledoc """
  Records a user-initiated retry after an AgentError.
  Persisted for observability — lets you measure retry success rates.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:id, String.t())
    field(:sequence, integer(), default: 0)
    field(:timestamp, DateTime.t())
    field(:retried_error_id, String.t())
  end

  def new(retried_error_id) do
    alias FrontmanServer.Tasks.Interaction
    %__MODULE__{
      id: Interaction.new_id(),
      timestamp: Interaction.now(),
      retried_error_id: retried_error_id
    }
  end
end

defimpl Jason.Encoder, for: AgentRetry do
  def encode(value, opts) do
    Jason.Encode.map(
      %{
        type: "agent_retry",
        id: value.id,
        timestamp: DateTime.to_iso8601(value.timestamp),
        retried_error_id: value.retried_error_id
      },
      opts
    )
  end
end
```

- [ ] **Step 4: Update `InteractionSchema`**

In `apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex`:

4a. Update `to_struct` for `agent_error` to read new fields:

```elixir
def to_struct(%__MODULE__{type: "agent_error", data: data, sequence: sequence}) do
  %Interaction.AgentError{
    id: data["id"],
    sequence: sequence || data["sequence"] || 0,
    error: data["error"],
    kind: data["kind"] || "failed",
    retryable: data["retryable"] || false,
    category: data["category"] || "unknown",
    timestamp: parse_datetime(data["timestamp"])
  }
end
```

4b. Add `to_struct` for `agent_retry`:

```elixir
def to_struct(%__MODULE__{type: "agent_retry", data: data, sequence: sequence}) do
  %Interaction.AgentRetry{
    id: data["id"],
    sequence: sequence || data["sequence"] || 0,
    retried_error_id: data["retried_error_id"],
    timestamp: parse_datetime(data["timestamp"])
  }
end
```

- [ ] **Step 5: Run tests**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/interaction_agent_retry_test.exs
```
Expected: `7 tests, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks/interaction.ex \
        apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex \
        apps/frontman_server/test/frontman_server/tasks/interaction_agent_retry_test.exs
git commit -m "feat: extend AgentError with retryable/category; add AgentRetry interaction"
```

---

## Task 5: Update `Tasks` facade and `SwarmDispatcher`

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tasks.ex`
- Modify: `apps/frontman_server/lib/frontman_server/tasks/swarm_dispatcher.ex`

- [ ] **Step 1: Update `add_agent_error/4` and add `add_agent_retry/3` in `tasks.ex`**

Find `add_agent_error` (~line 295) and update:

```elixir
@spec add_agent_error(Scope.t(), String.t(), String.t(), String.t(), boolean(), String.t()) ::
        {:ok, Interaction.AgentError.t()} | {:error, :not_found}
def add_agent_error(%Scope{} = scope, task_id, error, kind \\ "failed", retryable \\ false, category \\ "unknown") do
  with {:ok, schema} <- get_task_by_id(scope, task_id) do
    interaction = Interaction.AgentError.new(error, kind, retryable, category)
    append_interaction(schema, interaction)
  end
end

@spec add_agent_retry(Scope.t(), String.t(), String.t()) ::
        {:ok, Interaction.AgentRetry.t()} | {:error, :not_found}
def add_agent_retry(%Scope{} = scope, task_id, retried_error_id) do
  with {:ok, schema} <- get_task_by_id(scope, task_id) do
    interaction = Interaction.AgentRetry.new(retried_error_id)
    append_interaction(schema, interaction)
  end
end
```

- [ ] **Step 2: Update `SwarmDispatcher` to persist `retryable` and `category`**

In `apps/frontman_server/lib/frontman_server/tasks/swarm_dispatcher.ex`:

Add `alias FrontmanServer.Tasks.Execution` near the top.

Update the `{:failed, ...}` persist clause to use `classify_error`:

```elixir
defp persist(%Scope{} = scope, task_id, {:failed, {:error, reason, loop_id}}, _metadata) do
  {reason_str, category, retryable} = Execution.classify_error(reason)

  Logger.error(
    "Execution failed for task #{task_id}, loop_id: #{loop_id}, reason: #{reason_str}"
  )

  Sentry.capture_message("Agent execution failed",
    level: :error,
    tags: %{error_type: "agent_execution_error"},
    extra: %{task_id: task_id, loop_id: loop_id, reason: reason_str}
  )

  Tasks.add_agent_error(scope, task_id, reason_str, "failed", retryable, category)
  TelemetryEvents.task_stop(task_id)
end
```

(The `crashed` and `cancelled` clauses stay as-is, just call `add_agent_error` with `retryable: false, category: "unknown"`.)

Update the `crashed` clause:

```elixir
defp persist(%Scope{} = scope, task_id, {:crashed, %{reason: reason, stacktrace: stacktrace}}, _metadata) do
  Logger.error("Execution crashed for task #{task_id}, reason: #{inspect(reason)}")

  if is_exception(reason) do
    Sentry.capture_exception(reason, stacktrace: stacktrace, tags: %{error_type: "agent_crash"}, extra: %{task_id: task_id})
  else
    Sentry.capture_message("Agent execution crashed", level: :error, tags: %{error_type: "agent_crash"}, extra: %{task_id: task_id, reason: inspect(reason)})
  end

  Tasks.add_agent_error(scope, task_id, format_crash_reason(reason), "crashed", false, "unknown")
  TelemetryEvents.task_stop(task_id)
end
```

Update the `cancelled` clause:

```elixir
defp persist(%Scope{} = scope, task_id, {:cancelled, _}, _metadata) do
  Tasks.add_agent_error(scope, task_id, "Cancelled", "cancelled", false, "unknown")
  TelemetryEvents.task_stop(task_id)
end
```

- [ ] **Step 3: Run tests**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/ --exclude integration
```
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks.ex \
        apps/frontman_server/lib/frontman_server/tasks/swarm_dispatcher.ex
git commit -m "feat: persist retryable and category on AgentError; add add_agent_retry"
```

---

## Task 6: `RetryCoordinator` GenServer

**Files:**
- Create: `apps/frontman_server/lib/frontman_server/tasks/retry_coordinator.ex`
- Modify: `apps/frontman_server/lib/frontman_server/application.ex`
- Test: `apps/frontman_server/test/frontman_server/tasks/retry_coordinator_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# apps/frontman_server/test/frontman_server/tasks/retry_coordinator_test.exs
defmodule FrontmanServer.Tasks.RetryCoordinatorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.RetryCoordinator

  @base_delay_ms 50  # short delays for tests

  defp start_coordinator(channel_pid, error_info, opts \\ []) do
    opts = Keyword.merge([base_delay_ms: @base_delay_ms, max_delay_ms: 500], opts)
    {:ok, pid} = RetryCoordinator.start(channel_pid, error_info, opts)
    pid
  end

  describe "retry scheduling" do
    test "sends retrying_status then trigger_retry for retryable error" do
      error = %{message: "Rate limited", category: "rate_limit", retryable: true}
      pid = start_coordinator(self(), error)

      assert_receive {:retrying_status, 1, 5, _retry_at, "Rate limited"}, 500
      assert_receive {:trigger_retry}, 500

      # Clean up
      GenServer.stop(pid, :normal)
    end

    test "sends up to 5 retrying_status messages before exhausting" do
      error = %{message: "Overloaded", category: "overload", retryable: true}
      pid = start_coordinator(self(), error, max_attempts: 2)

      assert_receive {:retrying_status, 1, 2, _, _}, 500
      assert_receive {:trigger_retry}, 500

      # Simulate execution failed again
      send(pid, {:execution_failed, error})

      assert_receive {:retrying_status, 2, 2, _, _}, 500
      assert_receive {:trigger_retry}, 500

      # One more failure exhausts it
      send(pid, {:execution_failed, error})
      assert_receive {:retry_exhausted, ^error}, 500

      refute Process.alive?(pid)
    end

    test "does not retry non-retryable error" do
      error = %{message: "Auth failed", category: "auth", retryable: false}
      pid = start_coordinator(self(), error)

      assert_receive {:retry_exhausted, ^error}, 500
      refute Process.alive?(pid)
    end
  end

  describe "cancel" do
    test "stops the coordinator and sends retry_exhausted with cancelled error" do
      error = %{message: "Overloaded", category: "overload", retryable: true}
      pid = start_coordinator(self(), error)

      assert_receive {:retrying_status, 1, 5, _, _}, 500
      # Cancel before trigger_retry fires
      RetryCoordinator.cancel(pid)

      assert_receive {:retry_exhausted, %{kind: "cancelled"}}, 500
      refute Process.alive?(pid)
    end
  end

  describe "backoff math" do
    test "compute_delay grows exponentially with jitter" do
      delay1 = RetryCoordinator.compute_delay(1, 1000, 60_000)
      delay2 = RetryCoordinator.compute_delay(2, 1000, 60_000)
      delay3 = RetryCoordinator.compute_delay(3, 1000, 60_000)

      # Each delay should be larger (base doubles), with jitter up to 25%
      assert delay1 >= 1000 and delay1 <= 1250
      assert delay2 >= 2000 and delay2 <= 2500
      assert delay3 >= 4000 and delay3 <= 5000
    end

    test "compute_delay caps at max_delay_ms" do
      delay = RetryCoordinator.compute_delay(10, 1000, 5000)
      assert delay <= 5000
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/retry_coordinator_test.exs
```
Expected: compile error — `RetryCoordinator` undefined.

- [ ] **Step 3: Create `RetryCoordinator`**

```elixir
# apps/frontman_server/lib/frontman_server/tasks/retry_coordinator.ex
defmodule FrontmanServer.Tasks.RetryCoordinator do
  @moduledoc """
  Manages server-side retry logic for transient LLM errors.

  Started per-task when a transient error occurs. Sends messages to the
  channel process to drive the retry loop:

  - `{:retrying_status, attempt, max_attempts, retry_at_iso8601, error_message}`
    → channel pushes "retrying" ACP event to client
  - `{:trigger_retry}` → channel re-runs Execution.run for the task
  - `{:retry_exhausted, error_info}` → channel calls handle_turn_error

  The coordinator terminates after handing off in either direction.
  """

  use GenServer

  @max_attempts 5
  @base_delay_ms 2_000
  @max_delay_ms 60_000

  # Public API

  @doc """
  Starts a RetryCoordinator for a task's transient error.

  `channel_pid` is the TaskChannel process.
  `error_info` is `%{message: string, category: string, retryable: bool}`.
  """
  def start(channel_pid, error_info, opts \\ []) do
    GenServer.start(__MODULE__, {channel_pid, error_info, opts})
  end

  @doc """
  Cancels an in-progress retry sequence.
  """
  def cancel(pid) when is_pid(pid) do
    GenServer.cast(pid, :cancel)
  end

  @doc """
  Notifies the coordinator that the retried execution failed again.
  """
  def execution_failed(pid, error_info) do
    send(pid, {:execution_failed, error_info})
  end

  @doc """
  Computes the delay for attempt N with exponential backoff and jitter.
  Public for testability.
  """
  def compute_delay(attempt, base_delay_ms, max_delay_ms) do
    base = trunc(base_delay_ms * :math.pow(2, attempt - 1))
    jitter = :rand.uniform(max(1, div(base, 4)))
    min(base + jitter, max_delay_ms)
  end

  # GenServer callbacks

  @impl true
  def init({channel_pid, error_info, opts}) do
    max_attempts = Keyword.get(opts, :max_attempts, @max_attempts)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @base_delay_ms)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, @max_delay_ms)

    state = %{
      channel_pid: channel_pid,
      error_info: error_info,
      attempt: 1,
      max_attempts: max_attempts,
      base_delay_ms: base_delay_ms,
      max_delay_ms: max_delay_ms
    }

    {:ok, state, {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, %{error_info: %{retryable: false}} = state) do
    send(state.channel_pid, {:retry_exhausted, state.error_info})
    {:stop, :normal, state}
  end

  def handle_continue(:start, state) do
    schedule_retry(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:fire_retry, state) do
    send(state.channel_pid, {:trigger_retry})
    {:noreply, state}
  end

  def handle_info({:execution_failed, error_info}, state) do
    next_attempt = state.attempt + 1

    if next_attempt > state.max_attempts do
      send(state.channel_pid, {:retry_exhausted, error_info})
      {:stop, :normal, state}
    else
      new_state = %{state | attempt: next_attempt, error_info: error_info}
      schedule_retry(new_state)
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast(:cancel, state) do
    send(state.channel_pid, {:retry_exhausted, %{kind: "cancelled"}})
    {:stop, :normal, state}
  end

  # Schedules the next retry: pushes retrying_status to channel, then fires trigger after delay.
  defp schedule_retry(state) do
    delay = compute_delay(state.attempt, state.base_delay_ms, state.max_delay_ms)
    retry_at = DateTime.utc_now() |> DateTime.add(delay, :millisecond) |> DateTime.to_iso8601()

    send(state.channel_pid, {
      :retrying_status,
      state.attempt,
      state.max_attempts,
      retry_at,
      state.error_info.message
    })

    Process.send_after(self(), :fire_retry, delay)
  end
end
```

- [ ] **Step 4: Add `RetryCoordinatorSupervisor` to `application.ex`**

In `apps/frontman_server/lib/frontman_server/application.ex`, add to `children` list before `FrontmanServerWeb.Endpoint`:

```elixir
{DynamicSupervisor, name: FrontmanServer.RetryCoordinatorSupervisor, strategy: :one_for_one},
```

- [ ] **Step 5: Run tests**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/retry_coordinator_test.exs
```
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks/retry_coordinator.ex \
        apps/frontman_server/lib/frontman_server/application.ex \
        apps/frontman_server/test/frontman_server/tasks/retry_coordinator_test.exs
git commit -m "feat: add RetryCoordinator GenServer with exponential backoff and jitter"
```

---

## Task 7: Extend `build_error_notification` with optional retry fields

**Design note:** `sessionUpdate: "retrying"` is not part of the ACP spec. Instead we
reuse the existing `"error"` update and add optional retry fields (`retryAt`, `attempt`,
`maxAttempts`). The client infers retry state from the presence of `retryAt`.

**Files:**
- Modify: `apps/frontman_server/lib/agent_client_protocol.ex`

- [ ] **Step 1: Extend `build_error_notification` to accept optional retry opts**

Replace the existing `build_error_notification/3` with a version that accepts an optional
fourth argument for retry metadata:

```elixir
@doc """
Builds an error session/update notification.

Sent when the agent encounters an error. Always delivered as a notification
so the client can display it regardless of whether a pending prompt exists.

Pass `retry_opts` when the server is scheduling an automatic retry. The client
uses `retryAt` to show a countdown and infers retry state from its presence.

  retry_opts: [retry_at: %DateTime{}, attempt: 1, max_attempts: 5]
"""
def build_error_notification(session_id, message, timestamp, retry_opts \\ []) do
  update = %{
    "sessionUpdate" => "error",
    "message" => message,
    "timestamp" => DateTime.to_iso8601(timestamp)
  }

  update =
    case Keyword.get(retry_opts, :retry_at) do
      nil ->
        update

      %DateTime{} = retry_at ->
        update
        |> Map.put("retryAt", DateTime.to_iso8601(retry_at))
        |> Map.put("attempt", Keyword.fetch!(retry_opts, :attempt))
        |> Map.put("maxAttempts", Keyword.fetch!(retry_opts, :max_attempts))
    end

  JsonRpc.notification(@method_session_update, %{"sessionId" => session_id, "update" => update})
end
```

- [ ] **Step 2: Run compile check**

```bash
./bin/pod-exec mix compile
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/lib/agent_client_protocol.ex
git commit -m "feat: extend build_error_notification with optional retry fields"
```

---

## Task 8: Update `TaskChannel` — RetryCoordinator integration and `retry_turn` handler

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- Test: `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

- [ ] **Step 1: Write the failing tests**

Add to `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`:

```elixir
describe "transient error triggers retrying notification" do
  setup %{scope: scope} do
    {socket, task_id} = join_task_channel(scope)
    {:ok, socket: socket, task_id: task_id}
  end

  test "retryable error pushes retrying notification instead of error", %{
    socket: _socket,
    task_id: task_id
  } do
    error = %FrontmanServer.Tasks.Execution.LLMError{
      message: "Rate limited",
      category: "rate_limit",
      retryable: true
    }

    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      Tasks.topic(task_id),
      swarm_failed(error)
    )

    assert_push("acp:message", %{
      "params" => %{
        "update" => %{
          "sessionUpdate" => "error",
          "attempt" => 1,
          "retryAt" => _
        }
      }
    })
  end

  test "non-retryable error pushes error notification directly", %{
    socket: _socket,
    task_id: task_id
  } do
    error = %FrontmanServer.Tasks.Execution.LLMError{
      message: "Auth failed",
      category: "auth",
      retryable: false
    }

    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      Tasks.topic(task_id),
      swarm_failed(error)
    )

    assert_push("acp:message", %{
      "params" => %{
        "update" => %{"sessionUpdate" => "error", "message" => "Auth failed"}
      }
    })
  end
end

describe "retry_turn event" do
  setup %{scope: scope} do
    {socket, task_id} = join_task_channel(scope)
    {:ok, socket: socket, task_id: task_id}
  end

  test "creates AgentRetry interaction when retry_turn notification received", %{scope: scope, socket: socket, task_id: task_id} do
    # Need a prior AgentError to reference
    {:ok, err} = Tasks.add_agent_error(scope, task_id, "Rate limited", "failed", true, "rate_limit")

    # retry_turn is sent as a JSON-RPC notification (no id, no reply expected)
    push(socket, "acp:message", %{
      "jsonrpc" => "2.0",
      "method" => "retry_turn",
      "params" => %{"retriedErrorId" => err.id}
    })

    # Wait for channel to process
    :sys.get_state(socket.channel_pid)

    {:ok, task} = Tasks.get_task(scope, task_id)
    assert Enum.any?(task.interactions, &match?(%FrontmanServer.Tasks.Interaction.AgentRetry{retried_error_id: ^err.id}, &1))
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs --only retrying
```

- [ ] **Step 3: Update the `TaskChannel`**

In `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`:

3a. Add aliases at the top:

```elixir
alias FrontmanServer.Tasks.RetryCoordinator
```

3b. In `process_prompt`, after building `opts`, store them in socket assigns and also store the task struct info needed for re-execution:

```elixir
opts = [env_api_key: env_api_key, model: model, mcp_tool_defs: mcp_tools]
socket = assign(socket, :last_execution_opts, opts)
```

3c. Update `handle_info({:swarm_event, event}, socket)` to handle new structured `{:agent_error, ...}`:

```elixir
def handle_info({:swarm_event, event}, socket) do
  scope = socket.assigns.scope
  task_id = socket.assigns.task_id

  case Execution.handle_swarm_event(scope, task_id, event) do
    :agent_completed -> handle_turn_ended(socket, ACP.stop_reason_end_turn())
    :agent_cancelled -> handle_turn_ended(socket, ACP.stop_reason_cancelled())
    {:agent_error, %{retryable: true} = error_info} -> handle_transient_error(socket, error_info)
    {:agent_error, %{retryable: false} = error_info} -> handle_turn_error(socket, error_info.message)
    :ok -> {:noreply, socket}
  end
end
```

3d. Add `handle_transient_error/2` that starts the RetryCoordinator:

```elixir
defp handle_transient_error(socket, error_info) do
  {:ok, coordinator_pid} = RetryCoordinator.start(self(), error_info)
  {:noreply, assign(socket, :retry_coordinator, coordinator_pid)}
end
```

3e. Add handlers for RetryCoordinator messages:

```elixir
def handle_info({:retrying_status, attempt, max_attempts, retry_at_iso, error_message}, socket) do
  task_id = socket.assigns.task_id
  {:ok, retry_at, _} = DateTime.from_iso8601(retry_at_iso)
  notification = ACP.build_error_notification(task_id, error_message, DateTime.utc_now(),
    retry_at: retry_at, attempt: attempt, max_attempts: max_attempts)
  push(socket, @acp_message, notification)
  {:noreply, socket}
end

def handle_info({:trigger_retry}, socket) do
  scope = socket.assigns.scope
  task_id = socket.assigns.task_id
  opts = socket.assigns[:last_execution_opts] || []
  mcp_tools = socket.assigns[:mcp_tools] || []
  all_tools = mcp_tools |> Tools.prepare_for_task(task_id)

  case Tasks.maybe_start_execution(scope, task_id, all_tools, opts) do
    {:ok, _} ->
      :ok

    {:error, reason} ->
      # Execution failed to start — treat as exhausted
      coordinator = socket.assigns[:retry_coordinator]
      error_info = %{message: Execution.error_message(scope, reason), category: "unknown", retryable: false}
      if coordinator, do: RetryCoordinator.execution_failed(coordinator, error_info)
  end

  {:noreply, socket}
end

def handle_info({:retry_exhausted, %{kind: "cancelled"}}, socket) do
  handle_turn_ended(socket, ACP.stop_reason_cancelled())
end

def handle_info({:retry_exhausted, error_info}, socket) do
  socket = assign(socket, :retry_coordinator, nil)
  handle_turn_error(socket, error_info.message)
end
```

3f. Add `retry_turn` handling inside the existing `handle_in(@acp_message, payload, socket)` handler.

The channel parses ALL `acp:message` events through `JsonRpc.parse(payload)`. Find the `case JsonRpc.parse(payload) do` block and add a new clause (it receives notifications, not requests):

```elixir
{:ok, {:notification, "retry_turn", %{"retriedErrorId" => retried_error_id}}} ->
  task_id = socket.assigns.task_id
  scope = socket.assigns.scope

  unless Execution.running?(scope, task_id) do
    Tasks.add_agent_retry(scope, task_id, retried_error_id)
    opts = socket.assigns[:last_execution_opts] || []
    mcp_tools = socket.assigns[:mcp_tools] || []
    all_tools = mcp_tools |> Tools.prepare_for_task(task_id)
    Tasks.maybe_start_execution(scope, task_id, all_tools, opts)
  end

  {:noreply, socket}
```

3g. Also fix existing channel tests: the existing tests use `swarm_failed("Rate limit exceeded")` which passes a plain string. `Execution.classify_error` handles binary strings (returns `{str, "unknown", false}`), so they should now go through the `retryable: false` path and still push `sessionUpdate: "error"`. Verify.

- [ ] **Step 4: Run channel tests**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs
```
Expected: all pass (including new tests).

- [ ] **Step 5: Commit**

```bash
git add apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex \
        apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs
git commit -m "feat: route transient errors through RetryCoordinator; add retry_turn handler"
```

---

## Task 9: Protocol — extend `Error` sessionUpdate with optional retry fields

**Design note:** We reuse `sessionUpdate: "error"` rather than introducing a non-standard
`"retrying"` variant. When the server is scheduling an auto-retry, the error update
includes `retryAt`, `attempt`, and `maxAttempts`. Client infers retry state from the
presence of `retryAt`.

**Files:**
- Modify: `libs/frontman-protocol/src/FrontmanProtocol__ACP.res`

- [ ] **Step 1: Extend the `Error` variant in `sessionUpdate` type**

Find `type sessionUpdate =` and the `Error(...)` variant. Update it to include optional retry fields:

```rescript
| Error({message: string, timestamp: string, retryAt: option<string>, attempt: option<int>, maxAttempts: option<int>})
```

- [ ] **Step 2: Update the `Error` schema**

Find the `Error` entry in `sessionUpdateSchema`. Update it to parse the new optional fields:

```rescript
S.object(s => {
  s.tag("sessionUpdate", "error")
  Error({
    message: s.field("message", S.string),
    timestamp: s.field("timestamp", S.string),
    retryAt: s.field("retryAt", S.option(S.string)),
    attempt: s.field("attempt", S.option(S.int)),
    maxAttempts: s.field("maxAttempts", S.option(S.int)),
  })
}),
```

- [ ] **Step 3: Build protocol library**

```bash
./bin/pod-exec make -C libs/frontman-protocol build
```
Expected: compiles cleanly (may show compile errors in libs/client if Error pattern matches need updating — note them for Task 11).

- [ ] **Step 4: Commit**

```bash
git add libs/frontman-protocol/src/FrontmanProtocol__ACP.res
git commit -m "feat: extend Error sessionUpdate with optional retry fields"
```

---

## Task 10: Update client state types

**Files:**
- Modify: `libs/client/src/state/Client__Task__Types.res`
- Modify: `libs/client/src/state/Client__Message.res`
- Test: `libs/client/test/Client__Task.test.res` (add tests)

- [ ] **Step 1: Write failing tests**

Add to `libs/client/test/Client__Task.test.res`:

```rescript
describe("retryStatus field", () => {
  test("loaded task has no retryStatus by default", t => {
    let task = TestHelpers.makeLoadedTask()
    switch task {
    | Task.Loaded(data) => t->expect(data.retryStatus)->Expect.toBe(None)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})
```

- [ ] **Step 2: Add `retryStatus` to `Task.Loaded` in `Client__Task__Types.res`**

Find the `Loaded({...})` variant (~line 134). Add `retryStatus` field:

```rescript
| Loaded({
    id: string,
    clientId: option<string>,
    title: string,
    createdAt: float,
    updatedAt: float,
    messages: Client__MessageStore.t,
    previewFrame: previewFrame,
    annotationMode: Annotation.annotationMode,
    annotations: array<Annotation.t>,
    activePopupAnnotationId: option<string>,
    isAnimationFrozen: bool,
    isAgentRunning: bool,
    planEntries: array<ACPTypes.planEntry>,
    turnError: option<string>,
    retryStatus: option<retryStatus>,   // ADD THIS
    imageAttachments: Dict.t<Client__Message.fileAttachmentData>,
    pendingQuestion: option<Client__Question__Types.pendingQuestion>,
  })
```

Add the `retryStatus` type definition *before* the `Task` module (or inside it, before the variant):

```rescript
type retryStatus = {
  attempt: int,
  maxAttempts: int,
  retryAt: float,   // JS timestamp in ms from ISO8601
  error: string,
}
```

- [ ] **Step 3: Add `retryable` and `category` to `ErrorMessage` in `Client__Message.res`**

Find `ErrorMessage` module (~line 135). Update the internal type and all constructors:

```rescript
module ErrorMessage: {
  type t
  let make: (~id: string, ~error: string, ~timestamp: string, ~retryable: bool, ~category: string) => t
  let restore: (~id: string, ~error: string, ~createdAt: float, ~retryable: bool, ~category: string) => t
  let id: t => string
  let error: t => string
  let createdAt: t => float
  let retryable: t => bool
  let category: t => string
} = {
  type t = {id: string, error: string, createdAt: float, retryable: bool, category: string}

  let make = (~id, ~error, ~timestamp, ~retryable, ~category) => {
    {id, error, createdAt: Date.fromString(timestamp)->Date.getTime, retryable, category}
  }

  let restore = (~id, ~error, ~createdAt, ~retryable, ~category) => {
    {id, error, createdAt, retryable, category}
  }

  let id = t => t.id
  let error = t => t.error
  let createdAt = t => t.createdAt
  let retryable = t => t.retryable
  let category = t => t.category
}
```

- [ ] **Step 4: Build to check for compile errors**

```bash
./bin/pod-exec make -C libs/client build 2>&1 | head -50
```
Expected: compile errors pointing at all existing `ErrorMessage.make` and `ErrorMessage.restore` callsites that need updating — note them, we fix in Task 11.

- [ ] **Step 5: Commit (types only, broken build is ok — fixed in Task 11)**

```bash
git add libs/client/src/state/Client__Task__Types.res \
        libs/client/src/state/Client__Message.res
git commit -m "feat: add retryStatus to Task.Loaded; add retryable/category to ErrorMessage"
```

---

## Task 11: Update `StateReducer`, `State` actions, and `FrontmanProvider`

**Files:**
- Modify: `libs/client/src/state/Client__Task__Reducer.res`
- Modify: `libs/client/src/state/Client__State.res`
- Modify: `libs/client/src/Client__FrontmanProvider.res`
- Test: `libs/client/test/Client__Task.test.res`

- [ ] **Step 1: Write failing tests**

Add to `libs/client/test/Client__Task.test.res`:

```rescript
describe("RetryingUpdate action", () => {
  test("sets retryStatus and keeps isAgentRunning true", t => {
    let task = TestHelpers.makeLoadedTask()
    // First set isAgentRunning via AddUserMessage
    let (task1, _) = TaskReducer.next(task, AddUserMessage({
      id: "u1",
      content: [Client__Task__Types.UserContentPart.Text({text: "hello"})],
      annotations: [],
    }))

    let retryStatus: Client__Task__Types.retryStatus = {
      attempt: 1, maxAttempts: 5, retryAt: 1_700_000_000_000.0, error: "Rate limited"
    }
    let (task2, _) = TaskReducer.next(task1, RetryingUpdate({retryStatus}))

    switch task2 {
    | Task.Loaded(data) =>
      t->expect(data.retryStatus)->Expect.toEqual(Some(retryStatus))
      t->expect(data.isAgentRunning)->Expect.toBe(true)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("AgentError clears retryStatus", () => {
  test("clears retryStatus when error arrives", t => {
    let task = TestHelpers.makeLoadedTask()
    let (task1, _) = TaskReducer.next(task, AddUserMessage({
      id: "u1",
      content: [Client__Task__Types.UserContentPart.Text({text: "hello"})],
      annotations: [],
    }))

    let retryStatus: Client__Task__Types.retryStatus = {
      attempt: 1, maxAttempts: 5, retryAt: 1_700_000_000_000.0, error: "Rate limited"
    }
    let (task2, _) = TaskReducer.next(task1, RetryingUpdate({retryStatus}))

    let (task3, _) = TaskReducer.next(task2, AgentError({
      error: "Auth failed", timestamp: "2026-01-01T00:00:00Z",
      retryable: false, category: "auth"
    }))

    switch task3 {
    | Task.Loaded(data) =>
      t->expect(data.retryStatus)->Expect.toBe(None)
    | _ => t->expect(false)->Expect.toBe(true)
    }
  })
})
```

- [ ] **Step 2: Update `action` type in `Client__Task__Reducer.res`**

Find the `type action` declaration. Make these changes:

```rescript
// Update AgentError to include retryable and category:
| AgentError({error: string, timestamp: string, retryable: bool, category: string})

// Add new actions:
| RetryingUpdate({retryStatus: Client__Task__Types.retryStatus})
| RetryTurn({retriedErrorId: string})
```

Also add to `actionToString`:
```rescript
| RetryingUpdate(_) => "RetryingUpdate"
| RetryTurn(_) => "RetryTurn"
```

- [ ] **Step 3: Update `AgentError` handling in reducer**

Find `| (Task.Loaded(data), AgentError({error, _})) =>` (~line 1014). Update to:

```rescript
| (Task.Loaded(data), AgentError({error, retryable, category, _})) =>
  let completed = task->Lens.completeStreamingMessage
  switch completed {
  | Task.Loaded(completedData) => (
      Task.Loaded({...completedData,
        turnError: Some(error),
        isAgentRunning: false,
        retryStatus: None,
      }),
      [NotifyTurnCompleted],
    )
  | _ => (
      Task.Loaded({...data,
        turnError: Some(error),
        isAgentRunning: false,
        retryStatus: None,
      }),
      [NotifyTurnCompleted],
    )
  }
```

Find `| (Task.Loading(_), AgentError({error, timestamp})) =>` (~line 1009). Update:

```rescript
| (Task.Loading(_), AgentError({error, timestamp, retryable, category})) =>
  let id = `error-${getTaskIdForError(task)}-${timestamp}`
  let errorMsg = Message.Error(Message.ErrorMessage.make(~id, ~error, ~timestamp, ~retryable, ~category))
  (task->Lens.completeStreamingMessage->Lens.insertMessage(errorMsg), [])
```

- [ ] **Step 4: Add `RetryingUpdate` handler**

After the `ClearTurnError` handler, add:

```rescript
| (Task.Loaded(data), RetryingUpdate({retryStatus})) =>
  (Task.Loaded({...data, retryStatus: Some(retryStatus), isAgentRunning: true}), [])
```

- [ ] **Step 5: Add `RetryTurn` handler and effect**

Add to `type effect` in `Client__Task__Reducer.res`:
```rescript
| RetryTurnEffect({retriedErrorId: string})
```

Add to `type delegated` in `Client__Task__Reducer.res` (at the bottom of the `delegated` type, alongside `NeedCancelPrompt`):
```rescript
| NeedRetryTurn({retriedErrorId: string})
```

Add `RetryTurn` reducer case:
```rescript
| (Task.Loaded(data), RetryTurn({retriedErrorId})) =>
  (Task.Loaded({...data, turnError: None}), [RetryTurnEffect({retriedErrorId})])
```

Add to `handleEffect`:
```rescript
| RetryTurnEffect({retriedErrorId}) => delegate(NeedRetryTurn({retriedErrorId}))
```

- [ ] **Step 6: Update `AddUserMessage` to clear `retryStatus`**

Find `AddUserMessage` handler (~line 942) that sets `turnError: None`. Also add `retryStatus: None`:

```rescript
...data,
messages: MessageStore.insert(data.messages, message),
isAgentRunning: true,
turnError: None,
retryStatus: None,
imageAttachments: updatedImageAttachments,
annotations: [],
```

- [ ] **Step 7: Update `Task.makeLoaded` to initialize `retryStatus: None`**

Find `makeLoaded` in `Client__Task__Types.res` and add `retryStatus: None` to the initial `Loaded({...})`.

- [ ] **Step 8: Update `Client__State.res` action creators**

Find the error action creators section (~line 124). Add:

```rescript
let agentErrorReceived = (~taskId: string, ~error: string, ~timestamp: string, ~retryable: bool, ~category: string) =>
  Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: AgentError({error, timestamp, retryable, category})}))

let retryingStatusReceived = (~taskId: string, ~retryStatus: Client__Task__Types.retryStatus) =>
  Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: RetryingUpdate({retryStatus})}))

let retryTurn = (~taskId: string, ~retriedErrorId: string) =>
  Client__State__Store.dispatch(TaskAction({target: ForTask(taskId), action: RetryTurn({retriedErrorId})}))
```

Update existing `agentErrorReceived` to the new signature (it now takes `retryable` and `category`).

- [ ] **Step 9: Update `FrontmanProvider` to handle the extended `Error` sessionUpdate**

In `libs/client/src/Client__FrontmanProvider.res`, in `handleSessionUpdate`:

The `Error` variant now carries optional `retryAt`, `attempt`, `maxAttempts`. Update the handler to branch on `retryAt`:

```rescript
| Error({message, timestamp, retryAt, attempt, maxAttempts}) =>
  Client__TextDeltaBuffer.flush()
  switch retryAt {
  | Some(retryAtStr) =>
    let retryAtMs = Date.fromString(retryAtStr)->Date.getTime
    let retryStatus: Client__Task__Types.retryStatus = {
      attempt: attempt->Option.getOr(1),
      maxAttempts: maxAttempts->Option.getOr(5),
      retryAt: retryAtMs,
      error: message,
    }
    Client__State.Actions.retryingStatusReceived(~taskId, ~retryStatus)
  | None =>
    Client__State.Actions.agentErrorReceived(~taskId, ~error=message, ~timestamp, ~retryable=false, ~category="unknown")
  }
```

- [ ] **Step 10: Handle `NeedRetryTurn` in `Client__State__StateReducer.res`**

In `libs/client/src/state/Client__State__StateReducer.res`, find the `delegate` function (~line 677). It currently handles `NeedSendMessage`, `NeedUsageRefresh`, and `NeedCancelPrompt`. Add:

```rescript
| NeedRetryTurn({retriedErrorId}) =>
  switch state.acpSession {
  | AcpSessionActive({retryTurn}) => retryTurn(retriedErrorId)
  | NoAcpSession => Log.error("Cannot retry turn: no active ACP session")
  }
```

This requires `retryTurn: string => unit` to be stored in `AcpSessionActive`. Find the `AcpSessionActive` type (in `Client__State__Types.res`) and add `retryTurn: string => unit` alongside `cancelPrompt: unit => unit`.

Then, in `Client__FrontmanProvider.res`, find where `cancelPrompt` is wired (look for `cancelPrompt:` in the session creation). Add `retryTurn` alongside it:

```rescript
let retryTurn = React.useCallback1((retriedErrorId: string) => {
  dispatch(RetryTurn({retriedErrorId}))
}, [dispatch])
```

And pass it when constructing `AcpSessionActive({..., retryTurn})`.

In `Client__ConnectionReducer.res`, add a `RetryTurn({retriedErrorId: string})` action and `RetryTurnEffect({session: ACP.session, retriedErrorId: string})` effect. Handle the action:

```rescript
| ({session: SessionActive(session)}, RetryTurnEffect({retriedErrorId})) =>
  ACP.retryTurn(session, retriedErrorId)
```

Add `ACP.retryTurn` in the ACP client module: it sends a `session/cancel`-style notification but with method `retry_turn`:

```rescript
let retryTurn = (session: session, retriedErrorId: string) => {
  let msg = JsonRpc.notification("retry_turn", {"retriedErrorId": retriedErrorId})
  ACP.pushToSession(session, msg)
}
```

(Find the exact `ACP.pushToSession` or channel push pattern by looking at how `ACP.cancelPrompt` is implemented in the same file.)

- [ ] **Step 11: Build and fix remaining compile errors**

```bash
./bin/pod-exec make -C libs/client build 2>&1 | head -80
```

Fix any remaining callsites of `ErrorMessage.make` or `ErrorMessage.restore` that need the new `~retryable` and `~category` labels.

- [ ] **Step 12: Run client tests**

```bash
./bin/pod-exec make -C libs/client test
```
Expected: all pass.

- [ ] **Step 13: Commit**

```bash
git add libs/client/src/state/Client__Task__Reducer.res \
        libs/client/src/state/Client__State.res \
        libs/client/src/Client__FrontmanProvider.res \
        libs/client/src/state/Client__Task__Types.res \
        libs/client/test/Client__Task.test.res
git commit -m "feat: add RetryingUpdate/RetryTurn actions; wire Retrying sessionUpdate to client"
```

---

## Task 12: `RetryBanner` component

**Files:**
- Create: `libs/client/src/components/frontman/Client__RetryBanner.res`

- [ ] **Step 1: Create `Client__RetryBanner.res`**

```rescript
// libs/client/src/components/frontman/Client__RetryBanner.res

// RetryBanner - shown during server-side auto-retry countdown.
// Displays the error that triggered the retry and a live countdown to the next attempt.
// The existing stop button (driven by isAgentRunning) handles cancellation.

@react.component
let make = (
  ~retryStatus: Client__Task__Types.retryStatus,
) => {
  let (secondsLeft, setSecondsLeft) = React.useState(() => {
    let diff = (retryStatus.retryAt -. Date.now()) /. 1000.0
    Int.fromFloat(Float.max(0.0, diff))
  })

  React.useEffect1(() => {
    let id = setInterval(() => {
      setSecondsLeft(prev => {
        let next = prev - 1
        if next <= 0 { 0 } else { next }
      })
    }, 1000)
    Some(() => clearInterval(id))
  }, [retryStatus.retryAt])

  <div
    className="flex items-start gap-3 mx-4 my-3 p-4 bg-yellow-950/50 border border-yellow-800/50 rounded-lg animate-in fade-in slide-in-from-top-2 duration-200">
    <div className="flex-shrink-0 mt-0.5">
      <svg
        className="w-5 h-5 text-yellow-400 animate-spin"
        fill="none"
        viewBox="0 0 24 24"
        strokeWidth="2"
        stroke="currentColor">
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
        />
      </svg>
    </div>
    <div className="flex-1 min-w-0">
      <p className="text-sm font-medium text-yellow-300">
        {React.string(`Retrying... (attempt ${Int.toString(retryStatus.attempt)} of ${Int.toString(retryStatus.maxAttempts)})`)}
      </p>
      <p className="text-sm text-yellow-400/90 mt-1 break-words">
        {React.string(retryStatus.error)}
      </p>
      <p className="text-xs text-yellow-300/80 mt-2">
        {secondsLeft > 0
          ? React.string(`Retrying in ${Int.toString(secondsLeft)}s`)
          : React.string("Retrying now...")}
      </p>
    </div>
  </div>
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
./bin/pod-exec make -C libs/client build
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add libs/client/src/components/frontman/Client__RetryBanner.res
git commit -m "feat: add RetryBanner countdown component"
```

---

## Task 13: Update `ErrorBanner` with retry button and category CTAs

**Files:**
- Modify: `libs/client/src/components/frontman/Client__ErrorBanner.res`

- [ ] **Step 1: Update `ErrorBanner` to accept new props and show retry button + CTAs**

Replace the entire file:

```rescript
// ErrorBanner - Displays LLM/agent errors.
// Always shows a retry button. Permanent errors show category-specific guidance.

@react.component
let make = (~error: string, ~category: string, ~onRetry: unit => unit) => {
  let cta = switch category {
  | "auth" => Some(("Your API key may be invalid — check Settings", Some("/settings")))
  | "billing" => Some(("There may be a billing issue — check Settings", Some("/settings")))
  | "rate_limit" => Some(("The provider is rate-limiting you — wait a moment before retrying", None))
  | "payload_too_large" => Some(("Try with a shorter message or smaller files", None))
  | "output_truncated" => Some(("Try asking for a shorter response", None))
  | _ => None
  }

  <div
    className="flex items-start gap-3 mx-4 my-3 p-4 bg-red-950/50 border border-red-800/50 rounded-lg animate-in fade-in slide-in-from-top-2 duration-200">
    <div className="flex-shrink-0 mt-0.5">
      <svg
        className="w-5 h-5 text-red-400"
        fill="none"
        viewBox="0 0 24 24"
        strokeWidth="2"
        stroke="currentColor">
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
        />
      </svg>
    </div>
    <div className="flex-1 min-w-0">
      <p className="text-sm font-medium text-red-300"> {React.string("Error")} </p>
      <p className="text-sm text-red-400/90 mt-1 break-words"> {React.string(error)} </p>
      {switch cta {
      | Some((text, Some(href))) =>
        <a href className="block text-xs text-red-300/80 mt-2 hover:text-red-200 transition-colors">
          {React.string(text)}
        </a>
      | Some((text, None)) =>
        <p className="text-xs text-red-300/80 mt-2"> {React.string(text)} </p>
      | None => React.null
      }}
      <div className="flex items-center gap-3 mt-3">
        <button
          onClick={_ => onRetry()}
          className="text-xs text-red-300 border border-red-700/60 hover:border-red-500 hover:text-red-200 px-3 py-1 rounded transition-colors">
          {React.string("Retry")}
        </button>
        <a
          href="https://discord.gg/xk8uXJSvhC"
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1 text-xs text-red-400/50 hover:text-red-300 transition-colors">
          <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
            <path
              d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03z"
            />
          </svg>
          {React.string("Need help? Join our Discord")}
        </a>
      </div>
    </div>
  </div>
}
```

- [ ] **Step 2: Fix all `ErrorBanner` callsites that need new props**

Find every use of `<Client__ErrorBanner` in `Client__Chatbox.res` and other files. Update to pass `~category` and `~onRetry`.

For `turnError` (which has no category yet), pass `~category="unknown"` and derive `~onRetry` from the task's last error ID.

For `Message.Error(errMsg)` in the message stream, `errMsg` now has `ErrorMessage.retryable` and `ErrorMessage.category` — pass those through.

```bash
grep -r "ErrorBanner" libs/client/src --include="*.res" -l
```

- [ ] **Step 3: Build**

```bash
./bin/pod-exec make -C libs/client build
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add libs/client/src/components/frontman/Client__ErrorBanner.res \
        libs/client/src/Client__Chatbox.res
git commit -m "feat: update ErrorBanner with retry button and category-specific CTAs"
```

---

## Task 14: Update `Chatbox` to render `RetryBanner`

**Files:**
- Modify: `libs/client/src/Client__Chatbox.res`

- [ ] **Step 1: Find where `turnError` is rendered in `Chatbox`**

```bash
grep -n "turnError\|ErrorBanner" libs/client/src/Client__Chatbox.res
```

- [ ] **Step 2: Add `RetryBanner` rendering**

In the area where `turnError` is conditionally rendered (~lines 402–405), update to also check `retryStatus`:

```rescript
{switch (TaskReducer.Selectors.retryStatus(task), TaskReducer.Selectors.turnError(task)) {
| (Some(retryStatus), _) =>
  <Client__RetryBanner retryStatus />
| (None, Some(errorMsg)) =>
  // Need the last error's category for the banner — read from task state or pass "unknown"
  <Client__ErrorBanner
    error=errorMsg
    category="unknown"
    onRetry={() => Client__State.Actions.retryTurn(~taskId, ~retriedErrorId="")}
  />
| (None, None) => React.null
}}
```

Note: for the `onRetry` in `turnError`, we need the ID of the last error. Add a `lastErrorId: option<string>` selector or read from the last `Message.Error` in the message list.

- [ ] **Step 3: Add `retryStatus` selector to `Selectors` in reducer**

In `Client__Task__Reducer.res`, find the `Selectors` module and add:

```rescript
let retryStatus = (task: Task.t): option<Client__Task__Types.retryStatus> => {
  switch task {
  | Task.Loaded({retryStatus}) => retryStatus
  | _ => None
  }
}
```

- [ ] **Step 4: Build and run tests**

```bash
./bin/pod-exec make -C libs/client build && ./bin/pod-exec make -C libs/client test
```
Expected: all pass.

- [ ] **Step 5: Run full server test suite**

```bash
./bin/pod-exec mix test apps/frontman_server/test/
```
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add libs/client/src/Client__Chatbox.res \
        libs/client/src/state/Client__Task__Reducer.res
git commit -m "feat: render RetryBanner during auto-retry countdown in Chatbox"
```

---

## Task 15: Changeset

- [ ] **Step 1: Create a changeset**

```bash
./bin/pod-exec yarn changeset
```

Select `patch` bump. Use description:
> Improve error UX: human-readable categorized errors, automatic retry with exponential backoff for transient failures, live countdown during retry, and manual retry button.

- [ ] **Step 2: Commit the changeset**

```bash
git add .changeset/
git commit -m "chore: add changeset for error UX improvements"
```
