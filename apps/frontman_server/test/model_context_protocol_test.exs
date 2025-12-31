defmodule ModelContextProtocolTest do
  use ExUnit.Case, async: true

  describe "initialize_params/0" do
    test "returns params for MCP initialize request" do
      params = ModelContextProtocol.initialize_params()

      assert params["protocolVersion"] == "DRAFT-2025-v3"
      assert params["capabilities"] == %{}
      assert params["clientInfo"]["name"] == "frontman-server"
      assert params["clientInfo"]["version"] == "1.0.0"
    end
  end

  describe "protocol_version/0" do
    test "returns the MCP protocol version" do
      assert ModelContextProtocol.protocol_version() == "DRAFT-2025-v3"
    end
  end

  describe "client_info/0" do
    test "returns client info map" do
      info = ModelContextProtocol.client_info()

      assert info["name"] == "frontman-server"
      assert info["version"] == "1.0.0"
    end
  end
end
