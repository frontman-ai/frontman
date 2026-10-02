defmodule FrontmanServerWeb.BillingControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  import FrontmanServer.BillingFixtures
  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Billing.Customer
  alias FrontmanServer.Test.BillingClientStub

  setup %{conn: conn} do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()
    billing_client = Application.fetch_env!(:frontman_server, :billing_client)
    Application.put_env(:frontman_server, :billing_client, BillingClientStub)
    on_exit(fn -> Application.put_env(:frontman_server, :billing_client, billing_client) end)
    user = user_fixture()
    %{conn: put_embedded_client_bearer(conn, user), user: user, scope: Scope.for_user(user)}
  end

  for interval <- ~w(monthly yearly) do
    @interval interval
    test "#{interval} checkout preserves bearer identity despite a different browser account", %{
      conn: conn,
      user: user
    } do
      %{conn: conn, scope: browser_scope} = register_and_log_in_user(%{conn: conn})
      allow_access_for_scope_fixture(browser_scope)

      BillingClientStub.stub_start_checkout(
        {:ok, %{"url" => "https://checkout.stripe.test/session"}}
      )

      conn =
        post(conn, ~p"/api/billing/checkout", %{
          "interval" => @interval,
          "user_id" => browser_scope.user.id,
          "success_url" => "https://untrusted.example"
        })

      assert json_response(conn, 200) == %{"url" => "https://checkout.stripe.test/session"}

      assert_received {:start_checkout, checkout_user, nil, interval, urls,
                       [trial_eligible: true]}

      assert checkout_user.id == user.id
      assert to_string(interval) == @interval

      assert urls.success_url ==
               FrontmanServerWeb.Endpoint.url() <>
                 "/billing/stripe-return/success?session_id={CHECKOUT_SESSION_ID}"

      assert urls.cancel_url ==
               FrontmanServerWeb.Endpoint.url() <> "/billing/stripe-return/cancel"
    end
  end

  test "portal and status use bearer identity, not browser identity", %{conn: conn, scope: scope} do
    %{conn: conn, scope: browser_scope} = register_and_log_in_user(%{conn: conn})
    allow_access_for_scope_fixture(browser_scope)
    customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_editor"})
    BillingClientStub.stub_customer_portal_url({:ok, "https://billing.stripe.test/session"})

    response = post(conn, ~p"/api/billing/customer-portal")
    assert json_response(response, 200) == %{"url" => "https://billing.stripe.test/session"}

    assert_received {:create_customer_portal_url, %Customer{stripe_customer_id: "cus_editor"},
                     return_url}

    assert return_url ==
             FrontmanServerWeb.Endpoint.url() <> "/billing/stripe-return/customer-portal"

    assert %{"access_allowed" => false, "has_billing_customer" => true} =
             conn |> get(~p"/api/billing/status") |> json_response(200)
  end

  for path <- ~w(checkout customer-portal status),
      auth <- [:cookie_only, :wrong_origin, :invalid] do
    @path path
    @auth auth
    test "#{path} rejects #{auth} rather than falling back to browser login", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        case @auth do
          :cookie_only -> delete_req_header(conn, "authorization")
          :wrong_origin -> put_req_header(conn, "origin", "https://other.example")
          :invalid -> put_req_header(conn, "authorization", "Bearer invalid")
        end

      conn =
        case @path do
          "status" -> get(conn, "/api/billing/status")
          path -> post(conn, "/api/billing/#{path}", %{"interval" => "monthly"})
        end

      assert json_response(conn, 401)
      refute_received {:start_checkout, _, _, _, _, _}
      refute_received {:create_customer_portal_url, _, _}
    end
  end

  test "invalid intervals do not call Stripe", %{conn: conn} do
    for params <- [%{}, %{"interval" => "weekly"}, %{"interval" => 1}] do
      assert conn |> post(~p"/api/billing/checkout", params) |> json_response(422)
    end

    refute_received {:start_checkout, _, _, _, _, _}
  end

  test "active bearer account rejects checkout even when the browser account has no plan", %{
    conn: conn,
    scope: scope
  } do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    allow_access_for_scope_fixture(scope)
    conn = post(conn, ~p"/api/billing/checkout", %{"interval" => "monthly"})
    assert json_response(conn, 409)["error"] =~ "already have an active subscription"
    assert Sentry.Test.pop_sentry_reports() == []
    refute_received {:start_checkout, _, _, _, _, _}
  end

  for {path, interval} <- [
        {"checkout", "monthly"},
        {"checkout", "yearly"},
        {"customer-portal", nil}
      ],
      failure <- [:unauthorized, :upstream, :timeout] do
    @path path
    @interval interval
    @failure failure
    test "#{path} #{interval} safely reports #{failure}", %{conn: conn, scope: scope, user: user} do
      secret = "private-provider-test-value"

      reason =
        case @failure do
          :timeout ->
            %Req.TransportError{reason: :timeout}

          :unauthorized ->
            {:stripe_error, 401,
             %{"error" => %{"message" => secret, "code" => "api_key_expired"}}, ["req_test123"]}

          :upstream ->
            {:stripe_error, 503, %{"error" => %{"message" => secret, "code" => secret}}, [secret]}
        end

      operation =
        case @path do
          "customer-portal" ->
            customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_error_test"})
            BillingClientStub.stub_customer_portal_url({:error, reason})
            :customer_portal

          "checkout" ->
            BillingClientStub.stub_start_checkout({:error, reason})
            :checkout
        end

      conn =
        post(conn, "/api/billing/#{@path}", %{"interval" => @interval, "untrusted" => secret})

      response = json_response(conn, 502)
      assert response["error"] =~ "We could not open Stripe"
      refute inspect(response) =~ secret
      refute inspect(response) =~ "stripe_error"
      [event] = Sentry.Test.pop_sentry_reports()
      assert event.message.formatted == "Billing request failed"
      assert event.tags == %{error_type: "billing_failure", billing_operation: operation}
      assert event.user == %{id: user.id}
      assert event.request == nil
      assert event.breadcrumbs == []
      assert event.attachments == []
      assert [event.extra.request_id] == get_resp_header(conn, "x-request-id")
      assert response["request_id"] == event.extra.request_id
      refute inspect(event) =~ secret

      case @failure do
        :unauthorized ->
          assert event.extra.upstream_status == 401
          assert event.extra.stripe_code == "api_key_expired"
          assert event.extra.stripe_request_id == "req_test123"

        :upstream ->
          assert event.extra.upstream_status == 503
          assert event.extra.stripe_code == nil
          assert event.extra.stripe_request_id == nil

        :timeout ->
          assert event.extra.failure == "timeout"
      end
    end
  end

  test "missing billing customer is a safe business error", %{conn: conn} do
    conn = post(conn, ~p"/api/billing/customer-portal")
    assert json_response(conn, 422)["error"] =~ "no billing account to manage"
    assert Sentry.Test.pop_sentry_reports() == []
  end

  test "programming errors still raise", %{conn: conn} do
    assert_raise RuntimeError, "unexpected checkout through billing client stub", fn ->
      post(conn, ~p"/api/billing/checkout", %{"interval" => "monthly"})
    end
  end

  test "unknown provider errors are reported without inspecting them", %{conn: conn} do
    BillingClientStub.stub_start_checkout({:error, {:unexpected, "private-provider-data"}})
    conn = post(conn, ~p"/api/billing/checkout", %{"interval" => "monthly"})
    refute inspect(json_response(conn, 502)) =~ "private-provider-data"
    [event] = Sentry.Test.pop_sentry_reports()
    assert event.extra.failure == "unexpected_provider_error"
    refute inspect(event) =~ "private-provider-data"
  end

  for {path, title} <- [
        {"success", "Stripe checkout complete"},
        {"cancel", "Stripe checkout closed"},
        {"customer-portal", "Stripe billing portal closed"}
      ] do
    @path path
    @title title
    test "#{path} renders the safe return page" do
      response = build_conn() |> get("/billing/stripe-return/#{@path}") |> html_response(200)
      assert response =~ "billing-stripe-return"
      assert response =~ "data-auto-close-window"
      assert response =~ @title
      assert response =~ "You can close this tab and return to Frontman."

      assert response =~
               "Your original Frontman tab updates automatically when Stripe sends a billing event."
    end
  end
end
