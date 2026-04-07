defmodule FrontmanServerWeb.Plugs.CORSTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias FrontmanServerWeb.Plugs.CORS

  test "adds wildcard cors headers for api paths" do
    conn =
      conn("GET", "/api/user/me")
      |> put_req_header("origin", "http://localhost:3011")
      |> CORS.call(path_prefix: "/api")

    assert get_resp_header(conn, "vary") == ["origin"]
    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3011"]
    assert get_resp_header(conn, "access-control-allow-methods") == ["GET, POST, DELETE, OPTIONS"]
    assert get_resp_header(conn, "access-control-allow-headers") == ["content-type"]
    assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
  end

  test "halts preflight requests for api paths" do
    conn =
      conn("OPTIONS", "/api/user/me")
      |> put_req_header("origin", "http://localhost:3011")
      |> CORS.call(path_prefix: "/api")

    assert conn.halted
    assert conn.status == 204
    assert conn.resp_body == ""
    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3011"]
  end

  test "does not add cors headers outside configured path prefix" do
    conn = conn("GET", "/health") |> CORS.call(path_prefix: "/api")

    assert get_resp_header(conn, "access-control-allow-origin") == []
  end

  test "falls back to wildcard when no origin header is present" do
    conn = conn("GET", "/api/user/me") |> CORS.call(path_prefix: "/api")

    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
  end
end
