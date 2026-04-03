# Extract TasksFixtures Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract duplicated task creation and setup patterns across 13 test files into a reusable `FrontmanServer.Test.Fixtures.Tasks` module, and move tool-related fixtures into `Test.Fixtures.Tools`.

**Architecture:** Create a single fixture module with `task_fixture/2`, `task_with_pubsub_fixture/2`, and `user_content/1`. Update each test file to import and use the fixtures in place of manual `Ecto.UUID.generate() + Tasks.create_task()` calls. Move `question_args/0` and `question_mcp_tool_defs/0` from `execution_test.exs` to `Test.Fixtures.Tools`.

**Tech Stack:** Elixir, Phoenix PubSub, Ecto

---

## File Map

- **Create:** `apps/frontman_server/test/support/fixtures/tasks.ex` — new fixture module
- **Modify:** `apps/frontman_server/test/support/fixtures/tools.ex` — add question fixtures
- **Modify:** `apps/frontman_server/test/frontman_server/tasks/execution_test.exs` — use fixtures, remove local helpers
- **Modify:** `apps/frontman_server/test/frontman_server/tasks_test.exs` — use `task_fixture` where task is setup, not under test
- **Modify:** `apps/frontman_server/test/frontman_server/tasks/execution/error_propagation_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server/tasks/execution/execution_sentry_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server/tasks/execution/mcp_tool_broadcast_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server/tasks/execution/sub_agent_mcp_routing_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server/tasks/execution/tool_error_sentry_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server/tasks/todos_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server/tools_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server/workers/generate_title_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server/observability/otel_handler_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server_web/channels/tasks_channel_test.exs` — use fixtures
- **Modify:** `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs` — use fixtures where applicable

---

### Task 1: Create `FrontmanServer.Test.Fixtures.Tasks` module

**Files:**
- Create: `apps/frontman_server/test/support/fixtures/tasks.ex`

- [ ] **Step 1: Create the fixture module**

```elixir
defmodule FrontmanServer.Test.Fixtures.Tasks do
  @moduledoc """
  Reusable fixtures for task test setup.

  Provides helpers for creating tasks and subscribing to their PubSub topics,
  replacing the manual `Ecto.UUID.generate() + Tasks.create_task()` pattern.
  """

  alias FrontmanServer.Tasks

  @doc """
  Create a task and return its ID.

  ## Options

    * `:framework` - framework string, defaults to `"nextjs"`
    * `:task_id` - explicit task ID, defaults to `Ecto.UUID.generate()`
  """
  @spec task_fixture(FrontmanServer.Accounts.Scope.t(), keyword()) :: String.t()
  def task_fixture(scope, opts \\ []) do
    framework = Keyword.get(opts, :framework, "nextjs")
    task_id = Keyword.get(opts, :task_id, Ecto.UUID.generate())
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, framework)
    task_id
  end

  @doc """
  Create a task and subscribe the calling process to its PubSub topic.

  Accepts the same options as `task_fixture/2`.
  """
  @spec task_with_pubsub_fixture(FrontmanServer.Accounts.Scope.t(), keyword()) :: String.t()
  def task_with_pubsub_fixture(scope, opts \\ []) do
    task_id = task_fixture(scope, opts)
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))
    task_id
  end

  @doc """
  Build a user message content block.

      iex> user_content("Hello")
      [%{"type" => "text", "text" => "Hello"}]
  """
  @spec user_content(String.t()) :: [map()]
  def user_content(text), do: [%{"type" => "text", "text" => text}]
end
```

- [ ] **Step 2: Verify compilation**

