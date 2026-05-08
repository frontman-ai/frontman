defmodule FrontmanServerWeb.BillingControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import Mox

  alias FrontmanServer.Billing

  setup :verify_on_exit!

  describe "POST /api/billing/checkout" do
    setup :register_and_log_in_user

    test "starts checkout for monthly plan", %{conn: conn, user: current_user} do
      expect(
        FrontmanServer.Billing.ClientMock,
        :start_checkout,
        fn user, customer, interval, return_urls, opts ->
          assert user.id == current_user.id
          assert customer == nil
          assert interval == :monthly
          assert opts == [trial_eligible: true]

          assert return_urls == %{
                   success_url:
                     "http://localhost:4002/billing/success?session_id={CHECKOUT_SESSION_ID}",
                   cancel_url: "http://localhost:4002/billing/cancel"
                 }

          {:ok, %{"id" => "cs_test_monthly", "url" => "https://checkout.stripe.test/monthly"}}
        end
      )

      conn =
        post(conn, ~p"/api/billing/checkout", %{
          "interval" => "monthly"
        })

      response = json_response(conn, 200)

      assert response["id"] == "cs_test_monthly"
      assert response["url"] == "https://checkout.stripe.test/monthly"
    end

    test "starts checkout for yearly plan", %{conn: conn, user: current_user} do
      expect(
        FrontmanServer.Billing.ClientMock,
        :start_checkout,
        fn user, customer, interval, _return_urls, opts ->
          assert user.id == current_user.id
          assert customer == nil
          assert interval == :yearly
          assert opts == [trial_eligible: true]

          {:ok, %{"id" => "cs_test_yearly", "url" => "https://checkout.stripe.test/yearly"}}
        end
      )

      conn =
        post(conn, ~p"/api/billing/checkout", %{
          "interval" => "yearly"
        })

      response = json_response(conn, 200)

      assert response["id"] == "cs_test_yearly"
      assert response["url"] == "https://checkout.stripe.test/yearly"
    end

    test "returns unauthorized without user" do
      conn =
        post(build_conn(), ~p"/api/billing/checkout", %{
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
          interval: :monthly,
          price_id: "price_monthly_test"
        })

      conn = get(conn, ~p"/api/billing/status")

      assert %{
               "status" => "trialing",
               "interval" => "monthly",
               "price_id" => "price_monthly_test"
             } = json_response(conn, 200)
    end
  end
end
