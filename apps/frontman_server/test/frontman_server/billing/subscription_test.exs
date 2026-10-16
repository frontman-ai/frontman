defmodule FrontmanServer.Billing.SubscriptionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Billing.Subscription

  describe "allow_access?/1" do
    test "returns false without a subscription" do
      refute Subscription.allow_access?(nil)
    end

    test "returns true for trialing and active subscriptions" do
      assert Subscription.allow_access?(%Subscription{status: "trialing"})
      assert Subscription.allow_access?(%Subscription{status: "active"})
    end

    test "returns false for past due and other inactive subscription statuses" do
      for status <- [
            "past_due",
            "unpaid",
            "canceled",
            "incomplete",
            "incomplete_expired",
            "paused"
          ] do
        refute Subscription.allow_access?(%Subscription{status: status})
      end
    end
  end
end
