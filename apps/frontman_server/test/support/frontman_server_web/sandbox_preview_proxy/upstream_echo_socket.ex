defmodule FrontmanServerWeb.TestSupport.SandboxPreviewProxy.UpstreamEchoSocket do
  @moduledoc false

  @behaviour WebSock

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_in({payload, opcode: :text}, state), do: {:push, {:text, "echo:" <> payload}, state}

  def handle_in({payload, opcode: :binary}, state), do: {:push, {:binary, payload}, state}

  @impl true
  def handle_info(_message, state), do: {:ok, state}
end
