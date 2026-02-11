defmodule FrontmanServer.Protocols.JsonRpcContractTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.ProtocolSchema

  describe "JsonRpc.request/3" do
    test "validates against jsonrpc/request schema" do
      payload = JsonRpc.request(1, "initialize", %{"protocolVersion" => 1})
      ProtocolSchema.validate!(payload, "jsonrpc/request")
    end

    test "validates with nil params" do
      payload = JsonRpc.request(1, "ping", nil)
      ProtocolSchema.validate!(payload, "jsonrpc/request")
    end
  end

  describe "JsonRpc.success_response/2" do
    test "validates against jsonrpc/response schema" do
      payload = JsonRpc.success_response(1, %{"data" => "value"})
      ProtocolSchema.validate!(payload, "jsonrpc/response")
    end
  end

  describe "JsonRpc.error_response/3" do
    test "validates against jsonrpc/response schema" do
      payload = JsonRpc.error_response(1, -32_601, "Method not found")
      ProtocolSchema.validate!(payload, "jsonrpc/response")
    end
  end

  describe "JsonRpc.notification/2" do
    test "validates against jsonrpc/notification schema" do
      payload = JsonRpc.notification("session/update", %{"sessionId" => "abc"})
      ProtocolSchema.validate!(payload, "jsonrpc/notification")
    end
  end
end
