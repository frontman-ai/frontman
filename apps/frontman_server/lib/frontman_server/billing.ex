# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Billing do
  @moduledoc """
  Billing context for Stripe Managed Payments subscriptions.
  """

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts],
    exports: [Client, Customer, StripeEvent, Subscription, Webhooks]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Billing.{Customer, RunAllowance, Subscription}
  alias FrontmanServer.Repo

  @pretrial_run_limit 5

  @type interval :: :monthly | :yearly

  @doc """
  Starts provider checkout for the scoped user.
  """
  def start_checkout(%Scope{} = scope, interval, return_urls)
      when is_map(return_urls) do
    case get_current_subscription(scope) do
      %Subscription{status: status} when status in ["trialing", "active", "past_due"] ->
        {:error, :subscription_already_active}

      _subscription ->
        user = Accounts.scope_user(scope)
        customer = Customer |> Customer.for_user(user.id) |> Repo.one()

        billing_client().start_checkout(user, customer, interval, return_urls,
          trial_eligible: trial_eligible?(scope)
        )
    end
  end

  @doc """
  Creates a Stripe Customer Portal URL for the scoped user's billing customer.
  """
  def create_customer_portal_url(%Scope{} = scope, return_url)
      when is_binary(return_url) do
    case Customer |> Customer.for_user(Accounts.scope_user_id(scope)) |> Repo.one() do
      %Customer{} = customer ->
        case billing_client().create_customer_portal_url(customer, return_url) do
          {:ok, url} when is_binary(url) ->
            {:ok, url}

          {:error, reason} ->
            {:error, {:customer_portal_url_failed, reason}}
        end

      nil ->
        {:error, :billing_customer_missing}
    end
  end

  @doc """
  Returns whether checkout should include the configured trial period.
  """
  def trial_eligible?(%Scope{} = scope) do
    scope
    |> trial_consumed_query()
    |> Repo.exists?()
    |> Kernel.not()
  end

  @doc """
  Returns the current billing status payload for UI consumers.
  """
  def status(%Scope{} = scope) do
    subscription = get_current_subscription(scope)

    scope
    |> status_payload(subscription)
    |> Map.merge(%{
      trial_eligible: trial_eligible?(scope),
      trial_days: Application.fetch_env!(:frontman_server, :stripe) |> Keyword.fetch!(:trial_days)
    })
  end

  @doc """
  Returns the PubSub topic for billing status updates for a user.
  """
  def status_topic(%Scope{} = scope), do: "billing_status:user:#{Scope.user_id(scope)}"

  @doc """
  Broadcasts that a user's billing status changed.
  """
  def broadcast_status_changed(%Scope{} = scope) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      status_topic(scope),
      :billing_status_changed
    )
  end

  @doc """
  Returns whether the user's subscription permits new runs, excluding the BYOK allowance.
  """
  def subscription_allows_runs?(%Scope{} = scope) do
    scope
    |> get_current_subscription()
    |> Subscription.allow_access?()
  end

  @doc "Returns the subscription status used to determine hosted MCP access."
  def mcp_access(%Scope{} = scope) do
    case get_current_subscription(scope) do
      %Subscription{status: status} = subscription ->
        if Subscription.allow_access?(subscription),
          do: {:allowed, status},
          else: {:inactive, status}

      nil ->
        :none
    end
  end

  @doc "Advisory new-turn eligibility. authorize_new_turn/1 makes the authoritative billing decision."
  def can_start_turn?(%Scope{} = scope) do
    case subscription_allows_runs?(scope) do
      true -> true
      false -> remaining_runs(scope) > 0
    end
  end

  @doc "Authorizes a new turn, consuming allowance when needed. Call inside the turn-claim transaction."
  def authorize_new_turn(%Scope{} = scope) do
    case subscription_allows_runs?(scope) do
      true -> {:ok, :subscription}
      false -> consume_pretrial_run(scope)
    end
  end

  @doc """
  Returns the current billing subscription for the scoped user.
  """
  def get_current_subscription(%Scope{} = scope) do
    user_id = Accounts.scope_user_id(scope)

    Subscription
    |> Subscription.for_user(user_id)
    |> Repo.one()
  end

  defp consume_pretrial_run(scope) do
    case Repo.insert_all(RunAllowance, [%{user_id: Accounts.scope_user_id(scope), used: 1}],
           conflict_target: :user_id,
           on_conflict: RunAllowance.increment_below(@pretrial_run_limit)
         ) do
      {1, _} -> {:ok, :pretrial}
      {0, _} -> {:error, :billing_inactive}
    end
  end

  defp remaining_runs(scope) do
    case Repo.get(RunAllowance, Accounts.scope_user_id(scope)) do
      nil -> @pretrial_run_limit
      %RunAllowance{used: used} -> @pretrial_run_limit - used
    end
  end

  defp status_payload(scope, %Subscription{} = subscription) do
    {can_start_turn, remaining} =
      case Subscription.allow_access?(subscription) do
        true ->
          {true, nil}

        false ->
          remaining = remaining_runs(scope)
          {remaining > 0, remaining}
      end

    %{
      status: subscription.status,
      can_start_turn: can_start_turn,
      pretrial_runs_remaining: remaining,
      has_billing_customer: has_billing_customer?(scope, subscription),
      interval: subscription.interval,
      current_period_end: subscription.current_period_end,
      trial_end: subscription.trial_end,
      cancel_at: subscription.cancel_at,
      canceled_at: subscription.canceled_at
    }
  end

  defp status_payload(scope, nil) do
    remaining = remaining_runs(scope)

    %{
      status: "none",
      can_start_turn: remaining > 0,
      pretrial_runs_remaining: remaining,
      has_billing_customer: has_billing_customer?(scope, nil),
      interval: nil,
      current_period_end: nil,
      trial_end: nil,
      cancel_at: nil,
      canceled_at: nil
    }
  end

  defp has_billing_customer?(_scope, %Subscription{}), do: true

  defp has_billing_customer?(scope, nil) do
    Customer
    |> Customer.for_user(Accounts.scope_user_id(scope))
    |> Repo.exists?()
  end

  defp scoped_subscription_query(scope) do
    Subscription.for_user(Subscription, Accounts.scope_user_id(scope))
  end

  defp trial_consumed_query(scope) do
    scope
    |> scoped_subscription_query()
    |> Subscription.with_consumed_trial()
  end

  defp billing_client do
    Application.fetch_env!(:frontman_server, :billing_client)
  end
end
