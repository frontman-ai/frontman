defmodule FrontmanServerWeb.Plugs.SandboxPreviewProxyEndpointIntegrationTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServerWeb.TestSupport.SandboxPreviewProxy.UpstreamPlug
  alias Plug.Conn
  alias Plug.Session

  @session_options [
    store: :cookie,
    key: "_frontman_server_key",
    signing_salt: "4+DQeuxI",
    same_site: "None",
    secure: true,
    domain: ".frontman.local"
  ]

  setup do
    endpoint_port = free_port()

    original_preview_config = Application.get_env(:frontman_server, :sandbox_preview_proxy, [])

    Application.put_env(
      :frontman_server,
      :sandbox_preview_proxy,
      Keyword.put(original_preview_config, :app_login_port, endpoint_port)
    )

    on_exit(fn ->
      Application.put_env(:frontman_server, :sandbox_preview_proxy, original_preview_config)
    end)

    start_supervised!(
      {Bandit, plug: FrontmanServerWeb.Endpoint, ip: {127, 0, 0, 1}, port: endpoint_port}
    )

    user = user_fixture()
    scope = Scope.for_user(user)

    %{endpoint_port: endpoint_port, scope: scope, user: user}
  end

  test "proxies authenticated HTTP traffic across a real endpoint server", %{
    endpoint_port: endpoint_port,
    scope: scope,
    user: user
  } do
    upstream_port = free_port()

    start_supervised!({Bandit, plug: UpstreamPlug, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    preview_host = "#{sandbox.id}.preview.frontman.local"

    response =
      Req.get!(
        "http://127.0.0.1:#{endpoint_port}/hello?x=1",
        headers: [
          {"host", preview_host},
          {"cookie", session_cookie_for(user)}
        ],
        retry: false,
        redirect: false
      )

    assert response.status == 200
    assert response.body == "GET|x=1|#{preview_host}"
  end

  test "relays websocket frames through the preview proxy", %{
    endpoint_port: endpoint_port,
    scope: scope,
    user: user
  } do
    upstream_port = free_port()

    start_supervised!({Bandit, plug: UpstreamPlug, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    preview_host = "#{sandbox.id}.preview.frontman.local"
    cookie = session_cookie_for(user)

    {:ok, conn_pid} = :gun.open(~c"127.0.0.1", endpoint_port)
    assert_receive {:gun_up, ^conn_pid, _protocol}, 1_000

    stream_ref =
      :gun.ws_upgrade(conn_pid, "/hmr", [
        {"host", preview_host},
        {"cookie", cookie}
      ])

    assert_receive {:gun_upgrade, ^conn_pid, ^stream_ref, ["websocket"], _headers}, 1_000

    :ok = :gun.ws_send(conn_pid, stream_ref, {:text, "hello"})

    assert_receive {:gun_ws, ^conn_pid, ^stream_ref, {:text, "echo:hello"}}, 1_000

    :ok = :gun.close(conn_pid)
  end

  test "does not forward auth cookies to upstream websocket preview target", %{
    endpoint_port: endpoint_port,
    scope: scope,
    user: user
  } do
    upstream_port = free_port()

    start_supervised!({Bandit, plug: UpstreamPlug, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    preview_host = "#{sandbox.id}.preview.frontman.local"

    cookie =
      session_cookie_for(user) <>
        "; _frontman_server_web_user_remember_me=abc123; sandbox_pref=keep"

    {:ok, conn_pid} = :gun.open(~c"127.0.0.1", endpoint_port)
    assert_receive {:gun_up, ^conn_pid, _protocol}, 1_000

    stream_ref =
      :gun.ws_upgrade(conn_pid, "/hmr-cookie", [
        {"host", preview_host},
        {"cookie", cookie}
      ])

    assert_receive {:gun_upgrade, ^conn_pid, ^stream_ref, ["websocket"], _headers}, 1_000

    :ok = :gun.ws_send(conn_pid, stream_ref, {:text, "cookie-header"})

    assert_receive {:gun_ws, ^conn_pid, ^stream_ref, {:text, upstream_cookie}}, 1_000

    assert upstream_cookie == "cookie:sandbox_pref=keep"
    refute String.contains?(upstream_cookie, "_frontman_server_key=")
    refute String.contains?(upstream_cookie, "_frontman_server_web_user_remember_me=")

    :ok = :gun.close(conn_pid)
  end

  test "returns HTTP 401 for unauthenticated websocket upgrade", %{
    endpoint_port: endpoint_port,
    scope: scope
  } do
    upstream_port = free_port()

    start_supervised!({Bandit, plug: UpstreamPlug, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    preview_host = "#{sandbox.id}.preview.frontman.local"

    {:ok, conn_pid} = :gun.open(~c"127.0.0.1", endpoint_port)
    assert_receive {:gun_up, ^conn_pid, _protocol}, 1_000

    stream_ref = :gun.ws_upgrade(conn_pid, "/hmr", [{"host", preview_host}])

    assert_receive {:gun_response, ^conn_pid, ^stream_ref, :nofin, 401, _headers}, 1_000
    assert_receive {:gun_data, ^conn_pid, ^stream_ref, :fin, "authentication_required"}, 1_000

    :ok = :gun.close(conn_pid)
  end

  test "does not forward auth cookies to upstream HTTP preview target", %{
    endpoint_port: endpoint_port,
    scope: scope,
    user: user
  } do
    upstream_port = free_port()

    start_supervised!({Bandit, plug: UpstreamPlug, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    preview_host = "#{sandbox.id}.preview.frontman.local"

    response =
      Req.get!(
        "http://127.0.0.1:#{endpoint_port}/inspect-cookie",
        headers: [
          {"host", preview_host},
          {"cookie", session_cookie_for(user) <> "; _frontman_server_web_user_remember_me=abc123"}
        ],
        retry: false,
        redirect: false
      )

    assert response.status == 200
    refute String.contains?(response.body, "_frontman_server_key=")
    refute String.contains?(response.body, "_frontman_server_web_user_remember_me=")
  end

  test "does not forward upstream set-cookie headers to preview responses", %{
    endpoint_port: endpoint_port,
    scope: scope,
    user: user
  } do
    upstream_port = free_port()

    start_supervised!({Bandit, plug: UpstreamPlug, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    preview_host = "#{sandbox.id}.preview.frontman.local"

    response =
      Req.get!(
        "http://127.0.0.1:#{endpoint_port}/set-cookie",
        headers: [
          {"host", preview_host},
          {"cookie", session_cookie_for(user)}
        ],
        retry: false,
        redirect: false
      )

    assert response.status == 200
    assert response.body == "cookie-set"
    assert Map.get(response.headers, "set-cookie", []) == []
  end

  test "does not leak upstream gun connections when websocket upgrade is rejected", %{
    endpoint_port: endpoint_port,
    scope: scope,
    user: user
  } do
    upstream_port = free_port()

    start_supervised!({Bandit, plug: UpstreamPlug, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    preview_host = "#{sandbox.id}.preview.frontman.local"
    cookie = session_cookie_for(user)

    with_proxy_config([websocket_upgrade_timeout_ms: 50], fn ->
      baseline_connections = gun_connection_count()

      Enum.each(1..3, fn _attempt ->
        {:ok, conn_pid} = :gun.open(~c"127.0.0.1", endpoint_port)
        assert_receive {:gun_up, ^conn_pid, _protocol}, 1_000

        stream_ref =
          :gun.ws_upgrade(conn_pid, "/hmr-timeout", [
            {"host", preview_host},
            {"cookie", cookie}
          ])

        outcome =
          receive do
            {:gun_response, ^conn_pid, ^stream_ref, :nofin, status, _headers} ->
              {:response, status}

            {:gun_upgrade, ^conn_pid, ^stream_ref, ["websocket"], _headers} ->
              :upgraded
          after
            1_000 ->
              flunk("expected websocket rejection result")
          end

        case outcome do
          {:response, 502} ->
            assert_receive {:gun_data, ^conn_pid, ^stream_ref, :fin, "upstream_unreachable"},
                           1_000

          {:response, status} ->
            flunk("expected rejected websocket upgrade status 502, got #{status}")

          :upgraded ->
            assert_receive {:gun_down, ^conn_pid, :ws, _reason, _killed_streams}, 1_000
        end

        :ok = :gun.close(conn_pid)
      end)

      assert_eventually(fn -> gun_connection_count() == baseline_connections end, 2_000)
    end)
  end

  test "keeps the original chunked response when upstream streaming errors", %{
    endpoint_port: endpoint_port,
    scope: scope,
    user: user
  } do
    upstream_port = free_port()

    start_supervised!({Bandit, plug: UpstreamPlug, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    preview_host = "#{sandbox.id}.preview.frontman.local"

    with_proxy_config([upstream_stream_timeout_ms: 50], fn ->
      {:ok, socket} =
        :gen_tcp.connect(
          ~c"127.0.0.1",
          endpoint_port,
          [:binary, active: false, packet: :raw],
          1_000
        )

      request = [
        "GET /chunked-timeout HTTP/1.1\r\n",
        "Host: #{preview_host}\r\n",
        "Cookie: #{session_cookie_for(user)}\r\n",
        "Connection: close\r\n",
        "\r\n"
      ]

      :ok = :gen_tcp.send(socket, request)
      raw_response = recv_until_closed(socket, "")
      :ok = :gen_tcp.close(socket)

      assert String.starts_with?(raw_response, "HTTP/1.1 200")
      refute String.contains?(raw_response, "upstream_unreachable")
    end)
  end

  defp session_cookie_for(user) do
    token = Accounts.generate_user_session_token(user)

    conn =
      Plug.Test.conn("GET", "/")
      |> Map.put(:secret_key_base, FrontmanServerWeb.Endpoint.config(:secret_key_base))
      |> Session.call(Session.init(@session_options))
      |> Conn.fetch_session()
      |> Conn.put_session(:user_token, token)
      |> Conn.send_resp(200, "ok")

    conn
    |> Conn.get_resp_header("set-cookie")
    |> Enum.find(&String.starts_with?(&1, "_frontman_server_key="))
    |> String.split(";", parts: 2)
    |> List.first()
  end

  defp gun_connection_count do
    case Process.whereis(:gun_conns_sup) do
      nil -> 0
      _pid -> Supervisor.count_children(:gun_conns_sup).active
    end
  end

  defp assert_eventually(assertion, timeout_ms) when is_function(assertion, 0) do
    started_at = System.monotonic_time(:millisecond)
    do_assert_eventually(assertion, started_at, timeout_ms)
  end

  defp do_assert_eventually(assertion, started_at, timeout_ms) do
    case assertion.() do
      true ->
        :ok

      false ->
        if System.monotonic_time(:millisecond) - started_at < timeout_ms do
          Process.sleep(20)
          do_assert_eventually(assertion, started_at, timeout_ms)
        else
          flunk("condition was not met within #{timeout_ms}ms")
        end
    end
  end

  defp with_proxy_config(overrides, run) when is_function(run, 0) do
    original = Application.get_env(:frontman_server, :sandbox_preview_proxy, [])

    Application.put_env(
      :frontman_server,
      :sandbox_preview_proxy,
      Keyword.merge(original, overrides)
    )

    try do
      run.()
    after
      Application.put_env(:frontman_server, :sandbox_preview_proxy, original)
    end
  end

  defp recv_until_closed(socket, acc) do
    case :gen_tcp.recv(socket, 0, 500) do
      {:ok, chunk} -> recv_until_closed(socket, acc <> chunk)
      {:error, :closed} -> acc
      {:error, :timeout} -> acc
    end
  end

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
