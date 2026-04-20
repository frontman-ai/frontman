defmodule FrontmanServerWeb.Plugs.SandboxPreviewProxyTest.UpstreamStub do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/proxy-ok" do
    send_resp(conn, 200, "ok:#{conn.query_string}")
  end

  post "/echo" do
    {:ok, body, conn} = read_body(conn)
    send_resp(conn, 200, body)
  end

  match _ do
    send_resp(conn, 404, "missing")
  end
end

defmodule FrontmanServerWeb.Plugs.SandboxPreviewProxyTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServerWeb.Plugs.SandboxPreviewProxyTest.UpstreamStub

  setup %{conn: conn} do
    user = user_fixture()
    scope = Scope.for_user(user)

    conn =
      conn
      |> Map.replace!(:secret_key_base, FrontmanServerWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{conn: conn, user: user, scope: scope}
  end

  test "redirects unauthenticated preview requests to app login with return_to", %{
    conn: conn,
    scope: scope
  } do
    host_port = 13_000

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"web_preview_host_port" => host_port}
      })

    preview_host = "#{sandbox.id}.preview.frontman.local"

    conn =
      conn
      |> with_host(preview_host)
      |> get("/proxy-ok?x=1")

    assert conn.status == 302

    location = redirected_to(conn, 302)
    uri = URI.parse(location)

    assert uri.scheme == "http"
    assert uri.host == "frontman.local"
    assert uri.port == 4002
    assert uri.path == "/users/log-in"

    params = URI.decode_query(uri.query)
    assert params["return_to"] == "http://#{preview_host}/proxy-ok?x=1"
  end

  test "returns 404 for unknown sandbox_id on preview host", %{conn: conn, user: user} do
    conn =
      conn
      |> authenticate_as(user)
      |> with_host("#{Ecto.UUID.generate()}.preview.frontman.local")
      |> get("/proxy-ok")

    assert conn.status == 404
    assert conn.resp_body == "not_found"
  end

  test "returns 404 for non-UUID sandbox_id on preview host", %{conn: conn, user: user} do
    conn =
      conn
      |> authenticate_as(user)
      |> with_host("admin.preview.frontman.local")
      |> get("/proxy-ok")

    assert conn.status == 404
    assert conn.resp_body == "not_found"
  end

  test "returns 404 for non-owner sandbox", %{conn: conn, scope: scope} do
    host_port = 13_000

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"web_preview_host_port" => host_port}
      })

    other_user = user_fixture()

    conn =
      conn
      |> authenticate_as(other_user)
      |> with_host("#{sandbox.id}.preview.frontman.local")
      |> get("/proxy-ok")

    assert conn.status == 404
    assert conn.resp_body == "not_found"
  end

  test "returns 503 when sandbox exists but is unavailable", %{
    conn: conn,
    scope: scope,
    user: user
  } do
    host_port = 13_000

    sandbox =
      sandbox_fixture(scope, %{
        status: :stopped,
        port_map: %{"web_preview_host_port" => host_port}
      })

    conn =
      conn
      |> authenticate_as(user)
      |> with_host("#{sandbox.id}.preview.frontman.local")
      |> get("/proxy-ok")

    assert conn.status == 503
    assert conn.resp_body == "sandbox_unavailable"
  end

  test "proxies HTTP traffic for authenticated owner", %{conn: conn, scope: scope, user: user} do
    upstream_port = free_port()
    start_supervised!({Bandit, plug: UpstreamStub, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    conn =
      conn
      |> authenticate_as(user)
      |> with_host("#{sandbox.id}.preview.frontman.local")
      |> get("/proxy-ok?x=1")

    assert conn.status == 200
    assert conn.resp_body == "ok:x=1"
  end

  test "returns 502 when upstream port is unreachable", %{conn: conn, scope: scope, user: user} do
    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"web_preview_host_port" => free_port()}
      })

    conn =
      conn
      |> authenticate_as(user)
      |> with_host("#{sandbox.id}.preview.frontman.local")
      |> get("/proxy-ok")

    assert conn.status == 502
    assert conn.resp_body == "upstream_unreachable"
  end

  test "returns 401 for unauthenticated websocket upgrade requests", %{conn: conn, scope: scope} do
    host_port = 13_000

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"web_preview_host_port" => host_port}
      })

    conn =
      conn
      |> with_host("#{sandbox.id}.preview.frontman.local")
      |> put_req_header("upgrade", "websocket")
      |> put_req_header("connection", "Upgrade")
      |> get("/ws")

    assert conn.status == 401
    assert conn.resp_body == "authentication_required"
  end

  defp authenticate_as(conn, user) do
    token = Accounts.generate_user_session_token(user)
    init_test_session(conn, %{user_token: token})
  end

  defp with_host(conn, host) do
    %{conn | host: host}
  end

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
