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

    assert get_resp_header(conn, "content-security-policy") == [
             "base-uri 'self'; frame-ancestors 'self';"
           ]

    assert conn.resp_body =~ ~s(name="_csrf_token")
    assert conn.resp_body =~ ~s(name="ref" value="#{pending["ref"]}")
  end

  test "escapes the pending reference in the continuation form", %{conn: conn} do
    user = user_fixture()
    ref = ~s|" autofocus onfocus="alert('handoff')|

    conn =
      conn
      |> log_in_user(user)
      |> put_session(:connect_handoff, %{
        "external_auth_id" => "unverified",
        "ref" => ref,
        "started_at" => System.system_time(:second),
        "user_id" => user.id
      })
      |> get("/auth/mcp/workos/pending", %{ref: ref})

    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert LazyHTML.attribute(
             LazyHTML.query(document, "#connect-handoff input[name=ref]"),
             "value"
           ) ==
             [ref]

    assert LazyHTML.query(document, "#connect-handoff input[autofocus]") |> LazyHTML.to_tree() ==
             []
  end

  test "requires a valid CSRF token for the continuation form", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture())
      |> get("/auth/mcp/workos?external_auth_id=unverified")

    conn = conn |> recycle() |> get(redirected_to(conn))
    document = conn |> html_response(200) |> LazyHTML.from_document()

    [csrf_token] =
      LazyHTML.attribute(LazyHTML.query(document, "input[name=_csrf_token]"), "value")

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/auth/mcp/workos/pending", ref: "mismatch")
    end

    assert conn
           |> recycle()
           |> put_private(:plug_skip_csrf_protection, false)
           |> post("/auth/mcp/workos/pending", %{ref: "mismatch", _csrf_token: csrf_token})
           |> response(400)
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

  test "rejects ambiguous linked provider identities", %{conn: conn} do
    user = user_fixture()
    identity_fixture(user, %{provider: "github"})
    identity_fixture(user, %{provider: "google"})

    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=opaque")
    ref = get_session(conn, :connect_handoff)["ref"]

    assert conn
           |> recycle()
           |> post("/auth/mcp/workos/pending", ref: ref)
           |> response(400) == "Authorization could not continue"
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
