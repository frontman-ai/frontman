# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule JsonRpc do
  @moduledoc """
  JSON-RPC 2.0 message parsing and construction.

  This module handles the transport-level concerns of JSON-RPC 2.0 protocol,
  providing functions to parse incoming messages and build outgoing responses.

  ## Parsing Functions

  - `parse/1` - Parses requests and notifications (incoming from client)
  - `parse_response/1` - Parses success and error responses (incoming from MCP server)

  ## Construction Functions

  - `request/3` - Builds a request message
  - `notification/2` - Builds a notification message
  - `success_response/2` - Builds a success response message
  - `error_response/3` - Builds an error response message

  All parsing and construction functions validate messages according to JSON-RPC 2.0 specification.

  Domain logic should not depend on this module directly.
  """

  use Boundary

  @jsonrpc_version "2.0"

  # Standard JSON-RPC 2.0 error codes
  @error_parse -32_700
  @error_invalid_request -32_600
  @error_method_not_found -32_601
  @error_invalid_params -32_602
  @error_internal -32_603

  # ACP elicitation: URL mode elicitation required before request can proceed
  @error_url_elicitation_required -32_042

  def error_parse, do: @error_parse
  def error_invalid_request, do: @error_invalid_request
  def error_method_not_found, do: @error_method_not_found
  def error_invalid_params, do: @error_invalid_params
  def error_internal, do: @error_internal
  def error_url_elicitation_required, do: @error_url_elicitation_required

  @doc """
  Parses a JSON-RPC 2.0 message into a tagged tuple.

  Returns:
  - `{:ok, {:request, id, method, params}}` for requests (has id)
  - `{:ok, {:notification, method, params}}` for notifications (no id)
  - `{:error, reason}` for invalid messages

  ## Examples

      iex> JsonRpc.parse(%{"jsonrpc" => "2.0", "id" => 1, "method" => "test", "params" => %{}})
      {:ok, {:request, 1, "test", %{}}}

      iex> JsonRpc.parse(%{"jsonrpc" => "2.0", "method" => "notify", "params" => %{}})
      {:ok, {:notification, "notify", %{}}}
  """
  def parse(message) when is_map(message) do
    with {:ok, _version} <- validate_version(message),
         {:ok, method} <- extract_method(message) do
      params = Map.get(message, "params", %{})

      case Map.get(message, "id") do
        nil -> {:ok, {:notification, method, params}}
        id -> {:ok, {:request, id, method, params}}
      end
    end
  end

  def parse(_), do: {:error, :invalid_message}

  @doc """
  Parses a JSON-RPC 2.0 response message into a tagged tuple.

  Returns:
  - `{:ok, {:success, id, result}}` for success responses (has result)
  - `{:ok, {:error, id, error}}` for error responses (has error)
  - `{:error, reason}` for invalid messages

  ## Examples

      iex> JsonRpc.parse_response(%{"jsonrpc" => "2.0", "id" => 1, "result" => %{"data" => "value"}})
      {:ok, {:success, 1, %{"data" => "value"}}}

      iex> JsonRpc.parse_response(%{"jsonrpc" => "2.0", "id" => 1, "error" => %{"code" => -32601, "message" => "Not found"}})
      {:ok, {:error, 1, %{"code" => -32601, "message" => "Not found"}}}
  """
  def parse_response(message) when is_map(message) do
    with {:ok, _version} <- validate_version(message),
         {:ok, _id} <- extract_id(message) do
      extract_response_type(message)
    end
  end

  def parse_response(_), do: {:error, :invalid_message}

  defp extract_id(%{"id" => id}), do: {:ok, id}
  defp extract_id(_), do: {:error, :invalid_message}

  defp extract_response_type(%{"result" => _result, "error" => _error}) do
    # JSON-RPC 2.0 spec: MUST NOT have both result and error
    {:error, :invalid_message}
  end

  defp extract_response_type(%{"result" => result} = message) do
    id = Map.fetch!(message, "id")
    {:ok, {:success, id, result}}
  end

  defp extract_response_type(%{"error" => error} = message) do
    id = Map.fetch!(message, "id")

    # Validate error object structure per JSON-RPC 2.0 spec
    case error do
      %{"code" => code, "message" => message} when is_integer(code) and is_binary(message) ->
        {:ok, {:error, id, error}}

      _ ->
        {:error, :invalid_message}
    end
  end

  defp extract_response_type(_), do: {:error, :invalid_message}

  defp validate_version(%{"jsonrpc" => @jsonrpc_version}), do: {:ok, @jsonrpc_version}
  defp validate_version(%{"jsonrpc" => _}), do: {:error, :invalid_version}
  defp validate_version(_), do: {:error, :invalid_message}

  defp extract_method(%{"method" => method}) when is_binary(method), do: {:ok, method}
  defp extract_method(_), do: {:error, :invalid_message}

  @doc """
  Builds a JSON-RPC 2.0 success response.
  """
  def success_response(id, result) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => id,
      "result" => result
    }
  end

  @doc """
  Builds a JSON-RPC 2.0 error response.
  """
  def error_response(id, code, message) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => id,
      "error" => %{
        "code" => code,
        "message" => message
      }
    }
  end

  @doc """
  Builds a JSON-RPC 2.0 notification (no id).
  """
  def notification(method, params) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "method" => method,
      "params" => params
    }
  end

  @doc """
  Builds a JSON-RPC 2.0 request.
  """
  def request(id, method, params) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => id,
      "method" => method,
      "params" => params
    }
  end
end
