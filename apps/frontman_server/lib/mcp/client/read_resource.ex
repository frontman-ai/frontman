defmodule MCP.Client.ReadResource do
  @moduledoc false
  # Internal client module for reading resources.

  @doc """
  Create a read resource request.

  Returns `{:ok, request_map, request_id}`.
  """
  @spec request(uri :: String.t()) :: {:ok, map(), reference()}
  def request(uri) do
    params = %{uri: uri}

    with {:ok, validated_params} <- Zoi.parse(MCP.Schemas.Resource.read_params(), params),
         {:ok, request} <- MCP.Client.request("resources/read", validated_params) do
      {:ok, request, request.id}
    end
  end

  @doc """
  Parse read resource response.

  Returns `{:ok, %{contents: [...]}}`.
  """
  @spec parse_response(map()) :: {:ok, map()} | {:error, term()}
  def parse_response(%{result: result}) do
    Zoi.parse(MCP.Schemas.Resource.read_result(), result)
  end

  def parse_response(%{error: error}), do: {:error, error}
end
