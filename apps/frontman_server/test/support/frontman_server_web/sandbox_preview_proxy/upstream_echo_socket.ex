defmodule FrontmanServerWeb.TestSupport.SandboxPreviewProxy.UpstreamEchoSocket do
  @moduledoc false

  @behaviour WebSock

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_in({payload, opcode: :text}, state) do
    case {payload, Map.get(state, :cookie)} do
      {"cookie-header", cookie} -> {:push, {:text, "cookie:" <> (cookie || "")}, state}
      _ -> {:push, {:text, "echo:" <> payload}, state}
    end
  end

  def handle_in({payload, opcode: :binary}, state), do: {:push, {:binary, payload}, state}

  @impl true
  def handle_info(_message, state), do: {:ok, state}
end
