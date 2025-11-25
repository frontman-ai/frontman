defmodule MCP.Client.ListPrompts do
  @moduledoc false
  # Internal client module for listing prompts.

  @doc """
  Create a list prompts request.

  Optionally provide a cursor for pagination.
  """
  @spec request(cursor :: String.t() | nil) :: {:ok, map(), reference()}
  def request(cursor \\ nil) do
    params = if cursor, do: %{cursor: cursor}, else: nil
    {:ok, request} = MCP.Client.request("prompts/list", params)
    {:ok, request, request.id}
  end

  @doc """
  Parse list prompts response.

  Returns `{:ok, %{prompts: [...], next_cursor: ...}}`.
  """
  @spec parse_response(map()) :: {:ok, map()} | {:error, term()}
  def parse_response(%{result: result}) do
    with {:ok, validated} <- Zoi.parse(MCP.Schemas.Prompt.list_result(), result) do
      {:ok,
       %{
         prompts: validated.prompts,
         next_cursor: Map.get(validated, :nextCursor)
       }}
    end
  end

  def parse_response(%{error: error}), do: {:error, error}
end
