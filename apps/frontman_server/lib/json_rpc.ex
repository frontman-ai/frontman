defmodule JsonRpc do
  use Boundary

  @jsonrpc_version "2.0"

  @error_parse -32_700
  @error_invalid_request -32_600
  @error_method_not_found -32_601
  @error_invalid_params -32_602
  @error_internal -32_603

  @error_url_elicitation_required -32_042

  def error_parse, do: @error_parse
  def error_invalid_request, do: @error_invalid_request
  def error_method_not_found, do: @error_method_not_found
  def error_invalid_params, do: @error_invalid_params
  def error_internal, do: @error_internal
  def error_url_elicitation_required, do: @error_url_elicitation_required

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
    {:error, :invalid_message}
  end

  defp extract_response_type(%{"result" => result} = message) do
    id = Map.fetch!(message, "id")
    {:ok, {:success, id, result}}
  end

  defp extract_response_type(%{"error" => error} = message) do
    id = Map.fetch!(message, "id")

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

  def success_response(id, result) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => id,
      "result" => result
    }
  end

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

  def notification(method, params) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "method" => method,
      "params" => params
    }
  end

  def request(id, method, params) do
    %{
      "jsonrpc" => @jsonrpc_version,
      "id" => id,
      "method" => method,
      "params" => params
    }
  end
end
