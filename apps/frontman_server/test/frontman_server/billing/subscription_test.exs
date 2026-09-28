defmodule FrontmanServer.Billing.SubscriptionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Billing.Subscription

  describe "allow_access?/1" do
    test "returns false without a subscription" do
      refute Subscription.allow_access?(nil)
    end

    test "returns true for trialing, active, and past_due subscriptions" do
      assert Subscription.allow_access?(%Subscription{status: "trialing"})
      assert Subscription.allow_access?(%Subscription{status: "active"})
      assert Subscription.allow_access?(%Subscription{status: "past_due"})
    end

    test "returns false for other subscription statuses" do
      refute Subscription.allow_access?(%Subscription{status: "canceled"})
    end
  end
end
