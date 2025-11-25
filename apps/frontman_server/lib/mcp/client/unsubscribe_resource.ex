defmodule MCP.Client.UnsubscribeResource do
  @moduledoc false
  # Internal client module for unsubscribing from resource updates.

  @doc """
  Create an unsubscribe resource request.

  Returns `{:ok, request_map, request_id}`.
  """
  @spec request(uri :: String.t()) :: {:ok, map(), reference()}
  def request(uri) do
    params = %{uri: uri}

    with {:ok, validated_params} <- Zoi.parse(MCP.Schemas.Resource.subscribe_params(), params),
         {:ok, request} <- MCP.Client.request("resources/unsubscribe", validated_params) do
      {:ok, request, request.id}
    end
  end

  @doc """
  Parse unsubscribe resource response.

  Returns `:ok` on success.
  """
  @spec parse_response(map()) :: {:ok, :unsubscribed} | {:error, term()}
  def parse_response(%{result: %{}}), do: {:ok, :unsubscribed}
  def parse_response(%{error: error}), do: {:error, error}
end
