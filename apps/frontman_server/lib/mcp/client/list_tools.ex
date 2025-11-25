defmodule MCP.Client.ListTools do
  @moduledoc false
  # Internal client module for listing tools.

  @doc """
  Create a list tools request.

  Optionally provide a cursor for pagination.
  """
  @spec request(cursor :: String.t() | nil) :: {:ok, map(), reference()}
  def request(cursor \\ nil) do
    params = if cursor, do: %{cursor: cursor}, else: nil
    {:ok, request} = MCP.Client.request("tools/list", params)
    {:ok, request, request.id}
  end

  @doc """
  Parse list tools response.

  Returns `{:ok, %{tools: [...], next_cursor: ...}}`.
  """
  @spec parse_response(map()) :: {:ok, map()} | {:error, term()}
  def parse_response(%{result: result}) do
    with {:ok, validated} <- Zoi.parse(MCP.Schemas.Tool.list_result(), result) do
      {:ok,
       %{
         tools: validated.tools,
         next_cursor: Map.get(validated, :nextCursor)
       }}
    end
  end

  def parse_response(%{error: error}), do: {:error, error}
end
