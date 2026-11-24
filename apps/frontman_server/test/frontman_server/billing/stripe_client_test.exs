defmodule FrontmanServer.Billing.StripeClientTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Billing.Customer
  alias FrontmanServer.Billing.StripeClient
  alias FrontmanServer.Billing.StripeWebhookSignature
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServer.Test.HTTPFixture

  describe "start_checkout/5" do
    test "constructs Stripe Managed Payments Checkout params from domain values" do
      user = AccountsFixtures.user_fixture()
      customer = %Customer{stripe_customer_id: "cus_existing"}

      start_stripe_server(%{{"POST", "/v1/checkout/sessions"} => 1}, fn conn ->
        assert ["Bearer sk_test_123"] = Plug.Conn.get_req_header(conn, "authorization")

        expected_api_version = Keyword.fetch!(stripe_config(), :api_version)
        assert [expected_api_version] == Plug.Conn.get_req_header(conn, "stripe-version")

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        assert params["mode"] == "subscription"
        assert params["line_items[0][price]"] == "price_yearly_test"
        assert params["line_items[0][quantity]"] == "1"
        assert params["managed_payments[enabled]"] == "true"

        assert params["success_url"] ==
                 "https://frontman.test/billing/stripe-return/success?session_id={CHECKOUT_SESSION_ID}"

        assert params["cancel_url"] == "https://frontman.test/billing/stripe-return/cancel"
        assert params["client_reference_id"] == user.id
        refute Map.has_key?(params, "customer_email")
        assert params["customer"] == "cus_existing"
        assert params["subscription_data[trial_period_days]"] == "7"
        assert params["payment_method_collection"] == "always"
        assert params["subscription_data[metadata][user_id]"] == user.id

        assert params["subscription_data[metadata][interval]"] ==
                 "yearly"

        assert params["metadata[user_id]"] == user.id
        assert params["metadata[interval]"] == "yearly"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "cs_test_123"}))
      end)

      assert {:ok, %{"id" => "cs_test_123"}} =
               StripeClient.start_checkout(
                 user,
                 customer,
                 :yearly,
                 %{
                   success_url:
                     "https://frontman.test/billing/stripe-return/success?session_id={CHECKOUT_SESSION_ID}",
                   cancel_url: "https://frontman.test/billing/stripe-return/cancel"
                 },
                 trial_eligible: true
               )
    end
  end

  describe "checkout without a billing customer" do
    test "prefills email only for a new customer and omits a consumed trial" do
      user = AccountsFixtures.user_fixture()

      start_stripe_server(%{{"POST", "/v1/checkout/sessions"} => 1}, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        assert params["customer_email"] == user.email
        assert params["line_items[0][price]"] == "price_monthly_test"
        refute Map.has_key?(params, "customer")
        refute Map.has_key?(params, "subscription_data[trial_period_days]")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "cs_new_customer"}))
      end)

      assert {:ok, %{"id" => "cs_new_customer"}} =
               StripeClient.start_checkout(
                 user,
                 nil,
                 :monthly,
                 %{
                   success_url: "https://frontman.test/success",
                   cancel_url: "https://frontman.test/cancel"
                 },
                 trial_eligible: false
               )
    end
  end

  describe "create_customer_portal_url/2" do
    test "constructs Stripe Customer Portal params from domain values" do
      customer = %Customer{stripe_customer_id: "cus_existing"}

      start_stripe_server(%{{"POST", "/v1/billing_portal/sessions"} => 1}, fn conn ->
        assert ["Bearer sk_test_123"] = Plug.Conn.get_req_header(conn, "authorization")

        expected_api_version = Keyword.fetch!(stripe_config(), :api_version)
        assert [expected_api_version] == Plug.Conn.get_req_header(conn, "stripe-version")

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)

        assert params["customer"] == "cus_existing"

        assert params["return_url"] ==
                 "https://frontman.test/billing/stripe-return/customer-portal"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"url" => "https://billing.stripe.test/p/session"})
        )
      end)

      assert {:ok, "https://billing.stripe.test/p/session"} =
               StripeClient.create_customer_portal_url(
                 customer,
                 "https://frontman.test/billing/stripe-return/customer-portal"
               )
    end
  end

  describe "provider failures" do
    test "preserves Stripe request IDs for checkout and portal failures" do
      body = %{"error" => %{"code" => "api_key_expired", "message" => "Invalid API key"}}

      routes = %{
        {"POST", "/v1/checkout/sessions"} => 1,
        {"POST", "/v1/billing_portal/sessions"} => 1
      }

      start_stripe_server(routes, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.put_resp_header("request-id", "req_test123")
        |> Plug.Conn.send_resp(401, Jason.encode!(body))
      end)

      assert {:error, {:stripe_error, 401, ^body, ["req_test123"]}} =
               StripeClient.start_checkout(
                 AccountsFixtures.user_fixture(),
                 nil,
                 :monthly,
                 %{
                   success_url: "https://frontman.test/success",
                   cancel_url: "https://frontman.test/cancel"
                 },
                 trial_eligible: false
               )

      assert {:error, {:stripe_error, 401, ^body, ["req_test123"]}} =
               StripeClient.create_customer_portal_url(
                 %Customer{stripe_customer_id: "cus_existing"},
                 "https://frontman.test/return"
               )
    end
  end

  describe "construct_webhook_event/2" do
    test "accepts valid Stripe signatures" do
      raw_body = Jason.encode!(%{"id" => "evt_signed", "type" => "checkout.session.completed"})
      timestamp = System.system_time(:second)
      signature = signature(timestamp, raw_body)

      assert {:ok, %{"id" => "evt_signed"}} =
               StripeClient.construct_webhook_event(raw_body, "t=#{timestamp},v1=#{signature}")
    end

    test "accepts any matching v1 signature" do
      raw_body = Jason.encode!(%{"id" => "evt_signed", "type" => "checkout.session.completed"})
      timestamp = System.system_time(:second)
      signature = signature(timestamp, raw_body)

      assert {:ok, %{"id" => "evt_signed"}} =
               StripeClient.construct_webhook_event(
                 raw_body,
                 "t=#{timestamp},v1=bad,v1=#{signature}"
               )
    end

    test "rejects invalid Stripe signatures" do
      raw_body = Jason.encode!(%{"id" => "evt_signed", "type" => "checkout.session.completed"})
      timestamp = System.system_time(:second)

      assert {:error, :invalid_signature} =
               StripeClient.construct_webhook_event(raw_body, "t=#{timestamp},v1=bad")
    end

    test "uses configured signature tolerance" do
      raw_body = Jason.encode!(%{"id" => "evt_signed", "type" => "checkout.session.completed"})
      timestamp = System.system_time(:second) - 2
      signature = signature(timestamp, raw_body)
      stripe_config = Application.fetch_env!(:frontman_server, :stripe)

      Application.put_env(
        :frontman_server,
        :stripe,
        Keyword.put(stripe_config, :signature_tolerance_seconds, 1)
      )

      on_exit(fn -> Application.put_env(:frontman_server, :stripe, stripe_config) end)

      assert {:error, :stale_signature} =
               StripeClient.construct_webhook_event(raw_body, "t=#{timestamp},v1=#{signature}")
    end
  end

  defp signature(timestamp, raw_body) do
    [_, signature] =
      raw_body
      |> StripeWebhookSignature.sign(timestamp, "whsec_test_123")
      |> String.split("v1=", parts: 2)

    signature
  end

  defp stripe_config do
    Application.fetch_env!(:frontman_server, :stripe)
  end

  defp start_stripe_server(routes, respond) do
    base_url = HTTPFixture.start!(routes, respond)
    stripe_config = Application.fetch_env!(:frontman_server, :stripe)

    Application.put_env(
      :frontman_server,
      :stripe,
      Keyword.merge(stripe_config,
        api_base_url: "#{base_url}/v1",
        secret_key: "sk_test_123"
      )
    )

    on_exit(fn -> Application.put_env(:frontman_server, :stripe, stripe_config) end)
  end
end
