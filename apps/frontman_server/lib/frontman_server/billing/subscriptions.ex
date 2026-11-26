# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Billing.Subscriptions do
  @moduledoc "Scoped subscription lifecycle and access operations."

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.{Customer, Subscription}
  alias FrontmanServer.Repo

  def current(%Scope{} = scope) do
    scope |> Scope.user_id() |> Subscription.for_user() |> Repo.one()
  end

  def access(%Scope{} = scope) do
    case current(scope) do
      %Subscription{status: status} = subscription ->
        if Subscription.allow_access?(subscription),
          do: {:allowed, status},
          else: {:inactive, status}

      nil ->
        :none
    end
  end

  def trial_eligible?(%Scope{} = scope) do
    scope
    |> Scope.user_id()
    |> Subscription.for_user()
    |> Subscription.with_consumed_trial()
    |> Repo.exists?()
    |> Kernel.not()
  end

  def start_checkout(%Scope{} = scope, interval, return_urls) when is_map(return_urls) do
    case current(scope) do
      %Subscription{status: status} when status in ["trialing", "active", "past_due"] ->
        {:error, :subscription_already_active}

      _subscription ->
        Billing.start_checkout(scope, interval, return_urls,
          trial_eligible: trial_eligible?(scope)
        )
    end
  end

  def upsert_subscription(%Scope{} = scope, %Customer{id: id, user_id: user_id}, attrs) do
    ^user_id = Scope.user_id(scope)

    %Subscription{billing_customer_id: id}
    |> Subscription.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: attrs |> Map.to_list() |> Keyword.put(:updated_at, DateTime.utc_now(:second))
      ],
      conflict_target: :billing_customer_id,
      returning: true
    )
  end
end
