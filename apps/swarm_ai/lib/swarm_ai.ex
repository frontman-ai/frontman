defmodule SwarmAi do
  @moduledoc """
  Public API for supervised SwarmAi loop execution.

  Add `SwarmAi` to your supervision tree, then run loops through the
  top-level API:

      children = [
        {SwarmAi, name: MyApp.AgentRuntime}
      ]

      {:ok, pid} = SwarmAi.run(MyApp.AgentRuntime, loop)
      SwarmAi.running?(MyApp.AgentRuntime, loop.task_id)
      SwarmAi.cancel(MyApp.AgentRuntime, loop.task_id)

  SwarmAi owns execution lifecycle, cancellation, telemetry, and execution
  events. Callers provide LLM messages, tool execution, and event dispatch on
  the loop.
  """

  require Logger

  alias SwarmAi.Loop

  @doc "Returns a child spec for a supervised SwarmAi runtime."
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: {__MODULE__, name},
      start: {SwarmAi.Supervisor, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc "Runs a loop in a supervised runtime."
  @spec run(atom(), Loop.t()) ::
          {:ok, pid()} | {:error, :already_running | {:start_failed, term()}}
  def run(runtime, %Loop{} = loop) when is_atom(runtime) do
    case DynamicSupervisor.start_child(
           execution_supervisor_name(runtime),
           {SwarmAi.ExecutionWorker, {runtime, loop}}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> {:error, :already_running}
      {:error, reason} -> {:error, {:start_failed, reason}}
    end
  end

  @doc "Returns true when a conversation/task id is running."
  @spec running?(atom(), String.t()) :: boolean()
  def running?(runtime, task_id) when is_atom(runtime) and is_binary(task_id),
    do: running_lookup(runtime, task_id) != []

  @doc "Cancels a running execution by conversation/task id."
  @spec cancel(atom(), String.t()) :: :ok | {:error, :not_running}
  def cancel(runtime, task_id) when is_atom(runtime) and is_binary(task_id) do
    case running_lookup(runtime, task_id) do
      [{pid, _}] ->
        Logger.info("Cancelling execution for #{inspect(task_id)}")
        Process.exit(pid, :cancelled)
        :ok

      [] ->
        {:error, :not_running}
    end
  end

  @doc false
  @spec registry_name(atom()) :: atom()
  def registry_name(runtime), do: :"#{runtime}.Registry"

  @doc false
  @spec task_supervisor_name(atom()) :: atom()
  def task_supervisor_name(runtime), do: :"#{runtime}.TaskSupervisor"

  @doc false
  @spec execution_supervisor_name(atom()) :: atom()
  def execution_supervisor_name(runtime), do: :"#{runtime}.ExecutionSupervisor"

  @doc false
  defp running_lookup(runtime, task_id) do
    Registry.lookup(
      registry_name(runtime),
      task_id
    )
  end
end
