defmodule SwarmAi do
  require Logger

  alias SwarmAi.Loop

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: {__MODULE__, name},
      start: {SwarmAi.Supervisor, :start_link, [opts]},
      type: :supervisor
    }
  end

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

  @spec running?(atom(), String.t()) :: boolean()
  def running?(runtime, task_id) when is_atom(runtime) and is_binary(task_id),
    do: running_lookup(runtime, task_id) != []

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
