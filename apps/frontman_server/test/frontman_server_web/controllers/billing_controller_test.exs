defmodule FrontmanServerWeb.BillingControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import Mox

  alias FrontmanServer.Billing

  setup :verify_on_exit!

  describe "POST /api/billing/checkout-session" do
    setup :register_and_log_in_user

    test "creates checkout session for monthly plan", %{conn: conn, user: current_user} do
      expect(
        FrontmanServer.Billing.ClientMock,
        :create_checkout_session,
        fn user, customer, interval, return_urls ->
          assert user.id == current_user.id
          assert customer == nil
          assert interval == :monthly

          assert return_urls == %{
                   success_url:
                     "http://localhost:4002/billing/success?session_id={CHECKOUT_SESSION_ID}",
                   cancel_url: "http://localhost:4002/billing/cancel"
                 }

          {:ok, %{"id" => "cs_test_monthly", "url" => "https://checkout.stripe.test/monthly"}}
        end
      )

      conn =
        post(conn, ~p"/api/billing/checkout-session", %{
          "interval" => "monthly"
        })

      response = json_response(conn, 200)

      assert response["id"] == "cs_test_monthly"
      assert response["url"] == "https://checkout.stripe.test/monthly"
    end

    test "rejects invalid interval", %{conn: conn} do
      conn = post(conn, ~p"/api/billing/checkout-session", %{"interval" => "weekly"})
      assert %{"error" => "invalid_interval"} = json_response(conn, 422)
    end

    test "returns unauthorized without user" do
      conn =
        post(build_conn(), ~p"/api/billing/checkout-session", %{
          "interval" => "monthly"
        })

      assert %{"error" => "authentication_required"} = json_response(conn, 401)
    end
  end

  describe "GET /api/billing/status" do
    setup :register_and_log_in_user

    test "returns none before subscription exists", %{conn: conn} do
      conn = get(conn, ~p"/api/billing/status")
      assert %{"status" => "none"} = json_response(conn, 200)
    end

    test "returns subscription status", %{conn: conn, scope: scope} do
      {:ok, customer} =
        Billing.create_customer(scope, %{stripe_customer_id: "cus_status_test"})

      {:ok, _subscription} =
        Billing.create_subscription(scope, %{
          billing_customer_id: customer.id,
          stripe_subscription_id: "sub_status_test",
          stripe_customer_id: "cus_status_test",
          status: "trialing",
          interval: "month",
          price_id: "price_monthly_test"
        })

      conn = get(conn, ~p"/api/billing/status")

      assert %{
               "status" => "trialing",
               "interval" => "month",
               "price_id" => "price_monthly_test"
             } = json_response(conn, 200)
    end
  end
end
