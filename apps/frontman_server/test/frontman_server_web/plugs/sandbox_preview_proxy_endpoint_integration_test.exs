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

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
