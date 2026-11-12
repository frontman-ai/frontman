# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.BillingJSON do
  @moduledoc false

  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.Subscription
  alias FrontmanServer.Tasks

  @subscription_fields ~w(interval current_period_end trial_end cancel_at canceled_at)a

  def status(scope) do
    subscription = Billing.get_current_subscription(scope)

    {can_start_turn, remaining} =
      case Subscription.allow_access?(subscription) do
        true ->
          {true, nil}

        false ->
          remaining = Tasks.remaining_runs(scope)
          {remaining > 0, remaining}
      end

    fields =
      Map.new(@subscription_fields, fn field ->
        {field, subscription && Map.fetch!(subscription, field)}
      end)

    Map.merge(fields, %{
      status: if(subscription, do: subscription.status, else: "none"),
      can_start_turn: can_start_turn,
      pretrial_runs_remaining: remaining,
      has_billing_customer: if(subscription, do: true, else: Billing.has_customer?(scope)),
      trial_eligible: Billing.trial_eligible?(scope),
      trial_days: Application.fetch_env!(:frontman_server, :stripe) |> Keyword.fetch!(:trial_days)
    })
  end
end
