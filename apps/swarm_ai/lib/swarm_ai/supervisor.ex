defmodule SwarmAi.Supervisor do
  @moduledoc false

  use Supervisor

  @doc false
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    {:ok, event_dispatcher} = Keyword.fetch(opts, :event_dispatcher)

    Supervisor.start_link(__MODULE__, %{name: name, event_dispatcher: event_dispatcher},
      name: name
    )
  end

  @impl true
  @spec init(keyword()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(%{name: name, event_dispatcher: event_dispatcher}) do
    registry_name = SwarmAi.registry_name(name)
    task_sup_name = SwarmAi.task_supervisor_name(name)
    execution_sup_name = SwarmAi.execution_supervisor_name(name)

    children = [
      {Registry, keys: :unique, name: registry_name},
      {Task.Supervisor, name: task_sup_name},
      {DynamicSupervisor,
       name: execution_sup_name, strategy: :one_for_one, extra_arguments: [event_dispatcher]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
