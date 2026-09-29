defmodule FrontmanServerWeb.BillingControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  import FrontmanServer.BillingFixtures

  alias FrontmanServer.Billing.Customer
  alias FrontmanServer.Test.BillingClientStub

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()
    :ok
  end

  describe "GET /billing/checkout/monthly" do
    test "renders a CSRF-protected auto-submit form for authenticated users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/billing/checkout/monthly")
      response = html_response(conn, 200)

      assert response =~ "billing-stripe-launch"
      assert response =~ "billing-stripe-launch-form"
      assert response =~ "data-auto-submit"
      assert response =~ "Opening Stripe..."
      assert response =~ ~s(action="/billing/checkout/monthly")
      assert response =~ ~s(method="post")
      assert response =~ ~s(name="_csrf_token")
    end

    test "redirects unauthenticated users to login" do
      conn = get(build_conn(), ~p"/billing/checkout/monthly")

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "POST /billing/checkout/monthly" do
    test "rejects existing subscribers without creating another Stripe subscription", %{
      conn: conn
    } do
      use_billing_client_stub()
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      allow_access_for_scope_fixture(scope)

      conn = post(conn, ~p"/billing/checkout/monthly")

      assert html_response(conn, 409) =~ "already have an active subscription"
      assert Sentry.Test.pop_sentry_reports() == []
      refute_received {:start_checkout, _, _, _, _, _}
    end

    test "redirects to Stripe with server-owned safe return URLs", %{conn: conn} do
      use_billing_client_stub()

      BillingClientStub.stub_start_checkout(
        {:ok, %{"id" => "cs_monthly_test", "url" => "https://checkout.stripe.test/session"}}
      )

      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/billing/checkout/monthly")

      assert redirected_to(conn) == "https://checkout.stripe.test/session"

      assert_received {:start_checkout, checkout_user, nil, :monthly, return_urls,
                       [trial_eligible: true]}

      assert checkout_user.id == user.id

      assert String.ends_with?(
               return_urls.success_url,
               "/billing/stripe-return/success?session_id={CHECKOUT_SESSION_ID}"
             )

      assert String.ends_with?(return_urls.cancel_url, "/billing/stripe-return/cancel")
    end
  end

  describe "GET /billing/checkout/yearly" do
    test "renders a CSRF-protected auto-submit form for authenticated users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/billing/checkout/yearly")
      response = html_response(conn, 200)

      assert response =~ "billing-stripe-launch"
      assert response =~ "billing-stripe-launch-form"
      assert response =~ "data-auto-submit"
      assert response =~ "Opening Stripe..."
      assert response =~ ~s(action="/billing/checkout/yearly")
      assert response =~ ~s(method="post")
      assert response =~ ~s(name="_csrf_token")
    end
  end

  describe "POST /billing/checkout/yearly" do
    test "redirects to Stripe with yearly interval and safe return URLs", %{conn: conn} do
      use_billing_client_stub()

      BillingClientStub.stub_start_checkout(
        {:ok, %{"id" => "cs_yearly_test", "url" => "https://checkout.stripe.test/session"}}
      )

      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/billing/checkout/yearly")

      assert redirected_to(conn) == "https://checkout.stripe.test/session"

      assert_received {:start_checkout, checkout_user, nil, :yearly, return_urls,
                       [trial_eligible: true]}

      assert checkout_user.id == user.id

      assert String.ends_with?(
               return_urls.success_url,
               "/billing/stripe-return/success?session_id={CHECKOUT_SESSION_ID}"
             )

      assert String.ends_with?(return_urls.cancel_url, "/billing/stripe-return/cancel")
    end
  end

  describe "GET /billing/customer-portal" do
    test "renders a CSRF-protected auto-submit form for authenticated users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/billing/customer-portal")
      response = html_response(conn, 200)

      assert response =~ "billing-stripe-launch"
      assert response =~ "billing-stripe-launch-form"
      assert response =~ "data-auto-submit"
      assert response =~ "Opening Stripe..."
      assert response =~ ~s(action="/billing/customer-portal")
      assert response =~ ~s(method="post")
      assert response =~ ~s(name="_csrf_token")
    end
  end

  describe "POST /billing/customer-portal" do
    test "redirects to Stripe Customer Portal with safe return URL", %{conn: conn} do
      use_billing_client_stub()

      BillingClientStub.stub_customer_portal_url({:ok, "https://billing.stripe.test/p/session"})

      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_browser_management_test"})

      conn = post(conn, ~p"/billing/customer-portal")

      assert redirected_to(conn) == "https://billing.stripe.test/p/session"

      assert_received {
        :create_customer_portal_url,
        %Customer{stripe_customer_id: "cus_browser_management_test"},
        return_url
      }

      assert String.ends_with?(return_url, "/billing/stripe-return/customer-portal")
    end
  end

  describe "billing failure boundary" do
    for path <- [
          "/billing/checkout/monthly",
          "/billing/checkout/yearly",
          "/billing/customer-portal"
        ],
        failure <- [:unauthorized, :upstream, :timeout] do
      @path path
      @failure failure
      test "#{path} safely reports #{failure}", %{conn: conn} do
        use_billing_client_stub()
        %{conn: conn, scope: scope, user: user} = register_and_log_in_user(%{conn: conn})
        secret = "sk_live_DO_NOT_EXPOSE_TEST_SECRET"

        reason =
          case @failure do
            :timeout ->
              %Req.TransportError{reason: :timeout}

            :unauthorized ->
              {:stripe_error, 401,
               %{"error" => %{"message" => secret, "code" => "api_key_expired"}}, ["req_test123"]}

            :upstream ->
              {:stripe_error, 503, %{"error" => %{"message" => secret, "code" => secret}},
               [secret]}
          end

        operation =
          case @path do
            "/billing/customer-portal" ->
              customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_error_test"})
              BillingClientStub.stub_customer_portal_url({:error, reason})
              :customer_portal

            _checkout ->
              BillingClientStub.stub_start_checkout({:error, reason})
              :checkout
          end

        conn = post(conn, @path, %{"untrusted" => secret})
        response = html_response(conn, 502)
        assert response =~ "We could not open Stripe"
        assert response =~ "Request reference:"
        assert response =~ "Return to Frontman"
        refute response =~ secret
        refute response =~ "stripe_error"

        [event] = Sentry.Test.pop_sentry_reports()
        assert event.message.formatted == "Billing request failed"
        assert event.tags == %{error_type: "billing_failure", billing_operation: operation}
        assert event.user == %{id: user.id}
        assert event.request == nil
        assert event.breadcrumbs == []
        assert event.attachments == []
        assert [event.extra.request_id] == get_resp_header(conn, "x-request-id")
        assert response =~ event.extra.request_id
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

    test "missing billing customer is a safe business error without an incident", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/billing/customer-portal")
      assert html_response(conn, 422) =~ "no billing account to manage"
      assert Sentry.Test.pop_sentry_reports() == []
    end

    test "programming errors still raise instead of becoming handled billing failures", %{
      conn: conn
    } do
      use_billing_client_stub()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert_raise RuntimeError, "unexpected checkout through billing client stub", fn ->
        post(conn, ~p"/billing/checkout/monthly")
      end
    end

    test "unknown provider errors are reported without inspecting them", %{conn: conn} do
      use_billing_client_stub()
      BillingClientStub.stub_start_checkout({:error, {:unexpected, "private-provider-data"}})
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/billing/checkout/monthly")
      refute html_response(conn, 502) =~ "private-provider-data"
      [event] = Sentry.Test.pop_sentry_reports()
      assert event.extra.failure == "unexpected_provider_error"
      refute inspect(event) =~ "private-provider-data"
    end
  end

  describe "GET /billing/stripe-return/*" do
    test "success renders safe close page" do
      conn = get(build_conn(), ~p"/billing/stripe-return/success?session_id=cs_test")
      response = html_response(conn, 200)

      assert response =~ "billing-stripe-return"
      assert response =~ "data-auto-close-window"
      assert response =~ "Stripe checkout complete"
      assert response =~ "You can close this tab and return to Frontman."

      assert response =~
               "Your original Frontman tab updates automatically when Stripe sends a billing event."

      refute response =~ "refresh billing status"
    end

    test "cancel renders safe close page" do
      conn = get(build_conn(), ~p"/billing/stripe-return/cancel")
      response = html_response(conn, 200)

      assert response =~ "billing-stripe-return"
      assert response =~ "data-auto-close-window"
      assert response =~ "Stripe checkout closed"
      assert response =~ "You can close this tab and return to Frontman."

      assert response =~
               "Your original Frontman tab updates automatically when Stripe sends a billing event."

      refute response =~ "refresh billing status"
    end

    test "customer portal renders safe close page" do
      conn = get(build_conn(), ~p"/billing/stripe-return/customer-portal")
      response = html_response(conn, 200)

      assert response =~ "billing-stripe-return"
      assert response =~ "data-auto-close-window"
      assert response =~ "Stripe billing portal closed"
      assert response =~ "You can close this tab and return to Frontman."

      assert response =~
               "Your original Frontman tab updates automatically when Stripe sends a billing event."

      refute response =~ "refresh billing status"
    end
  end

  defp use_billing_client_stub do
    billing_client = Application.fetch_env!(:frontman_server, :billing_client)
    Application.put_env(:frontman_server, :billing_client, BillingClientStub)
    on_exit(fn -> Application.put_env(:frontman_server, :billing_client, billing_client) end)
  end
end
