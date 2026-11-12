defmodule FrontmanServer.BillingTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.BillingFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Billing
  alias FrontmanServer.SubscriptionWebhook
  alias FrontmanServer.Tasks
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServerWeb.BillingJSON

  describe "start_checkout/3" do
    setup :setup_paper_tiger

    test "rejects a second checkout for active, trialing, and past-due subscriptions" do
      for status <- ["trialing", "active", "past_due"] do
        scope = scope_with_subscription_fixture(status)

        assert {:error, :subscription_already_active} =
                 Billing.start_checkout(scope, :monthly, %{
                   success_url: "https://frontman.test/success",
                   cancel_url: "https://frontman.test/cancel"
                 })
      end

      assert PaperTiger.Test.requests(method: :post, path: "/v1/checkout/sessions") == []
    end

    test "allows a canceled subscriber to return without a second trial" do
      scope = AccountsFixtures.user_scope_fixture()
      customer = customer_for_scope_fixture(scope)
      run_allowance_fixture(scope, 4)

      subscription =
        subscription_for_customer_fixture(scope, customer, %{
          status: "trialing",
          trial_end: ~U[2026-01-01 00:00:00Z]
        })

      subscription |> Ecto.Changeset.change(status: "canceled") |> Repo.update!()
      assert %{can_start_turn: true, pretrial_runs_remaining: 1} = BillingJSON.status(scope)

      assert {:ok, checkout} =
               Billing.start_checkout(scope, :yearly, %{
                 success_url: "https://frontman.test/success",
                 cancel_url: "https://frontman.test/cancel"
               })

      assert_paper_tiger_checkout_session!(checkout)

      assert [%{params: params}] =
               PaperTiger.Test.requests(method: :post, path: "/v1/checkout/sessions")

      assert params["customer"] == customer.stripe_customer_id
      refute get_in(params, ["subscription_data", "trial_period_days"])
      assert %{trial_eligible: false, trial_days: 7} = BillingJSON.status(scope)
    end
  end

  describe "trial_eligible?/1" do
    test "returns true when the user has never had a trial" do
      user = AccountsFixtures.user_fixture()
      assert Billing.trial_eligible?(Scope.for_user(user))
    end

    test "returns false when the user has a trialing subscription" do
      scope = AccountsFixtures.user_scope_fixture()
      subscription_for_scope_fixture(scope, %{status: "trialing"})
      refute Billing.trial_eligible?(scope)
    end

    test "returns false when the user has any subscription with a trial end" do
      scope = AccountsFixtures.user_scope_fixture()

      subscription_for_scope_fixture(scope, %{
        status: "active",
        trial_end: ~U[2026-01-01 00:00:00Z]
      })

      refute Billing.trial_eligible?(scope)
    end
  end

  describe "status presentation" do
    test "returns none before subscription exists" do
      scope = AccountsFixtures.user_scope_fixture()

      assert %{
               status: "none",
               can_start_turn: true,
               pretrial_runs_remaining: 5,
               trial_eligible: true,
               trial_days: 7,
               has_billing_customer: false,
               interval: nil,
               current_period_end: nil,
               trial_end: nil,
               cancel_at: nil,
               canceled_at: nil
             } = BillingJSON.status(scope)
    end

    test "returns customer flag before subscription exists" do
      scope = AccountsFixtures.user_scope_fixture()
      customer_for_scope_fixture(scope)

      assert %{
               status: "none",
               can_start_turn: true,
               has_billing_customer: true
             } = BillingJSON.status(scope)
    end

    test "returns allowed subscription status" do
      scope = AccountsFixtures.user_scope_fixture()
      current_period_end = ~U[2026-06-01 00:00:00Z]

      subscription_for_scope_fixture(scope, %{
        status: "trialing",
        interval: :monthly,
        current_period_end: current_period_end
      })

      assert %{
               status: "trialing",
               can_start_turn: true,
               pretrial_runs_remaining: nil,
               trial_eligible: false,
               has_billing_customer: true,
               interval: :monthly,
               current_period_end: ^current_period_end
             } = BillingJSON.status(scope)
    end
  end

  describe "get_current_subscription/1" do
    test "returns nil when the scoped user has no subscription" do
      scope = AccountsFixtures.user_scope_fixture()
      assert Billing.get_current_subscription(scope) == nil
    end

    test "returns the scoped user's subscription" do
      scope = AccountsFixtures.user_scope_fixture()
      subscription = subscription_for_scope_fixture(scope)
      assert Billing.get_current_subscription(scope).id == subscription.id
    end
  end

  describe "status change notifications" do
    test "broadcast_status_changed publishes on the user billing topic" do
      scope = AccountsFixtures.user_scope_fixture()

      assert Tasks.status_topic(scope) == "billing_status:user:#{Scope.user_id(scope)}"
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.status_topic(scope))
      assert :ok = Tasks.broadcast_status_changed(scope)
      assert_receive :billing_status_changed
    end

    test "subscription webhook broadcasts billing status change" do
      scope = AccountsFixtures.user_scope_fixture()
      event = subscription_webhook_event(scope.user.id)
      current_period_end = DateTime.from_unix!(1_780_243_481, :second)
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.status_topic(scope))

      assert {:ok, :processed} = SubscriptionWebhook.process_event(event)
      assert_receive :billing_status_changed

      assert %{
               status: "active",
               can_start_turn: true,
               has_billing_customer: true,
               interval: :monthly,
               current_period_end: ^current_period_end
             } = BillingJSON.status(scope)
    end

    test "payment failure blocks access until the subscription becomes active again" do
      scope = AccountsFixtures.user_scope_fixture()
      run_allowance_fixture(scope, 5)
      event = subscription_webhook_event(scope.user.id)
      assert {:ok, :processed} = SubscriptionWebhook.process_event(event)
      assert {:allowed, "active"} = Billing.subscription_access(scope)
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.status_topic(scope))

      past_due_event =
        event
        |> Map.put("id", event["id"] <> "_past_due")
        |> Map.put("type", "customer.subscription.updated")
        |> put_in(["data", "object", "status"], "past_due")

      assert {:ok, :processed} = SubscriptionWebhook.process_event(past_due_event)
      assert_receive :billing_status_changed
      assert {:inactive, "past_due"} = Billing.subscription_access(scope)
      refute Tasks.can_start_turn?(scope)

      assert %{status: "past_due", can_start_turn: false, has_billing_customer: true} =
               BillingJSON.status(scope)

      recovered_event =
        event
        |> Map.put("id", event["id"] <> "_recovered")
        |> Map.put("type", "customer.subscription.updated")

      assert {:ok, :processed} = SubscriptionWebhook.process_event(recovered_event)
      assert_receive :billing_status_changed
      assert {:allowed, "active"} = Billing.subscription_access(scope)
      assert %{status: "active", can_start_turn: true} = BillingJSON.status(scope)
    end

    test "trial cancellation blocks exhausted users immediately and undoing it restores access" do
      for cancellation <- [
            %{"cancel_at" => 1_780_243_481},
            %{"canceled_at" => 1_780_157_081},
            %{
              "cancel_at_period_end" => true,
              "cancel_at" => 1_780_243_481,
              "canceled_at" => 1_780_157_081
            }
          ] do
        scope = AccountsFixtures.user_scope_fixture()
        run_allowance_fixture(scope, 5)

        event =
          subscription_webhook_event(scope.user.id)
          |> put_in(["data", "object", "status"], "trialing")
          |> put_in(["data", "object", "trial_end"], 1_780_243_481)

        assert {:ok, :processed} = SubscriptionWebhook.process_event(event)
        assert {:allowed, "trialing"} = Billing.subscription_access(scope)
        Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.status_topic(scope))

        canceled_event =
          event
          |> Map.put("id", event["id"] <> "_cancel")
          |> Map.put("type", "customer.subscription.updated")
          |> update_in(["data", "object"], &Map.merge(&1, cancellation))

        assert {:ok, :processed} = SubscriptionWebhook.process_event(canceled_event)
        assert_receive :billing_status_changed
        assert {:inactive, "trialing"} = Billing.subscription_access(scope)
        refute Tasks.can_start_turn?(scope)

        assert %{
                 status: "trialing",
                 can_start_turn: false,
                 pretrial_runs_remaining: 0,
                 trial_eligible: false
               } = BillingJSON.status(scope)

        resumed_event =
          event
          |> Map.put("id", event["id"] <> "_resume")
          |> Map.put("type", "customer.subscription.updated")
          |> put_in(["data", "object", "status"], "trialing")

        assert {:ok, :processed} = SubscriptionWebhook.process_event(resumed_event)
        assert_receive :billing_status_changed
        assert {:allowed, "trialing"} = Billing.subscription_access(scope)
        assert %{can_start_turn: true, pretrial_runs_remaining: nil} = BillingJSON.status(scope)
      end
    end

    test "canceling a trial preserves the unused free prompts" do
      scope = AccountsFixtures.user_scope_fixture()
      run_allowance_fixture(scope, 4)

      event =
        subscription_webhook_event(scope.user.id)
        |> Map.put("type", "customer.subscription.updated")
        |> put_in(["data", "object", "status"], "trialing")
        |> put_in(["data", "object", "trial_end"], 1_780_243_481)
        |> put_in(["data", "object", "cancel_at"], 1_780_243_481)
        |> put_in(["data", "object", "canceled_at"], 1_780_157_081)

      assert {:ok, :processed} = SubscriptionWebhook.process_event(event)
      assert {:inactive, "trialing"} = Billing.subscription_access(scope)
      assert %{can_start_turn: true, pretrial_runs_remaining: 1} = BillingJSON.status(scope)
    end

    test "scheduling cancellation of a paid subscription preserves access" do
      scope = AccountsFixtures.user_scope_fixture()
      run_allowance_fixture(scope, 5)

      event =
        subscription_webhook_event(scope.user.id)
        |> Map.put("type", "customer.subscription.updated")
        |> put_in(["data", "object", "trial_end"], 1_780_157_081)
        |> put_in(["data", "object", "cancel_at_period_end"], true)
        |> put_in(["data", "object", "cancel_at"], 1_780_243_481)
        |> put_in(["data", "object", "canceled_at"], 1_780_157_081)

      assert {:ok, :processed} = SubscriptionWebhook.process_event(event)
      assert {:allowed, "active"} = Billing.subscription_access(scope)
      assert %{status: "active", can_start_turn: true} = BillingJSON.status(scope)
    end

    test "checkout webhook broadcasts billing status change" do
      scope = AccountsFixtures.user_scope_fixture()
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.status_topic(scope))

      assert {:ok, :processed} =
               SubscriptionWebhook.process_event(checkout_webhook_event(scope.user.id))

      assert_receive :billing_status_changed

      assert %{status: "none", can_start_turn: true, has_billing_customer: true} =
               BillingJSON.status(scope)
    end
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
