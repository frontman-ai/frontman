defmodule MCP.Schemas do
  @moduledoc """
  Core Zoi schema definitions for MCP message types.

  Defines schemas for JSON-RPC 2.0 messages according to the
  Model Context Protocol specification (2024-11-05).

  These schemas are private implementation details. Use the MCP module
  public API instead of accessing these schemas directly.
  """

  @doc """
  JSON-RPC 2.0 request schema.

  Request messages must include:
  - jsonrpc: "2.0"
  - id: string or integer (NOT null)
  - method: string
  - params: optional map
  """
  def request do
    Zoi.object(%{
      jsonrpc: Zoi.literal("2.0"),
      id: Zoi.union([Zoi.string(), Zoi.integer()]),
      method: Zoi.string(),
      params: Zoi.any() |> Zoi.optional()
    })
  end

  @doc """
  JSON-RPC 2.0 response schema.

  Response messages must include:
  - jsonrpc: "2.0"
  - id: string or integer matching the request
  - result: map (if successful)
  - error: error object (if failed)

  A response MUST have exactly one of result or error, not both.
  """
  def response do
    Zoi.object(%{
      jsonrpc: Zoi.literal("2.0"),
      id: Zoi.union([Zoi.string(), Zoi.integer()]),
      result: Zoi.any() |> Zoi.optional(),
      error: error() |> Zoi.optional()
    })
    |> Zoi.refine(fn data ->
      # Validate result XOR error (exactly one must be present)
      has_result = Map.has_key?(data, :result)
      has_error = Map.has_key?(data, :error)

      case {has_result, has_error} do
        {true, false} -> {:ok, data}
        {false, true} -> {:ok, data}
        {false, false} -> {:error, "Response must have either result or error"}
        {true, true} -> {:error, "Response cannot have both result and error"}
      end
    end)
  end

  @doc """
  JSON-RPC 2.0 notification schema.

  Notification messages must include:
  - jsonrpc: "2.0"
  - method: string
  - params: optional map

  Notifications MUST NOT include an id field.
  """
  def notification do
    Zoi.object(%{
      jsonrpc: Zoi.literal("2.0"),
      method: Zoi.string(),
      params: Zoi.any() |> Zoi.optional()
    })
  end

  @doc """
  JSON-RPC 2.0 error object schema.

  Error objects must include:
  - code: integer error code
  - message: string error message
  - data: optional additional error data
  """
  def error do
    Zoi.object(%{
      code: Zoi.integer(),
      message: Zoi.string(),
      data: Zoi.any() |> Zoi.optional()
    })
  end

  @doc """
  Generic message schema that accepts any valid MCP message type.

  Used for detecting and validating incoming messages when the
  type is not known in advance.
  """
  def message do
    Zoi.union([request(), response(), notification()])
  end
end
