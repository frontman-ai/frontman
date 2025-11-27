defmodule FrontmanServerWeb.MCPProtocol do
  @moduledoc """
  MCP (Model Context Protocol) constants and params.

  Provides MCP-specific data for the initialization flow.
  Use with `JsonRpc` to build wire messages.
  """

  @protocol_version "DRAFT-2025-v3"
  @client_name "frontman-server"
  @client_version "1.0.0"

  def protocol_version, do: @protocol_version

  def client_info do
    %{
      "name" => @client_name,
      "version" => @client_version
    }
  end

  @doc """
  Returns params for an MCP initialize request.

  Use with `JsonRpc.request(id, "initialize", MCPProtocol.initialize_params())`.
  """
  def initialize_params do
    %{
      "protocolVersion" => @protocol_version,
      "capabilities" => %{},
      "clientInfo" => client_info()
    }
  end
end
