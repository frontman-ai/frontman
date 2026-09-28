defmodule SwarmAi.Supervisor do
  @moduledoc false

  use Supervisor

  @doc false
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    runtime_name = Keyword.fetch!(opts, :name)

    Supervisor.start_link(__MODULE__, %{runtime_name: runtime_name})
  end

  @impl true
  @spec init(keyword()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(%{runtime_name: runtime_name}) do
    children = [
      {SwarmAi.Runtime, runtime: runtime_name},
      SwarmAi.Runtime.Registry.child_spec(runtime_name),
      {Task.Supervisor, name: SwarmAi.Runtime.task_supervisor_name(runtime_name)},
      {DynamicSupervisor,
       name: SwarmAi.Runtime.execution_supervisor_name(runtime_name), strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
