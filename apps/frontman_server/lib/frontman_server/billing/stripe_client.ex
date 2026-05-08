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
  def create_checkout_session(user, customer, interval, return_urls) do
    params = checkout_session_params(user, customer, interval, return_urls)

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
             webhook_secret!(),
             signature_tolerance_seconds!()
           ) do
      Jason.decode(raw_body)
    end
  end

  defp new do
    Req.new(
      base_url: stripe_api_base_url(),
      auth: {:bearer, secret_key!()},
      headers: [
        {"stripe-version", api_version!()}
      ]
    )
  end

  defp checkout_session_params(user, customer, interval, return_urls) do
    base_params = [
      {"mode", "subscription"},
      {"line_items[0][price]", price_id!(interval)},
      {"line_items[0][quantity]", "1"},
      {"managed_payments[enabled]", "true"},
      {"success_url", Map.fetch!(return_urls, :success_url)},
      {"cancel_url", Map.fetch!(return_urls, :cancel_url)},
      {"client_reference_id", user.id},
      {"customer_email", user.email},
      {"subscription_data[trial_period_days]", Integer.to_string(trial_days!())},
      {"subscription_data[metadata][user_id]", user.id},
      {"subscription_data[metadata][interval]", Atom.to_string(interval)},
      {"metadata[user_id]", user.id},
      {"metadata[interval]", Atom.to_string(interval)}
    ]

    customer_params(customer) ++ base_params
  end

  defp customer_params(%Customer{stripe_customer_account_id: customer_account_id})
       when is_binary(customer_account_id) do
    [{"customer_account", customer_account_id}]
  end

  defp customer_params(%Customer{stripe_customer_id: customer_id}) when is_binary(customer_id) do
    [{"customer", customer_id}]
  end

  defp customer_params(_customer), do: []

  defp stripe_api_base_url do
    stripe_config()
    |> Keyword.fetch!(:api_base_url)
    |> URI.merge("/v1")
    |> URI.to_string()
  end

  defp secret_key!, do: fetch_stripe_string_config!(:secret_key)
  defp webhook_secret!, do: fetch_stripe_string_config!(:webhook_secret)
  defp api_version!, do: fetch_stripe_string_config!(:api_version)

  defp signature_tolerance_seconds!,
    do: fetch_stripe_integer_config!(:signature_tolerance_seconds)

  defp price_id!(:monthly), do: fetch_stripe_string_config!(:monthly_price_id)
  defp price_id!(:yearly), do: fetch_stripe_string_config!(:yearly_price_id)

  defp trial_days!, do: fetch_stripe_integer_config!(:trial_days)

  defp stripe_config do
    Application.fetch_env!(:frontman_server, :stripe)
  end

  defp fetch_stripe_config!(key) do
    value = Keyword.fetch!(stripe_config(), key)

    case value do
      nil -> raise "missing Stripe config: #{key}"
      "" -> raise "missing Stripe config: #{key}"
      value -> value
    end
  end

  defp fetch_stripe_string_config!(key) do
    value = fetch_stripe_config!(key)

    case value do
      value when is_binary(value) -> value
      _value -> raise "Stripe config must be a string: #{key}"
    end
  end

  defp fetch_stripe_integer_config!(key) do
    value = fetch_stripe_config!(key)

    case value do
      value when is_integer(value) -> value
      _value -> raise "Stripe config must be an integer: #{key}"
    end
  end
end
