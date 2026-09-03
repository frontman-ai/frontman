defmodule SwarmAi.TerminalEvent do
  @moduledoc false

  require Logger

  @doc false
  @spec emit(SwarmAi.Loop.t(), term()) :: term()
  def emit(_loop, :normal), do: :ok

  def emit(%SwarmAi.Loop{} = loop, :cancelled) do
    Logger.info("Execution cancelled for #{loop.task_id}")
    loop.dispatch_event.({:cancelled, nil})
  end

  def emit(%SwarmAi.Loop{} = loop, :shutdown) do
    Logger.info("Execution terminated by supervisor for #{loop.task_id}, reason: :shutdown")
    loop.dispatch_event.({:terminated, nil})
  end

  def emit(%SwarmAi.Loop{} = loop, :killed) do
    Logger.info("Execution terminated by supervisor for #{loop.task_id}, reason: :killed")
    loop.dispatch_event.({:terminated, :killed})
  end

  def emit(%SwarmAi.Loop{} = loop, {:shutdown, reason}) do
    Logger.info(fn ->
      "Execution terminated by supervisor for #{loop.task_id}, reason: #{inspect(reason)}"
    end)

    loop.dispatch_event.({:terminated, reason})
  end

  def emit(%SwarmAi.Loop{} = loop, reason) do
    Logger.warning(fn ->
      "Execution crashed for #{loop.task_id}, reason: #{inspect(reason)}"
    end)

    loop.dispatch_event.({:crashed, %{message: Exception.format_exit(reason)}})
  end
end
