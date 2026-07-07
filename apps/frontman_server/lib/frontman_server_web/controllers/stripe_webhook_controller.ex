# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.StripeWebhookController do
  use FrontmanServerWeb, :controller

  require Logger

  alias FrontmanServer.Billing.Webhooks

  def create(conn, _params) do
    raw_body = conn.assigns.raw_body
    signature = conn |> get_req_header("stripe-signature") |> List.first()

    with {:ok, event} <- billing_client().construct_webhook_event(raw_body, signature),
         {:ok, result} <- Webhooks.process_event(event) do
      json(conn, %{status: "ok", result: result})
    else
      {:error, reason} ->
        Logger.warning("stripe webhook rejected: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_stripe_webhook"})
    end
  end

  defp billing_client do
    Application.fetch_env!(:frontman_server, :billing_client)
  end
end
