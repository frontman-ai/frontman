defmodule FrontmanServerWeb.McpConfigTest do
  use ExUnit.Case

  alias FrontmanServerWeb.McpConfig

  @resource "https://resource.example/mcp"
  @issuer "https://issuer.example/tenant"

  test "requires valid configured identifiers" do
    for config <- [nil, [], [resource: @resource], [issuer: @issuer]] do
      assert McpConfig.fetch(config) == {:error, :invalid_configuration}
    end

    invalid = [
      "",
      "http://host/mcp",
      "/mcp",
      "https:///mcp",
      "https://[broken/mcp",
      "https://host:abc/mcp",
      "https://host:0/mcp",
      "https://host:99999/mcp",
      "https://user@host/mcp",
      "https://host/mcp?",
      "https://host/mcp#",
      "https://host/mcp?x=1",
      "https://host/mcp#x",
      "https://host/space here",
      "https://host/\\bad",
      "https://host/\r\nbad",
      "https://host/%",
      "https://host/%0",
      "https://host/%zz",
      "https://host:/mcp"
    ]

    for key <- [:resource, :issuer], url <- invalid do
      config = Keyword.put([resource: @resource, issuer: @issuer], key, url)
      assert McpConfig.fetch(config) == {:error, :invalid_configuration}
    end

    for path <- ["/other", "/mcp/", "/%6dcp", "/a/../mcp"] do
      config = [resource: "https://host#{path}", issuer: @issuer]
      assert McpConfig.fetch(config) == {:error, :invalid_configuration}
    end
  end

  test "preserves configured identifiers" do
    for {resource, issuer} <- [
          {"https://resource.example:8443/mcp", "https://issuer.example"},
          {"https://[::1]/mcp", "https://issuer.example/tenant%20name"}
        ] do
      assert McpConfig.fetch(resource: resource, issuer: issuer) == {:ok, resource, issuer}
    end
  end
end
