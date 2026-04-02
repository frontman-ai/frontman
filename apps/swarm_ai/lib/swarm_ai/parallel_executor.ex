defmodule SwarmAi.ParallelExecutor do
  @moduledoc """
  Runs tool calls in parallel with per-task deadlines.

  Each tool's execution policy (`timeout_ms`, `on_timeout`) controls what happens
  when its deadline fires. This module is called from the anonymous function built
  by `Runtime.do_wrap_executor/3`, which executes inside the Runtime task process.
  All `Process.send_after` timers and monitor messages target that process.

  ## Return values

  - `{:ok, [ToolResult.t()]}` — all tools completed (or errored gracefully); results
    in original call order
  - `{:halt, {:pause_agent, tool_name, timeout_ms}}` — a `:pause_agent` deadline fired;
    all remaining tasks cancelled; first deadline wins (ties non-deterministic)
  """

  require Logger

  alias SwarmAi.{Tool, ToolCall, ToolResult}

  @type halt_reason :: {:pause_agent, String.t(), pos_integer()}
  @type result :: {:ok, [ToolResult.t()]} | {:halt, halt_reason()}

  @typep pending_entry :: %{
           ref: reference(),
           pid: pid(),
           timer: reference(),
           tc: ToolCall.t(),
           tool_def: Tool.t()
         }
  @typep results_map :: %{ToolCall.id() => ToolResult.t()}
  @typep pending :: %{reference() => pending_entry()}

  @doc """
  Spawns all tool calls concurrently, collects results with per-task deadlines.

  `tool_map` is a name → `Tool.t()` index. Tool calls with names absent from
  `tool_map` are treated as LLM hallucinations — an error ToolResult is returned
  immediately without spawning a task.
  """
  @spec run([ToolCall.t()], %{String.t() => Tool.t()}, function(), pid() | atom()) :: result()
  def run(tool_calls, tool_map, executor, task_supervisor) do
    {immediates, pending} =
      tool_calls
      |> Enum.map(&spawn_or_reject(&1, tool_map, executor, task_supervisor))
      |> split_results()

    case collect_results(pending, immediates, task_supervisor) do
      {:ok, results_map} -> {:ok, finalize(tool_calls, results_map)}
      {:halt, _} = halt -> halt
    end
  end

  @spec spawn_or_reject(ToolCall.t(), map(), function(), pid() | atom()) ::
          {:immediate, {ToolCall.id(), ToolResult.t()}} | {:pending, reference(), pending_entry()}
  defp spawn_or_reject(tc, tool_map, executor, task_supervisor) do
    case Map.get(tool_map, tc.name) do
      nil ->
        result = ToolResult.make(tc.id, "Unknown tool: #{tc.name}", true)
        {:immediate, {tc.id, result}}

      tool_def ->
        # async_nolink: task crash does not kill this process.
        # async_nolink sets up a monitor (ref), so :DOWN is guaranteed in the mailbox.
        task =
          Task.Supervisor.async_nolink(task_supervisor, fn ->
            [result] = executor.([tc])
            result
          end)

        timer = Process.send_after(self(), {:deadline, task.ref}, tool_def.timeout_ms)

        entry = %{ref: task.ref, pid: task.pid, timer: timer, tc: tc, tool_def: tool_def}
        {:pending, task.ref, entry}
    end
  end

  @spec split_results(list()) :: {results_map(), pending()}
  defp split_results(entries) do
    Enum.reduce(entries, {%{}, %{}}, fn
      {:immediate, {id, result}}, {imm, pend} ->
        {Map.put(imm, id, result), pend}

      {:pending, ref, entry}, {imm, pend} ->
        {imm, Map.put(pend, ref, entry)}
    end)
  end

  @spec collect_results(pending(), results_map(), pid() | atom()) ::
          {:ok, results_map()} | {:halt, halt_reason()}
  defp collect_results(pending, results, _task_supervisor) when pending == %{} do
    {:ok, results}
  end

  defp collect_results(pending, results, task_supervisor) do
    receive do
      {ref, result} when is_map_key(pending, ref) ->
        Process.demonitor(ref, [:flush])
        %{timer: timer, tc: tc} = Map.fetch!(pending, ref)
        Process.cancel_timer(timer)

        collect_results(
          Map.delete(pending, ref),
          Map.put(results, tc.id, result),
          task_supervisor
        )

      {:DOWN, ref, :process, _pid, reason} when is_map_key(pending, ref) ->
        %{timer: timer, tc: tc} = Map.fetch!(pending, ref)
        Process.cancel_timer(timer)
        error_result = ToolResult.make(tc.id, "Tool crashed: #{inspect(reason)}", true)

        collect_results(
          Map.delete(pending, ref),
          Map.put(results, tc.id, error_result),
          task_supervisor
        )

      {:deadline, ref} when is_map_key(pending, ref) ->
        handle_deadline(pending, results, ref, task_supervisor)
    end
  end

  @spec handle_deadline(pending(), results_map(), reference(), pid() | atom()) ::
          {:ok, results_map()} | {:halt, halt_reason()}
  defp handle_deadline(pending, results, ref, task_supervisor) do
    %{tc: tc, tool_def: tool_def, pid: pid} = Map.fetch!(pending, ref)

    # terminate_child is synchronous — child is dead when it returns.
    # async_nolink sets up a monitor, so :DOWN is guaranteed in the mailbox.
    Task.Supervisor.terminate_child(task_supervisor, pid)

    receive do
      {:DOWN, ^ref, :process, _, _} -> :ok
    end

    case tool_def.on_timeout do
      :error ->
        error_result =
          ToolResult.make(tc.id, "Tool timed out after #{tool_def.timeout_ms}ms", true)

        collect_results(
          Map.delete(pending, ref),
          Map.put(results, tc.id, error_result),
          task_supervisor
        )

      :pause_agent ->
        # First :pause_agent wins. If multiple deadlines fire concurrently,
        # whichever :deadline message is dequeued first triggers the halt.
        cancel_remaining(pending, ref, task_supervisor)
        {:halt, {:pause_agent, tc.name, tool_def.timeout_ms}}
    end
  end

  @spec cancel_remaining(pending(), reference(), pid() | atom()) :: :ok
  defp cancel_remaining(pending, triggered_ref, task_supervisor) do
    pending
    |> Map.delete(triggered_ref)
    |> Enum.each(fn {ref, %{timer: timer, pid: pid}} ->
      # Cancel timer first — prevents a stale :deadline from firing mid-cleanup
      Process.cancel_timer(timer)
      Task.Supervisor.terminate_child(task_supervisor, pid)

      receive do
        {:DOWN, ^ref, :process, _, _} -> :ok
      end
    end)
  end

  # Re-order results map into a list matching the original tool_calls order.
  @spec finalize([ToolCall.t()], results_map()) :: [ToolResult.t()]
  defp finalize(tool_calls, results_map) do
    Enum.map(tool_calls, fn tc -> Map.fetch!(results_map, tc.id) end)
  end
end
