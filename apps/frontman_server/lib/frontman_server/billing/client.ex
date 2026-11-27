# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Billing.Client do
  @moduledoc """
  Behaviour for billing provider API clients.
  """

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Billing.Customer

  @callback checkout_offers(trial_eligible: boolean()) ::
              {:ok, [FrontmanServer.Billing.checkout_offer()]} | {:error, term()}

  @optional_callbacks checkout_offers: 1

  @callback start_checkout(
              User.t(),
              Customer.t() | nil,
              FrontmanServer.Billing.interval(),
              %{success_url: String.t(), cancel_url: String.t()},
              trial_eligible: boolean()
            ) :: {:ok, map()} | {:error, term()}

  @callback create_customer_portal_url(Customer.t(), String.t()) ::
              {:ok, String.t()} | {:error, term()}

  @callback construct_webhook_event(binary(), String.t()) :: {:ok, map()} | {:error, term()}
end
