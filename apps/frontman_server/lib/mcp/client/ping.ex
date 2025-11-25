defmodule MCP.Client.Ping do
  @moduledoc false
  # Internal client module for ping protocol.

  @doc """
  Create a ping request.

  Returns `{:ok, request_map, request_id}`.
  """
  @spec request() :: {:ok, map(), reference()}
  def request do
    {:ok, request} = MCP.Client.request("ping")
    {:ok, request, request.id}
  end

  @doc """
  Parse ping response.

  Ping responses have an empty result object.
  Returns `:pong` on success.
  """
  @spec parse_response(map()) :: {:ok, :pong} | {:error, term()}
  def parse_response(%{result: %{}}), do: {:ok, :pong}
  def parse_response(%{error: error}), do: {:error, error}
end