Run: `cd apps/frontman_server && mix compile --warnings-as-errors`
Expected: Compiles with 0 errors, 0 warnings.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/test/support/fixtures/tasks.ex
git commit -m "refactor: add Test.Fixtures.Tasks module (#777)"
```

---

### Task 2: Add question fixtures to `Test.Fixtures.Tools`

**Files:**
- Modify: `apps/frontman_server/test/support/fixtures/tools.ex`

- [ ] **Step 1: Add `question_args/0` and `question_mcp_tool_defs/0`**

Add these two public functions at the end of the module, before the closing `end`:

```elixir
  @doc """
  Structured question tool input for interactive tool tests.
  """
  @spec question_args() :: map()
  def question_args do
    %{
      "questions" => [
        %{
          "question" => "Pick one",
          "header" => "Test",
          "options" => [%{"label" => "A", "description" => "Option A"}]
        }
      ]
    }
  end

  @doc """
  MCP tool definition list for the interactive `question` tool.
  """
  @spec question_mcp_tool_defs() :: [FrontmanServer.Tools.MCP.t()]
  def question_mcp_tool_defs do
    alias FrontmanServer.Tools.MCP

    [
      %MCP{
        name: "question",
        description: "Ask the user a question",
        input_schema: %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        visible_to_agent: true,
        execution_mode: :interactive
      }
    ]
  end
```

- [ ] **Step 2: Verify compilation**

Run: `cd apps/frontman_server && mix compile --warnings-as-errors`
Expected: Compiles with 0 errors, 0 warnings.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/test/support/fixtures/tools.ex
git commit -m "refactor: move question tool fixtures to Test.Fixtures.Tools (#777)"
```

---

### Task 3: Update `execution_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/tasks/execution_test.exs`

- [ ] **Step 1: Add import after the existing aliases (around line 20)**

Add after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.Test.Fixtures.Tools, only: [question_args: 0, question_mcp_tool_defs: 0]
```

- [ ] **Step 2: Remove local `user_content/1`, `question_args/0`, `question_mcp_tool_defs/0` helpers**

Delete these functions (lines ~26-55):
- `defp user_content(text), do: ...`
- `defp question_args do ... end`
- The `alias FrontmanServer.Tools.MCP` line before `question_mcp_tool_defs`
- `defp question_mcp_tool_defs do ... end`

- [ ] **Step 3: Simplify `setup_task/1` to use fixtures**

Replace the task creation + PubSub subscribe lines in `setup_task/1` with:

```elixir
  defp setup_task(_context) do
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "exec_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = task_with_pubsub_fixture(scope)

    {:ok, task_id: task_id, scope: scope}
  end
```

- [ ] **Step 4: Simplify `setup_task_with_channel/1` to use fixtures**

Replace the task creation lines in `setup_task_with_channel/1` with:

```elixir
  defp setup_task_with_channel(_context) do
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "exec_ch_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = task_fixture(scope)

    {:ok, _reply, socket} =
      FrontmanServerWeb.UserSocket
      |> socket("user_id", %{scope: scope})
      |> subscribe_and_join("task:#{task_id}", %{})

    {:ok, task_id: task_id, scope: scope, socket: socket}
  end
