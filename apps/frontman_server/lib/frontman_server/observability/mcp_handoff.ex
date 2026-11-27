defmodule FrontmanServer.Observability.MCPHandoff do
  @moduledoc "Telemetry contract shared by the MCP handoff controller and its observers."
  @enforce_keys [:stage, :outcome, :reason, :user_id]
  defstruct @enforce_keys ++ [client: :unknown]

  def telemetry_name, do: [:frontman_server, :mcp, :handoff]
end
