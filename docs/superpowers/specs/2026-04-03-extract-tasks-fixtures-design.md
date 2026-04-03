# Extract TasksFixtures Module

**Issue:** #777
**Date:** 2026-04-03

## Problem

The pattern `Ecto.UUID.generate() + Tasks.create_task() + PubSub.subscribe()` is copy-pasted across 14 test files with 60+ occurrences. `user_content/1` is inlined in at least 6 files. There is no `Test.Fixtures.Tasks` module despite every other domain having a fixtures module.

## Design

### New Module: `FrontmanServer.Test.Fixtures.Tasks`

**File:** `test/support/fixtures/tasks.ex`

```elixir
defmodule FrontmanServer.Test.Fixtures.Tasks do
  alias FrontmanServer.Tasks

  def task_fixture(scope, opts \\ []) do
    framework = Keyword.get(opts, :framework, "nextjs")
    task_id = Keyword.get(opts, :task_id, Ecto.UUID.generate())
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, framework)
    task_id
  end

  def task_with_pubsub_fixture(scope, opts \\ []) do
    task_id = task_fixture(scope, opts)
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))
    task_id
  end

  def user_content(text) do
    [%{"type" => "text", "text" => text}]
  end
end
```

### Additions to `FrontmanServer.Test.Fixtures.Tools`

Move from `execution_test.exs`:

- `question_args/0` — structured question tool input map
- `question_mcp_tool_defs/0` — list of interactive MCP tool definitions

These are generic interactive-tool fixtures, not specific to any one test file.

### Cleanup Targets

Each file gets `import FrontmanServer.Test.Fixtures.Tasks` and replaces manual patterns:

| File | Changes |
|------|---------|
| `tasks_test.exs` | Replace ~25 `Ecto.UUID.generate() + create_task` with `task_fixture(scope)` |
| `execution_test.exs` | Remove local `user_content/1`, `question_args/0`, `question_mcp_tool_defs/0`. Simplify `setup_task/1` and `setup_task_with_channel/1` to use `task_with_pubsub_fixture` / `task_fixture` internally |
| `error_propagation_test.exs` | Replace inline `user_content` and manual `create_task + subscribe` |
| `execution_sentry_test.exs` | Replace inline `user_content` and manual `create_task + subscribe` |
| `mcp_tool_broadcast_test.exs` | Replace inline `user_content` and two manual setup blocks |
| `sub_agent_mcp_routing_test.exs` | Replace manual `create_task + subscribe` |
| `tool_error_sentry_test.exs` | Replace manual `create_task` |
| `todos_test.exs` | Replace manual `create_task` |
| `tools_test.exs` | Replace manual `create_task` |
| `generate_title_test.exs` | Replace manual `create_task` |
| `otel_handler_test.exs` | Replace manual `create_task + subscribe` |
| `tasks_channel_test.exs` | Replace ~12 manual `create_task` calls (leave multi-task/cross-scope tests that need custom setup) |
| `task_channel_test.exs` | Replace remaining manual `create_task + subscribe_and_join` blocks where `join_task_channel` isn't used |

### What's NOT Touched

- `ChannelCase.join_task_channel/2` — serves a different purpose (channel + blocking agent)
- Test assertions or logic — purely setup DRY-up
- Tests that exercise `Tasks.create_task/3` directly (e.g., the `"creates task with framework"` test in `tasks_test.exs`) — these are testing the function itself, not using it as setup
- User registration setup — tests that need a user continue using `AccountsFixtures.user_scope_fixture/0` directly

## Testing

Run the full test suite after changes. No new tests needed — this is a pure refactoring. All existing tests must continue to pass with identical behavior.
