defmodule MCP.Codec do
  @moduledoc false
  # Internal module for JSON encoding/decoding of MCP messages.
  # Do not use directly - use MCP.encode_message/1 and MCP.decode_message/1 instead.

  @doc """
  Decode a JSON string into a validated MCP message.

  Parses the JSON and validates the structure according to MCP specification.
  Returns `{:ok, message_map}` or `{:error, reason}`.
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, term()}
  def decode(json) when is_binary(json) do
    with {:ok, data} <- Jason.decode(json, keys: :atoms),
         {:ok, validated} <- MCP.Client.parse(data) do
      {:ok, validated}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, {:json_decode_error, error}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Encode an MCP message map into a JSON string.

  Validates the message structure before encoding.
  Returns `{:ok, json_string}` or `{:error, reason}`.
  """
  @spec encode(map()) :: {:ok, binary()} | {:error, term()}
  def encode(message) when is_map(message) do
    # Validate before encoding
    with {:ok, validated} <- MCP.Client.parse(message),
         {:ok, json} <- Jason.encode(validated) do
      {:ok, json}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end
end
