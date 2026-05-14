# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Billing.StripeClient do
  @moduledoc """
  Req-backed Stripe client for Managed Payments Checkout.
  """

  @behaviour FrontmanServer.Billing.Client

  alias FrontmanServer.Billing.{Customer, StripeWebhookSignature}

  @impl true
  def start_checkout(user, customer, interval, return_urls, opts) do
    params = checkout_session_params(user, customer, interval, return_urls, opts)

    case Req.post(new(), url: "/checkout/sessions", form: params) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:stripe_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def construct_webhook_event(raw_body, signature_header) do
    with :ok <-
           StripeWebhookSignature.verify(
             raw_body,
             signature_header,
             stripe_config!(:webhook_secret),
             stripe_config!(:signature_tolerance_seconds)
           ) do
      Jason.decode(raw_body)
    end
  end

  defp new do
    Req.new(
      base_url: stripe_config!(:api_base_url),
      auth: {:bearer, stripe_config!(:secret_key)},
      headers:
        [
          {"stripe-version", stripe_config!(:api_version)}
        ] ++ extra_headers()
    )
  end

  defp extra_headers do
    case stripe_config(:extra_headers, []) do
      {module, function, args} -> apply(module, function, args)
      headers -> headers
    end
  end

  defp checkout_session_params(user, customer, interval, return_urls, opts) do
    base_params = [
      {"mode", "subscription"},
      {"line_items[0][price]", stripe_config!(price_id_key(interval))},
      {"line_items[0][quantity]", "1"},
      {"managed_payments[enabled]", "true"},
      {"success_url", Map.fetch!(return_urls, :success_url)},
      {"cancel_url", Map.fetch!(return_urls, :cancel_url)},
      {"client_reference_id", user.id},
      {"customer_email", user.email},
      {"subscription_data[metadata][user_id]", user.id},
      {"subscription_data[metadata][interval]", Atom.to_string(interval)},
      {"metadata[user_id]", user.id},
      {"metadata[interval]", Atom.to_string(interval)}
    ]

    customer_params(customer) ++ trial_params(opts) ++ base_params
  end

  defp trial_params(opts) do
    case Keyword.fetch!(opts, :trial_eligible) do
      true ->
        [{"subscription_data[trial_period_days]", Integer.to_string(stripe_config!(:trial_days))}]

      false ->
        []
    end
  end

  defp customer_params(%Customer{stripe_customer_id: customer_id}) when is_binary(customer_id) do
    [{"customer", customer_id}]
  end

  defp customer_params(_customer), do: []

  defp price_id_key(:monthly), do: :monthly_price_id
  defp price_id_key(:yearly), do: :yearly_price_id

  defp stripe_config!(key) do
    Application.fetch_env!(:frontman_server, :stripe)
    |> Keyword.fetch!(key)
  end

  defp stripe_config(key, default) do
    Application.fetch_env!(:frontman_server, :stripe)
    |> Keyword.get(key, default)
  end
end
