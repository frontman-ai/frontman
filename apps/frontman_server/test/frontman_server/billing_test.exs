defmodule FrontmanServer.BillingTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.BillingFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.Webhooks
  alias FrontmanServer.Test.BillingClientStub
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  describe "trial_eligible?/1" do
    test "returns true when the user has never had a trial" do
      user = AccountsFixtures.user_fixture()

      assert Billing.trial_eligible?(Scope.for_user(user))
    end

    test "returns false when the user has a trialing subscription" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      customer = customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_trialing_test"})

      subscription_for_customer_fixture(scope, customer, %{
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

      customer = customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_trial_end_test"})

      subscription_for_customer_fixture(scope, customer, %{
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

  describe "create_customer_portal_url/2" do
    test "returns missing customer before calling the billing client" do
      use_billing_client_stub()

      scope = AccountsFixtures.user_scope_fixture()

      assert {:error, :billing_customer_missing} =
               Billing.create_customer_portal_url(
                 scope,
                 "https://frontman.test/billing/stripe-return/customer-portal"
               )

      refute_received {:create_customer_portal_url, _customer, _return_url}
    end

    test "returns a Stripe Customer Portal URL for the scoped billing customer" do
      use_billing_client_stub()

      BillingClientStub.stub_customer_portal_url({:ok, "https://billing.stripe.test/p/session"})

      scope = AccountsFixtures.user_scope_fixture()

      customer =
        customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_customer_portal_test"})

      assert {:ok, "https://billing.stripe.test/p/session"} =
               Billing.create_customer_portal_url(
                 scope,
                 "https://frontman.test/billing/stripe-return/customer-portal"
               )

      assert_received {
        :create_customer_portal_url,
        ^customer,
        "https://frontman.test/billing/stripe-return/customer-portal"
      }
    end

    test "wraps billing client failures" do
      use_billing_client_stub()
      BillingClientStub.stub_customer_portal_url({:error, :stripe_timeout})

      scope = AccountsFixtures.user_scope_fixture()
      customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_customer_portal_error_test"})

      assert {:error, {:customer_portal_url_failed, :stripe_timeout}} =
               Billing.create_customer_portal_url(
                 scope,
                 "https://frontman.test/billing/stripe-return/customer-portal"
               )
    end
  end

  describe "status/1" do
    test "returns none before subscription exists" do
      scope = AccountsFixtures.user_scope_fixture()

      assert %{
               status: "none",
               access_allowed: false,
               has_billing_customer: false,
               interval: nil,
               current_period_end: nil,
               trial_end: nil,
               cancel_at: nil,
               canceled_at: nil
             } = Billing.status(scope)
    end

    test "returns customer flag before subscription exists" do
      scope = AccountsFixtures.user_scope_fixture()
      customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_status_customer_test"})

      assert %{
               status: "none",
               access_allowed: false,
               has_billing_customer: true
             } = Billing.status(scope)
    end

    test "returns allowed subscription status" do
      scope = AccountsFixtures.user_scope_fixture()
      customer = customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_status_test"})

      subscription =
        subscription_for_customer_fixture(scope, customer, %{
          stripe_subscription_id: "sub_status_test",
          stripe_customer_id: "cus_status_test",
          status: "trialing",
          interval: :monthly,
          price_id: "price_monthly_test",
          current_period_end: ~U[2026-06-01 00:00:00Z]
        })

      current_period_end = subscription.current_period_end

      assert %{
               status: "trialing",
               access_allowed: true,
               has_billing_customer: true,
               interval: :monthly,
               current_period_end: ^current_period_end
             } = Billing.status(scope)
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

      customer = customer_for_scope_fixture(scope, %{stripe_customer_id: "cus_status_test"})

      subscription =
        subscription_for_customer_fixture(scope, customer, %{
          stripe_subscription_id: "sub_status_test",
          stripe_customer_id: "cus_status_test",
          status: "trialing",
          interval: :monthly,
          price_id: "price_monthly_test"
        })

      assert Billing.get_current_subscription(Scope.for_user(user)).id == subscription.id
    end
  end

  describe "status change notifications" do
    test "broadcast_status_changed publishes on the user billing topic" do
      user_id = Ecto.UUID.generate()

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Billing.status_topic(user_id))

      assert :ok = Billing.broadcast_status_changed(user_id)
      assert_receive :billing_status_changed
    end

    test "subscription webhook broadcasts billing status change" do
      scope = AccountsFixtures.user_scope_fixture()
      current_period_end = DateTime.from_unix!(1_780_243_481, :second)

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Billing.status_topic(scope.user.id))

      assert {:ok, :processed} = Webhooks.process_event(subscription_webhook_event(scope.user.id))
      assert_receive :billing_status_changed

      assert %{
               status: "active",
               access_allowed: true,
               has_billing_customer: true,
               interval: :monthly,
               current_period_end: ^current_period_end
             } = Billing.status(scope)
    end

    test "checkout webhook broadcasts billing status change" do
      scope = AccountsFixtures.user_scope_fixture()

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Billing.status_topic(scope.user.id))

      assert {:ok, :processed} = Webhooks.process_event(checkout_webhook_event(scope.user.id))
      assert_receive :billing_status_changed

      assert %{
               status: "none",
               access_allowed: false,
               has_billing_customer: true
             } = Billing.status(scope)
    end
  end

  defp use_billing_client_stub do
    billing_client = Application.fetch_env!(:frontman_server, :billing_client)
    Application.put_env(:frontman_server, :billing_client, BillingClientStub)
    on_exit(fn -> Application.put_env(:frontman_server, :billing_client, billing_client) end)
  end

  defp subscription_webhook_event(user_id) do
    unique = System.unique_integer([:positive])

    %{
      "id" => "evt_subscription_broadcast_#{unique}",
      "type" => "customer.subscription.created",
      "data" => %{
        "object" => %{
          "id" => "sub_broadcast_#{unique}",
          "customer" => "cus_broadcast_#{unique}",
          "status" => "active",
          "metadata" => %{"user_id" => user_id},
          "items" => %{
            "data" => [
              %{
                "current_period_end" => 1_780_243_481,
                "price" => %{
                  "id" => "price_monthly_test",
                  "recurring" => %{"interval" => "month"}
                }
              }
            ]
          }
        }
      }
    }
  end

  defp checkout_webhook_event(user_id) do
    unique = System.unique_integer([:positive])

    %{
      "id" => "evt_checkout_broadcast_#{unique}",
      "type" => "checkout.session.completed",
      "data" => %{
        "object" => %{
          "id" => "cs_broadcast_#{unique}",
          "customer" => "cus_checkout_broadcast_#{unique}",
          "client_reference_id" => user_id,
          "metadata" => %{"user_id" => user_id}
        }
      }
    }
  end
end