```

- [ ] **Step 5: Run tests for this file**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks/execution_test.exs`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/frontman_server/test/frontman_server/tasks/execution_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in execution_test (#777)"
```

---

### Task 4: Update `error_propagation_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/tasks/execution/error_propagation_test.exs`

- [ ] **Step 1: Add import and simplify setup**

Add import after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

Replace the setup block's task creation + PubSub lines (lines ~34-37) with:

```elixir
    setup do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      {:ok, user} =
        Accounts.register_user(%{
          email: "error_prop_#{System.unique_integer([:positive])}@test.local",
          name: "Test User",
          password: "testpassword123!"
        })

      scope = Scope.for_user(user)
      task_id = task_with_pubsub_fixture(scope, framework: "test-framework")

      {:ok, task_id: task_id, scope: scope}
    end
```

Replace inline `user_content = [%{"type" => "text", "text" => "..."}]` occurrences in test bodies with `user_content("...")`.

- [ ] **Step 2: Run tests**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks/execution/error_propagation_test.exs`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/test/frontman_server/tasks/execution/error_propagation_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in error_propagation_test (#777)"
```

---

### Task 5: Update `execution_sentry_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/tasks/execution/execution_sentry_test.exs`

- [ ] **Step 1: Add import and simplify setup**

Add import after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

Replace the task creation + PubSub lines in setup with:

```elixir
  setup do
    Sentry.Test.start_collecting_sentry_reports()

    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "exec_sentry_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = task_with_pubsub_fixture(scope, framework: "test-framework")

    {:ok, task_id: task_id, scope: scope}
  end
```

Replace inline `user_content = [%{"type" => "text", "text" => "..."}]` in test bodies with `user_content("...")`.

- [ ] **Step 2: Run tests**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks/execution/execution_sentry_test.exs`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/test/frontman_server/tasks/execution/execution_sentry_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in execution_sentry_test (#777)"
```

---

### Task 6: Update `mcp_tool_broadcast_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/tasks/execution/mcp_tool_broadcast_test.exs`

- [ ] **Step 1: Add import and simplify both setup blocks**

Add import after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

Replace the task creation + PubSub lines in **both** setup blocks (lines ~32-35 and ~102-105) with:

```elixir
      task_id = task_with_pubsub_fixture(scope, framework: "test-framework")
```

Replace inline `user_content = [%{"type" => "text", "text" => "..."}]` in test bodies with `user_content("...")`.

- [ ] **Step 2: Run tests**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks/execution/mcp_tool_broadcast_test.exs`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/test/frontman_server/tasks/execution/mcp_tool_broadcast_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in mcp_tool_broadcast_test (#777)"
```

---

### Task 7: Update `sub_agent_mcp_routing_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/tasks/execution/sub_agent_mcp_routing_test.exs`

- [ ] **Step 1: Add import and simplify setup**

Add import after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

Replace the task creation line in setup (line ~36) with:

```elixir
      task_id = task_fixture(scope, framework: "test-framework")
```

Note: This test uses channel join + PubSub subscribe separately, so use `task_fixture` not `task_with_pubsub_fixture`. The PubSub subscribe remains in setup after channel join.

- [ ] **Step 2: Run tests**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks/execution/sub_agent_mcp_routing_test.exs`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/test/frontman_server/tasks/execution/sub_agent_mcp_routing_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in sub_agent_mcp_routing_test (#777)"
```

---

### Task 8: Update `tool_error_sentry_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/tasks/execution/tool_error_sentry_test.exs`

- [ ] **Step 1: Add import and simplify setup**

Add import after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

Replace the task creation lines in setup with:

```elixir
    task_id = task_fixture(scope, framework: "test-framework")
```

(No PubSub subscribe in this file's setup.)

- [ ] **Step 2: Run tests**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks/execution/tool_error_sentry_test.exs`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/test/frontman_server/tasks/execution/tool_error_sentry_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in tool_error_sentry_test (#777)"
```

---

### Task 9: Update `todos_test.exs`, `tools_test.exs`, `generate_title_test.exs`

These three files follow the same pattern: DataCase-based setup with manual `create_task`.

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/tasks/todos_test.exs`
- Modify: `apps/frontman_server/test/frontman_server/tools_test.exs`
- Modify: `apps/frontman_server/test/frontman_server/workers/generate_title_test.exs`

- [ ] **Step 1: Update `todos_test.exs`**

Add import after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

Replace the setup's task creation (lines ~19-20) with:

```elixir
    task_id = task_fixture(scope, framework: "test-framework")
```

- [ ] **Step 2: Update `tools_test.exs`**

Add import after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

Replace the setup's task creation (lines ~21-22) with:

```elixir
    task_id = task_fixture(scope, framework: "test-framework")
    {:ok, task} = Tasks.get_task(scope, task_id)
    {:ok, task_id: task_id, task: task, scope: scope}
```

- [ ] **Step 3: Update `generate_title_test.exs`**

Add import after existing imports:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

Replace the manual task creation in the `"perform/1"` describe's test (around line 55) with:

```elixir
      task_id = task_fixture(scope)
```

- [ ] **Step 4: Run tests for all three files**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks/todos_test.exs test/frontman_server/tools_test.exs test/frontman_server/workers/generate_title_test.exs`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/frontman_server/test/frontman_server/tasks/todos_test.exs apps/frontman_server/test/frontman_server/tools_test.exs apps/frontman_server/test/frontman_server/workers/generate_title_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in todos, tools, generate_title tests (#777)"
```

---

### Task 10: Update `otel_handler_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/observability/otel_handler_test.exs`

- [ ] **Step 1: Add import and simplify setup**

Add import after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

Replace the task creation + PubSub lines in setup (lines ~72-73) with:

```elixir
    task_id = task_with_pubsub_fixture(scope, framework: "test-framework")
```

- [ ] **Step 2: Run tests**

Run: `cd apps/frontman_server && mix test test/frontman_server/observability/otel_handler_test.exs`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/test/frontman_server/observability/otel_handler_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in otel_handler_test (#777)"
```

---

### Task 11: Update `tasks_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/tasks_test.exs`

This file has ~25 manual `create_task` calls. Many tests ARE testing `create_task` directly and should NOT be changed. Only replace task creation that's used as setup for testing other functionality.

- [ ] **Step 1: Add import**

Add import after the alias block:

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

- [ ] **Step 2: Replace task creation in tests where task is setup, not under test**

Replace `task_id = Ecto.UUID.generate()` + `{:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")` with `task_id = task_fixture(scope)` in these describe blocks:
- `get_short_desc/2` (except tests that test error paths like "non-existent task")
- `get_task/2 authorization`
- `LLM message conversion`
- `add_agent_response/4`
- `add_tool_call/4`
- `add_tool_result/5`
- `submit_user_message/5`
- `enqueue_title_generation/4`
- Any other describe where create_task is just setup

Do NOT change:
- `create_task/3` describe block — these test the function itself
- Tests that use a specific framework value other than "nextjs" — pass `framework: "value"` option

- [ ] **Step 3: Replace inline `user_content` patterns**

Replace `[%{"type" => "text", "text" => "..."}]` with `user_content("...")` in test bodies where it appears as a message content argument.

- [ ] **Step 4: Run tests**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks_test.exs`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/frontman_server/test/frontman_server/tasks_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in tasks_test (#777)"
```

---

### Task 12: Update `tasks_channel_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server_web/channels/tasks_channel_test.exs`

This file uses `FrontmanServerWeb.ChannelCase` which provides `scope` in the setup context. It uses fully qualified `FrontmanServer.Tasks.create_task(scope, task_id, "nextjs")` calls.

- [ ] **Step 1: Add import**

Add at the top of the module (after aliases):

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

- [ ] **Step 2: Replace manual `create_task` calls**

Replace each `task_id = Ecto.UUID.generate()` + `{:ok, ^task_id} = FrontmanServer.Tasks.create_task(scope, task_id, "nextjs")` pair with `task_id = task_fixture(scope)`.

Leave multi-task tests (like lines ~394-397 where two tasks are created) and cross-scope tests (where `other_scope` creates a task) — these need explicit IDs or different scopes and should keep their manual setup. For cross-scope tests using `other_scope`, still replace with `task_fixture(other_scope, framework: "vite")` where the pattern is straightforward.

- [ ] **Step 3: Run tests**

Run: `cd apps/frontman_server && mix test test/frontman_server_web/channels/tasks_channel_test.exs`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add apps/frontman_server/test/frontman_server_web/channels/tasks_channel_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in tasks_channel_test (#777)"
```

---

### Task 13: Update `task_channel_test.exs`

**Files:**
- Modify: `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

Most of this file uses `join_task_channel` already. Only a few manual `create_task` calls remain.

- [ ] **Step 1: Add import**

Add at the top of the module (after aliases):

```elixir
  import FrontmanServer.Test.Fixtures.Tasks
```

- [ ] **Step 2: Replace remaining manual `create_task` calls**

Replace `task_id = Ecto.UUID.generate()` + `{:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")` with `task_id = task_fixture(scope)` at:
- Line ~53 (in "join task:<id>" describe)
- Lines ~1042-1043 (in reconnect describe setup)

Leave channel join patterns (`subscribe_and_join`) as-is — those are channel-specific setup.

- [ ] **Step 3: Run tests**

Run: `cd apps/frontman_server && mix test test/frontman_server_web/channels/task_channel_test.exs`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs
git commit -m "refactor: use Test.Fixtures.Tasks in task_channel_test (#777)"
```

---

### Task 14: Run full test suite and format

- [ ] **Step 1: Format all modified files**

Run: `cd apps/frontman_server && mix format`

- [ ] **Step 2: Run full test suite**

Run: `cd apps/frontman_server && mix test`
Expected: All tests pass with no regressions.

- [ ] **Step 3: Commit formatting if needed**

```bash
git add -u apps/frontman_server/test/
git commit -m "style: format test files (#777)"
```
