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
  alias FrontmanServer.Billing.{Customer, Subscription}
  alias FrontmanServer.Repo

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
    user = Accounts.scope_user(scope)
    customer = Customer |> Customer.for_user(user.id) |> Repo.one()
    trial_eligible = trial_eligible?(scope)

    billing_client().start_checkout(user, customer, interval, return_urls,
      trial_eligible: trial_eligible
    )
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
          access_allowed: boolean(),
          has_billing_customer: boolean(),
          interval: atom() | nil,
          current_period_end: DateTime.t() | nil,
          trial_end: DateTime.t() | nil,
          cancel_at: DateTime.t() | nil,
          canceled_at: DateTime.t() | nil
        }
  def status(%Scope{} = scope) do
    subscription = get_current_subscription(scope)
    status_payload(scope, subscription)
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
  Returns whether billing allows access for the scoped user.
  """
  @spec allow_access?(Scope.t()) :: boolean()
  def allow_access?(%Scope{} = scope) do
    scope
    |> get_current_subscription()
    |> Subscription.allow_access?()
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
      access_allowed: Subscription.allow_access?(subscription),
      has_billing_customer: has_billing_customer?(scope, subscription),
      interval: subscription.interval,
      current_period_end: subscription.current_period_end,
      trial_end: subscription.trial_end,
      cancel_at: subscription.cancel_at,
      canceled_at: subscription.canceled_at
    }
  end

  defp status_payload(scope, nil) do
    %{
      status: "none",
      access_allowed: false,
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
