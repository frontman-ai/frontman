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
  defdelegate run(runtime, loop), to: SwarmAi.Runtime

  @doc "Returns true when a conversation/task id is running."
  @spec running?(atom(), String.t()) :: boolean()
  defdelegate running?(runtime, task_id), to: SwarmAi.Runtime

  @doc "Returns the number of active executions owned by a supervised runtime."
  @spec active_count(atom()) :: non_neg_integer()
  defdelegate active_count(runtime), to: SwarmAi.Runtime

  @doc false
  @spec registry_name(atom()) :: atom()
  defdelegate registry_name(runtime), to: SwarmAi.Runtime.Registry, as: :name

  @doc false
  @spec task_supervisor_name(atom()) :: atom()
  defdelegate task_supervisor_name(runtime), to: SwarmAi.Runtime

  @doc false
  @spec execution_supervisor_name(atom()) :: atom()
  defdelegate execution_supervisor_name(runtime), to: SwarmAi.Runtime

  @doc "Cancels a running execution by conversation/task id."
  @spec cancel(atom(), String.t()) :: :ok | {:error, :not_running}
  defdelegate cancel(runtime, task_id), to: SwarmAi.Runtime
end
