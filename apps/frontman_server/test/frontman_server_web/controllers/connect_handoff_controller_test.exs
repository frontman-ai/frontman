defmodule FrontmanServerWeb.ConnectHandoffControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  test "retains a pending provider request through Frontman login", %{conn: conn} do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        FrontmanServer.Accounts.deliver_login_instructions(user, url)
      end)

    conn = get(conn, "/auth/mcp/workos?external_auth_id=unverified-request")
    assert redirected_to(conn) == "/users/log-in"
    pending = get_session(conn, :connect_handoff)
    assert pending["external_auth_id"] == "unverified-request"

    conn = conn |> recycle() |> get("/users/log-in")
    conn = conn |> recycle() |> post("/users/log-in", user: %{token: token})
    assert redirected_to(conn) == "/auth/mcp/workos/pending?ref=#{pending["ref"]}"

    conn = conn |> recycle() |> get(redirected_to(conn))
    assert html_response(conn, 200) =~ "does not grant access to a WordPress site"
    refute conn.resp_body =~ "unverified-request"
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
  end

  test "rejects missing, oversized, and mismatched requests", %{conn: conn} do
    assert conn |> get("/auth/mcp/workos") |> response(400)

    assert conn
           |> get("/auth/mcp/workos?external_auth_id=" <> String.duplicate("x", 513))
           |> response(400)

    conn = conn |> log_in_user(user_fixture()) |> get("/auth/mcp/workos?external_auth_id=opaque")
    conn = conn |> recycle() |> get("/auth/mcp/workos/pending?ref=other")
    assert response(conn, 400)
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  test "scrubs request and referrer from Sentry", %{conn: conn} do
    conn =
      conn
      |> put_req_header("referer", "https://frontman.example/auth/mcp/workos/pending?ref=private")
      |> get("/auth/mcp/workos?external_auth_id=private")

    scrubbed = Sentry.Scrubber.scrub(conn)
    assert scrubbed.query_params == %{}
    assert scrubbed.query_string == ""
    assert scrubbed.params == %{}
    refute inspect(scrubbed.req_headers) =~ "private"
    refute inspect(Sentry.PlugContext.build_request_interface_data(conn, [])) =~ "private"
  end

  test "rejects stale references, expired requests and a different user", %{conn: conn} do
    user = user_fixture()
    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=first")
    first = get_session(conn, :connect_handoff)
    conn = conn |> recycle() |> get("/auth/mcp/workos?external_auth_id=second")
    second = get_session(conn, :connect_handoff)
    user_token = get_session(conn, :user_token)

    assert conn
           |> recycle()
           |> post("/auth/mcp/workos/pending", ref: first["ref"])
           |> response(400)

    for pending <- [
          %{second | "started_at" => System.system_time(:second) - 901},
          %{second | "user_id" => user_fixture().id}
        ] do
      assert conn
             |> recycle()
             |> init_test_session(%{user_token: user_token, connect_handoff: pending})
             |> post("/auth/mcp/workos/pending", ref: second["ref"])
             |> response(400)
    end
  end
end
