defmodule FrontmanServer.Billing.CheckoutOffersTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Billing
  alias FrontmanServer.BillingFixtures
  alias FrontmanServer.Test.Fixtures.Accounts

  setup :setup_paper_tiger

  test "reads both configured prices and eligible trial days without creating checkout" do
    scope = Accounts.user_scope_fixture()

    assert {:ok,
            [
              %{interval: :monthly, label: "USD 20.00 / month", trial_days: 7},
              %{interval: :yearly, label: "USD 200.00 / year", trial_days: 7}
            ]} = Billing.checkout_offers(scope)

    response =
      Req.get!(PaperTiger.Test.base_url("/v1/checkout/sessions"),
        headers: PaperTiger.Test.auth_headers()
      )

    assert response.body["data"] == []
  end

  test "does not offer a second trial after a consumed trial" do
    scope = Accounts.user_scope_fixture()

    BillingFixtures.subscription_for_scope_fixture(scope, %{
      status: "canceled",
      trial_start: ~U[2026-01-01 00:00:00Z],
      trial_end: ~U[2026-01-08 00:00:00Z]
    })

    assert {:ok, offers} = Billing.checkout_offers(scope)
    assert Enum.all?(offers, &(&1.trial_days == 0))
  end

  test "formats actual non-dollar and zero-decimal prices" do
    configure_monthly_price("price_offer_jpy", "jpy", 1234)
    assert {:ok, [monthly, _yearly]} = Billing.checkout_offers(Accounts.user_scope_fixture())
    assert monthly.label == "JPY 1234 / month"
  end

  test "preserves fractional currency units and configured trial length" do
    configure_monthly_price("price_offer_eur", "eur", 1234)
    configure_stripe(trial_days: 14)
    assert {:ok, [monthly, _yearly]} = Billing.checkout_offers(Accounts.user_scope_fixture())
    assert monthly.label == "EUR 12.34 / month"
    assert monthly.trial_days == 14
  end

  test "returns an error for a missing configured price rather than partial offers" do
    configure_stripe(yearly_price_id: "price_missing_offer")

    assert {:error, {:stripe_error, 404, _body, _request_ids}} =
             Billing.checkout_offers(Accounts.user_scope_fixture())
  end

  test "rejects a configured price whose recurrence does not match checkout" do
    configure_stripe(monthly_price_id: "price_yearly_test")

    assert {:error, :unsupported_checkout_price} =
             Billing.checkout_offers(Accounts.user_scope_fixture())
  end

  test "rejects unsupported currency instead of guessing minor units" do
    configure_monthly_price("price_offer_unknown", "zzz", 1234)

    assert {:error, :unsupported_checkout_currency} =
             Billing.checkout_offers(Accounts.user_scope_fixture())
  end

  defp configure_monthly_price(id, currency, amount) do
    response =
      Req.post!(PaperTiger.Test.base_url("/v1/prices"),
        headers: PaperTiger.Test.auth_headers(),
        form: [
          {"id", id},
          {"product", "prod_frontman_monthly"},
          {"currency", currency},
          {"unit_amount", amount},
          {"recurring[interval]", "month"}
        ]
      )

    assert response.status in 200..299
    configure_stripe(monthly_price_id: id)
  end

  defp configure_stripe(updates) do
    previous = Application.fetch_env!(:frontman_server, :stripe)
    Application.put_env(:frontman_server, :stripe, Keyword.merge(previous, updates))
    on_exit(fn -> Application.put_env(:frontman_server, :stripe, previous) end)
  end
end
