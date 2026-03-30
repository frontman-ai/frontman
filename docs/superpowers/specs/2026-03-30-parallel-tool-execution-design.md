# Parallel Tool Execution in SwarmAi

**Issue:** #743
**Date:** 2026-03-30
**Status:** Approved

## Problem

All tool calls in the SwarmAi agent loop execute sequentially. The LLM emits batches of independent tool calls (e.g., multiple `read_file` or `grep` calls), but `execute_loop/4` processes each `{:execute_tool, tc}` effect one at a time, blocking until completion before starting the next. This adds unnecessary latency proportional to batch size.

The LLM is also never told it can emit parallel tool calls -- `parallel_tool_calls` is supported by ReqLLM but never set in `LLMClient` opts.

## Approach

Blanket parallel execution via `Task.Supervisor.async_stream_nolink`. All tool types (backend, MCP, interactive) run concurrently in isolated Task processes. Interactive tools (e.g., `question`) simply block their individual Task until the human responds -- no special-casing needed.

### Why not partition interactive tools?

Interactive tools rarely appear in batches. Even if they did, each blocks independently in its own Task with no interference. The idle Task process cost is trivial in BEAM. Partitioning adds complexity for a marginal benefit that can be added later if needed.

## Architecture

### Current flow

```
execute_loop matches [{:execute_tool, tc} | rest]
  -> execute_tool_with_spawn(tc)      # blocks
  -> Loop.handle_tool_result(result)
  -> execute_loop(rest)                # next tool
```

### Proposed flow

```
execute_loop matches [{:execute_tool, _} | _]
  -> split_tool_effects(effects)       # collect all consecutive tool effects
  -> execute_tools_parallel(tool_calls)  # Task.Supervisor.async_stream_nolink
  -> Enum.reduce(results, loop, &Loop.handle_tool_result/2)
  -> execute_loop(rest)
```

The pure-functional core (Loop, Runner, Step, Effect) is untouched. The change is entirely in the side-effect shell (`swarm_ai.ex`).

## Detailed Design

### 1. Batching tool effects in `execute_loop/4`

Replace the single-tool pattern match with a batch collector:

```elixir
defp execute_loop(loop, [{:execute_tool, _} | _] = effects, tool_executor, callbacks) do
  {tool_effects, rest} = split_tool_effects(effects)
  tool_calls = Enum.map(tool_effects, fn {:execute_tool, tc} -> tc end)

  # Fire all on_tool_call callbacks up front
  Enum.each(tool_calls, callbacks.on_tool_call)

  # Execute tools (parallel or sequential based on supervisor availability)
  results =
    case callbacks[:task_supervisor] do
      nil -> execute_tools_sequential(loop, tool_calls, tool_executor)
      sup -> execute_tools_parallel(loop, tool_calls, tool_executor, sup)
    end

  # Feed results into the loop (pure-functional, no side effects)
  {updated_loop, new_effects} =
    Enum.reduce(results, {loop, []}, fn result, {loop_acc, effects_acc} ->
      {l, e} = Loop.handle_tool_result(loop_acc, result)
      {l, effects_acc ++ e}
    end)

  execute_loop(updated_loop, new_effects ++ rest, tool_executor, callbacks)
end
```

`split_tool_effects/1` splits leading consecutive `:execute_tool` effects from the rest:

```elixir
defp split_tool_effects(effects) do
  Enum.split_while(effects, &match?({:execute_tool, _}, &1))
end
```

### 2. Parallel execution with fault isolation

```elixir
defp execute_tools_parallel(loop, tool_calls, tool_executor, task_supervisor) do
  tool_calls
  |> Task.Supervisor.async_stream_nolink(
    task_supervisor,
    fn tc -> execute_tool_with_spawn(loop, tc, tool_executor) end,
    max_concurrency: 10,
    ordered: true,
    timeout: :timer.minutes(30)
  )
  |> Enum.zip(tool_calls)
  |> Enum.map(fn
    {{:ok, result}, _tc} -> result
    {{:exit, reason}, tc} ->
      ToolResult.make(tc.id, "Tool execution crashed: #{inspect(reason)}", true)
  end)
end
```

