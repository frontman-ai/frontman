defmodule FrontmanServerWeb.BillingControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Billing

  describe "POST /api/billing/checkout" do
    setup :setup_paper_tiger
    setup :register_and_log_in_user

    test "starts checkout for monthly plan", %{conn: conn} do
      conn =
        post(conn, ~p"/api/billing/checkout", %{
          "interval" => "monthly"
        })

      response = json_response(conn, 200)

      assert_paper_tiger_checkout_session!(response)
    end

    test "starts checkout for yearly plan", %{conn: conn} do
      conn =
        post(conn, ~p"/api/billing/checkout", %{
          "interval" => "yearly"
        })

      response = json_response(conn, 200)

      assert_paper_tiger_checkout_session!(response)
    end

    test "returns unauthorized without user" do
      conn =
        post(build_conn(), ~p"/api/billing/checkout", %{
          "interval" => "monthly"
        })

      assert %{"error" => "authentication_required"} = json_response(conn, 401)
    end

    test "rejects unsupported checkout intervals", %{conn: conn} do
      assert_raise Phoenix.ActionClauseError, fn ->
        post(conn, ~p"/api/billing/checkout", %{
          "interval" => "weekly"
        })
      end
    end
  end

  describe "GET /api/billing/status" do
    setup :register_and_log_in_user

    test "returns none before subscription exists", %{conn: conn} do
      conn = get(conn, ~p"/api/billing/status")

      assert %{
               "status" => "none",
               "allow_access" => false
             } = json_response(conn, 200)
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
               "price_id" => "price_monthly_test",
               "allow_access" => true
             } = json_response(conn, 200)
    end
  end
end
