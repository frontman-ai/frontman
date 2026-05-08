# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.BillingController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Billing
  alias FrontmanServer.Billing.Subscription

  @checkout_intervals [:monthly, :yearly]
  @checkout_interval_params Enum.map(@checkout_intervals, &Atom.to_string/1)

  def create_checkout_session(conn, %{"interval" => interval}) do
    scope = conn.assigns.current_scope

    with {:ok, interval} <- parse_checkout_interval(interval),
         {:ok, %{"url" => url, "id" => session_id}} <-
           Billing.create_checkout_session(scope, interval, checkout_return_urls(conn)) do
      json(conn, %{id: session_id, url: url})
    else
      {:error, :invalid_interval} ->
        invalid_interval(conn)

      {:error, reason} ->
        checkout_error(conn, reason)
    end
  end

  def create_checkout_session(conn, _params) do
    invalid_interval(conn)
  end

  def status(conn, _params) do
    json(conn, status_response(Billing.get_status(conn.assigns.current_scope)))
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

  defp invalid_interval(conn) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "invalid_interval"})
  end

  defp checkout_error(conn, reason) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: "stripe_checkout_session_failed", reason: inspect(reason)})
  end

  defp parse_checkout_interval(interval) when interval in @checkout_interval_params do
    {:ok, String.to_existing_atom(interval)}
  end

  defp parse_checkout_interval(_interval), do: {:error, :invalid_interval}
end
