defmodule FrontmanServerWeb.TestSupport.SandboxPreviewProxy.UpstreamPlug do
  @moduledoc false

  import Plug.Conn

  alias FrontmanServerWeb.TestSupport.SandboxPreviewProxy.UpstreamEchoSocket

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/hmr"} = conn, _opts) do
    conn
    |> WebSockAdapter.upgrade(UpstreamEchoSocket, %{}, [])
    |> halt()
  end

  def call(%Plug.Conn{request_path: "/hmr-cookie"} = conn, _opts) do
    cookie = conn |> get_req_header("cookie") |> List.first()

    conn
    |> WebSockAdapter.upgrade(UpstreamEchoSocket, %{cookie: cookie}, [])
    |> halt()
  end

  def call(%Plug.Conn{request_path: "/hmr-reject"} = conn, _opts) do
    send_resp(conn, 426, "upgrade_required")
  end

  def call(%Plug.Conn{request_path: "/hmr-timeout"} = conn, _opts) do
    Process.sleep(1_000)
    send_resp(conn, 408, "timeout")
  end

  def call(%Plug.Conn{request_path: "/hello"} = conn, _opts) do
    forwarded_host = conn |> get_req_header("x-forwarded-host") |> List.first()
    send_resp(conn, 200, "#{conn.method}|#{conn.query_string}|#{forwarded_host}")
  end

  def call(%Plug.Conn{request_path: "/inspect-cookie"} = conn, _opts) do
    cookie = conn |> get_req_header("cookie") |> List.first()
    send_resp(conn, 200, cookie || "")
  end

  def call(%Plug.Conn{request_path: "/set-cookie"} = conn, _opts) do
    conn
    |> put_resp_header("set-cookie", "_frontman_server_key=evil; Domain=.frontman.local; Path=/")
    |> send_resp(200, "cookie-set")
  end

  def call(%Plug.Conn{request_path: "/chunked-timeout"} = conn, _opts) do
    conn = send_chunked(conn, 200)
    {:ok, conn} = chunk(conn, "partial-")
    Process.sleep(200)
    conn
  end

  def call(conn, _opts), do: send_resp(conn, 404, "missing")
end
