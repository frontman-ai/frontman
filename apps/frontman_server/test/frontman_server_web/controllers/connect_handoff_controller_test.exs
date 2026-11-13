defmodule FrontmanServerWeb.ConnectHandoffControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.BillingFixtures

  alias FrontmanServer.BillingFixtures
  alias FrontmanServer.Repo

  test "retains a pending provider request through Frontman login", %{conn: conn} do
    user = user_fixture()

    subscription_for_scope_fixture(user_scope_fixture(user), %{
      cancel_at: ~U[2030-01-01 00:00:00Z]
    })

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
    document = conn |> html_response(200) |> LazyHTML.from_document()
    assert LazyHTML.query(document, "#connect-account") |> LazyHTML.text() =~ user.email

    assert LazyHTML.query(document, "#connect-heading") |> LazyHTML.text() =~
             "Confirm your Frontman account"

    assert conn.resp_body =~
             "This does not connect a new website, start a subscription, or change your site content"

    value = LazyHTML.query(document, "#connect-value") |> LazyHTML.text()
    assert value =~ "One site. Two ways to work."
    assert value =~ "visual editor for hands-on changes"
    assert value =~ "AI assistant for conversational updates"
    assert value =~ "Continue to authorize assistant access to your connected sites"

    assert conn.resp_body =~ "read, change, and delete site content"
    refute conn.resp_body =~ "unverified-request"
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]

    assert get_resp_header(conn, "content-security-policy") == [
             "base-uri 'self'; frame-ancestors 'self';"
           ]

    assert conn.resp_body =~ ~s(name="_csrf_token")
    assert conn.resp_body =~ ~s(name="ref" value="#{pending["ref"]}")
  end

  test "explains assistant setup only for a live session-backed handoff", %{conn: conn} do
    generic = get(conn, "/users/log-in?from=chatgpt")
    refute html_response(generic, 200) =~ ~s(id="assistant-setup-steps")

    conn = get(conn, "/auth/mcp/workos?external_auth_id=private-request")
    pending = get_session(conn, :connect_handoff)
    conn = conn |> recycle() |> get("/users/log-in")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert LazyHTML.query(document, "h1") |> LazyHTML.text() =~
             "Edit your WordPress site, your way"

    assert LazyHTML.query(document, "#assistant-setup-steps li") |> LazyHTML.to_tree() |> length() ==
             3

    requirements = LazyHTML.query(document, "#assistant-requirements") |> LazyHTML.text()

    assert requirements =~
             "No separate AI-provider API key is needed to use Frontman through your assistant"

    assert requirements =~ "An active Frontman subscription or eligible trial is required"

    assert LazyHTML.query(document, "p") |> LazyHTML.text() =~
             "Work in Frontman's visual editor, or update your site from the AI assistant"

    assert LazyHTML.query(document, "h2") |> LazyHTML.text() =~
             "Connect Frontman to your AI assistant"

    assert conn.resp_body =~
             "Sign in, confirm your account, then choose a connected WordPress site"

    assert conn.resp_body =~ "Use your Frontman email to receive a sign-in link"
    assert conn.resp_body =~ "Continue with Google or GitHub to create an account"
    assert conn.resp_body =~ "Return to your assistant"
    refute conn.resp_body =~ "Enter the runtime era"
    refute conn.resp_body =~ "private-request"
    assert get_resp_header(conn, "cache-control") == ["no-store"]

    expired = Map.put(pending, "started_at", System.system_time(:second) - 901)

    conn =
      conn |> recycle() |> init_test_session(connect_handoff: expired) |> get("/users/log-in")

    refute html_response(conn, 200) =~ ~s(id="assistant-setup-steps")
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
      returned = returned |> recycle() |> get("/users/log-in")
      assert html_response(returned, 200) =~ ~s(id="assistant-setup-steps")
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

      response =
        conn
        |> recycle()
        |> init_test_session(connect_handoff: pending, pending_auth: verification)
        |> get("/auth/verify-email")
        |> html_response(200)

      assert response =~ "Verify your email"

      case embedded_request do
        nil -> assert response =~ "Next, confirm the Frontman account"
        _request -> refute response =~ "Next, confirm the Frontman account"
      end
    end
  end

  test "switching accounts retains setup and binds it to the next signed-in user", %{conn: conn} do
    first_user = user_fixture()
    next_user = user_fixture()

    conn =
      conn
      |> log_in_user(first_user)
      |> get("/auth/mcp/workos?external_auth_id=private-request")

    pending = get_session(conn, :connect_handoff)
    previous_token = get_session(conn, :user_token)
    conn = conn |> recycle() |> get(redirected_to(conn))
    document = conn |> html_response(200) |> LazyHTML.from_document()
    form = LazyHTML.query(document, "#connect-switch-account")
    [action] = LazyHTML.attribute(form, "action")
    [csrf] = LazyHTML.attribute(LazyHTML.query(form, "input[name=_csrf_token]"), "value")
    [ref] = LazyHTML.attribute(LazyHTML.query(form, "input[name=ref]"), "value")

    conn =
      conn
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post(action, %{ref: ref, _csrf_token: csrf})

    assert redirected_to(conn) == "/users/log-in"
    refute get_session(conn, :user_token)
    refute FrontmanServer.Accounts.get_user_by_session_token(previous_token)
    assert get_session(conn, :connect_handoff) == Map.put(pending, "user_id", nil)

    conn = conn |> recycle() |> get("/users/log-in")
    assert html_response(conn, 200) =~ ~s(id="assistant-setup-steps")

    {token, _hashed_token} = generate_user_magic_link_token(next_user)
    conn = conn |> recycle() |> post("/users/log-in", user: %{token: token})
    assert redirected_to(conn) == "/auth/mcp/workos/pending?ref=#{pending["ref"]}"
    conn = conn |> recycle() |> get(redirected_to(conn))
    document = conn |> html_response(200) |> LazyHTML.from_document()
    assert LazyHTML.query(document, "#connect-account") |> LazyHTML.text() =~ next_user.email
    refute LazyHTML.query(document, "#connect-account") |> LazyHTML.text() =~ first_user.email
    assert get_session(conn, :connect_handoff)["user_id"] == next_user.id
  end

  test "account switching rejects invalid references and requires CSRF", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture())
      |> get("/auth/mcp/workos?external_auth_id=private-request")

    pending = get_session(conn, :connect_handoff)
    token = get_session(conn, :user_token)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/auth/mcp/workos/switch-account", ref: pending["ref"])
    end

    rejected = conn |> recycle() |> post("/auth/mcp/workos/switch-account", ref: "wrong")
    assert response(rejected, 400)
    assert get_session(rejected, :user_token) == token
    assert get_session(rejected, :connect_handoff) == pending
  end

  test "escapes the pending reference in the continuation form", %{conn: conn} do
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))
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
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))

    conn =
      conn
      |> log_in_user(user)
      |> get("/auth/mcp/workos?external_auth_id=unverified")

    conn = conn |> recycle() |> get(redirected_to(conn))
    document = conn |> html_response(200) |> LazyHTML.from_document()

    [csrf_token] =
      LazyHTML.attribute(
        LazyHTML.query(document, "#connect-handoff input[name=_csrf_token]"),
        "value"
      )

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
    subscription_for_scope_fixture(user_scope_fixture(user))
    identity_fixture(user, %{provider: "github"})
    identity_fixture(user, %{provider: "google"})

    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=opaque")
    ref = get_session(conn, :connect_handoff)["ref"]

    assert conn
           |> recycle()
           |> post("/auth/mcp/workos/pending", ref: ref)
           |> response(400) == "Authorization could not continue"
  end

  test "rejects a provider identity linked to another account", %{conn: conn} do
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))
    identity = identity_fixture(user, %{provider: "github"})
    identity_fixture(user_fixture(), %{provider: "google", provider_id: identity.provider_id})

    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=opaque")
    ref = get_session(conn, :connect_handoff)["ref"]

    assert conn
           |> recycle()
           |> post("/auth/mcp/workos/pending", ref: ref)
           |> response(400) == "Authorization could not continue"
  end

  test "blocks inactive subscriptions on GET and POST without consuming the handoff", %{
    conn: conn
  } do
    for {status, reason} <- [
          {nil, "No active subscription is linked"},
          {"past_due", "subscription payment failed"},
          {"unpaid", "unpaid invoice"},
          {"canceled", "subscription has ended"},
          {"incomplete", "Billing setup did not produce"},
          {"incomplete_expired", "Billing setup did not produce"},
          {"paused", "subscription is paused"},
          {"unknown", "cannot confirm an active subscription"}
        ] do
      user = user_fixture()
      scope = user_scope_fixture(user)
      if status, do: subscription_for_scope_fixture(scope, %{status: status})

      started =
        conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=private-request")

      pending = get_session(started, :connect_handoff)
      shown = started |> recycle() |> get(redirected_to(started))
      document = shown |> html_response(200) |> LazyHTML.from_document()
      assert LazyHTML.query(document, "#connect-access") |> LazyHTML.text() =~ reason
      assert LazyHTML.query(document, "#connect-account") |> LazyHTML.text() =~ user.email
      assert LazyHTML.query(document, "#connect-handoff") |> LazyHTML.to_tree() == []
      recheck = LazyHTML.query(document, "#connect-recheck-form")
      assert LazyHTML.attribute(recheck, "method") == ["get"]

      assert LazyHTML.query(recheck, "button#connect-recheck[type=submit]") |> LazyHTML.text() =~
               "Check access again"

      [recheck_action] = LazyHTML.attribute(recheck, "action")
      [recheck_ref] = LazyHTML.attribute(LazyHTML.query(recheck, "input[name=ref]"), "value")
      assert recheck_ref == pending["ref"]
      assert LazyHTML.query(document, "#connect-switch-account") |> LazyHTML.to_tree() != []
      refute shown.resp_body =~ "private-request"
      refute shown.resp_body =~ "/checkout"
      refute shown.resp_body =~ "Upgrade"

      blocked = shown |> recycle() |> post("/auth/mcp/workos/pending", ref: pending["ref"])
      assert html_response(blocked, 403) =~ reason
      assert get_session(blocked, :connect_handoff) == pending

      assert blocked
             |> recycle()
             |> get(recheck_action, ref: recheck_ref)
             |> html_response(200) =~ reason
    end
  end

  test "rechecks subscription changes before continuing", %{conn: conn} do
    user = user_fixture()
    scope = user_scope_fixture(user)
    subscription = subscription_for_scope_fixture(scope, %{status: "past_due"})
    identity_fixture(user, %{provider: "github"})
    identity_fixture(user, %{provider: "google"})

    started = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=private")
    pending = get_session(started, :connect_handoff)
    shown = started |> recycle() |> get(redirected_to(started))
    assert html_response(shown, 200) =~ "subscription payment failed"

    subscription = subscription |> Ecto.Changeset.change(status: "trialing") |> Repo.update!()
    active = shown |> recycle() |> get("/auth/mcp/workos/pending", ref: pending["ref"])
    assert html_response(active, 200) =~ "Assistant access available"
    assert active.resp_body =~ ~s(id="connect-continue")
    assert active.resp_body =~ "Your Frontman trial includes assistant access"

    subscription = subscription |> Ecto.Changeset.change(status: "canceled") |> Repo.update!()
    blocked = active |> recycle() |> post("/auth/mcp/workos/pending", ref: pending["ref"])
    assert html_response(blocked, 403) =~ "subscription has ended"
    assert get_session(blocked, :connect_handoff) == pending

    subscription |> Ecto.Changeset.change(status: "trialing") |> Repo.update!()

    assert blocked
           |> recycle()
           |> post("/auth/mcp/workos/pending", ref: pending["ref"])
           |> response(400) == "Authorization could not continue"
  end

  test "trial cancellation after GET blocks POST without consuming the handoff", %{conn: conn} do
    user = user_fixture()
    subscription = subscription_for_scope_fixture(user_scope_fixture(user), %{status: "trialing"})
    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=opaque")
    pending = get_session(conn, :connect_handoff)
    shown = conn |> recycle() |> get(redirected_to(conn))
    assert html_response(shown, 200) =~ "Your Frontman trial includes assistant access"

    subscription |> Ecto.Changeset.change(canceled_at: ~U[2020-01-01 00:00:00Z]) |> Repo.update!()
    blocked = shown |> recycle() |> post("/auth/mcp/workos/pending", ref: pending["ref"])
    assert html_response(blocked, 403) =~ "Your trial is canceled or otherwise ineligible"
    assert get_session(blocked, :connect_handoff) == pending
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

  test "rechecks subscription after the handoff page is shown", %{conn: conn} do
    scope = BillingFixtures.scope_with_allowed_access_fixture()
    subscription = FrontmanServer.Billing.get_current_subscription(scope)
    conn = conn |> log_in_user(scope.user) |> get("/auth/mcp/workos?external_auth_id=opaque")
    pending = get_session(conn, :connect_handoff)
    ref = pending["ref"]

    assert conn |> recycle() |> get("/auth/mcp/workos/pending", %{ref: ref}) |> html_response(200) =~
             "Continue to your assistant"

    subscription |> Ecto.Changeset.change(status: "canceled") |> Repo.update!()
    result = conn |> recycle() |> post("/auth/mcp/workos/pending", %{ref: ref})
    page = html_response(result, 403)
    assert page =~ scope.user.email
    assert page =~ "active subscription or eligible trial is required"
    refute page =~ "Continue to your assistant"
    assert get_session(result, :connect_handoff) == pending
    assert page =~ "existing active subscription"
    assert page =~ "No site has been changed"
    document = LazyHTML.from_document(page)
    recheck = LazyHTML.query(document, "#connect-recheck-form")
    [path] = LazyHTML.attribute(recheck, "action")
    assert LazyHTML.attribute(LazyHTML.query(recheck, "input[name=ref]"), "value") == [ref]

    subscription |> Repo.reload!() |> Ecto.Changeset.change(status: "active") |> Repo.update!()

    assert result |> recycle() |> get(path, ref: ref) |> html_response(200) =~
             "Continue to your assistant"
  end

  test "blocked handoff explains billing recovery and preserves account switching", %{conn: conn} do
    scope = BillingFixtures.scope_with_subscription_fixture("past_due")
    conn = conn |> log_in_user(scope.user) |> get("/auth/mcp/workos?external_auth_id=opaque")
    pending = get_session(conn, :connect_handoff)
    conn = conn |> recycle() |> get(redirected_to(conn))
    page = html_response(conn, 200)
    document = LazyHTML.from_document(page)

    assert page =~ "WordPress Dashboard"
    assert page =~ "Select Manage in Stripe"
    assert page =~ "Use a different account"
    refute page =~ "Signing out ends this connection attempt"
    assert page =~ "original AI assistant"
    assert page =~ "expires after 15 minutes"
    assert page =~ "It does not start a subscription or retry a payment"
    assert page =~ "mailto:support@frontman.sh"
    refute page =~ "opaque"
    refute page =~ "/billing/checkout"
    refute page =~ "Continue to your assistant"

    recheck = LazyHTML.query(document, "#connect-recheck-form")
    [retry_path] = LazyHTML.attribute(recheck, "action")
    [ref] = LazyHTML.attribute(LazyHTML.query(recheck, "input[name=ref]"), "value")
    assert ref == pending["ref"]
    result = conn |> recycle() |> get(retry_path, ref: ref)
    assert get_session(result, :connect_handoff) == pending

    result =
      result
      |> recycle()
      |> post("/auth/mcp/workos/switch-account", %{ref: ref})

    assert redirected_to(result) == "/users/log-in"
    assert get_session(result, :connect_handoff) == Map.put(pending, "user_id", nil)
  end

  test "rejects stale references, expired requests and a different user", %{conn: conn} do
    user = user_fixture()
    subscription_for_scope_fixture(user_scope_fixture(user))
    conn = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=first")
    first = get_session(conn, :connect_handoff)
    conn = conn |> recycle() |> get("/auth/mcp/workos?external_auth_id=second")
    second = get_session(conn, :connect_handoff)
    user_token = get_session(conn, :user_token)

    assert conn
           |> recycle()
           |> post("/auth/mcp/workos/pending", ref: first["ref"])
           |> response(400) == "Invalid or expired request"

    for pending <- [
          %{second | "started_at" => System.system_time(:second) - 901},
          %{second | "user_id" => user_fixture().id}
        ] do
      assert conn
             |> recycle()
             |> init_test_session(%{user_token: user_token, connect_handoff: pending})
             |> post("/auth/mcp/workos/pending", ref: second["ref"])
             |> response(400) == "Invalid or expired request"
    end
  end
end
