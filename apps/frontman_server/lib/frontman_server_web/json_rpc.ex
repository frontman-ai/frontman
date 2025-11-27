defmodule FrontmanServerWeb.JsonRpc do
  @moduledoc """
  JSON-RPC 2.0 message parsing and construction.

  This module handles the transport-level concerns of JSON-RPC 2.0 protocol,
  providing functions to parse incoming messages and build outgoing responses.
  Domain logic should not depend on this module directly.
  """

  @jsonrpc_version "2.0"

  # Standard JSON-RPC 2.0 error codes
  @error_parse -32700
  @error_invalid_request -32600
  @error_method_not_found -32601
  @error_invalid_params -32602
  @error_internal -32603

  def error_parse, do: @error_parse
  def error_invalid_request, do: @error_invalid_request
  def error_method_not_found, do: @error_method_not_found
  def error_invalid_params, do: @error_invalid_params
  def error_internal, do: @error_internal

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
