defmodule FrontmanServerWeb.WordPressOnboardingControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  import FrontmanServer.StripeIntegrationCase

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.BillingFixtures
  alias FrontmanServer.Repo
  alias FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.WordPress.Connection

  setup :setup_paper_tiger

  test "requires sign in and retains the return path", %{conn: conn} do
    conn = get(conn, ~p"/wordpress/connect?check=1")
    assert redirected_to(conn) == ~p"/users/log-in"
    assert get_session(conn, :user_return_to) == "/wordpress/connect?check=1"
  end

  test "site instructions precede purchase even without a subscription", %{conn: conn} do
    user = Accounts.user_fixture()
    conn = conn |> log_in_user(user) |> get(~p"/wordpress/connect")
    page = html_response(conn, 200)
    document = LazyHTML.from_document(page)
    instructions = LazyHTML.query(document, "#connect-no-sites") |> LazyHTML.text()
    assert instructions =~ "Install and activate"
    assert instructions =~ user.email
    assert instructions =~ "enable MCP"
    refute page =~ ~s(id="connect-access")
    refute page =~ ~s(id="checkout-plan")
    assert PaperTiger.Test.requests(method: :get, path: "/v1/prices/price_monthly_test") == []
    assert LazyHTML.query(document, "#connect-continue") |> LazyHTML.to_tree() == []
    refute page =~ "ChatGPT"
  end

  test "active accounts receive setup without purchase controls", %{conn: conn} do
    scope = BillingFixtures.scope_with_allowed_access_fixture()
    conn = conn |> log_in_user(scope.user) |> get(~p"/wordpress/connect")
    page = html_response(conn, 200)
    assert page =~ "Install and activate"
    refute page =~ ~s(id="connect-access")
    refute page =~ "/wordpress/connect/checkout"
    refute page =~ "/wordpress/connect/portal"
  end

  test "a stale saved selection falls back to the sole owned site without accepting foreign submissions",
       %{conn: conn} do
    scope = BillingFixtures.scope_with_allowed_access_fixture()
    site = insert_site(scope.user, "https://remaining.example/wp-json/frontman/v1/tools")
    stale_id = Ecto.UUID.generate()

    conn =
      conn
      |> log_in_user(scope.user)
      |> put_session(:setup_site_id, stale_id)
      |> get("/auth/mcp/workos?external_auth_id=original")

    pending = get_session(conn, :connect_handoff)
    shown = conn |> recycle() |> get(redirected_to(conn))
    document = shown |> html_response(200) |> LazyHTML.from_document()

    assert LazyHTML.query(document, "#connect-selected-site") |> LazyHTML.text() =~
             "remaining.example"

    assert LazyHTML.query(document, "#connect-handoff input[name=site_id]")
           |> LazyHTML.attribute("value") == [site.id]

    assert LazyHTML.query(document, "#connect-continue") |> LazyHTML.text() =~
             "Continue to your assistant"

    rejected =
      shown
      |> recycle()
      |> post("/auth/mcp/workos/pending", ref: pending["ref"], site_id: stale_id)

    assert html_response(rejected, 403) =~ "Connect a site and activate assistant access"
    assert get_session(rejected, :connect_handoff) == pending
  end

  test "site setup finishes without buying access or naming a particular assistant", %{conn: conn} do
    for status <- ["none", "past_due", "unpaid", "canceled", "trialing", "active"] do
      user = Accounts.user_fixture()
      scope = Scope.for_user(user)

      if status != "none",
        do: BillingFixtures.subscription_for_scope_fixture(scope, %{status: status})

      site = insert_site(user, "https://owned.example/wp-json/frontman/v1/tools")
      signed_in = conn |> recycle() |> log_in_user(user) |> get(~p"/wordpress/connect")
      result = signed_in |> recycle() |> post(~p"/wordpress/connect", %{site_id: site.id})
      page = html_response(result, 200)
      assert page =~ ~s(id="connect-selected-site")
      assert page =~ "owned.example"

      if status in ["trialing", "active"] do
        assert page =~ ~s(id="connect-finished")
      else
        assert page =~ ~s(id="connect-access")
      end

      assert get_session(result, :setup_site_id) == site.id
      assert Repo.reload!(site) == site
      refute page =~ "ChatGPT"
      refute page =~ "Verified read access"
      refute page =~ "secret-password"
      refute page =~ "secret-user"
    end
  end

  test "selection is scoped to the signed-in account and required for multiple sites", %{
    conn: conn
  } do
    user = Accounts.user_fixture()
    first = insert_site(user, "https://first.example/wp-json/frontman/v1/tools")
    insert_site(user, "https://second.example/wp-json/frontman/v1/tools")

    foreign =
      insert_site(Accounts.user_fixture(), "https://private.example/wp-json/frontman/v1/tools")

    conn = conn |> log_in_user(user) |> get(~p"/wordpress/connect")
    page = html_response(conn, 200)
    assert page =~ "Choose your WordPress site"
    refute page =~ "private.example"

    for id <- ["", "bad-id", Ecto.UUID.generate(), foreign.id] do
      result = conn |> recycle() |> post(~p"/wordpress/connect", %{site_id: id})
      assert html_response(result, 200) =~ "Choose a connected WordPress site"
      refute result.resp_body =~ ~s(id="connect-finished")
      refute get_session(result, :setup_site_id)
    end

    result = conn |> recycle() |> post(~p"/wordpress/connect", %{site_id: first.id})
    assert html_response(result, 200) =~ "first.example"
    assert get_session(result, :setup_site_id) == first.id
  end

  test "selected site survives checkout and polling refresh and rejects another account's site",
       %{conn: conn} do
    user = Accounts.user_fixture()
    first = insert_site(user, "https://first.example/wp-json/frontman/v1/tools")
    second = insert_site(user, "https://second.example/wp-json/frontman/v1/tools")

    foreign =
      insert_site(Accounts.user_fixture(), "https://private.example/wp-json/frontman/v1/tools")

    started = conn |> log_in_user(user) |> get("/auth/mcp/workos?external_auth_id=original")
    pending = get_session(started, :connect_handoff)

    selected =
      started
      |> recycle()
      |> post("/wordpress/connect/site", ref: pending["ref"], site_id: second.id)

    assert get_session(selected, :setup_site_id) == second.id
    shown = selected |> recycle() |> get(redirected_to(selected))
    document = shown |> html_response(200) |> LazyHTML.from_document()

    assert LazyHTML.query(document, "#connect-selected-site") |> LazyHTML.text() =~
             "second.example"

    assert LazyHTML.query(document, "#connect-change-site select option[selected]")
           |> LazyHTML.attribute("value") == [second.id]

    rejected =
      shown
      |> recycle()
      |> post("/wordpress/connect/site", ref: pending["ref"], site_id: foreign.id)

    assert get_session(rejected, :setup_site_id) == second.id

    checkout =
      rejected
      |> recycle()
      |> post("/wordpress/connect/checkout", ref: pending["ref"], interval: "monthly")

    assert redirected_to(checkout) =~ "http://localhost:"
    assert get_session(checkout, :setup_site_id) == second.id

    returned =
      checkout
      |> recycle()
      |> get("/auth/mcp/workos/pending", ref: pending["ref"], checkout: "success")

    page = html_response(returned, 200)
    assert page =~ ~s(id="checkout-pending")
    refute page =~ ~s(id="checkout-monthly")
    assert page =~ "second.example"
    assert Repo.reload!(first)
    assert get_session(returned, :connect_handoff) == pending
    document = LazyHTML.from_document(page)

    [refresh] =
      LazyHTML.query(document, "#hosted-setup") |> LazyHTML.attribute("data-setup-page-url")

    refreshed = returned |> recycle() |> get(refresh)
    assert get_session(refreshed, :setup_site_id) == second.id
  end

  test "finish, checkout and portal require CSRF", %{conn: conn} do
    user = Accounts.user_fixture()
    site = insert_site(user, "https://owned.example/wp-json/frontman/v1/tools")
    conn = conn |> log_in_user(user) |> get(~p"/wordpress/connect")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    [token] =
      LazyHTML.query(document, "#checkout-plan input[name=_csrf_token]")
      |> LazyHTML.attribute("value")

    for path <- [
          "/wordpress/connect",
          "/wordpress/connect/site",
          "/wordpress/connect/checkout",
          "/wordpress/connect/portal"
        ],
        params <- [%{}, %{_csrf_token: "invalid"}] do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post(path, params)
      end
    end

    result =
      conn
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/wordpress/connect", %{site_id: site.id, _csrf_token: token})

    assert html_response(result, 200) =~ ~s(id="connect-selected-site")
  end

  test "polling observes persisted sites and access without finishing setup", %{conn: conn} do
    user = Accounts.user_fixture()
    scope = Scope.for_user(user)
    conn = conn |> log_in_user(user) |> get(~p"/wordpress/connect")
    initial = conn |> recycle() |> get("/wordpress/connect/status") |> json_response(200)
    assert initial["expired"] == false
    assert is_binary(initial["revision"])
    assert conn |> recycle() |> get("/wordpress/connect/status") |> json_response(200) == initial

    site = insert_site(user, "https://owned.example/wp-json/frontman/v1/tools")
    sites = conn |> recycle() |> get("/wordpress/connect/status")
    sites_status = json_response(sites, 200)
    refute sites_status["revision"] == initial["revision"]
    refute get_session(sites, :setup_site_id)
    refute get_session(sites, :connect_handoff)

    BillingFixtures.subscription_for_scope_fixture(scope)
    access = sites |> recycle() |> get("/wordpress/connect/status")
    refute json_response(access, 200)["revision"] == sites_status["revision"]
    refute get_session(access, :setup_site_id)
    assert Repo.reload!(site) == site

    insert_site(Accounts.user_fixture(), "https://private.example/wp-json/frontman/v1/tools")

    assert access |> recycle() |> get("/wordpress/connect/status") |> json_response(200) ==
             json_response(access, 200)
  end

  test "hosted actions and polling require authentication", %{conn: conn} do
    for path <- ["/wordpress/connect", "/wordpress/connect/checkout", "/wordpress/connect/portal"] do
      assert conn |> post(path, %{}) |> redirected_to() == "/users/log-in"
    end

    assert conn |> get("/wordpress/connect/status") |> redirected_to() == "/users/log-in"
  end

  defp insert_site(user, catalog) do
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
