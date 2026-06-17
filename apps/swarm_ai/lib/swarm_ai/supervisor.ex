defmodule SwarmAi.Supervisor do
  @moduledoc false

  use Supervisor

  @doc false
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    runtime_name = Keyword.fetch!(opts, :name)

    Supervisor.start_link(
      __MODULE__,
      %{runtime_name: runtime_name},
      name: runtime_name
    )
  end

  @impl true
  @spec init(keyword()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(%{runtime_name: runtime_name}) do
    registry_name = SwarmAi.registry_name(runtime_name)
    task_sup_name = SwarmAi.task_supervisor_name(runtime_name)
    execution_sup_name = SwarmAi.execution_supervisor_name(runtime_name)

    children = [
      {Registry, keys: :unique, name: registry_name},
      {Task.Supervisor, name: task_sup_name},
      {DynamicSupervisor, name: execution_sup_name, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
