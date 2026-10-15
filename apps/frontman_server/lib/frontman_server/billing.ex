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
  @spec start_checkout(Scope.t(), interval(), %{
          success_url: String.t(),
          cancel_url: String.t()
        }) ::
          {:ok, map()} | {:error, term()}
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
  @spec create_customer_portal_url(Scope.t(), String.t()) ::
          {:ok, String.t()}
          | {:error, :billing_customer_missing}
          | {:error, {:customer_portal_url_failed, term()}}
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
  @spec trial_eligible?(Scope.t()) :: boolean()
  def trial_eligible?(%Scope{} = scope) do
    scope
    |> trial_consumed_query()
    |> Repo.exists?()
    |> Kernel.not()
  end

  @doc """
  Returns the current billing status payload for UI consumers.
  """
  @spec status(Scope.t()) :: %{
          status: String.t(),
          can_start_turn: boolean(),
          pretrial_runs_remaining: non_neg_integer() | nil,
          has_billing_customer: boolean(),
          trial_eligible: boolean(),
          trial_days: pos_integer(),
          interval: atom() | nil,
          current_period_end: DateTime.t() | nil,
          trial_end: DateTime.t() | nil,
          cancel_at: DateTime.t() | nil,
          canceled_at: DateTime.t() | nil
        }
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
  @spec status_topic(String.t()) :: String.t()
  def status_topic(user_id) when is_binary(user_id), do: "billing_status:user:#{user_id}"

  @doc """
  Broadcasts that a user's billing status changed.
  """
  @spec broadcast_status_changed(String.t()) :: :ok | {:error, term()}
  def broadcast_status_changed(user_id) when is_binary(user_id) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      status_topic(user_id),
      :billing_status_changed
    )
  end

  @doc """
  Returns whether the user's subscription permits new runs, excluding the BYOK allowance.
  """
  @spec subscription_allows_runs?(Scope.t()) :: boolean()
  def subscription_allows_runs?(%Scope{} = scope) do
    scope
    |> get_current_subscription()
    |> Subscription.allows_runs?()
  end

  @doc "Checks permission to start a new turn, not to continue an already-claimed turn."
  def can_start_turn?(%Scope{} = scope) do
    case get_current_subscription(scope) do
      nil -> remaining_runs(scope) > 0
      subscription -> Subscription.allows_runs?(subscription)
    end
  end

  @doc "Consumes a BYOK run inside the transaction that records its turn."
  def consume_pretrial_run(%Scope{} = scope) do
    case get_current_subscription(scope) do
      nil ->
        case Repo.insert_all(RunAllowance, [%{user_id: Accounts.scope_user_id(scope), used: 1}],
               conflict_target: :user_id,
               on_conflict: RunAllowance.increment_below(@pretrial_run_limit)
             ) do
          {1, _} -> :ok
          {0, _} -> {:error, :billing_inactive}
        end

      %Subscription{} ->
        {:error, :billing_inactive}
    end
  end

  defp remaining_runs(scope) do
    case Repo.get(RunAllowance, Accounts.scope_user_id(scope)) do
      nil -> @pretrial_run_limit
      %RunAllowance{used: used} -> @pretrial_run_limit - used
    end
  end

  @doc """
  Returns the current billing subscription for the scoped user.
  """
  @spec get_current_subscription(Scope.t()) :: Subscription.t() | nil
  def get_current_subscription(%Scope{} = scope) do
    user_id = Accounts.scope_user_id(scope)

    Subscription
    |> Subscription.for_user(user_id)
    |> Repo.one()
  end

  defp status_payload(scope, %Subscription{} = subscription) do
    %{
      status: subscription.status,
      can_start_turn: Subscription.allows_runs?(subscription),
      pretrial_runs_remaining: nil,
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
