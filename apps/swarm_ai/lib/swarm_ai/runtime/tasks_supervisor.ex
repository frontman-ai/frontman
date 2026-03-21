defmodule SwarmAi.Runtime.TasksSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    registry_name = Keyword.fetch!(opts, :registry)
    task_sup_name = Keyword.fetch!(opts, :task_supervisor)

    children = [
      {Registry, keys: :unique, name: registry_name},
      {Task.Supervisor, name: task_sup_name}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
