defmodule FrontmanServer.Test.Fixtures.JsonRpc do
  @jsonrpc_version "2.0"

  @error_parse -32_700
  @error_invalid_request -32_600
  @error_method_not_found -32_601
  @error_invalid_params -32_602
  @error_internal -32_603

  def request_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, unique_id()),
      "method" => Keyword.get(overrides, :method, "test/method"),
      "params" => Keyword.get(overrides, :params, %{})
    }
  end

  def request_message_without_params(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, unique_id()),
      "method" => Keyword.get(overrides, :method, "test/method")
    }
  end

  def notification_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "method" => Keyword.get(overrides, :method, "notification/test"),
      "params" => Keyword.get(overrides, :params, %{})
    }
  end

  def notification_message_without_params(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "method" => Keyword.get(overrides, :method, "ping")
    }
  end

  def success_response_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, unique_id()),
      "result" => Keyword.get(overrides, :result, %{})
    }
  end

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

  def invalid_version_message(overrides \\ []) do
    %{
      "jsonrpc" => Keyword.get(overrides, :version, "1.0"),
      "id" => Keyword.get(overrides, :id, 1),
      "method" => Keyword.get(overrides, :method, "test")
    }
  end

  def missing_jsonrpc_message(overrides \\ []) do
    %{
      "id" => Keyword.get(overrides, :id, 1),
      "method" => Keyword.get(overrides, :method, "test")
    }
  end

  def missing_method_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1)
    }
  end

  def missing_id_response_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "result" => Keyword.get(overrides, :result, %{})
    }
  end

  def ambiguous_response_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1),
      "result" => Keyword.get(overrides, :result, %{}),
      "error" => Keyword.get(overrides, :error, %{"code" => -32_601, "message" => "Error"})
    }
  end

  def empty_response_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1)
    }
  end

  def malformed_error_missing_code(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1),
      "error" => %{"message" => Keyword.get(overrides, :message, "Error")}
    }
  end

  def malformed_error_missing_message(overrides \\ []) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => Keyword.get(overrides, :id, 1),
      "error" => %{"code" => Keyword.get(overrides, :code, -32_601)}
    }
  end

  def error_code_parse, do: @error_parse

  def error_code_invalid_request, do: @error_invalid_request

  def error_code_method_not_found, do: @error_method_not_found

  def error_code_invalid_params, do: @error_invalid_params

  def error_code_internal, do: @error_internal

  defp unique_id do
    System.unique_integer([:positive])
  end
end
