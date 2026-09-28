defmodule SwarmAi.ExecutionWorker do
  @moduledoc false

  use GenServer, restart: :temporary
  use TypedStruct

  typedstruct enforce: true do
    field(:runtime, atom())
    field(:key, String.t())
    field(:loop, SwarmAi.Loop.t())
  end

  @spec start_link({atom(), String.t(), SwarmAi.Loop.t()}) :: GenServer.on_start()
  def start_link({runtime, key, %SwarmAi.Loop{} = loop}) when is_binary(key) do
    GenServer.start_link(__MODULE__, {runtime, key, loop},
      name: SwarmAi.Runtime.Registry.via(runtime, key)
    )
  end

  @impl true
  def init({runtime, key, %SwarmAi.Loop{} = loop}) do
    state = %__MODULE__{
      runtime: runtime,
      key: key,
      loop: loop
    }

    {:ok, state, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, %__MODULE__{loop: loop, runtime: runtime, key: key} = state) do
    task_supervisor = SwarmAi.Runtime.task_supervisor_name(runtime)

    final_loop = SwarmAi.Executor.run(loop, task_supervisor)
    :ok = SwarmAi.Runtime.Registry.mark_finishing(runtime, key)

    try do
      final_loop.dispatch_event.(final_loop.status)
    after
      SwarmAi.Runtime.execution_finished(runtime, key)
    end

    {:stop, :normal, state}
  end

  @impl true
  def terminate(:shutdown, %__MODULE__{} = state),
    do: dispatch_shutdown_terminal_event(state, :shutdown)

  def terminate({:shutdown, _reason} = reason, %__MODULE__{} = state),
    do: dispatch_shutdown_terminal_event(state, reason)

  def terminate(_reason, _state), do: :ok

  defp dispatch_shutdown_terminal_event(
         %__MODULE__{runtime: runtime, key: key, loop: loop},
         reason
       ) do
    SwarmAi.TerminalEvent.emit(loop, reason)
    SwarmAi.Runtime.execution_finished(runtime, key)
    :ok
  end
end
