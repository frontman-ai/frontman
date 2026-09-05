defmodule SwarmAi.ExecutionWorker do
  @moduledoc false

  use GenServer, restart: :temporary
  use TypedStruct

  typedstruct enforce: true do
    field(:runtime, atom())
    field(:loop, SwarmAi.Loop.t())
  end

  @spec start_link({atom(), SwarmAi.Loop.t()}) :: GenServer.on_start()
  def start_link({runtime, %SwarmAi.Loop{task_id: task_id} = loop}) do
    GenServer.start_link(__MODULE__, {runtime, loop},
      name: SwarmAi.Runtime.Registry.via(runtime, task_id)
    )
  end

  @impl true
  def init({runtime, %SwarmAi.Loop{} = loop}) do
    state = %__MODULE__{
      runtime: runtime,
      loop: loop
    }

    {:ok, state, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, %__MODULE__{loop: loop, runtime: runtime} = state) do
    task_supervisor = SwarmAi.Runtime.task_supervisor_name(runtime)

    final_loop = SwarmAi.Executor.run(loop, task_supervisor)
    :ok = SwarmAi.Runtime.Registry.mark_finishing(runtime, loop.task_id)

    try do
      final_loop.dispatch_event.(final_loop.status)
    after
      SwarmAi.Runtime.execution_finished(runtime, loop.task_id)
    end

    {:stop, :normal, state}
  end

  @impl true
  def terminate(:shutdown, %__MODULE__{runtime: runtime, loop: loop}),
    do: dispatch_shutdown_terminal_event(runtime, loop, :shutdown)

  def terminate({:shutdown, _reason} = reason, %__MODULE__{runtime: runtime, loop: loop}),
    do: dispatch_shutdown_terminal_event(runtime, loop, reason)

  def terminate(_reason, _state), do: :ok

  defp dispatch_shutdown_terminal_event(runtime, loop, reason) do
    SwarmAi.TerminalEvent.emit(loop, reason)
    SwarmAi.Runtime.execution_finished(runtime, loop.task_id)
    :ok
  end
end
