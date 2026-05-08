defmodule FrontmanServer.BillingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FrontmanServer.Billing` context.
  """

  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.{StripeEvent, Subscription}
  alias FrontmanServer.Repo
  alias FrontmanServer.Test.Fixtures.Accounts

  @doc """
  Generate a billing customer for an existing user scope.
  """
  def customer_for_scope_fixture(scope, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, customer} =
      attrs
      |> Enum.into(%{
        stripe_customer_account_id: "acct_#{unique}",
        stripe_customer_id: "cus_#{unique}"
      })
      |> then(&Billing.create_customer(scope, &1))

    customer
  end

  @doc """
  Generate a subscription for an existing billing customer.
  """
  def subscription_for_customer_fixture(scope, customer, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, subscription} =
      attrs
      |> Enum.into(%{
        billing_customer_id: customer.id,
        stripe_customer_account_id: customer.stripe_customer_account_id,
        stripe_customer_id: customer.stripe_customer_id,
        stripe_subscription_id: "sub_#{unique}",
        status: "active",
        interval: :monthly,
        price_id: "price_monthly_test"
      })
      |> then(&Billing.create_subscription(scope, &1))

    subscription
  end

  @doc """
  Generate a subscription for an existing user scope.
  """
  def subscription_for_scope_fixture(scope, attrs \\ %{}) do
    customer = customer_for_scope_fixture(scope)
    subscription_for_customer_fixture(scope, customer, attrs)
  end

  @doc """
  Generate a user scope with no subscription.
  """
  def scope_requiring_billing_fixture do
    Accounts.user_scope_fixture()
  end

  @doc """
  Generate a user scope with a subscription status.
  """
  def scope_with_subscription_fixture(status, attrs \\ %{}) do
    scope = Accounts.user_scope_fixture()
    subscription_for_scope_fixture(scope, attrs |> Enum.into(%{}) |> Map.put(:status, status))
    scope
  end

  @doc """
  Generate a user scope with billing access allowed.
  """
  def scope_with_allowed_access_fixture(attrs \\ %{}) do
    scope_with_subscription_fixture("active", attrs)
  end

  @doc """
  Generate a user scope with billing access blocked by an existing subscription.
  """
  def scope_with_blocked_access_fixture(attrs \\ %{}) do
    scope_with_subscription_fixture("canceled", attrs)
  end

  @doc """
  Create an allowed-access subscription for an existing user scope.
  """
  def allow_access_for_scope_fixture(scope, attrs \\ %{}) do
    case Billing.get_current_subscription(scope) do
      nil ->
        subscription_for_scope_fixture(
          scope,
          attrs |> Enum.into(%{}) |> Map.put(:status, "active")
        )

      %Subscription{} = subscription ->
        if Subscription.allow_access?(subscription) do
          subscription
        else
          raise "scope already has a subscription that does not allow access"
        end
    end
  end

  @doc """
  Create a blocked-access subscription for an existing user scope.
  """
  def block_access_for_scope_fixture(scope, attrs \\ %{}) do
    subscription_for_scope_fixture(scope, attrs |> Enum.into(%{}) |> Map.put(:status, "canceled"))
  end

  @doc """
  Generate a customer.
  """
  def customer_fixture(attrs \\ %{}) do
    user = Accounts.user_fixture()
    scope = Accounts.user_scope_fixture(user)
    customer_for_scope_fixture(scope, attrs)
  end

  @doc """
  Generate a subscription.
  """
  def subscription_fixture(attrs \\ %{}) do
    customer = customer_fixture()
    user = Repo.preload(customer, :user).user
    scope = Accounts.user_scope_fixture(user)
    subscription_for_customer_fixture(scope, customer, attrs)
  end

  @doc """
  Generate a stripe_event.
  """
  def stripe_event_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, stripe_event} =
      attrs
      |> Enum.into(%{
        payload: %{},
        processed_at: ~U[2026-05-06 19:32:00Z],
        stripe_event_id: "evt_#{unique}",
        type: "some type"
      })
      |> then(&StripeEvent.changeset(%StripeEvent{}, &1))
      |> Repo.insert()

    stripe_event
  end
end
