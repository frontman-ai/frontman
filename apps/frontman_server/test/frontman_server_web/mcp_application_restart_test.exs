defmodule FrontmanServerWeb.MCP.ApplicationRestartTest do
  use ExUnit.Case, async: false

  @tag :application_restart
  test "invalid configuration stops startup and canonical IPv6 restart serves the SDK" do
    previous = Application.fetch_env!(:frontman_server, :mcp_server)
    previous_endpoint = Application.fetch_env!(:frontman_server, FrontmanServerWeb.Endpoint)
    Process.flag(:trap_exit, true)

    on_exit(fn ->
      case Application.stop(:frontman_server) do
        :ok -> :ok
        {:error, {:not_started, :frontman_server}} -> :ok
      end

      Application.put_env(:frontman_server, :mcp_server, previous)
      Application.put_env(:frontman_server, FrontmanServerWeb.Endpoint, previous_endpoint)
      {:ok, _} = Application.ensure_all_started(:frontman_server)
    end)

    assert :ok = Application.stop(:frontman_server)
    Application.put_env(:frontman_server, :mcp_server, issuer: nil)

    assert {:error, {:frontman_server, _reason}} =
             Application.ensure_all_started(:frontman_server)

    refute Process.whereis(Anubis.Server.Registry.supervisor_name(FrontmanServerWeb.MCP.Server))

    Application.put_env(:frontman_server, :mcp_server, previous)

    Application.put_env(
      :frontman_server,
      FrontmanServerWeb.Endpoint,
      Keyword.put(previous_endpoint, :url, host: nil, port: 443, scheme: "https")
    )

    assert {:error, {:frontman_server, _reason}} =
             Application.ensure_all_started(:frontman_server)

    refute Process.whereis(Anubis.Server.Registry.supervisor_name(FrontmanServerWeb.MCP.Server))

    Application.put_env(
      :frontman_server,
      FrontmanServerWeb.Endpoint,
      Keyword.put(previous_endpoint, :url, host: "::1", port: 443, scheme: "https")
    )

    Application.put_env(:frontman_server, :mcp_server, issuer: previous[:issuer])
    assert {:ok, _} = Application.ensure_all_started(:frontman_server)
    {:ok, {_ip, port}} = FrontmanServerWeb.Endpoint.server_info(:http)

    metadata =
      Req.get!("http://127.0.0.1:#{port}/.well-known/oauth-protected-resource",
        retry: false,
        receive_timeout: 5_000
      )

    assert metadata.status == 200
    assert metadata.body["resource"] == "https://[::1]/mcp"

    for {origin, status} <- [
          {"https://[::1]", 401},
          {"https://[0:0:0:0:0:0:0:1]", 403},
          {"https://%3A%3A1", 403},
          {"https://[::1]:443", 403}
        ] do
      challenge =
        Req.post!("http://127.0.0.1:#{port}/mcp",
          body: "{",
          headers: [{"content-type", "application/json"}, {"origin", origin}],
          retry: false,
          receive_timeout: 5_000
        )

      assert challenge.status == status
      if status == 401, do: assert(challenge.headers["www-authenticate"] != nil)
    end
  end
end
