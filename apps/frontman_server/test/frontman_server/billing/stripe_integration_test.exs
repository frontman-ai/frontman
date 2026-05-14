defmodule FrontmanServer.Billing.StripeIntegrationTest do
  use FrontmanServerWeb.ConnCase, async: false

  alias FrontmanServer.Billing.{Customer, StripeEvent, Subscription}
  alias FrontmanServer.Repo
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  @moduletag :stripe_integration

  setup :setup_paper_tiger_webhook

  test "stores customer from PaperTiger checkout webhook delivery" do
    user = AccountsFixtures.user_fixture()

    paper_tiger_post!("/v1/customers", [{"id", "cus_checkout_webhook"}])

    %{"id" => session_id} =
      paper_tiger_post!("/v1/checkout/sessions", [
        {"mode", "subscription"},
        {"success_url", "https://billing.test/success"},
        {"cancel_url", "https://billing.test/cancel"},
        {"customer", "cus_checkout_webhook"},
        {"metadata[user_id]", user.id}
      ])

    response = paper_tiger_post!("/_test/checkout/sessions/#{session_id}/complete", [])

    assert response["status"] == "complete"

    assert_eventually(fn ->
      assert %Customer{stripe_customer_id: "cus_checkout_webhook"} =
               Repo.get_by(Customer, user_id: user.id)
    end)

    assert_eventually(fn ->
      assert %StripeEvent{type: "checkout.session.completed"} =
               Repo.get_by(StripeEvent, type: "checkout.session.completed")
    end)
  end

  test "stores subscription from PaperTiger subscription webhook delivery" do
    user = AccountsFixtures.user_fixture()

    paper_tiger_post!("/v1/customers", [{"id", "cus_subscription_webhook"}])

    paper_tiger_post!("/v1/subscriptions", [
      {"id", "sub_subscription_webhook"},
      {"customer", "cus_subscription_webhook"},
      {"status", "trialing"},
      {"metadata[user_id]", user.id},
      {"items[0][price]", "price_monthly_test"}
    ])

    customer = assert_eventually(fn -> Repo.get_by!(Customer, user_id: user.id) end)

    subscription =
      assert_eventually(fn ->
        assert %Subscription{} =
                 Repo.get_by(Subscription, stripe_subscription_id: "sub_subscription_webhook")
      end)

    assert subscription.billing_customer_id == customer.id
    assert subscription.stripe_customer_id == "cus_subscription_webhook"
    assert subscription.status == "trialing"
    assert subscription.interval == :monthly
    assert subscription.price_id == "price_monthly_test"

    assert_eventually(fn ->
      assert %StripeEvent{type: "customer.subscription.created"} =
               Repo.get_by(StripeEvent, type: "customer.subscription.created")
    end)
  end

  defp paper_tiger_post!(path, form) do
    response =
      path
      |> PaperTiger.Test.base_url()
      |> Req.post!(form: form, headers: PaperTiger.Test.auth_headers())

    assert response.status in 200..299

    response.body
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 1 do
    fun.()
  rescue
    _error in [ExUnit.AssertionError, Ecto.NoResultsError] ->
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
  end

  defp assert_eventually(fun, _attempts), do: fun.()
end
