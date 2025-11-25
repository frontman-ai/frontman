defmodule MCP.Client.CallTool do
  @moduledoc false
  # Internal client module for calling tools.

  @doc """
  Create a call tool request.

  Returns `{:ok, request_map, request_id}`.
  """
  @spec request(name :: String.t(), arguments :: map()) :: {:ok, map(), reference()}
  def request(name, arguments \\ %{}) do
    params = %{name: name, arguments: arguments}

    with {:ok, validated_params} <- Zoi.parse(MCP.Schemas.Tool.call_params(), params),
         {:ok, request} <- MCP.Client.request("tools/call", validated_params) do
      {:ok, request, request.id}
    end
  end

  @doc """
  Parse call tool response.

  Returns `{:ok, result}` with the tool's output.
  """
  @spec parse_response(map()) :: {:ok, map()} | {:error, term()}
  def parse_response(%{result: result}) do
    Zoi.parse(MCP.Schemas.Tool.call_result(), result)
  end

  def parse_response(%{error: error}), do: {:error, error}
end
