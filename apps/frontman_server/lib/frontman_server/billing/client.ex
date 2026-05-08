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

  @callback create_checkout_session(
              User.t(),
              Customer.t() | nil,
              FrontmanServer.Billing.interval(),
              %{success_url: String.t(), cancel_url: String.t()}
            ) :: {:ok, map()} | {:error, term()}

  @callback construct_webhook_event(binary(), String.t()) :: {:ok, map()} | {:error, term()}
end
