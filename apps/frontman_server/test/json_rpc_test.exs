defmodule JsonRpcTest do
  use ExUnit.Case, async: true

  import FrontmanServer.Test.Fixtures.JsonRpc

  describe "parse/1" do
    test "parses valid request with params" do
      message = request_message(id: 1, params: %{"key" => "value"})

      assert {:ok, {:request, 1, "test/method", %{"key" => "value"}}} = JsonRpc.parse(message)
    end

    test "parses valid request without params" do
      message = request_message_without_params(id: "abc")

      assert {:ok, {:request, "abc", "test/method", %{}}} = JsonRpc.parse(message)
    end

    test "parses notification with params" do
      message =
        notification_message(method: "session/update", params: %{"sessionId" => "sess_123"})

      assert {:ok, {:notification, "session/update", %{"sessionId" => "sess_123"}}} =
               JsonRpc.parse(message)
    end

    test "parses notification without params" do
      message = notification_message_without_params(method: "ping")

      assert {:ok, {:notification, "ping", %{}}} = JsonRpc.parse(message)
    end

    test "returns error for wrong jsonrpc version" do
      assert {:error, :invalid_version} = JsonRpc.parse(invalid_version_message())
    end

    test "returns error for missing jsonrpc field" do
      assert {:error, :invalid_message} = JsonRpc.parse(missing_jsonrpc_message())
    end

    test "returns error for missing method field" do
      assert {:error, :invalid_message} = JsonRpc.parse(missing_method_message())
    end
  end

  describe "parse_response/1" do
    test "parses valid success response" do
      message = success_response_message(id: 1, result: %{"data" => "value"})

      assert {:ok, {:success, 1, %{"data" => "value"}}} = JsonRpc.parse_response(message)
    end

    test "parses success response with string id" do
      message = success_response_message(id: "req-123")

      assert {:ok, {:success, "req-123", %{}}} = JsonRpc.parse_response(message)
    end

    test "parses valid error response" do
      message = error_response_message(id: 1)

      assert {:ok, {:error, 1, %{"code" => -32_601, "message" => "Method not found"}}} =
               JsonRpc.parse_response(message)
    end

    test "returns error for wrong jsonrpc version in response" do
      message = %{"jsonrpc" => "1.0", "id" => 1, "result" => %{}}

      assert {:error, :invalid_version} = JsonRpc.parse_response(message)
    end

    test "returns error for missing jsonrpc field in response" do
      message = %{"id" => 1, "result" => %{}}

      assert {:error, :invalid_message} = JsonRpc.parse_response(message)
    end

    test "returns error for missing id field in response" do
      assert {:error, :invalid_message} = JsonRpc.parse_response(missing_id_response_message())
    end

    test "returns error for response with both result and error" do
      assert {:error, :invalid_message} = JsonRpc.parse_response(ambiguous_response_message())
    end

    test "returns error for response with neither result nor error" do
      assert {:error, :invalid_message} = JsonRpc.parse_response(empty_response_message())
    end

    test "returns error for response with malformed error object (missing code)" do
      assert {:error, :invalid_message} = JsonRpc.parse_response(malformed_error_missing_code())
    end

    test "returns error for response with malformed error object (missing message)" do
      assert {:error, :invalid_message} =
               JsonRpc.parse_response(malformed_error_missing_message())
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_message} = JsonRpc.parse_response("not a map")
      assert {:error, :invalid_message} = JsonRpc.parse_response(nil)
      assert {:error, :invalid_message} = JsonRpc.parse_response([])
    end
  end

  describe "success_response/2" do
    test "builds valid success response" do
      assert JsonRpc.success_response(1, %{"data" => "value"}) ==
               success_response_message(id: 1, result: %{"data" => "value"})
    end

    test "preserves string id" do
      result = JsonRpc.success_response("req-123", %{})

      assert result["id"] == "req-123"
    end
  end

  describe "error_response/3" do
    test "builds valid error response" do
      assert JsonRpc.error_response(1, -32_601, "Method not found") ==
               error_response_message(id: 1)
    end
  end

  describe "notification/2" do
    test "builds valid notification" do
      assert JsonRpc.notification("session/update", %{"sessionId" => "sess_123"}) ==
               notification_message(
                 method: "session/update",
                 params: %{"sessionId" => "sess_123"}
               )
    end

    test "notification has no id field" do
      result = JsonRpc.notification("ping", %{})

      refute Map.has_key?(result, "id")
    end
  end

  describe "error codes" do
    test "provides standard JSON-RPC error codes" do
      assert JsonRpc.error_parse() == error_code_parse()
      assert JsonRpc.error_invalid_request() == error_code_invalid_request()
      assert JsonRpc.error_method_not_found() == error_code_method_not_found()
      assert JsonRpc.error_invalid_params() == error_code_invalid_params()
      assert JsonRpc.error_internal() == error_code_internal()
    end
  end

  describe "request/3" do
    test "builds valid request" do
      assert JsonRpc.request(1, "test/method", %{"key" => "value"}) ==
               request_message(id: 1, params: %{"key" => "value"})
    end

    test "preserves string id" do
      result = JsonRpc.request("req-123", "test", %{})

      assert result["id"] == "req-123"
    end
  end
end
