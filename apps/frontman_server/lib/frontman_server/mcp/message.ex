defmodule FrontmanServer.MCP.Message do
  @moduledoc """
  Base message schemas common to all MCP (Model Context Protocol) message types.

  This module provides reusable schema functions that can be composed into specific
  message types. All functions return Zoi schemas that can be used for validation.
  """

  @doc """
  Returns a schema for request IDs (string or number).
  """
  def request_id do
    Zoi.string()
  end

  @doc """
  Returns a schema for params objects (arbitrary maps).
  Params may contain _meta, progressToken, and other method-specific parameters.
  """
  def params do
    Zoi.map()
  end

  @doc """
  Returns a schema for result objects (arbitrary maps).
  Results may contain _meta and method-specific response data.
  """
  def result do
    Zoi.map()
  end

  @doc """
  Returns a schema for error objects with code, message, and optional data.
  """
  def error do
    Zoi.object(%{
      code: Zoi.integer(),
      message: Zoi.string(),
      data: Zoi.any() |> Zoi.optional()
    })
  end
end
