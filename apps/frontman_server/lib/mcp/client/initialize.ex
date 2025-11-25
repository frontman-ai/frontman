defmodule MCP.Client.Initialize do
  @moduledoc false
  # Internal client module for initialize protocol.

  @doc """
  Create an initialize request.

  Returns `{:ok, request_map, request_id}` for tracking the response.
  """
  @spec request(
          client_info :: map(),
          capabilities :: map(),
          protocol_version :: String.t()
        ) :: {:ok, map(), reference()} | {:error, term()}
  def request(client_info, capabilities, protocol_version \\ "2024-11-05") do
    params = %{
      protocolVersion: protocol_version,
      clientInfo: client_info,
      capabilities: capabilities
    }

    with {:ok, validated_params} <-
           Zoi.parse(MCP.Schemas.Initialize.request_params(), params),
         {:ok, request} <- MCP.Client.request("initialize", validated_params) do
      {:ok, request, request.id}
    end
  end

  @doc """
  Parse initialize response from server.

  Returns parsed server info and capabilities.
  """
  @spec parse_response(map()) :: {:ok, map()} | {:error, term()}
  def parse_response(%{result: result}) do
    Zoi.parse(MCP.Schemas.Initialize.response_result(), result)
  end

  def parse_response(%{error: error}), do: {:error, error}
end
