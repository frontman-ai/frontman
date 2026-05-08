defmodule FrontmanServer.BillingTest do
  use FrontmanServer.DataCase, async: true

  import Mox

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.{Customer, Subscription}
  alias FrontmanServer.Billing.Webhooks
  alias FrontmanServer.Repo
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  setup :verify_on_exit!

  describe "customers" do
    test "create_customer/2 accepts classic Stripe customer ids" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      assert {:ok, %Customer{} = customer} =
               Billing.create_customer(scope, %{stripe_customer_id: "cus_test"})

      assert customer.user_id == user.id
      assert customer.stripe_customer_id == "cus_test"
      assert customer.stripe_customer_account_id == nil
    end

    test "create_customer/2 accepts Accounts v2 customer account ids" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      assert {:ok, %Customer{} = customer} =
               Billing.create_customer(scope, %{stripe_customer_account_id: "acct_test"})

      assert customer.user_id == user.id
      assert customer.stripe_customer_id == nil
      assert customer.stripe_customer_account_id == "acct_test"
    end
  end

  describe "start_checkout/3" do
    test "creates a yearly managed-payments subscription checkout with trial" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      expect(
        FrontmanServer.Billing.ClientMock,
        :start_checkout,
        fn checkout_user, customer, interval, return_urls, opts ->
          assert checkout_user.id == user.id
          assert customer == nil
          assert interval == :yearly
          assert opts == [trial_eligible: true]

          assert return_urls == %{
                   success_url: "https://billing.test/success?session_id={CHECKOUT_SESSION_ID}",
                   cancel_url: "https://billing.test/cancel"
                 }

          {:ok, %{"id" => "cs_test_123", "url" => "https://checkout.stripe.test/session"}}
        end
      )

      assert {:ok, %{"id" => "cs_test_123"}} =
               Billing.start_checkout(scope, :yearly, %{
                 success_url: "https://billing.test/success?session_id={CHECKOUT_SESSION_ID}",
                 cancel_url: "https://billing.test/cancel"
               })
    end

    test "starts checkout without a trial after the user has consumed one" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      {:ok, customer} =
        Billing.create_customer(scope, %{stripe_customer_id: "cus_checkout_trial_used"})

      {:ok, _subscription} =
        Billing.create_subscription(scope, %{
          billing_customer_id: customer.id,
          stripe_subscription_id: "sub_checkout_trial_used",
          stripe_customer_id: "cus_checkout_trial_used",
          status: "active",
          interval: :monthly,
          price_id: "price_monthly_test",
          trial_end: ~U[2026-01-01 00:00:00Z]
        })

      expect(
        FrontmanServer.Billing.ClientMock,
        :start_checkout,
        fn checkout_user, ^customer, interval, _return_urls, opts ->
          assert checkout_user.id == user.id
          assert interval == :monthly
          assert opts == [trial_eligible: false]

          {:ok, %{"id" => "cs_test_no_trial", "url" => "https://checkout.stripe.test/session"}}
        end
      )

      assert {:ok, %{"id" => "cs_test_no_trial"}} =
               Billing.start_checkout(scope, :monthly, %{
                 success_url: "https://billing.test/success?session_id={CHECKOUT_SESSION_ID}",
                 cancel_url: "https://billing.test/cancel"
               })
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

  describe "get_status/1" do
    test "returns nil when the scoped user has no subscription" do
      user = AccountsFixtures.user_fixture()

      assert Billing.get_status(Scope.for_user(user)) == nil
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

      assert Billing.get_status(Scope.for_user(user)).id == subscription.id
    end
  end

  describe "Webhooks.process_event/1" do
    test "stores customer from checkout.session.completed" do
      user = AccountsFixtures.user_fixture()

      event = %{
        "id" => "evt_checkout_completed",
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "client_reference_id" => user.id,
            "customer" => "cus_test_123",
            "customer_account" => nil,
            "metadata" => %{"user_id" => user.id}
          }
        }
      }

      assert {:ok, :processed} = Webhooks.process_event(event)

      assert %Customer{stripe_customer_id: "cus_test_123"} =
               Repo.get_by(Customer, user_id: user.id)
    end

    test "stores subscription updates linked to the user" do
      user = AccountsFixtures.user_fixture()

      event = %{
        "id" => "evt_subscription_updated",
        "type" => "customer.subscription.updated",
        "data" => %{
          "object" => %{
            "id" => "sub_test_123",
            "customer" => "cus_test_123",
            "customer_account" => nil,
            "status" => "trialing",
            "current_period_end" => 1_767_225_600,
            "trial_end" => 1_767_225_600,
            "cancel_at" => nil,
            "canceled_at" => nil,
            "metadata" => %{"user_id" => user.id},
            "items" => %{
              "data" => [
                %{
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

      assert {:ok, :processed} = Webhooks.process_event(event)

      assert %Subscription{} =
               subscription =
               Repo.get_by(Subscription, stripe_subscription_id: "sub_test_123")

      customer = Repo.get_by!(Customer, user_id: user.id)
      assert subscription.billing_customer_id == customer.id
      assert subscription.status == "trialing"
      assert subscription.interval == :monthly
      assert subscription.price_id == "price_monthly_test"
    end

    test "ignores duplicate webhook events" do
      event = %{
        "id" => "evt_duplicate",
        "type" => "checkout.session.async_payment_failed",
        "data" => %{"object" => %{}}
      }

      assert {:ok, :ignored} = Webhooks.process_event(event)
      assert {:ok, :duplicate} = Webhooks.process_event(event)
    end

    test "failed events are retryable and not treated as duplicates" do
      user = AccountsFixtures.user_fixture()

      bad_event = %{
        "id" => "evt_retryable",
        "type" => "customer.subscription.updated",
        "data" => %{
          "object" => %{
            "id" => "sub_retryable",
            "customer" => "cus_retryable",
            "customer_account" => nil,
            "status" => nil,
            "current_period_end" => nil,
            "trial_end" => nil,
            "cancel_at" => nil,
            "canceled_at" => nil,
            "metadata" => %{"user_id" => user.id},
            "items" => %{"data" => []}
          }
        }
      }

      assert {:error, _reason} = Webhooks.process_event(bad_event)

      assert Repo.get_by(FrontmanServer.Billing.StripeEvent, stripe_event_id: "evt_retryable") ==
               nil

      good_event =
        put_in(
          bad_event,
          ["data", "object", "status"],
          "trialing"
        )

      assert {:ok, :processed} = Webhooks.process_event(good_event)

      assert %Subscription{stripe_subscription_id: "sub_retryable"} =
               Repo.get_by!(Subscription, stripe_subscription_id: "sub_retryable")
    end
  end
end
