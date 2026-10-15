# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.BillingController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Billing

  action_fallback FrontmanServerWeb.BillingFallbackController

  def status(conn, _params), do: json(conn, Billing.status(conn.assigns.current_scope))

  def checkout(conn, %{"interval" => "monthly"}), do: checkout_url(conn, :monthly)
  def checkout(conn, %{"interval" => "yearly"}), do: checkout_url(conn, :yearly)

  def checkout(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Choose a monthly or yearly interval."})
  end

  def customer_portal(conn, _params) do
    case Billing.create_customer_portal_url(
           conn.assigns.current_scope,
           url(~p"/billing/stripe-return/customer-portal")
         ) do
      {:ok, url} when is_binary(url) -> json(conn, %{url: url})
      {:error, reason} -> {:error, {:billing, :customer_portal, reason}}
    end
  end

  def stripe_return_success(conn, _params),
    do: stripe_return(conn, "Checkout complete. Back to your next improvement.")

  def stripe_return_cancel(conn, _params),
    do: stripe_return(conn, "Your request is still waiting for you.")

  def stripe_return_customer_portal(conn, _params),
    do: stripe_return(conn, "Return to your work in Frontman.")

  defp checkout_url(conn, interval) do
    return_urls = %{
      success_url: url(~p"/billing/stripe-return/success") <> "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: url(~p"/billing/stripe-return/cancel")
    }

    case Billing.start_checkout(conn.assigns.current_scope, interval, return_urls) do
      {:ok, %{"url" => url}} when is_binary(url) -> json(conn, %{url: url})
      {:error, reason} -> {:error, {:billing, :checkout, reason}}
    end
  end

  defp stripe_return(conn, title) do
    render(conn, :stripe_return,
      page_title: title,
      title: title,
      message: "Close this tab to continue in Frontman. No edits run automatically."
    )
  end
end
