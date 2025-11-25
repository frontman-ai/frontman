defmodule MCP.Schemas.Initialize do
  @moduledoc false
  # Internal schemas for the initialize protocol.

  @doc "Client or server implementation information"
  def implementation_info do
    Zoi.object(%{
      name: Zoi.string(),
      version: Zoi.string()
    })
  end

  @doc "Client capabilities"
  def client_capabilities do
    Zoi.object(%{
      roots: roots_capability() |> Zoi.optional(),
      sampling: Zoi.object(%{}) |> Zoi.optional(),
      experimental: Zoi.map(Zoi.string(), Zoi.any()) |> Zoi.optional()
    })
  end

  @doc "Server capabilities"
  def server_capabilities do
    Zoi.object(%{
      logging: Zoi.object(%{}) |> Zoi.optional(),
      prompts: list_changed_capability() |> Zoi.optional(),
      resources: resources_capability() |> Zoi.optional(),
      tools: list_changed_capability() |> Zoi.optional(),
      experimental: Zoi.map(Zoi.string(), Zoi.any()) |> Zoi.optional()
    })
  end

  # Roots capability with listChanged support
  defp roots_capability do
    Zoi.object(%{
      listChanged: Zoi.boolean() |> Zoi.optional()
    })
  end

  # List changed capability
  defp list_changed_capability do
    Zoi.object(%{
      listChanged: Zoi.boolean() |> Zoi.optional()
    })
  end

  # Resources capability with subscribe and listChanged support
  defp resources_capability do
    Zoi.object(%{
      subscribe: Zoi.boolean() |> Zoi.optional(),
      listChanged: Zoi.boolean() |> Zoi.optional()
    })
  end

  @doc "Initialize request parameters"
  def request_params do
    Zoi.object(%{
      protocolVersion: Zoi.string(),
      capabilities: client_capabilities(),
      clientInfo: implementation_info()
    })
  end

  @doc "Initialize response result"
  def response_result do
    Zoi.object(%{
      protocolVersion: Zoi.string(),
      capabilities: server_capabilities(),
      serverInfo: implementation_info()
    })
  end
end
