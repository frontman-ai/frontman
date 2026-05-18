defmodule FrontmanServerWeb.BillingControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  import FrontmanServer.BillingFixtures

  alias FrontmanServer.Billing.Customer
  alias FrontmanServer.Test.BillingClientStub

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
