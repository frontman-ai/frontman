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
    event_dispatcher = Keyword.get(opts, :event_dispatcher)

    registry_name = SwarmAi.Runtime.registry_name(name)
    task_sup_name = SwarmAi.Runtime.task_supervisor_name(name)

    # Store event_dispatcher in persistent_term so Runtime.run/5
    # can read it without process coupling.
    # This is static config that only changes on full restart.
    :persistent_term.put({SwarmAi.Runtime, name, :event_dispatcher}, event_dispatcher)

    children = [
      {SwarmAi.Runtime.TasksSupervisor,
       name: :"#{name}.TasksSupervisor", registry: registry_name, task_supervisor: task_sup_name}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
