defmodule FrontmanServer.BillingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FrontmanServer.Billing` context.
  """

  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.StripeEvent
  alias FrontmanServer.Repo
  alias FrontmanServer.Test.Fixtures.Accounts

  @doc """
  Generate a subscription for an existing user scope.
  """
  def subscription_for_scope_fixture(scope, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, customer} =
      Billing.create_customer(scope, %{
        stripe_customer_account_id: "acct_#{unique}",
        stripe_customer_id: "cus_#{unique}"
      })

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
  Ensures an existing user scope has a subscription fixture.
  """
  def ensure_subscription_for_scope_fixture(scope) do
    Billing.get_status(scope) || subscription_for_scope_fixture(scope)
  end

  @doc """
  Generate a customer.
  """
  def customer_fixture(attrs \\ %{}) do
    user = Accounts.user_fixture()
    scope = Accounts.user_scope_fixture(user)
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
  Generate a subscription.
  """
  def subscription_fixture(attrs \\ %{}) do
    customer = customer_fixture()
    user = Repo.preload(customer, :user).user
    scope = Accounts.user_scope_fixture(user)
    unique = System.unique_integer([:positive])

    {:ok, subscription} =
      attrs
      |> Enum.into(%{
        cancel_at: ~U[2026-05-06 19:32:00Z],
        canceled_at: ~U[2026-05-06 19:32:00Z],
        current_period_end: ~U[2026-05-06 19:32:00Z],
        interval: "some interval",
        price_id: "some price_id",
        status: "some status",
        stripe_customer_account_id: "acct_#{unique}",
        stripe_customer_id: "cus_#{unique}",
        stripe_subscription_id: "sub_#{unique}",
        trial_end: ~U[2026-05-06 19:32:00Z],
        billing_customer_id: customer.id
      })
      |> then(&Billing.create_subscription(scope, &1))

    subscription
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
