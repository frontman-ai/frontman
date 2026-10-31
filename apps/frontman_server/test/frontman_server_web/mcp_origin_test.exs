defmodule FrontmanServerWeb.MCP.OriginTest do
  use ExUnit.Case, async: true

  alias FrontmanServerWeb.MCP.Origin

  test "accepts only canonical configured HTTPS resource origins" do
    for {resource, origin} <- [
          {"https://resource.example/mcp", "https://resource.example"},
          {"https://resource.example:444/mcp", "https://resource.example:444"},
          {"https://foo_~!.example/mcp", "https://foo_~!.example"},
          {"https://[::1]/mcp", "https://[::1]"}
        ] do
      assert {:ok, identity} = Origin.resource(resource)
      assert Origin.allowed?(identity, origin)
    end
  end

  test "rejects malformed and unrelated origins" do
    assert {:ok, identity} = Origin.resource("https://resource.example/mcp")

    for origin <- [
          "null",
          "https://other.example",
          "https://resource.example" <> <<255>>,
          "https://resource.example:443"
        ] do
      refute Origin.allowed?(identity, origin), origin
    end

    assert {:ok, ipv6} = Origin.resource("https://[::1]/mcp")
    refute Origin.allowed?(ipv6, "https://%3A%3A1")
    refute Origin.allowed?(ipv6, "https://[0:0:0:0:0:0:0:1]")
  end

  test "invalid configured resources fail closed" do
    for resource <- [
          nil,
          "",
          "http://resource.example/mcp",
          "https://resource.example",
          "https://resource.example/other",
          "https://user@resource.example/mcp",
          "https://RESOURCE.example/mcp",
          "https://resource.example:443/mcp",
          "https://%72esource.example/mcp",
          "https://[0:0:0:0:0:0:0:1]/mcp",
          "https://resource.example:/mcp",
          "https://%FF.example/mcp",
          "https://%25.example/mcp",
          "https://bad%20host/mcp",
          "https://%3A%3A1/mcp",
          "https://resource.example" <> <<255>> <> "/mcp",
          "https://resource.example/mcp?q=1",
          "https://resource.example/mcp#fragment"
        ] do
      assert :error = Origin.resource(resource)
    end
  end
end
