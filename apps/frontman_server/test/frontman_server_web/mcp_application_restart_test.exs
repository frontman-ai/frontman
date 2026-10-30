defmodule FrontmanServerWeb.MCP.ApplicationRestartTest do
  use ExUnit.Case, async: false

  @tag :application_restart
  test "invalid MCP configuration stops startup and a configured restart serves the SDK" do
    previous = Application.fetch_env!(:frontman_server, :mcp_server)
    Process.flag(:trap_exit, true)

    on_exit(fn ->
      Application.put_env(:frontman_server, :mcp_server, previous)
      {:ok, _} = Application.ensure_all_started(:frontman_server)
    end)

    assert :ok = Application.stop(:frontman_server)
    Application.put_env(:frontman_server, :mcp_server, resource: nil, issuer: nil)

    assert {:error, {:frontman_server, _reason}} =
             Application.ensure_all_started(:frontman_server)

    refute Process.whereis(Anubis.Server.Registry.supervisor_name(FrontmanServerWeb.MCP.Server))

    Application.put_env(:frontman_server, :mcp_server, previous)
    assert {:ok, _} = Application.ensure_all_started(:frontman_server)
    {:ok, {_ip, port}} = FrontmanServerWeb.Endpoint.server_info(:http)

    metadata =
      Req.get!("http://127.0.0.1:#{port}/.well-known/oauth-protected-resource",
        retry: false,
        receive_timeout: 5_000
      )

    assert metadata.status == 200
    assert metadata.body["resource"] == previous[:resource]

    challenge =
      Req.post!("http://127.0.0.1:#{port}/mcp",
        body: "{}",
        headers: [{"content-type", "application/json"}],
        retry: false,
        receive_timeout: 5_000
      )

    assert challenge.status == 401
    assert challenge.headers["www-authenticate"] != nil
  end
end
