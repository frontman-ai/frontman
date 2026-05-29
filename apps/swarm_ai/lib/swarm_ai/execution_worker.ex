defmodule SwarmAi.ExecutionWorker do
  @moduledoc false

  use GenServer, restart: :temporary

  @spec start_link(nil | {module(), atom(), list()}, {atom(), SwarmAi.ExecutionRunner.task()}) ::
          GenServer.on_start()
  def start_link(event_dispatcher, {runtime, task}) do
    registry = SwarmAi.registry_name(runtime)

    name =
      {:via, Registry, {registry, SwarmAi.running_execution_registry_entry_for_agent(task.agent)}}

    GenServer.start_link(__MODULE__, {runtime, event_dispatcher, task}, name: name)
  end

  @impl true
  def init({runtime, event_dispatcher, task}) do
    runner = SwarmAi.ExecutionRunner.prepare(runtime, event_dispatcher, task)
    {:ok, runner, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, runner) do
    SwarmAi.ExecutionRunner.run(runner)
    {:stop, :normal, runner}
  end
end
