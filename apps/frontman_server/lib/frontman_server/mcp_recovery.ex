defmodule FrontmanServer.MCPRecovery do
  @moduledoc false

  use GenServer

  alias FrontmanServer.Tasks

  @batch_size 100
  @interval_ms 5_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    interval_ms = Keyword.get(options, :interval_ms, @interval_ms)
    batch_size = Keyword.get(options, :batch_size, @batch_size)
    {:ok, %{interval_ms: interval_ms, batch_size: batch_size}, {:continue, :recover}}
  end

  @impl true
  def handle_continue(:recover, state) do
    recover(state)
  end

  @impl true
  def handle_info(:recover, state) do
    recover(state)
  end

  defp recover(state) do
    Tasks.recover_tool_call_claims(state.batch_size)
    Process.send_after(self(), :recover, state.interval_ms)
    {:noreply, state}
  end
end
