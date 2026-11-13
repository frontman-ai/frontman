defmodule SwarmAi.Supervisor do
  @moduledoc false

  use Supervisor

  @doc false
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    runtime_name = Keyword.fetch!(opts, :name)
    initialize_process = Keyword.get(opts, :initialize_process, fn -> :ok end)

    Supervisor.start_link(__MODULE__, %{
      runtime_name: runtime_name,
      initialize_process: initialize_process
    })
  end

  @impl true
  @spec init(map()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(%{runtime_name: runtime_name, initialize_process: initialize_process}) do
    children = [
      {SwarmAi.Runtime, runtime: runtime_name, initialize_process: initialize_process},
      SwarmAi.Runtime.Registry.child_spec(runtime_name),
      {Task.Supervisor, name: SwarmAi.Runtime.task_supervisor_name(runtime_name)},
      {DynamicSupervisor,
       name: SwarmAi.Runtime.execution_supervisor_name(runtime_name), strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
