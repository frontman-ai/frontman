defmodule FrontmanServerWeb.McpServerControllerTest do
  use FrontmanServerWeb.ConnCase

  alias FrontmanServerWeb.MCP.Server

  @resource "https://resource.example/mcp"
  @issuer "https://issuer.example/tenant"
  @metadata "/.well-known/oauth-protected-resource/mcp"

  setup do
    previous = Application.fetch_env!(:frontman_server, :mcp_server)
    on_exit(fn -> Application.put_env(:frontman_server, :mcp_server, previous) end)
    Application.put_env(:frontman_server, :mcp_server, resource: @resource, issuer: @issuer)
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
             "authorization_servers" => [@issuer],
             "bearer_methods_supported" => ["header"],
             "scopes_supported" => []
           }
  end

  test "metadata is unavailable when either server identifier is missing", %{conn: conn} do
    for config <- [[], [resource: @resource], [issuer: @issuer]] do
      Application.put_env(:frontman_server, :mcp_server, config)
      assert conn |> get(@metadata) |> response(503)
    end
  end

  test "the MCP endpoint challenges unauthenticated requests before parsing" do
    for version <- ["2025-06-18", "2026-07-28"],
        authorization <- [[], [{"authorization", "Bearer unverified"}]] do
      response =
        wire(:post, "/mcp", [{"mcp-protocol-version", version} | authorization], "{")

      assert response.status == 401

      assert response.headers["www-authenticate"] == [
               ~s(Bearer realm="mcp", resource_metadata="https://resource.example/.well-known/oauth-protected-resource")
             ]

      assert response.headers["x-request-id"] != nil
    end
  end

  test "valid-looking bearer cannot authenticate discovery" do
    body = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "server/discover", params: %{}})

    response =
      wire(
        :post,
        "/mcp",
        [
          {"authorization", "Bearer eyJhbGciOiJub25lIn0.eyJzdWIiOiJ1c2VyIn0.signature"},
          {"mcp-protocol-version", "2026-07-28"},
          {"mcp-method", "server/discover"}
        ],
        body
      )

    assert response.status == 401
    assert response.headers["www-authenticate"] != nil
  end

  test "metadata aliases use the same trusted configuration" do
    root = wire(:get, "/.well-known/oauth-protected-resource", [{"host", "evil.example"}], nil)
    alias_response = wire(:get, @metadata, [], nil)
    assert root.status == 200
    assert root.body == alias_response.body
    assert root.body["resource"] == @resource
    assert root.body["authorization_servers"] == [@issuer]
  end

  test "SDK server information uses the Mix project identity" do
    project = Mix.Project.config()

    assert Server.server_info() == %{
             "name" => Atom.to_string(project[:app]),
             "version" => project[:version]
           }
  end

  test "origin and duplicate authorization checks precede query and body parsing" do
    for path <- ["/mcp", "/%6dcp", "/m%63p", "/mcp?x=%FF", "/mcp/extra"],
        headers <- [
          [{"origin", "https://evil.example"}],
          [{"origin", "https://resource.example"}, {"origin", "https://resource.example"}],
          [{"origin", "https://%FF.example"}],
          [{"authorization", "Bearer one"}, {"authorization", "Bearer two"}]
        ] do
      response = wire(:post, path, headers, "{")
      assert response.status == 403
      assert response.headers["x-request-id"] != nil
    end

    assert wire(:post, "/mcp", [{"origin", "https://resource.example"}], "{").status == 401

    for origin <- [
          "https://RESOURCE.example",
          "https://resource.example:443",
          "https://%72esource.example"
        ] do
      assert wire(:post, "/mcp", [{"origin", origin}], "{").status == 403
    end
  end

  test "raw invalid UTF-8 Origin is rejected before malformed query and body" do
    {:ok, {_ip, port}} = FrontmanServerWeb.Endpoint.server_info(:http)
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 5_000)

    try do
      :ok =
        :gen_tcp.send(socket, [
          "POST /mcp?x=%FF HTTP/1.1\r\n",
          "host: 127.0.0.1\r\n",
          "origin: https://resource.example",
          <<255>>,
          "\r\ncontent-type: application/json\r\ncontent-length: 1\r\nconnection: close\r\n\r\n{"
        ])

      assert {:ok, response} = :gen_tcp.recv(socket, 0, 5_000)
      assert response =~ ~r/\AHTTP\/1\.1 403\b/
      assert response =~ ~r/\r\nx-request-id: [^\r\n]+\r\n/i
    after
      :gen_tcp.close(socket)
    end
  end

  test "configuration changes cannot expose an unconfigured server" do
    for config <- [
          [],
          [resource: @resource],
          [issuer: @issuer],
          [resource: @resource, issuer: "http://bad"]
        ] do
      Application.put_env(:frontman_server, :mcp_server, config)
      assert wire(:post, "/mcp", [], "{}").status == 503
      assert wire(:get, "/.well-known/oauth-protected-resource", [], nil).status == 503
      assert wire(:get, @metadata, [], nil).status == 503
    end
  end

  test "malformed issuer cannot start a metadata-publishing SDK server" do
    Application.put_env(:frontman_server, :mcp_server,
      resource: @resource,
      issuer: "https://%FF.example"
    )

    assert_raise MatchError, fn ->
      FrontmanServerWeb.MCP.child_specs()
    end

    assert wire(:get, "/.well-known/oauth-protected-resource", [], nil).status == 503
    assert wire(:get, @metadata, [], nil).status == 503
  end

  test "malformed issuer authorities are not accepted for startup" do
    for issuer <- [
          "https://issuer.example:",
          "https://issuer.example:0",
          "https://issuer.example:65536",
          "https://%zz.example",
          "https://%3A%3A1"
        ] do
      Application.put_env(:frontman_server, :mcp_server, resource: @resource, issuer: issuer)

      assert_raise MatchError, fn ->
        FrontmanServerWeb.MCP.child_specs()
      end
    end
  end

  test "noncanonical resource URLs cannot start the MCP server" do
    Application.put_env(:frontman_server, :mcp_server,
      resource: "https://resource.example:443/mcp",
      issuer: @issuer
    )

    assert_raise MatchError, fn -> FrontmanServerWeb.MCP.child_specs() end
    assert wire(:post, "/mcp", [], "{}").status == 503
  end

  test "startup rejects absent and partial MCP configuration" do
    for config <- [[], [resource: nil, issuer: nil], [resource: @resource], [issuer: @issuer]] do
      Application.put_env(:frontman_server, :mcp_server, config)

      assert_raise MatchError, fn ->
        FrontmanServerWeb.MCP.child_specs()
      end
    end
  end

  test "the dedicated MCP path preserves endpoint and SDK telemetry without router dispatch" do
    handler = {__MODULE__, make_ref()}

    events =
      [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:anubis_mcp, :server, :authorization, :start],
        [:anubis_mcp, :server, :authorization, :stop]
      ]

    :ok =
      :telemetry.attach_many(
        handler,
        events,
        fn event, _, _, pid -> send(pid, {event, Sentry.Context.get_all().request}) end,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    assert wire(:post, "/mcp?secret=query", [{"authorization", "Bearer secret"}], "secret").status ==
             401

    for event <- events do
      assert_receive {^event, context}
      refute inspect(context) =~ "secret"
    end
  end

  test "an unexpected MCP boundary error reaches Sentry without request secrets" do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()
    Application.put_env(:frontman_server, :mcp_server, :invalid)
    handler = {__MODULE__, make_ref()}
    owner = self()

    :ok =
      :telemetry.attach(
        handler,
        [:phoenix, :endpoint, :start],
        fn _, _, %{conn: conn}, _ ->
          if conn.request_path == "/mcp" and conn.query_string == "private-marker=query",
            do: Sentry.Test.allow_sentry_reports(owner, self())
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    response =
      wire(
        :post,
        "/mcp?private-marker=query",
        [{"authorization", "Bearer private-marker"}, {"origin", "https://resource.example"}],
        "private-marker"
      )

    assert response.status == 500
    [event] = Sentry.Test.pop_sentry_reports()
    assert event.request.method == "POST"
    assert is_binary(event.request.env["REQUEST_ID"])
    refute inspect(event) =~ "private-marker"
  end

  defp wire(method, path, headers, body) do
    {:ok, {_ip, port}} = FrontmanServerWeb.Endpoint.server_info(:http)

    Req.request!(
      method: method,
      url: "http://127.0.0.1:#{port}#{path}",
      headers: [{"content-type", "application/json"}, {"connection", "close"} | headers],
      body: body,
      retry: false,
      receive_timeout: 5_000
    )
  end
end
