defmodule MCP.Client do
  @moduledoc false
  # Internal module for low-level message building.
  # Do not use directly - use the MCP module public API instead.

  @doc """
  Create a request with auto-generated ID.

  Returns `{:ok, request_map}` with the validated request.
  The request map includes a unique `id` field for tracking the response.
  """
  @spec request(method :: String.t(), params :: map() | nil) :: {:ok, map()} | {:error, term()}
  def request(method, params \\ nil) do
    request(next_id(), method, params)
  end

  @doc """
  Create a request with a specific ID.

  Validates the request structure according to JSON-RPC 2.0 spec.
  """
  @spec request(id :: String.t() | integer(), method :: String.t(), params :: map() | nil) ::
          {:ok, map()} | {:error, term()}
  def request(id, method, params) do
    data = %{jsonrpc: "2.0", id: id, method: method}
    data = if params, do: Map.put(data, :params, params), else: data

    Zoi.parse(MCP.Schemas.request(), data)
  end

  @doc """
  Create a notification message.

  Notifications do not include an ID and do not expect a response.
  """
  @spec notify(method :: String.t(), params :: map() | nil) :: {:ok, map()}
  def notify(method, params \\ nil) do
    data = %{jsonrpc: "2.0", method: method}
    data = if params, do: Map.put(data, :params, params), else: data

    Zoi.parse(MCP.Schemas.notification(), data)
  end

  @doc """
  Parse and validate an incoming message.

  Detects whether the message is a request, response, or notification
  and validates it accordingly.
  """
  @spec parse(map()) :: {:ok, map()} | {:error, term()}
  def parse(data) do
    Zoi.parse(MCP.Schemas.message(), data)
  end

  # Generate unique request IDs
  defp next_id do
    System.unique_integer([:positive, :monotonic])
  end
end
