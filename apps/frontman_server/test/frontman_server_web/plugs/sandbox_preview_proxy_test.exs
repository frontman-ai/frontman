defmodule FrontmanServerWeb.Plugs.SandboxPreviewProxyTest.UpstreamStub do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/proxy-ok" do
    send_resp(conn, 200, "ok:#{conn.query_string}")
  end

  get "/burst-stream" do
    conn = send_chunked(conn, 200)
    payload = String.duplicate("x", 256 * 1024)

    conn =
      Enum.reduce_while(1..3, conn, fn _index, conn ->
        case chunk(conn, payload) do
          {:ok, conn} ->
            Process.sleep(100)
            {:cont, conn}

          {:error, _reason} ->
            {:halt, conn}
        end
      end)

    conn
  end

  post "/echo" do
    {:ok, body, conn} = read_body(conn)
    send_resp(conn, 200, body)
  end

  match _ do
    send_resp(conn, 404, "missing")
  end
end

defmodule FrontmanServerWeb.Plugs.SandboxPreviewProxyTest.FailingChunkAdapter do
  @moduledoc false

  @behaviour Plug.Conn.Adapter

  alias Plug.Adapters.Test.Conn, as: TestAdapter

  def wrap(%Plug.Conn{adapter: {TestAdapter, state}} = conn) do
    %{conn | adapter: {__MODULE__, %{state: state}}}
  end

  def send_resp(%{state: state} = payload, status, headers, body) do
    {:ok, sent_body, next_state} = TestAdapter.send_resp(state, status, headers, body)
    {:ok, sent_body, %{payload | state: next_state}}
  end

  def send_file(%{state: state} = payload, status, headers, file, offset, length) do
    {:ok, sent_body, next_state} =
      TestAdapter.send_file(state, status, headers, file, offset, length)

    {:ok, sent_body, %{payload | state: next_state}}
  end

  def send_chunked(%{state: state} = payload, status, headers) do
    {:ok, sent_body, next_state} = TestAdapter.send_chunked(state, status, headers)
    {:ok, sent_body, %{payload | state: next_state}}
  end

  def chunk(_payload, _body), do: {:error, :closed}

  def read_req_body(%{state: state} = payload, options) do
    case TestAdapter.read_req_body(state, options) do
      {:ok, data, next_state} ->
        {:ok, data, %{payload | state: next_state}}

      {:more, data, next_state} ->
        {:more, data, %{payload | state: next_state}}
    end
  end

  def inform(%{state: state}, status, headers) do
    TestAdapter.inform(state, status, headers)
  end

  def upgrade(%{state: state} = payload, protocol, options) do
    case TestAdapter.upgrade(state, protocol, options) do
      {:ok, next_state} -> {:ok, %{payload | state: next_state}}
      {:error, reason} -> {:error, reason}
    end
  end

  def push(%{state: state}, path, headers) do
    TestAdapter.push(state, path, headers)
  end

  def get_peer_data(%{state: state}) do
    TestAdapter.get_peer_data(state)
  end

  def get_sock_data(%{state: state}) do
    TestAdapter.get_sock_data(state)
  end

  def get_ssl_data(%{state: state}) do
    TestAdapter.get_ssl_data(state)
  end

  def get_http_protocol(%{state: state}) do
    TestAdapter.get_http_protocol(state)
  end
end

defmodule FrontmanServerWeb.Plugs.SandboxPreviewProxyTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServerWeb.Plugs.SandboxPreviewProxyTest.FailingChunkAdapter
  alias FrontmanServerWeb.Plugs.SandboxPreviewProxyTest.UpstreamStub
  alias Plug.Adapters.Test.Conn, as: TestConnAdapter

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

  test "cancels async upstream stream when chunk relay fails", %{
    conn: conn,
    scope: scope,
    user: user
  } do
    upstream_port = free_port()
    start_supervised!({Bandit, plug: UpstreamStub, ip: {127, 0, 0, 1}, port: upstream_port})

    sandbox =
      sandbox_fixture(scope, %{
        status: :running,
        port_map: %{"3000" => upstream_port, "web_preview_host_port" => upstream_port}
      })

    leaked_before = drain_req_async_messages()
    assert leaked_before == 0

    conn =
      conn
      |> authenticate_as(user)
      |> with_host("#{sandbox.id}.preview.frontman.local")
      |> TestConnAdapter.conn("GET", "/burst-stream", nil)
      |> with_failing_chunk_adapter()

    conn = FrontmanServerWeb.Endpoint.call(conn, FrontmanServerWeb.Endpoint.init([]))

    assert conn.status == 200

    # Allow any post-failure async stream messages to land in mailbox.
    Process.sleep(200)

    leaked_after = drain_req_async_messages()

    assert leaked_after == 0
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

  defp with_failing_chunk_adapter(conn) do
    FailingChunkAdapter.wrap(conn)
  end

  defp drain_req_async_messages(count \\ 0) do
    receive do
      {_ref, {:data, _data}} ->
        drain_req_async_messages(count + 1)

      {_ref, {:trailers, _trailers}} ->
        drain_req_async_messages(count + 1)

      {_ref, {:error, _reason}} ->
        drain_req_async_messages(count + 1)

      {_ref, :done} ->
        drain_req_async_messages(count + 1)
    after
      0 -> count
    end
  end

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
