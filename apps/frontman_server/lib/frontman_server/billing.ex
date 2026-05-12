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
  Returns whether the scoped user can receive their lifetime trial.
  """
  @spec trial_eligible?(Scope.t()) :: boolean()
  def trial_eligible?(%Scope{} = scope) do
    scope
    |> trial_consumed_query()
    |> Repo.exists?()
    |> Kernel.not()
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

  def get_customer!(%Scope{} = scope, id), do: scoped_customer_query(scope) |> Repo.get!(id)

  def list_billing_customers(%Scope{} = scope) do
    Customer
    |> Customer.for_user(Accounts.scope_user_id(scope))
    |> Repo.all()
  end

  def create_customer(%Scope{} = scope, attrs) do
    %Customer{user_id: Accounts.scope_user_id(scope)}
    |> Customer.changeset(attrs)
    |> Repo.insert()
  end

  def update_customer(%Scope{} = scope, %Customer{} = customer, attrs) do
    scope
    |> get_customer!(customer.id)
    |> Customer.changeset(attrs)
    |> Repo.update()
  end

  def delete_customer(%Scope{} = scope, %Customer{} = customer) do
    scope
    |> get_customer!(customer.id)
    |> Repo.delete()
  end

  def change_customer(%Scope{} = scope, %Customer{} = customer, attrs \\ %{}) do
    scope
    |> get_customer!(customer.id)
    |> Customer.changeset(attrs)
  end

  def list_billing_subscriptions(%Scope{} = scope) do
    scoped_subscription_query(scope)
    |> Repo.all()
  end

  def get_subscription!(%Scope{} = scope, id),
    do: scoped_subscription_query(scope) |> Repo.get!(id)

  def create_subscription(%Scope{} = scope, attrs) do
    customer = get_customer!(scope, attr_value(attrs, :billing_customer_id))

    %Subscription{billing_customer_id: customer.id}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  def update_subscription(%Scope{} = scope, %Subscription{} = subscription, attrs) do
    scope
    |> get_subscription!(subscription.id)
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  def delete_subscription(%Scope{} = scope, %Subscription{} = subscription) do
    scope
    |> get_subscription!(subscription.id)
    |> Repo.delete()
  end

  def change_subscription(%Scope{} = scope, %Subscription{} = subscription, attrs \\ %{}) do
    scope
    |> get_subscription!(subscription.id)
    |> Subscription.changeset(attrs)
  end

  defp attr_value(attrs, key), do: attrs[key] || attrs[Atom.to_string(key)]

  defp scoped_customer_query(scope) do
    Customer.for_user(Customer, Accounts.scope_user_id(scope))
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
