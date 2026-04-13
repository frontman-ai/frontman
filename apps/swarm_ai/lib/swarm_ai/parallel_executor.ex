defmodule SwarmAi.ParallelExecutor do
  @moduledoc """
  Runs tool executions in parallel with per-task deadlines.

  Accepts a list of `ToolExecution.t()` structs. PE is the sole execution
  authority — executors build descriptions, PE runs them.

  - `Sync` executions are spawned as supervised tasks.
  - `Await` executions call their start MFA in PE's own process, then wait
    for `{:tool_result, message_key, content, is_error}` in PE's receive loop.

  ## Return values

  - `{:ok, [ToolResult.t()]}` — all tools completed; results in original call order
  - `{:halt, {:pause_agent, tool_call_id, tool_name, timeout_ms}}` — a `:pause_agent`
    deadline fired; all remaining tasks cancelled; first deadline wins
  """

  require Logger

  alias SwarmAi.{ToolCall, ToolExecution, ToolResult}

  @type halt_reason :: {:pause_agent, String.t(), String.t(), pos_integer()}
  @type result :: {:ok, [ToolResult.t()]} | {:halt, halt_reason()}

  @typep sync_entry :: %{
           kind: :sync,
           exec: ToolExecution.Sync.t(),
           timer: reference(),
           pid: pid()
         }
  @typep await_entry :: %{
           kind: :await,
           exec: ToolExecution.Await.t(),
           timer: reference()
         }
  @typep pending_entry :: sync_entry() | await_entry()
  @typep results_map :: %{ToolCall.id() => ToolResult.t()}
  @typep pending :: %{reference() => pending_entry()}
  @typep awaiting :: %{term() => reference()}

  @doc """
  Runs all executions concurrently and collects results with per-tool deadlines.
  """
  @spec run([ToolExecution.t()], pid() | atom()) :: result()
  def run(executions, task_supervisor) do
    {pending, awaiting} = spawn_all(executions, task_supervisor)

    tool_calls = Enum.map(executions, & &1.tool_call)

    case collect_results(pending, awaiting, %{}, task_supervisor) do
      {:ok, results_map} -> {:ok, finalize(tool_calls, results_map)}
      {:halt, _} = halt -> halt
    end
  end

  @spec spawn_all([ToolExecution.t()], pid() | atom()) :: {pending(), awaiting()}
  defp spawn_all(executions, task_supervisor) do
    Enum.reduce(executions, {%{}, %{}}, fn exec, {pending, awaiting} ->
      case exec do
        %ToolExecution.Sync{} ->
          task = spawn_sync(exec, task_supervisor)
          timer = Process.send_after(self(), {:deadline, task.ref}, exec.timeout_ms)
          entry = %{kind: :sync, exec: exec, timer: timer, pid: task.pid}
          {Map.put(pending, task.ref, entry), awaiting}

        %ToolExecution.Await{} ->
          ref = make_ref()
          {mod, fun, args} = exec.start
          # Called in PE's own process so self() = PE's pid, enabling the client
          # to route {:tool_result, ...} back to PE's mailbox.
          apply(mod, fun, args ++ [exec.tool_call])
          timer = Process.send_after(self(), {:deadline, ref}, exec.timeout_ms)
          entry = %{kind: :await, exec: exec, timer: timer}
          {Map.put(pending, ref, entry), Map.put(awaiting, exec.message_key, ref)}
      end
    end)
  end

  @spec collect_results(pending(), awaiting(), results_map(), pid() | atom()) ::
          {:ok, results_map()} | {:halt, halt_reason()}
  defp collect_results(pending, _awaiting, results, _task_supervisor) when pending == %{} do
    {:ok, results}
  end

  defp collect_results(pending, awaiting, results, task_supervisor) do
    receive do
      {ref, result} when is_map_key(pending, ref) ->
        # Sync task completed normally.
        Process.demonitor(ref, [:flush])
        %{timer: timer, exec: exec} = Map.fetch!(pending, ref)
        Process.cancel_timer(timer)

        collect_results(
          Map.delete(pending, ref),
          awaiting,
          Map.put(results, exec.tool_call.id, result),
          task_supervisor
        )

      {:DOWN, ref, :process, _pid, reason} when is_map_key(pending, ref) ->
        # Sync task crashed.
        %{timer: timer, exec: exec} = Map.fetch!(pending, ref)
        Process.cancel_timer(timer)

        error_result =
          ToolResult.make(exec.tool_call.id, "Tool crashed: #{inspect(reason)}", true)

        collect_results(
          Map.delete(pending, ref),
          awaiting,
          Map.put(results, exec.tool_call.id, error_result),
          task_supervisor
        )

      {:tool_result, key, content, is_error} when is_map_key(awaiting, key) ->
        # Await tool received its browser client response.
        ref = Map.fetch!(awaiting, key)
        %{exec: exec, timer: timer} = Map.fetch!(pending, ref)
        Process.cancel_timer(timer)

        result = build_await_result(exec, content, is_error)

        collect_results(
          Map.delete(pending, ref),
          Map.delete(awaiting, key),
          Map.put(results, exec.tool_call.id, result),
          task_supervisor
        )

      {:deadline, ref} when is_map_key(pending, ref) ->
        handle_deadline(pending, awaiting, results, ref, task_supervisor)
    end
  end

  @spec handle_deadline(pending(), awaiting(), results_map(), reference(), pid() | atom()) ::
          {:ok, results_map()} | {:halt, halt_reason()}
  defp handle_deadline(pending, awaiting, results, ref, task_supervisor) do
    %{kind: kind, exec: exec} = Map.fetch!(pending, ref)

    {mod, fun, args} = exec.on_timeout
    apply(mod, fun, args ++ [exec.tool_call, :triggered])

    awaiting =
      case kind do
        :sync ->
          %{pid: pid} = Map.fetch!(pending, ref)
          # terminate_child is synchronous — child is dead when it returns.
          # async_nolink sets up a monitor, so :DOWN is guaranteed in the mailbox.
          Task.Supervisor.terminate_child(task_supervisor, pid)

          receive do
            {:DOWN, ^ref, :process, _, _} -> :ok
          end

          awaiting

        :await ->
          Map.delete(awaiting, exec.message_key)
      end

    case exec.on_timeout_policy do
      :error ->
        error_result =
          ToolResult.make(exec.tool_call.id, "Tool timed out after #{exec.timeout_ms}ms", true)

        collect_results(
          Map.delete(pending, ref),
          awaiting,
          Map.put(results, exec.tool_call.id, error_result),
          task_supervisor
        )

      :pause_agent ->
        # First :pause_agent wins. Cancel all remaining.
        cancel_remaining(Map.delete(pending, ref), awaiting, task_supervisor)
        {:halt, {:pause_agent, exec.tool_call.id, exec.tool_call.name, exec.timeout_ms}}
    end
  end

  @spec cancel_remaining(pending(), awaiting(), pid() | atom()) :: :ok
  defp cancel_remaining(pending, awaiting, task_supervisor) do
    Enum.each(pending, fn {ref, entry} ->
      %{kind: kind, exec: exec, timer: timer} = entry
      # Cancel timer first — prevents a stale :deadline from firing mid-cleanup.
      Process.cancel_timer(timer)

      {mod, fun, args} = exec.on_timeout
      apply(mod, fun, args ++ [exec.tool_call, :cancelled])

      case kind do
        :sync ->
          Task.Supervisor.terminate_child(task_supervisor, entry.pid)

          receive do
            {:DOWN, ^ref, :process, _, _} -> :ok
          end

        :await ->
          # Remove from awaiting so stale {:tool_result, ...} messages are ignored.
          _ = Map.delete(awaiting, exec.message_key)
          :ok
      end
    end)
  end

  @spec spawn_sync(ToolExecution.Sync.t(), pid() | atom()) :: Task.t()
  defp spawn_sync(exec, task_supervisor) do
    Task.Supervisor.async_nolink(task_supervisor, fn ->
      {mod, fun, args} = exec.run
      apply(mod, fun, args ++ [exec.tool_call])
    end)
  end

  @spec build_await_result(ToolExecution.Await.t(), term(), boolean()) :: ToolResult.t()
  defp build_await_result(exec, content, is_error) do
    case exec.process_result do
      nil -> ToolResult.make(exec.tool_call.id, content, is_error)
      {mod, fun, args} -> apply(mod, fun, args ++ [exec.tool_call, content, is_error])
    end
  end

  # Re-order results map into a list matching the original tool_calls order.
  @spec finalize([ToolCall.t()], results_map()) :: [ToolResult.t()]
  defp finalize(tool_calls, results_map) do
    Enum.map(tool_calls, fn tc -> Map.fetch!(results_map, tc.id) end)
  end
end
