defmodule FrontmanServerWeb.McpControllerTest do
  use FrontmanServerWeb.ConnCase

  @resource "https://resource.example/mcp"
  @issuer "https://issuer.example/tenant"
  @metadata "/.well-known/oauth-protected-resource/mcp"

  setup do
    previous = Application.get_env(:frontman_server, :mcp_discovery)
    on_exit(fn -> Application.put_env(:frontman_server, :mcp_discovery, previous) end)
    Application.put_env(:frontman_server, :mcp_discovery, resource: @resource, issuer: @issuer)
    :ok
  end

  test "metadata is public and ignores request host headers", %{conn: conn} do
    conn =
      conn
      |> Map.put(:host, "attacker.example")
      |> put_req_header("x-forwarded-host", "attacker.example")
      |> get(@metadata)

    assert json_response(conn, 200) == %{
             "resource" => @resource,
             "authorization_servers" => [@issuer]
           }
  end

  test "metadata is unavailable when configuration is missing or invalid", %{conn: conn} do
    for config <- [nil, [resource: @resource], [resource: @resource, issuer: "http://invalid"]] do
      Application.put_env(:frontman_server, :mcp_discovery, config)
      assert conn |> get(@metadata) |> response(503)
    end
  end
end
