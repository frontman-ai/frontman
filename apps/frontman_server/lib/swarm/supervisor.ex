defmodule Swarm.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {DynamicSupervisor, name: Swarm.ExecutionSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Swarm.TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
