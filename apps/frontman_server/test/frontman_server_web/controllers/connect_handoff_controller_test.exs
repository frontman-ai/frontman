defmodule FrontmanServerWeb.ConnectHandoffControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.BillingFixtures
  import FrontmanServer.StripeIntegrationCase

  alias FrontmanServer.Repo
  alias FrontmanServer.WordPress.Connection

  setup :setup_paper_tiger

  test "retains a pending provider request through Frontman login", %{conn: conn} do
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))
    insert_site(user)
    {token, _hashed_token} = generate_user_magic_link_token(user)
    conn = get(conn, "/auth/mcp/workos?external_auth_id=unverified-request")
    assert redirected_to(conn) == "/users/log-in"
    pending = get_session(conn, :connect_handoff)
    assert pending["external_auth_id"] == "unverified-request"
    conn = conn |> recycle() |> get("/users/log-in")
    conn = conn |> recycle() |> post("/users/log-in", user: %{token: token})
    assert redirected_to(conn) == "/auth/mcp/workos/pending?ref=#{pending["ref"]}"
    conn = conn |> recycle() |> get(redirected_to(conn))
    document = conn |> html_response(200) |> LazyHTML.from_document()
    assert LazyHTML.query(document, "#connect-account") |> LazyHTML.text() =~ user.email
    assert conn.resp_body =~ "Connect your WordPress site"
    assert conn.resp_body =~ "read, change, and delete"
    assert conn.resp_body =~ "This selection does not restrict access to only one site"
    refute conn.resp_body =~ "unverified-request"
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
    assert get_resp_header(conn, "cache-control") == ["no-store"]

    assert get_resp_header(conn, "content-security-policy") == [
             "base-uri 'self'; frame-ancestors 'self';"
           ]

    assert conn.resp_body =~ ~s(name="_csrf_token")
    assert conn.resp_body =~ ~s(name="ref" value="#{pending["ref"]}")
  end

  test "assistant login context requires a live session-backed handoff", %{conn: conn} do
    generic = get(conn, "/users/log-in?from=chatgpt")
    refute html_response(generic, 200) =~ ~s(id="assistant-requirements")
    conn = get(conn, "/auth/mcp/workos?external_auth_id=private-request")
    pending = get_session(conn, :connect_handoff)
    conn = conn |> recycle() |> get("/users/log-in")
    page = html_response(conn, 200)
    assert page =~ "Sign in to Frontman"
    assert page =~ "no separate AI-provider API key"
    assert page =~ "active Frontman plan or eligible trial"
    assert page =~ "Continue with Google"
    assert page =~ "Continue with GitHub"
    refute page =~ "private-request"
    expired = Map.put(pending, "started_at", System.system_time(:second) - 901)

    conn =
      conn |> recycle() |> init_test_session(connect_handoff: expired) |> get("/users/log-in")

    refute html_response(conn, 200) =~ ~s(id="assistant-requirements")
  end

  test "Google and GitHub cancellation retain the setup context for retry", %{conn: conn} do
    for provider <- ~w(google github) do
      started = get(conn, "/auth/mcp/workos?external_auth_id=private-request")
      pending = get_session(started, :connect_handoff)
      started = started |> recycle() |> post("/auth/#{provider}")
      state = get_session(started, :oauth_signin_state)["state"]

      returned =
        started
        |> recycle()
        |> get("/auth/callback", %{"error" => "access_denied", "state" => state})

      assert redirected_to(returned) == "/users/log-in"
      assert get_session(returned, :connect_handoff) == pending
      assert get_session(returned, :user_return_to) =~ pending["ref"]

      assert returned |> recycle() |> get("/users/log-in") |> html_response(200) =~
               ~s(id="assistant-requirements")
    end
  end

  test "email verification uses its own flow context, not an unrelated assistant tab", %{
    conn: conn
  } do
    conn = get(conn, "/auth/mcp/workos?external_auth_id=private-request")
    pending = get_session(conn, :connect_handoff)

    for embedded_request <- [nil, %{"origin" => "https://site.example", "state" => "embedded"}] do
      verification = %{
        "email" => "alex@example.com",
        "state" => "verification",
        "request" => embedded_request
      }

      page =
        conn
        |> recycle()
        |> init_test_session(connect_handoff: pending, pending_auth: verification)
        |> get("/auth/verify-email")
        |> html_response(200)

      assert page =~ "Verify your email"

      case embedded_request do
        nil -> assert page =~ "Next, connect your WordPress site"
        _ -> refute page =~ "Next, connect your WordPress site"
      end
    end
  end

  test "switching accounts retains setup and binds it to the next signed-in user", %{conn: conn} do
    first_user = user_fixture()
    next_user = user_fixture()

    conn =
      conn |> log_in_user(first_user) |> get("/auth/mcp/workos?external_auth_id=private-request")

    pending = get_session(conn, :connect_handoff)
    previous_token = get_session(conn, :user_token)
    conn = conn |> recycle() |> get(redirected_to(conn))
    document = conn |> html_response(200) |> LazyHTML.from_document()
    form = LazyHTML.query(document, "#connect-switch-account")
    [action] = LazyHTML.attribute(form, "action")
    [csrf] = LazyHTML.attribute(LazyHTML.query(form, "input[name=_csrf_token]"), "value")

    conn =
      conn
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post(action, %{ref: pending["ref"], _csrf_token: csrf})

    assert redirected_to(conn) == "/users/log-in"
    refute get_session(conn, :user_token)
    refute FrontmanServer.Accounts.get_user_by_session_token(previous_token)
    assert get_session(conn, :connect_handoff) == Map.put(pending, "user_id", nil)
    conn = conn |> recycle() |> get("/users/log-in")
    {token, _hashed_token} = generate_user_magic_link_token(next_user)
    conn = conn |> recycle() |> post("/users/log-in", user: %{token: token})
    assert redirected_to(conn) == "/auth/mcp/workos/pending?ref=#{pending["ref"]}"
    conn = conn |> recycle() |> get(redirected_to(conn))
    page = html_response(conn, 200)
    assert page =~ next_user.email
    refute page =~ first_user.email
    assert get_session(conn, :connect_handoff)["user_id"] == next_user.id
  end

  test "continuation and account switching require CSRF and valid references", %{conn: conn} do
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))
    insert_site(user)
    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=private")
    pending = get_session(conn, :connect_handoff)
    token = get_session(conn, :user_token)
    conn = conn |> recycle() |> get(redirected_to(conn))
    document = conn |> html_response(200) |> LazyHTML.from_document()

    [csrf] =
      LazyHTML.query(document, "#connect-handoff input[name=_csrf_token]")
      |> LazyHTML.attribute("value")

    for path <- ["/auth/mcp/workos/pending", "/auth/mcp/workos/switch-account"] do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post(path, ref: pending["ref"])
      end

      rejected =
        conn
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post(path, ref: "wrong", _csrf_token: csrf)

      assert html_response(rejected, 400) =~ ~s(id="connect-expired")
      assert get_session(rejected, :user_token) == token
      assert get_session(rejected, :connect_handoff) == pending
    end
  end

  test "escapes the pending reference in the continuation form", %{conn: conn} do
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))
    insert_site(user)
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

    assert LazyHTML.query(document, "#connect-handoff input[name=ref]")
           |> LazyHTML.attribute("value") == [ref]

    assert LazyHTML.query(document, "#connect-handoff input[autofocus]") |> LazyHTML.to_tree() ==
             []
  end

  test "missing, oversized, stale, expired and cross-account requests render recovery", %{
    conn: conn
  } do
    for params <- [%{}, %{external_auth_id: String.duplicate("x", 513)}] do
      assert conn |> get("/auth/mcp/workos", params) |> html_response(400) =~
               "Your setup is saved"
    end

    conn = conn |> log_in_user(user_fixture()) |> get("/auth/mcp/workos?external_auth_id=first")
    first = get_session(conn, :connect_handoff)
    conn = conn |> recycle() |> get("/auth/mcp/workos?external_auth_id=second")
    second = get_session(conn, :connect_handoff)

    for {pending, ref} <- [
          {second, first["ref"]},
          {Map.put(second, "started_at", System.system_time(:second) - 901), second["ref"]},
          {Map.put(second, "user_id", user_fixture().id), second["ref"]}
        ] do
      for method <- [:get, :post] do
        result =
          conn
          |> recycle()
          |> init_test_session(connect_handoff: pending)
          |> dispatch(@endpoint, method, "/auth/mcp/workos/pending", %{ref: ref})

        page = html_response(result, 400)
        assert page =~ ~s(id="connect-expired")
        assert page =~ "View saved site setup"
        refute page =~ "external_auth_id"
        refute get_session(result, :setup_site_id)
      end
    end
  end

  test "pending GET and POST require authentication", %{conn: conn} do
    assert conn |> get("/auth/mcp/workos/pending?ref=private") |> redirected_to() ==
             "/users/log-in"

    assert conn |> post("/auth/mcp/workos/pending", ref: "private") |> redirected_to() ==
             "/users/log-in"
  end

  test "ambiguous or cross-account identities render authorization failure and retain handoff", %{
    conn: conn
  } do
    for kind <- [:ambiguous, :cross_account] do
      user = user_fixture()
      subscription_for_scope_fixture(user_scope_fixture(user))
      site = insert_site(user)
      identity = identity_fixture(user, %{provider: "github"})

      case kind do
        :ambiguous ->
          identity_fixture(user, %{provider: "google"})

        :cross_account ->
          identity_fixture(user_fixture(), %{
            provider: "google",
            provider_id: identity.provider_id
          })
      end

      started =
        conn |> recycle() |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=private")

      pending = get_session(started, :connect_handoff)

      result =
        started
        |> recycle()
        |> post("/auth/mcp/workos/pending", ref: pending["ref"], site_id: site.id)

      assert html_response(result, 400) =~ "Your assistant could not authorize this account"
      assert get_session(result, :connect_handoff) == pending
      refute result.resp_body =~ "secret-password"
    end
  end

  test "inactive access and foreign sites cannot authorize", %{conn: conn} do
    for status <- [
          "none",
          "past_due",
          "unpaid",
          "canceled",
          "incomplete",
          "incomplete_expired",
          "paused",
          "unknown"
        ] do
      user = user_fixture()

      if status != "none",
        do: subscription_for_scope_fixture(user_scope_fixture(user), %{status: status})

      site = insert_site(user)

      started =
        conn |> recycle() |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=private")

      pending = get_session(started, :connect_handoff)
      shown = started |> recycle() |> get(redirected_to(started))
      assert html_response(shown, 200) =~ ~s(id="connect-access")
      refute shown.resp_body =~ ~s(id="connect-continue")

      blocked =
        shown
        |> recycle()
        |> post("/auth/mcp/workos/pending", ref: pending["ref"], site_id: site.id)

      assert html_response(blocked, 403) =~ "Connect a site and activate assistant access"
      assert get_session(blocked, :connect_handoff) == pending
    end

    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))
    insert_site(user)
    foreign = insert_site(user_fixture())

    started =
      conn |> recycle() |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=private")

    pending = get_session(started, :connect_handoff)

    blocked =
      started
      |> recycle()
      |> post("/auth/mcp/workos/pending", ref: pending["ref"], site_id: foreign.id)

    assert html_response(blocked, 403)
    assert get_session(blocked, :connect_handoff) == pending
    refute get_session(blocked, :setup_site_id)
  end

  test "access is rechecked on POST after a trial is canceled", %{conn: conn} do
    user = user_fixture()
    subscription = subscription_for_scope_fixture(user_scope_fixture(user), %{status: "trialing"})
    site = insert_site(user)
    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=private")
    pending = get_session(conn, :connect_handoff)
    shown = conn |> recycle() |> get(redirected_to(conn))
    assert html_response(shown, 200) =~ "Continue to your assistant"
    refute shown.resp_body =~ "/wordpress/connect/checkout"
    subscription |> Ecto.Changeset.change(canceled_at: ~U[2020-01-01 00:00:00Z]) |> Repo.update!()

    blocked =
      shown
      |> recycle()
      |> post("/auth/mcp/workos/pending", ref: pending["ref"], site_id: site.id)

    assert html_response(blocked, 403) =~ ~s(id="connect-access")
    assert get_session(blocked, :connect_handoff) == pending
  end

  test "polling reports persisted revisions without authorizing or consuming the request", %{
    conn: conn
  } do
    user = user_fixture()
    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=private")
    pending = get_session(conn, :connect_handoff)
    first = conn |> recycle() |> get("/wordpress/connect/status", ref: pending["ref"])
    revision = json_response(first, 200)["revision"]
    insert_site(user)
    second = first |> recycle() |> get("/wordpress/connect/status", ref: pending["ref"])
    refute json_response(second, 200)["revision"] == revision
    subscription_for_scope_fixture(user_scope_fixture(user))
    third = second |> recycle() |> get("/wordpress/connect/status", ref: pending["ref"])
    refute json_response(third, 200)["revision"] == json_response(second, 200)["revision"]
    assert get_session(third, :connect_handoff) == pending
    refute get_session(third, :setup_site_id)
    assert get_resp_header(third, "cache-control") == ["no-store"]

    assert third
           |> recycle()
           |> get("/wordpress/connect/status", ref: "wrong")
           |> json_response(200) == %{"expired" => true}
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

  defp insert_site(user) do
    %Connection{user_id: user.id}
    |> Connection.changeset(%{
      catalog_url: "https://owned.example/wp-json/frontman/v1/tools",
      call_url: "https://owned.example/wp-json/frontman/v1/tools/call",
      username: "secret-user",
      password: "secret-password"
    })
    |> Repo.insert!()
  end
end
