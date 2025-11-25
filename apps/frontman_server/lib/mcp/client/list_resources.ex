defmodule MCP.Client.ListResources do
  @moduledoc false
  # Internal client module for listing resources.

  @doc """
  Create a list resources request.

  Optionally provide a cursor for pagination.
  """
  @spec request(cursor :: String.t() | nil) :: {:ok, map(), reference()}
  def request(cursor \\ nil) do
    params = if cursor, do: %{cursor: cursor}, else: nil
    {:ok, request} = MCP.Client.request("resources/list", params)
    {:ok, request, request.id}
  end

  @doc """
  Parse list resources response.

  Returns `{:ok, %{resources: [...], next_cursor: ...}}`.
  """
  @spec parse_response(map()) :: {:ok, map()} | {:error, term()}
  def parse_response(%{result: result}) do
    with {:ok, validated} <- Zoi.parse(MCP.Schemas.Resource.list_result(), result) do
      {:ok,
       %{
         resources: validated.resources,
         next_cursor: Map.get(validated, :nextCursor)
       }}
    end
  end

  def parse_response(%{error: error}), do: {:error, error}
end
