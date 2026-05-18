defmodule FrontmanServer.Billing.StripeClientTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Billing.Customer
  alias FrontmanServer.Billing.StripeClient
  alias FrontmanServer.Billing.StripeWebhookSignature
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  describe "start_checkout/5" do
    setup :setup_stripe_bypass

    test "constructs Stripe Managed Payments Checkout params from domain values", %{
      bypass: bypass
    } do
      user = AccountsFixtures.user_fixture()
      customer = %Customer{stripe_customer_id: "cus_existing"}

      Bypass.expect(bypass, "POST", "/v1/checkout/sessions", fn conn ->
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
        assert params["customer_email"] == user.email
        assert params["customer"] == "cus_existing"
        assert params["subscription_data[trial_period_days]"] == "14"
        assert params["subscription_data[metadata][user_id]"] == user.id

        assert params["subscription_data[metadata][interval]"] ==
                 "yearly"

        assert params["metadata[user_id]"] == user.id
        assert params["metadata[interval]"] == "yearly"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"id" => "cs_test_123"}))
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

  describe "create_customer_portal_url/2" do
    setup :setup_stripe_bypass

    test "constructs Stripe Customer Portal params from domain values", %{bypass: bypass} do
      customer = %Customer{stripe_customer_id: "cus_existing"}

      Bypass.expect(bypass, "POST", "/v1/billing_portal/sessions", fn conn ->
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
        |> Plug.Conn.resp(
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

  defp setup_stripe_bypass(_context) do
    bypass = Bypass.open()
    stripe_config = Application.fetch_env!(:frontman_server, :stripe)

    Application.put_env(
      :frontman_server,
      :stripe,
      Keyword.merge(stripe_config,
        api_base_url: "http://localhost:#{bypass.port}/v1",
        secret_key: "sk_test_123"
      )
    )

    on_exit(fn -> Application.put_env(:frontman_server, :stripe, stripe_config) end)

    %{bypass: bypass}
  end
end