Key decisions:
- **`async_stream_nolink`**: Fault isolation. A crashing tool produces an error result instead of killing the agent loop.
- **`max_concurrency: 10`**: Bounds resource usage. Prevents runaway spawning if the LLM emits a large batch. Sub-agents spawned via `:spawn` within tools compound the load.
- **`ordered: true`**: Deterministic result ordering for reproducible behavior in tests.
- **`timeout: 30 minutes`**: Safety net. Individual tools have their own timeouts (60s for MCP, 24h for interactive), but this caps the overall batch.
- **Registry auto-cleanup**: BEAM's Registry removes entries when the owning process dies, so crashed Tasks don't leak Registry entries.

### 3. Sequential fallback

When no `task_supervisor` is provided, preserve current sequential behavior:

```elixir
defp execute_tools_sequential(loop, tool_calls, tool_executor) do
  Enum.map(tool_calls, &execute_tool_with_spawn(loop, &1, tool_executor))
end
```

### 4. Plumbing the Task.Supervisor

The `Task.Supervisor` reference flows through opts:

**`SwarmAi.Runtime` (`build_streaming_opts`):** Add `task_supervisor` to the opts passed to `run_streaming`:

```elixir
defp build_streaming_opts(opts, dispatcher, key, metadata, watcher) do
  Keyword.merge(opts,
    task_supervisor: task_supervisor_name(runtime),
    on_chunk: fn chunk -> ... end,
    on_response: fn response -> ... end,
    on_tool_call: fn tc -> ... end
  )
end
```

**`SwarmAi.run_streaming/3`:** Passes `:task_supervisor` from opts into callbacks map, making it available to `execute_loop`.

SwarmAi remains a pure library with no application supervision tree. The Runtime (or any caller) opts in to parallelism by providing a supervisor.

### 5. Enabling parallel tool calls from the LLM

In `LLMClient`'s `stream/3` implementation, add `parallel_tool_calls: true` to opts sent to ReqLLM:

```elixir
llm_opts =
  client.llm_opts
  |> Keyword.put_new(:tools, reqllm_tools)
  |> Keyword.put_new(:parallel_tool_calls, true)
  |> Keyword.reject(fn {_k, v} -> v == [] end)
```

Using `put_new` so callers can override to `false` if needed.

### 6. Disconnect/reconnect behavior

No change to current semantics:
- On disconnect, `TaskChannel.terminate/2` sends error results to registered PIDs via `notify_tool_result`
- With parallel execution, the registered PID is the Task process (not the agent process), but routing works identically -- `Registry.register/3` stores `self()` (the Task PID) and `notify_tool_result` sends to `caller_pid`
- The 24h safety timeout on interactive tools remains unchanged

## Files Changed

| File | Change |
|------|--------|
| `apps/swarm_ai/lib/swarm_ai.ex` | Refactor `execute_loop` `:execute_tool` clause to batch + parallel. Add `execute_tools_parallel/4`, `execute_tools_sequential/3`, `split_tool_effects/1` |
| `apps/swarm_ai/lib/swarm_ai/runtime.ex` | Pass `task_supervisor` in `build_streaming_opts` |
| `apps/frontman_server/lib/frontman_server/tasks/execution/llm_client.ex` | Add `parallel_tool_calls: true` to `llm_opts` in `stream/3` |
| `apps/swarm_ai/test/` | New tests for parallel execution |

No interface changes to `ToolExecutor`, `Loop`, `Runner`, `Step`, or `Effect`.

## Testing Strategy

### Unit tests (swarm_ai)

- Multiple tool effects execute concurrently (verify via timing)
- Results are correctly fed back into the loop regardless of completion order
- Task crashes produce error results (not loop crashes)
- Fallback to sequential when no `task_supervisor` provided
- `split_tool_effects` correctly separates tool effects from other effect types

### Integration test (swarm_ai)

- LLM returns multiple tool calls -> all execute -> results accumulate -> LLM called again with all results
- One tool in a batch crashes -> others complete -> loop continues with error result for crashed tool

### Existing tests

Existing `ToolExecutor` and `LLMClient` tests remain unchanged -- no interface modifications.
