defmodule MCP.Client.GetPrompt do
  @moduledoc false
  # Internal client module for getting prompts.

  @doc """
  Create a get prompt request.

  Returns `{:ok, request_map, request_id}`.
  """
  @spec request(name :: String.t(), arguments :: map()) :: {:ok, map(), reference()}
  def request(name, arguments \\ %{}) do
    params = %{name: name, arguments: arguments}

    with {:ok, validated_params} <- Zoi.parse(MCP.Schemas.Prompt.get_params(), params),
         {:ok, request} <- MCP.Client.request("prompts/get", validated_params) do
      {:ok, request, request.id}
    end
  end

  @doc """
  Parse get prompt response.

  Returns `{:ok, %{messages: [...], description: ...}}`.
  """
  @spec parse_response(map()) :: {:ok, map()} | {:error, term()}
  def parse_response(%{result: result}) do
    Zoi.parse(MCP.Schemas.Prompt.get_result(), result)
  end

  def parse_response(%{error: error}), do: {:error, error}
end
