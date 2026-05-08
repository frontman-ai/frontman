# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.BillingController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.Subscription

  def checkout(conn, %{"interval" => "monthly"}) do
    checkout_with_interval(conn, :monthly)
  end

  def checkout(conn, %{"interval" => "yearly"}) do
    checkout_with_interval(conn, :yearly)
  end

  defp checkout_with_interval(conn, interval) do
    scope = conn.assigns.current_scope

    case Billing.start_checkout(scope, interval, checkout_return_urls(conn)) do
      {:ok, %{"url" => url, "id" => session_id}} ->
        json(conn, %{id: session_id, url: url})

      {:error, reason} ->
        checkout_error(conn, reason)
    end
  end

  def status(conn, _params) do
    scope = conn.assigns.current_scope
    subscription = Billing.get_current_subscription(scope)

    response =
      subscription
      |> status_response()
      |> Map.put(:allow_access, Subscription.allow_access?(subscription))

    json(conn, response)
  end

  defp status_response(%Subscription{} = subscription) do
    %{
      status: subscription.status,
      interval: subscription.interval,
      price_id: subscription.price_id,
      current_period_end: subscription.current_period_end,
      trial_end: subscription.trial_end,
      cancel_at: subscription.cancel_at,
      canceled_at: subscription.canceled_at
    }
  end

  defp status_response(nil) do
    %{
      status: "none",
      interval: nil,
      price_id: nil,
      current_period_end: nil,
      trial_end: nil,
      cancel_at: nil,
      canceled_at: nil
    }
  end

  defp checkout_return_urls(conn) do
    origin = request_origin(conn)

    %{
      success_url: origin <> ~p"/billing/success" <> "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: origin <> ~p"/billing/cancel"
    }
  end

  defp request_origin(conn) do
    uri = conn |> Phoenix.Controller.current_url() |> URI.parse()

    case uri.port do
      nil -> "#{uri.scheme}://#{uri.host}"
      80 when uri.scheme == "http" -> "#{uri.scheme}://#{uri.host}"
      443 when uri.scheme == "https" -> "#{uri.scheme}://#{uri.host}"
      port -> "#{uri.scheme}://#{uri.host}:#{port}"
    end
  end

  defp checkout_error(conn, reason) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: "stripe_checkout_session_failed", reason: inspect(reason)})
  end
end
