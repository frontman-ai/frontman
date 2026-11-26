# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Billing do
  @moduledoc """
  Public API for billing customers, subscriptions, checkout, and provider events.
  """

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts],
    exports: [Client, Customer, StripeEvent, Subscription]

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Billing.{Customer, StripeEvent, Subscriptions}
  alias FrontmanServer.Repo

  @type interval :: :monthly | :yearly

  defdelegate get_current_subscription(scope), to: Subscriptions, as: :current

  @doc """
  Returns `:none`, `{:allowed, status}`, or `{:inactive, status}` for subscription access.
  """
  defdelegate subscription_access(scope), to: Subscriptions, as: :access

  defdelegate trial_eligible?(scope), to: Subscriptions
  defdelegate start_checkout(scope, interval, return_urls), to: Subscriptions
  defdelegate upsert_subscription(scope, customer, attrs), to: Subscriptions

  def start_checkout(%Scope{} = scope, interval, return_urls, trial_eligible: trial_eligible)
      when is_map(return_urls) do
    billing_client().start_checkout(Scope.user(scope), customer(scope), interval, return_urls,
      trial_eligible: trial_eligible
    )
  end

  @doc """
  Creates a Stripe Customer Portal URL for the scoped user's billing customer.
  """
  def create_customer_portal_url(%Scope{} = scope, return_url)
      when is_binary(return_url) do
    case customer(scope) do
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

  def has_customer?(%Scope{} = scope) do
    Customer
    |> Customer.for_user(Scope.user_id(scope))
    |> Repo.exists?()
  end

  def upsert_customer(%Scope{} = scope, stripe_customer_id) do
    %Customer{user_id: Scope.user_id(scope)}
    |> Customer.changeset(%{stripe_customer_id: stripe_customer_id})
    |> Repo.insert(
      on_conflict: [
        set: [stripe_customer_id: stripe_customer_id, updated_at: DateTime.utc_now(:second)]
      ],
      conflict_target: :user_id,
      returning: true
    )
  end

  def record_event(%{"id" => event_id, "type" => type} = event) do
    %StripeEvent{}
    |> StripeEvent.changeset(%{stripe_event_id: event_id, type: type, payload: event})
    |> Repo.insert(mode: :savepoint)
    |> case do
      {:ok, _event} ->
        {:ok, :inserted}

      {:error, changeset} ->
        if unique_event?(changeset), do: {:ok, :duplicate}, else: {:error, changeset}
    end
  end

  defp unique_event?(%Ecto.Changeset{errors: errors}) do
    errors
    |> Keyword.get_values(:stripe_event_id)
    |> Enum.any?(fn {_message, opts} -> opts[:constraint] == :unique end)
  end

  defp customer(scope) do
    Customer
    |> Customer.for_user(Scope.user_id(scope))
    |> Repo.one()
  end

  defp billing_client do
    Application.fetch_env!(:frontman_server, :billing_client)
  end
end
