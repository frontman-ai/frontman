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

  @checkout_intervals [:monthly, :yearly]

  @type interval :: :monthly | :yearly

  def checkout_interval?(interval), do: interval in @checkout_intervals

  @doc """
  Creates a Stripe Checkout Session for the scoped user.
  """
  @spec create_checkout_session(Scope.t(), interval(), %{
          success_url: String.t(),
          cancel_url: String.t()
        }) ::
          {:ok, map()} | {:error, term()}
  def create_checkout_session(%Scope{} = scope, interval, return_urls)
      when is_map(return_urls) do
    true = checkout_interval?(interval)
    user = Accounts.scope_user(scope)
    customer = Customer |> Customer.for_user(user.id) |> Repo.one()

    billing_client().create_checkout_session(user, customer, interval, return_urls)
  end

  @doc """
  Returns the current billing subscription for the scoped user.
  """
  @spec get_status(Scope.t()) :: Subscription.t() | nil
  def get_status(%Scope{} = scope) do
    user_id = Accounts.scope_user_id(scope)

    Subscription
    |> Subscription.for_user(user_id)
    |> Repo.one()
  end

  def list_billing_customers(%Scope{} = scope) do
    Customer
    |> Customer.for_user(Accounts.scope_user_id(scope))
    |> Repo.all()
  end

  def get_customer!(%Scope{} = scope, id), do: scoped_customer_query(scope) |> Repo.get!(id)

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

  defp billing_client do
    Application.fetch_env!(:frontman_server, :billing_client)
  end
end
