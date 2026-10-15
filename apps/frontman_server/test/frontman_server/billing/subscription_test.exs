defmodule FrontmanServer.Billing.SubscriptionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Billing.Subscription

  describe "allows_runs?/1" do
    test "returns false without a subscription" do
      refute Subscription.allows_runs?(nil)
    end

    test "returns true for trialing and active subscriptions" do
      assert Subscription.allows_runs?(%Subscription{status: "trialing"})
      assert Subscription.allows_runs?(%Subscription{status: "active"})
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
        refute Subscription.allows_runs?(%Subscription{status: status})
      end
    end
  end
end
