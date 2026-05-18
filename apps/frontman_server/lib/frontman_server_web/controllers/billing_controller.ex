# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.BillingController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Billing

  def checkout_monthly(conn, _params) do
    stripe_launch(conn, ~p"/billing/checkout/monthly")
  end

  def create_monthly_checkout(conn, _params) do
    checkout_browser_redirect(conn, :monthly)
  end

  def checkout_yearly(conn, _params) do
    stripe_launch(conn, ~p"/billing/checkout/yearly")
  end

  def create_yearly_checkout(conn, _params) do
    checkout_browser_redirect(conn, :yearly)
  end

  def customer_portal(conn, _params) do
    stripe_launch(conn, ~p"/billing/customer-portal")
  end

  def create_customer_portal(conn, _params) do
    customer_portal_browser_redirect(conn)
  end

  def stripe_return_success(conn, _params) do
    stripe_return(conn, "Stripe checkout complete")
  end

  def stripe_return_cancel(conn, _params) do
    stripe_return(conn, "Stripe checkout closed")
  end

  def stripe_return_customer_portal(conn, _params) do
    stripe_return(conn, "Stripe billing portal closed")
  end

  defp checkout_return_urls do
    %{
      success_url: url(~p"/billing/stripe-return/success") <> "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: url(~p"/billing/stripe-return/cancel")
    }
  end

  defp customer_portal_return_url do
    url(~p"/billing/stripe-return/customer-portal")
  end

  defp stripe_launch(conn, action) do
    render(conn, :stripe_launch,
      page_title: "Opening Stripe",
      title: "Opening Stripe...",
      message: "This tab will continue to Stripe automatically.",
      action: action,
      submit_label: "Open Stripe"
    )
  end

  defp checkout_browser_redirect(conn, interval) do
    scope = conn.assigns.current_scope

    case Billing.start_checkout(scope, interval, checkout_return_urls()) do
      {:ok, %{"url" => url}} when is_binary(url) ->
        redirect(conn, external: url)

      {:error, reason} ->
        checkout_error(conn, reason)
    end
  end

  defp customer_portal_browser_redirect(conn) do
    scope = conn.assigns.current_scope

    case Billing.create_customer_portal_url(
           scope,
           customer_portal_return_url()
         ) do
      {:ok, url} when is_binary(url) ->
        redirect(conn, external: url)

      {:error, reason} ->
        customer_portal_url_error(conn, reason)
    end
  end

  defp stripe_return(conn, title) do
    render(conn, :stripe_return,
      page_title: title,
      title: title,
      message: "You can close this tab and return to Frontman."
    )
  end

  defp checkout_error(conn, reason) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: "stripe_checkout_session_failed", reason: inspect(reason)})
  end

  defp customer_portal_url_error(conn, :billing_customer_missing) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "billing_customer_missing"})
  end

  defp customer_portal_url_error(
         conn,
         {:customer_portal_url_failed, reason}
       ) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: "customer_portal_url_failed", reason: inspect(reason)})
  end
end
