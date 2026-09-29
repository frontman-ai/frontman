defmodule SwarmAi.ParallelExecutor do
  @moduledoc """
  Runs tool executions with per-task deadlines.

  Accepts a list of `ToolExecution.t()` structs. PE is the sole execution
  authority — executors build descriptions, PE runs them.

  - `Sync` executions are spawned as supervised tasks with finite deadlines.
  - `Await` executions call their start MFA in PE's own process, then wait
    for `{:tool_result, tool_call_id, content, is_error}` in PE's receive loop.
    An infinite deadline creates no timer, so human input can arrive later.
  - Finite deadlines and Sync crashes return the error callback's canonical `ToolResult`.

  Returns `{:ok, [ToolResult.t()]}` with results in original call order.
  """

  alias SwarmAi.{ToolCall, ToolExecution, ToolResult}

  @type result :: {:ok, [ToolResult.t()]}

  @typep sync_entry :: %{
           kind: :sync,
           exec: ToolExecution.Sync.t(),
           timer: reference(),
           task: Task.t()
         }
  @typep await_entry :: %{
           kind: :await,
           exec: ToolExecution.Await.t(),
           timer: reference() | nil
         }
  @typep pending_entry :: sync_entry() | await_entry()
  @typep results_map :: %{ToolCall.id() => ToolResult.t()}
  @typep pending :: %{reference() => pending_entry()}
  @typep awaiting :: %{term() => reference()}

  @doc """
  Runs all executions concurrently and collects results with per-tool deadlines.

  `on_wait` receives `true` only while all pending tools have infinite deadlines,
  and `false` before handling a result or continuing execution.
  """
  @spec run([ToolExecution.t()], pid() | atom(), (boolean() -> :ok)) :: result()
  def run(executions, task_supervisor, on_wait \\ fn _waiting -> :ok end) do
    {pending, awaiting} = spawn_all(executions, task_supervisor)
    tool_calls = Enum.map(executions, & &1.tool_call)
    results_map = collect_results(pending, awaiting, %{}, on_wait)
    {:ok, finalize(tool_calls, results_map)}
  end

  @doc """
  Runs executions one at a time and preserves original call order.
  """
  @spec run_serial([ToolExecution.t()], pid() | atom(), (boolean() -> :ok)) :: result()
  def run_serial(executions, task_supervisor, on_wait \\ fn _waiting -> :ok end) do
    results =
      Enum.map(executions, fn exec ->
        {:ok, [result]} = run([exec], task_supervisor, on_wait)
        result
      end)

    {:ok, results}
  end

  @spec spawn_all([ToolExecution.t()], pid() | atom()) :: {pending(), awaiting()}
  defp spawn_all(executions, task_supervisor) do
    Enum.reduce(executions, {%{}, %{}}, fn exec, {pending, awaiting} ->
      case exec do
        %ToolExecution.Sync{} ->
          task = spawn_sync(exec, task_supervisor)
          timer = start_timer(task.ref, exec.timeout_ms)
          entry = %{kind: :sync, exec: exec, timer: timer, task: task}
          {Map.put(pending, task.ref, entry), awaiting}

        %ToolExecution.Await{} ->
          ref = make_ref()
          {mod, fun, args} = exec.start
          apply(mod, fun, args ++ [exec.tool_call])
          timer = start_timer(ref, exec.timeout_ms)
          entry = %{kind: :await, exec: exec, timer: timer}
          {Map.put(pending, ref, entry), Map.put(awaiting, exec.tool_call.id, ref)}
      end
    end)
  end

  defp start_timer(_ref, :infinity), do: nil

  defp start_timer(ref, timeout_ms) when is_integer(timeout_ms) and timeout_ms > 0 do
    Process.send_after(self(), {:deadline, ref}, timeout_ms)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer), do: Process.cancel_timer(timer)

  @spec collect_results(pending(), awaiting(), results_map(), (boolean() -> :ok)) :: results_map()
  defp collect_results(pending, _awaiting, results, _on_wait) when pending == %{}, do: results

  defp collect_results(pending, awaiting, results, on_wait) do
    waiting = Enum.all?(pending, fn {_ref, entry} -> entry.timer == nil end)
    :ok = on_wait.(waiting)

    receive do
      {ref, result} when is_map_key(pending, ref) ->
        :ok = on_wait.(false)
        Process.demonitor(ref, [:flush])
        %{timer: timer, exec: exec} = Map.fetch!(pending, ref)
        cancel_timer(timer)

        collect_results(
          Map.delete(pending, ref),
          awaiting,
          Map.put(results, exec.tool_call.id, result),
          on_wait
        )

      {:DOWN, ref, :process, _pid, reason} when is_map_key(pending, ref) ->
        :ok = on_wait.(false)
        %{timer: timer, exec: exec} = Map.fetch!(pending, ref)
        cancel_timer(timer)

        error_result = error_result(exec, {:crashed, reason})

        collect_results(
          Map.delete(pending, ref),
          awaiting,
          Map.put(results, exec.tool_call.id, error_result),
          on_wait
        )

      {:tool_result, key, content, is_error} when is_map_key(awaiting, key) ->
        :ok = on_wait.(false)
        ref = Map.fetch!(awaiting, key)
        %{exec: exec, timer: timer} = Map.fetch!(pending, ref)
        cancel_timer(timer)

        result = ToolResult.make(exec.tool_call.id, content, is_error)

        collect_results(
          Map.delete(pending, ref),
          Map.delete(awaiting, key),
          Map.put(results, exec.tool_call.id, result),
          on_wait
        )

      {:deadline, ref} when is_map_key(pending, ref) ->
        :ok = on_wait.(false)
        handle_deadline(pending, awaiting, results, ref, on_wait)
    end
  end

  defp handle_deadline(pending, awaiting, results, ref, on_wait) do
    entry = Map.fetch!(pending, ref)
    exec = entry.exec

    case entry do
      %{kind: :sync, task: task} -> Task.shutdown(task, :brutal_kill)
      %{kind: :await} -> :ok
    end

    result = error_result(exec, :timeout)

    collect_results(
      Map.delete(pending, ref),
      Map.delete(awaiting, exec.tool_call.id),
      Map.put(results, exec.tool_call.id, result),
      on_wait
    )
  end

  defp error_result(exec, reason) do
    {mod, fun, args} = exec.on_error
    %ToolResult{id: id} = result = apply(mod, fun, args ++ [reason, exec.tool_call])
    true = id == exec.tool_call.id
    result
  end

  @spec spawn_sync(ToolExecution.Sync.t(), pid() | atom()) :: Task.t()
  defp spawn_sync(%{timeout_ms: timeout_ms} = exec, task_supervisor)
       when is_integer(timeout_ms) and timeout_ms > 0 do
    Task.Supervisor.async_nolink(task_supervisor, fn ->
      {mod, fun, args} = exec.run
      apply(mod, fun, args ++ [exec.tool_call])
    end)
  end

  @spec finalize([ToolCall.t()], results_map()) :: [ToolResult.t()]
  defp finalize(tool_calls, results_map) do
    Enum.map(tool_calls, fn tc -> Map.fetch!(results_map, tc.id) end)
  end
end
