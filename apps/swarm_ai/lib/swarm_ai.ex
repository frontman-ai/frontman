defmodule SwarmAi do
  @moduledoc """
  Public API for supervised SwarmAi agent execution.

  Add `SwarmAi` to your supervision tree, then run agents through the
  top-level API:

      children = [
        {SwarmAi,
         name: MyApp.AgentRuntime,
         event_dispatcher: {MyApp.SwarmDispatcher, :dispatch, []}}
      ]

      agent = %MyAgent{id: task_id, messages: "Analyze this code"}

      {:ok, pid} = SwarmAi.run(MyApp.AgentRuntime, agent)
      SwarmAi.running?(MyApp.AgentRuntime, SwarmAi.Agent.id(agent))
      SwarmAi.cancel(MyApp.AgentRuntime, SwarmAi.Agent.id(agent))

  `SwarmAi.Agent.tool_executor/1` returns the batch tool builder and
  execution mode. SwarmAi owns execution lifecycle, concurrency, timeouts,
  cancellation, telemetry, and execution events.
  """

  require Logger

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

  @doc "Runs an agent in a supervised runtime."
  @spec run(atom(), SwarmAi.Agent.t()) :: {:ok, pid()} | {:error, term()}
  def run(runtime, agent) when is_atom(runtime) do
    case DynamicSupervisor.start_child(
           execution_supervisor_name(runtime),
           {SwarmAi.ExecutionWorker, {runtime, agent}}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> {:error, :already_running}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Returns true when an agent id is running."
  @spec running?(atom(), String.t()) :: boolean()
  def running?(runtime, id) when is_atom(runtime) and is_binary(id),
    do: running_lookup(runtime, id) != []

  @doc "Cancels a running execution by agent id."
  @spec cancel(atom(), String.t()) :: :ok | {:error, :not_running}
  def cancel(runtime, id) when is_atom(runtime) and is_binary(id) do
    case running_lookup(runtime, id) do
      [{pid, _}] ->
        Logger.info("Cancelling execution for agent #{inspect(id)}")
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
  @spec running_execution_registry_entry(String.t()) :: {:running, String.t()}
  def running_execution_registry_entry(id) when is_binary(id), do: {:running, id}

  @doc false
  @spec running_execution_registry_entry_for_agent(SwarmAi.Agent.t()) :: {:running, String.t()}
  def running_execution_registry_entry_for_agent(agent),
    do: agent |> SwarmAi.Agent.id() |> running_execution_registry_entry()

  defp running_lookup(runtime, agent_id) do
    Registry.lookup(
      registry_name(runtime),
      running_execution_registry_entry(agent_id)
    )
  end
end
