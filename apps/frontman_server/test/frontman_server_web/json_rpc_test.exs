defmodule FrontmanServerWeb.JsonRpcTest do
  use ExUnit.Case, async: true

  alias FrontmanServerWeb.JsonRpc

  describe "parse/1" do
    test "parses valid request with params" do
      message = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "test/method",
        "params" => %{"key" => "value"}
      }

      assert {:ok, {:request, 1, "test/method", %{"key" => "value"}}} = JsonRpc.parse(message)
    end

    test "parses valid request without params" do
      message = %{"jsonrpc" => "2.0", "id" => "abc", "method" => "test/method"}

      assert {:ok, {:request, "abc", "test/method", %{}}} = JsonRpc.parse(message)
    end

    test "parses notification with params" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{"sessionId" => "sess_123"}
      }

      assert {:ok, {:notification, "session/update", %{"sessionId" => "sess_123"}}} =
               JsonRpc.parse(message)
    end

    test "parses notification without params" do
      message = %{"jsonrpc" => "2.0", "method" => "ping"}

      assert {:ok, {:notification, "ping", %{}}} = JsonRpc.parse(message)
    end

    test "returns error for wrong jsonrpc version" do
      message = %{"jsonrpc" => "1.0", "id" => 1, "method" => "test"}

      assert {:error, :invalid_version} = JsonRpc.parse(message)
    end

    test "returns error for missing jsonrpc field" do
      message = %{"id" => 1, "method" => "test"}

      assert {:error, :invalid_message} = JsonRpc.parse(message)
    end

    test "returns error for missing method field" do
      message = %{"jsonrpc" => "2.0", "id" => 1}

      assert {:error, :invalid_message} = JsonRpc.parse(message)
    end
  end

  describe "success_response/2" do
    test "builds valid success response" do
      result = JsonRpc.success_response(1, %{"data" => "value"})

      assert result == %{
               "jsonrpc" => "2.0",
               "id" => 1,
               "result" => %{"data" => "value"}
             }
    end

    test "preserves string id" do
      result = JsonRpc.success_response("req-123", %{})

      assert result["id"] == "req-123"
    end
  end

  describe "error_response/3" do
    test "builds valid error response" do
      result = JsonRpc.error_response(1, -32601, "Method not found")

      assert result == %{
               "jsonrpc" => "2.0",
               "id" => 1,
               "error" => %{
                 "code" => -32601,
                 "message" => "Method not found"
               }
             }
    end
  end

  describe "notification/2" do
    test "builds valid notification" do
      result = JsonRpc.notification("session/update", %{"sessionId" => "sess_123"})

      assert result == %{
               "jsonrpc" => "2.0",
               "method" => "session/update",
               "params" => %{"sessionId" => "sess_123"}
             }
    end

    test "notification has no id field" do
      result = JsonRpc.notification("ping", %{})

      refute Map.has_key?(result, "id")
    end
  end

  describe "error codes" do
    test "provides standard JSON-RPC error codes" do
      assert JsonRpc.error_parse() == -32700
      assert JsonRpc.error_invalid_request() == -32600
      assert JsonRpc.error_method_not_found() == -32601
      assert JsonRpc.error_invalid_params() == -32602
      assert JsonRpc.error_internal() == -32603
    end
  end

  describe "request/3" do
    test "builds valid request" do
      result = JsonRpc.request(1, "test/method", %{"key" => "value"})

      assert result == %{
               "jsonrpc" => "2.0",
               "id" => 1,
               "method" => "test/method",
               "params" => %{"key" => "value"}
             }
    end

    test "preserves string id" do
      result = JsonRpc.request("req-123", "test", %{})

      assert result["id"] == "req-123"
    end
  end
end
