defmodule FrontmanServer.Test.Fixtures.JsonRpc do
  @moduledoc """
  Reusable fixtures for JSON-RPC message tests.

  Provides factory functions for building valid and invalid JSON-RPC 2.0
  messages with sensible defaults and optional overrides.

  ## Usage

      import FrontmanServer.Test.Fixtures.JsonRpc

      # Build a request with defaults
      request_message()
      # => %{"jsonrpc" => "2.0", "id" => 1, "method" => "test/method", "params" => %{}}

      # Build with overrides
      request_message(id: "req-123", method: "session/create", params: %{"key" => "value"})

      # Build invalid messages for error case testing
      invalid_version_message()
      missing_jsonrpc_message()
  """

  @jsonrpc_version "2.0"

  # Standard JSON-RPC 2.0 error codes
  @error_parse -32_700
  @error_invalid_request -32_600
  @error_method_not_found -32_601
  @error_invalid_params -32_602
  @error_internal -32_603

  # ---------------------------------------------------------------------------
  # Request Messages
  # ---------------------------------------------------------------------------

  @doc """
  Builds a valid JSON-RPC 2.0 request message.

  ## Options

    * `:id` - Request ID (default: unique integer)
    * `:method` - Method name (default: "test/method")
    * `:params` - Request params (default: %{})

  ## Examples

      request_message()
      request_message(id: "abc", method: "tools/list")
      request_message(params: %{"name" => "value"})
  """
  @spec request_message(keyword()) :: map()
  def request_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, unique_id()),
      "method" => Keyword.get(overrides, :method, "test/method"),
      "params" => Keyword.get(overrides, :params, %{})
    }
  end

  @doc """
  Builds a valid JSON-RPC 2.0 request message without params.
  """
  @spec request_message_without_params(keyword()) :: map()
  def request_message_without_params(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, unique_id()),
      "method" => Keyword.get(overrides, :method, "test/method")
    }
  end

  # ---------------------------------------------------------------------------
  # Notification Messages
  # ---------------------------------------------------------------------------

  @doc """
  Builds a valid JSON-RPC 2.0 notification message (no id).

  ## Options

    * `:method` - Method name (default: "notification/test")
    * `:params` - Notification params (default: %{})

  ## Examples

      notification_message()
      notification_message(method: "session/update", params: %{"sessionId" => "sess_123"})
  """
  @spec notification_message(keyword()) :: map()
  def notification_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "method" => Keyword.get(overrides, :method, "notification/test"),
      "params" => Keyword.get(overrides, :params, %{})
    }
  end

  @doc """
  Builds a valid JSON-RPC 2.0 notification message without params.
  """
  @spec notification_message_without_params(keyword()) :: map()
  def notification_message_without_params(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "method" => Keyword.get(overrides, :method, "ping")
    }
  end

  # ---------------------------------------------------------------------------
  # Response Messages
  # ---------------------------------------------------------------------------

  @doc """
  Builds a valid JSON-RPC 2.0 success response message.

  ## Options

    * `:id` - Response ID (default: unique integer)
    * `:result` - Result data (default: %{})

  ## Examples

      success_response_message()
      success_response_message(id: "req-123", result: %{"data" => "value"})
  """
  @spec success_response_message(keyword()) :: map()
  def success_response_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, unique_id()),
      "result" => Keyword.get(overrides, :result, %{})
    }
  end

  @doc """
  Builds a valid JSON-RPC 2.0 error response message.

  ## Options

    * `:id` - Response ID (default: unique integer)
    * `:code` - Error code (default: -32601)
    * `:message` - Error message (default: "Method not found")
    * `:data` - Optional error data (default: not included)

  ## Examples

      error_response_message()
      error_response_message(code: -32600, message: "Invalid request")
  """
  @spec error_response_message(keyword()) :: map()
  def error_response_message(overrides \\ []) do
    error =
      %{
        "code" => Keyword.get(overrides, :code, @error_method_not_found),
        "message" => Keyword.get(overrides, :message, "Method not found")
      }
      |> maybe_add_error_data(Keyword.get(overrides, :data))

    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, unique_id()),
      "error" => error
    }
  end

  defp maybe_add_error_data(error, nil), do: error
  defp maybe_add_error_data(error, data), do: Map.put(error, "data", data)

  # ---------------------------------------------------------------------------
  # Invalid Messages (for error case testing)
  # ---------------------------------------------------------------------------

  @doc "Message with wrong JSON-RPC version"
  @spec invalid_version_message(keyword()) :: map()
  def invalid_version_message(overrides \\ []) do
    %{
      "jsonrpc" => Keyword.get(overrides, :version, "1.0"),
      "id" => Keyword.get(overrides, :id, 1),
      "method" => Keyword.get(overrides, :method, "test")
    }
  end

  @doc "Message missing the jsonrpc field"
  @spec missing_jsonrpc_message(keyword()) :: map()
  def missing_jsonrpc_message(overrides \\ []) do
    %{
      "id" => Keyword.get(overrides, :id, 1),
      "method" => Keyword.get(overrides, :method, "test")
    }
  end

  @doc "Message missing the method field"
  @spec missing_method_message(keyword()) :: map()
  def missing_method_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1)
    }
  end

  @doc "Response missing the id field"
  @spec missing_id_response_message(keyword()) :: map()
  def missing_id_response_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "result" => Keyword.get(overrides, :result, %{})
    }
  end

  @doc "Response with both result and error (invalid per spec)"
  @spec ambiguous_response_message(keyword()) :: map()
  def ambiguous_response_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1),
      "result" => Keyword.get(overrides, :result, %{}),
      "error" => Keyword.get(overrides, :error, %{"code" => -32_601, "message" => "Error"})
    }
  end

  @doc "Response with neither result nor error (invalid per spec)"
  @spec empty_response_message(keyword()) :: map()
  def empty_response_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1)
    }
  end

  @doc "Error response with malformed error object (missing code)"
  @spec malformed_error_missing_code(keyword()) :: map()
  def malformed_error_missing_code(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1),
      "error" => %{"message" => Keyword.get(overrides, :message, "Error")}
    }
  end

  @doc "Error response with malformed error object (missing message)"
  @spec malformed_error_missing_message(keyword()) :: map()
  def malformed_error_missing_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1),
      "error" => %{"code" => Keyword.get(overrides, :code, -32_601)}
    }
  end

  # ---------------------------------------------------------------------------
  # Error Code Helpers
  # ---------------------------------------------------------------------------

  @doc "Standard JSON-RPC parse error code (-32700)"
  def error_code_parse, do: @error_parse

  @doc "Standard JSON-RPC invalid request error code (-32600)"
  def error_code_invalid_request, do: @error_invalid_request

  @doc "Standard JSON-RPC method not found error code (-32601)"
  def error_code_method_not_found, do: @error_method_not_found

  @doc "Standard JSON-RPC invalid params error code (-32602)"
  def error_code_invalid_params, do: @error_invalid_params

  @doc "Standard JSON-RPC internal error code (-32603)"
  def error_code_internal, do: @error_internal

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp unique_id do
    System.unique_integer([:positive])
  end
end
