defmodule FrontmanServerWeb.WordPressOnboardingControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.BillingFixtures
  alias FrontmanServer.Repo
  alias FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.WordPress.Connection

  test "requires sign in and retains the return path", %{conn: conn} do
    conn = get(conn, ~p"/wordpress/connect?check=1")
    assert redirected_to(conn) == ~p"/users/log-in"
    assert get_session(conn, :user_return_to) == "/wordpress/connect?check=1"
  end

  test "inactive subscriptions cannot start verification regardless of allowance", %{conn: conn} do
    for status <- ["past_due", "unpaid", "canceled", "none"], used <- [0, 5] do
      user = Accounts.user_fixture()
      scope = Scope.for_user(user)
      if used > 0, do: BillingFixtures.run_allowance_fixture(scope, used)

      if status != "none",
        do: BillingFixtures.subscription_for_scope_fixture(scope, %{status: status})

      site = insert_site(user, "unreachable.invalid")
      signed_in = conn |> recycle() |> log_in_user(user)

      signed_in = get(signed_in, ~p"/wordpress/connect")
      page = html_response(signed_in, 200)
      assert page =~ user.email
      assert page =~ "subscription-instructions"
      refute page =~ "Verify site access</button>"
      refute page =~ "checkout"

      page =
        signed_in
        |> recycle()
        |> post(~p"/wordpress/connect", %{site_id: site.id})
        |> html_response(200)

      assert page =~ "subscription-instructions"
      refute page =~ "Verified read access"
    end
  end

  test "active account without sites gets plugin instructions", %{conn: conn} do
    scope = BillingFixtures.scope_with_allowed_access_fixture()
    page = conn |> log_in_user(scope.user) |> get(~p"/wordpress/connect") |> html_response(200)
    assert page =~ scope.user.email
    assert page =~ "Install and activate"
    assert page =~ "same Frontman account"
    refute page =~ "Open ChatGPT"
  end

  test "eligible trial can start verification and canceled trial cannot", %{conn: conn} do
    scope = BillingFixtures.scope_with_subscription_fixture("trialing")
    subscription = FrontmanServer.Billing.get_current_subscription(scope)
    site = insert_site(scope.user, "trial.invalid")
    conn = conn |> log_in_user(scope.user) |> get(~p"/wordpress/connect")
    page = html_response(conn, 200)
    assert page =~ "Trial"
    assert page =~ ~s(id="verify-site")

    invalid = conn |> recycle() |> post(~p"/wordpress/connect", %{site_id: Ecto.UUID.generate()})
    assert html_response(invalid, 400) =~ "Cannot verify access"

    subscription |> Ecto.Changeset.change(cancel_at: ~U[2030-01-01 00:00:00Z]) |> Repo.update!()
    blocked = conn |> recycle() |> post(~p"/wordpress/connect", %{site_id: site.id})
    assert html_response(blocked, 200) =~ "Your trial is canceled or otherwise ineligible"
    refute blocked.resp_body =~ ~s(id="verify-site")
  end

  test "blocked account can recheck its subscription", %{conn: conn} do
    scope = BillingFixtures.scope_with_subscription_fixture("past_due")
    subscription = FrontmanServer.Billing.get_current_subscription(scope)
    conn = conn |> log_in_user(scope.user) |> get(~p"/wordpress/connect")
    page = html_response(conn, 200)
    document = LazyHTML.from_document(page)
    assert page =~ "existing active subscription"
    assert page =~ "No site has been changed"
    assert page =~ "Connect your WordPress site"
    refute page =~ "assistant-setup-steps"

    assert LazyHTML.attribute(LazyHTML.query(document, "#check-status-again"), "href") ==
             ["/wordpress/connect"]

    subscription |> Ecto.Changeset.change(status: "active") |> Repo.update!()

    assert conn |> recycle() |> get(~p"/wordpress/connect") |> html_response(200) =~
             "Install and activate"
  end

  test "blocked accounts receive instructions for their subscription state", %{conn: conn} do
    for {status, explanation, instruction} <- [
          {"none", "No active subscription is linked", "Sign out and use the account"},
          {"past_due", "Your subscription payment failed", "Select Manage in Stripe"},
          {"unpaid", "Your subscription has an unpaid invoice", "Select Manage in Stripe"},
          {"canceled", "Your subscription has ended", "Review your subscription status"},
          {"paused", "Your subscription is paused", "Review your subscription status"},
          {"incomplete", "Billing setup did not produce",
           "Check whether billing setup has completed"},
          {"incomplete_expired", "Billing setup did not produce",
           "Check whether billing setup has completed"},
          {"unknown", "Frontman cannot confirm", "Review your subscription status"}
        ] do
      user = Accounts.user_fixture()
      scope = Scope.for_user(user)

      if status != "none",
        do: BillingFixtures.subscription_for_scope_fixture(scope, %{status: status})

      page =
        conn
        |> recycle()
        |> log_in_user(user)
        |> get(~p"/wordpress/connect")
        |> html_response(200)

      document = LazyHTML.from_document(page)
      assert LazyHTML.text(LazyHTML.query(document, "#subscription-reason")) =~ explanation
      assert LazyHTML.text(LazyHTML.query(document, "#subscription-next-steps")) =~ instruction
      assert page =~ "It does not start a subscription or retry a payment"
      assert page =~ "mailto:support@frontman.sh"
      refute page =~ "/billing/checkout"
      refute page =~ "Choose monthly"
      refute page =~ "Choose yearly"
    end
  end

  test "known site links open Frontman directly without changing the MCP site summaries", %{
    conn: conn
  } do
    scope = BillingFixtures.scope_with_subscription_fixture("past_due")
    site = insert_site(scope.user, "https://northstar.example/company/wp-json/frontman/v1/tools")
    insert_site(Accounts.user_fixture(), "https://private.example/wp-json/frontman/v1/tools")

    page = conn |> log_in_user(scope.user) |> get(~p"/wordpress/connect") |> html_response(200)
    document = LazyHTML.from_document(page)
    link = LazyHTML.query(document, "#frontman-site-links a")

    assert LazyHTML.attribute(link, "href") == ["https://northstar.example/company/frontman"]
    assert LazyHTML.attribute(link, "target") == ["_blank"]
    assert LazyHTML.attribute(link, "rel") == ["noopener noreferrer"]
    assert LazyHTML.attribute(link, "referrerpolicy") == ["no-referrer"]
    assert LazyHTML.text(link) =~ "Open Frontman on northstar.example"
    assert page =~ "Then open"
    refute page =~ "WordPress Dashboard"
    refute page =~ "private.example"
    refute page =~ "secret-user"
    refute page =~ "secret-password"
    assert LazyHTML.query(document, "#check-status-again.btn") |> LazyHTML.to_tree() == []

    assert FrontmanServer.WordPress.list_sites(scope) == [
             %{id: site.id, label: "northstar.example"}
           ]
  end

  test "links preserve subdirectories and WordPress front-controller paths", %{conn: conn} do
    scope = BillingFixtures.scope_with_subscription_fixture("past_due")

    urls = [
      {"https://example.com/wp-json/frontman/v1/tools", "https://example.com/frontman"},
      {"https://example.com/site/wp-json/frontman/v1/tools/",
       "https://example.com/site/frontman"},
      {"https://example.com/site/index.php/wp-json/frontman/v1/tools",
       "https://example.com/site/index.php/frontman"},
      {"https://example.com/?rest_route=/frontman/v1/tools",
       "https://example.com/index.php/frontman"},
      {"https://example.com/blog/?rest_route=%2Ffrontman%2Fv1%2Ftools",
       "https://example.com/blog/index.php/frontman"},
      {"https://example.com/blog/index.php?rest_route=/frontman/v1/tools",
       "https://example.com/blog/index.php/frontman"},
      {"https://example.com:8443/site/wp-json/frontman/v1/tools",
       "https://example.com:8443/site/frontman"}
    ]

    for {catalog, _expected} <- urls, do: insert_site(scope.user, catalog)
    insert_site(scope.user, elem(hd(urls), 0))
    page = conn |> log_in_user(scope.user) |> get(~p"/wordpress/connect") |> html_response(200)
    document = LazyHTML.from_document(page)
    links = LazyHTML.query(document, "#frontman-site-links a")
    expected = urls |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.sort()

    assert Enum.sort(LazyHTML.attribute(links, "href")) == expected
    assert page =~ "Choose the WordPress site"
  end

  test "unknown or unsafe catalog URLs retain instructions instead of guessed links", %{
    conn: conn
  } do
    scope = BillingFixtures.scope_with_subscription_fixture("past_due")

    for catalog <- [
          "https://example.com/custom-catalog",
          "http://example.com/wp-json/frontman/v1/tools",
          "https://user:private-token@example.com/wp-json/frontman/v1/tools",
          "https://example.com/wp-json/frontman/v1/tools?token=private-token",
          "https://example.com/?rest_route=/frontman/v1/tools&token=private-token",
          "https://example.com/wp-json/frontman/v1/tools#private-token"
        ],
        do: insert_site(scope.user, catalog)

    page = conn |> log_in_user(scope.user) |> get(~p"/wordpress/connect") |> html_response(200)
    document = LazyHTML.from_document(page)
    assert LazyHTML.query(document, "#frontman-site-links") |> LazyHTML.to_tree() == []
    assert page =~ "WordPress Dashboard"
    refute page =~ "private-token"
  end

  test "wrong account can sign out and return to setup with the subscribed account", %{conn: conn} do
    user = Accounts.user_fixture()
    conn = conn |> log_in_user(user) |> get(~p"/wordpress/connect")
    document = conn |> html_response(200) |> LazyHTML.from_document()
    [switch_path] = LazyHTML.attribute(LazyHTML.query(document, "#use-another-account"), "href")
    assert URI.parse(switch_path).path == "/users/log-out"

    assert URI.decode_query(URI.parse(switch_path).query) == %{
             "return_to" => "/wordpress/connect"
           }

    result =
      conn
      |> recycle()
      |> delete(~p"/users/log-out", %{return_to: "/wordpress/connect"})

    login_path = redirected_to(result)
    scope = BillingFixtures.scope_with_allowed_access_fixture()
    {token, _stored_token} = Accounts.generate_user_magic_link_token(scope.user)
    result = result |> recycle() |> get(login_path)
    result = result |> recycle() |> post(~p"/users/log-in", user: %{token: token})
    assert redirected_to(result) == "/wordpress/connect"
    page = result |> recycle() |> get(~p"/wordpress/connect") |> html_response(200)
    assert page =~ scope.user.email
    assert page =~ "Install and activate"
    refute page =~ user.email
  end

  test "verification requires CSRF protection", %{conn: conn} do
    scope = BillingFixtures.scope_with_allowed_access_fixture()
    insert_site(scope.user, "owned.invalid")
    conn = conn |> log_in_user(scope.user) |> get(~p"/wordpress/connect")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    [token] =
      LazyHTML.attribute(
        LazyHTML.query(document, "#verify-site input[name=_csrf_token]"),
        "value"
      )

    for params <- [%{site_id: "invalid"}, %{site_id: "invalid", _csrf_token: "invalid"}] do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post(~p"/wordpress/connect", params)
      end
    end

    assert conn
           |> recycle()
           |> put_private(:plug_skip_csrf_protection, false)
           |> post(~p"/wordpress/connect", %{site_id: "invalid", _csrf_token: token})
           |> html_response(400) =~ "Cannot verify access"
  end

  test "selected site must be owned and verified, and failures do not disclose credentials", %{
    conn: conn
  } do
    scope = BillingFixtures.scope_with_allowed_access_fixture()
    site = insert_site(scope.user, "unreachable.invalid")
    foreign = insert_site(Accounts.user_fixture(), "private.invalid")
    signed_in = log_in_user(conn, scope.user)
    signed_in = get(signed_in, ~p"/wordpress/connect")
    page = html_response(signed_in, 200)
    assert page =~ "unreachable.invalid"
    refute page =~ "private.invalid"
    refute page =~ "Verified read access"

    for id <- ["bad-id", foreign.id] do
      result = signed_in |> recycle() |> post(~p"/wordpress/connect", %{site_id: id})
      assert html_response(result, 400) =~ "Cannot verify access"
    end

    page =
      signed_in
      |> recycle()
      |> post(~p"/wordpress/connect", %{site_id: site.id})
      |> html_response(200)

    assert page =~ "Cannot verify access"
    refute page =~ "Verified read access"
    refute page =~ "secret-user"
    refute page =~ "secret-password"
  end

  defp insert_site(user, "https://" <> _ = catalog) do
    insert_catalog(user, catalog)
  end

  defp insert_site(user, "http://" <> _ = catalog) do
    insert_catalog(user, catalog)
  end

  defp insert_site(user, host) do
    insert_catalog(user, "https://#{host}/tools")
  end

  defp insert_catalog(user, catalog) do
    %Connection{user_id: user.id}
    |> Connection.changeset(%{
      catalog_url: catalog,
      call_url: catalog,
      username: "secret-user",
      password: "secret-password"
    })
    |> Repo.insert!()
  end
end
