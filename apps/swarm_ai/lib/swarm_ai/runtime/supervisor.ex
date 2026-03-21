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
    monitor_name = SwarmAi.Runtime.monitor_name(name)

    # Store event_dispatcher in persistent_term so Runtime.run/5 and
    # ExecutionMonitor can read it without process coupling.
    # This is static config that only changes on full restart.
    :persistent_term.put({SwarmAi.Runtime, name, :event_dispatcher}, event_dispatcher)

    # Snapshot table is owned by this Supervisor so it survives
    # ExecutionMonitor restarts — prevents cascading crashes in
    # execution processes that write snapshots via stash_snapshot/3.
    :ets.new(
      SwarmAi.Runtime.ExecutionMonitor.snapshot_table_name(monitor_name),
      [:set, :public, :named_table]
    )

    children = [
      {SwarmAi.Runtime.TasksSupervisor,
       name: :"#{name}.TasksSupervisor",
       registry: registry_name,
       task_supervisor: task_sup_name},
      {SwarmAi.Runtime.ExecutionMonitor,
       name: monitor_name, registry: registry_name, event_dispatcher: event_dispatcher}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
