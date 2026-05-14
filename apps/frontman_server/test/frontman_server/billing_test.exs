defmodule FrontmanServer.BillingTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.BillingFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.Customer
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  describe "customers" do
    test "create_customer/2 accepts classic Stripe customer ids" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      assert {:ok, %Customer{} = customer} =
               Billing.create_customer(scope, %{stripe_customer_id: "cus_test"})

      assert customer.user_id == user.id
      assert customer.stripe_customer_id == "cus_test"
    end
  end

  describe "trial_eligible?/1" do
    test "returns true when the user has never had a trial" do
      user = AccountsFixtures.user_fixture()

      assert Billing.trial_eligible?(Scope.for_user(user))
    end

    test "returns false when the user has a trialing subscription" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      {:ok, customer} =
        Billing.create_customer(scope, %{stripe_customer_id: "cus_trialing_test"})

      {:ok, _subscription} =
        Billing.create_subscription(scope, %{
          billing_customer_id: customer.id,
          stripe_subscription_id: "sub_trialing_test",
          stripe_customer_id: "cus_trialing_test",
          status: "trialing",
          interval: :monthly,
          price_id: "price_monthly_test"
        })

      refute Billing.trial_eligible?(scope)
    end

    test "returns false when the user has any subscription with a trial end" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      {:ok, customer} =
        Billing.create_customer(scope, %{stripe_customer_id: "cus_trial_end_test"})

      {:ok, _subscription} =
        Billing.create_subscription(scope, %{
          billing_customer_id: customer.id,
          stripe_subscription_id: "sub_trial_end_test",
          stripe_customer_id: "cus_trial_end_test",
          status: "active",
          interval: :yearly,
          price_id: "price_yearly_test",
          trial_end: ~U[2026-01-01 00:00:00Z]
        })

      refute Billing.trial_eligible?(scope)
    end
  end

  describe "allow_access?/1" do
    test "returns false when the user has no subscription" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      refute Billing.allow_access?(scope)
    end

    test "returns true for active subscriptions" do
      scope = scope_with_subscription_fixture("active")

      assert Billing.allow_access?(scope)
    end
  end

  describe "get_current_subscription/1" do
    test "returns nil when the scoped user has no subscription" do
      user = AccountsFixtures.user_fixture()

      assert Billing.get_current_subscription(Scope.for_user(user)) == nil
    end

    test "returns the scoped user's subscription" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      {:ok, customer} =
        Billing.create_customer(scope, %{stripe_customer_id: "cus_status_test"})

      {:ok, subscription} =
        Billing.create_subscription(scope, %{
          billing_customer_id: customer.id,
          stripe_subscription_id: "sub_status_test",
          stripe_customer_id: "cus_status_test",
          status: "trialing",
          interval: :monthly,
          price_id: "price_monthly_test"
        })

      assert Billing.get_current_subscription(Scope.for_user(user)).id == subscription.id
    end
  end
end
