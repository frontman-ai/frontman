defmodule MCP.Client.SubscribeResource do
  @moduledoc false
  # Internal client module for subscribing to resource updates.

  @doc """
  Create a subscribe resource request.

  Returns `{:ok, request_map, request_id}`.
  """
  @spec request(uri :: String.t()) :: {:ok, map(), reference()}
  def request(uri) do
    params = %{uri: uri}

    with {:ok, validated_params} <- Zoi.parse(MCP.Schemas.Resource.subscribe_params(), params),
         {:ok, request} <- MCP.Client.request("resources/subscribe", validated_params) do
      {:ok, request, request.id}
    end
  end

  @doc """
  Parse subscribe resource response.

  Returns `:ok` on success.
  """
  @spec parse_response(map()) :: {:ok, :subscribed} | {:error, term()}
  def parse_response(%{result: %{}}), do: {:ok, :subscribed}
  def parse_response(%{error: error}), do: {:error, error}
end
