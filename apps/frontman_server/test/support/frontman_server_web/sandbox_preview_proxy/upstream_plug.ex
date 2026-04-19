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

  def call(%Plug.Conn{request_path: "/hello"} = conn, _opts) do
    forwarded_host = conn |> get_req_header("x-forwarded-host") |> List.first()
    send_resp(conn, 200, "#{conn.method}|#{conn.query_string}|#{forwarded_host}")
  end

  def call(conn, _opts), do: send_resp(conn, 404, "missing")
end
