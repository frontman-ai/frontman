defmodule SwarmAi.Runtime.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)

    registry_name = SwarmAi.Runtime.registry_name(name)
    task_sup_name = SwarmAi.Runtime.task_supervisor_name(name)
    monitor_name = SwarmAi.Runtime.monitor_name(name)

    children = [
      {Registry, keys: :unique, name: registry_name},
      {Task.Supervisor, name: task_sup_name},
      {SwarmAi.Runtime.ExecutionMonitor, name: monitor_name, registry: registry_name}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
