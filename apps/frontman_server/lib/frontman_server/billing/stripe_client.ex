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
  def checkout_offers(opts) do
    trial_days =
      case Keyword.fetch!(opts, :trial_eligible) do
        true -> stripe_config!(:trial_days)
        false -> 0
      end

    with {:ok, monthly} <- checkout_offer(:monthly, "month", trial_days),
         {:ok, yearly} <- checkout_offer(:yearly, "year", trial_days) do
      {:ok, [monthly, yearly]}
    end
  end

  @impl true
  def start_checkout(user, customer, interval, return_urls, opts) do
    params = checkout_session_params(user, customer, interval, return_urls, opts)

    case Req.post(new(), url: "/checkout/sessions", form: params) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body} = response} ->
        {:error, {:stripe_error, status, body, Req.Response.get_header(response, "request-id")}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def create_customer_portal_url(
        %Customer{stripe_customer_id: customer_id},
        return_url
      )
      when is_binary(customer_id) and is_binary(return_url) do
    params = [
      {"customer", customer_id},
      {"return_url", return_url}
    ]

    case Req.post(new(), url: "/billing_portal/sessions", form: params) do
      {:ok, %{status: status, body: %{"url" => url}}} when status in 200..299 ->
        {:ok, url}

      {:ok, %Req.Response{status: status, body: body} = response} ->
        {:error, {:stripe_error, status, body, Req.Response.get_header(response, "request-id")}}

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

  defp checkout_offer(interval, period, trial_days)
       when is_integer(trial_days) and trial_days >= 0 do
    price_id = stripe_config!(price_id_key(interval))

    case Req.get(new(),
           url: "/prices/#{URI.encode_www_form(price_id)}",
           receive_timeout: 5_000,
           retry: false
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        with {:ok, label} <- price_label(body, period) do
          {:ok, %{interval: interval, label: label, trial_days: trial_days}}
        end

      {:ok, %Req.Response{status: status, body: body} = response} ->
        {:error, {:stripe_error, status, body, Req.Response.get_header(response, "request-id")}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp price_label(
         %{
           "active" => true,
           "billing_scheme" => "per_unit",
           "unit_amount" => amount,
           "currency" => currency,
           "recurring" => %{
             "interval" => period,
             "interval_count" => 1,
             "usage_type" => "licensed"
           }
         } = price,
         period
       )
       when is_integer(amount) and amount >= 0 and is_binary(currency) do
    with nil <- Map.get(price, "transform_quantity"),
         {:ok, digits} <- currency_digits(currency) do
      divisor = Integer.pow(10, digits)
      whole = Integer.to_string(div(amount, divisor))
      fraction = amount |> rem(divisor) |> Integer.to_string() |> String.pad_leading(digits, "0")
      formatted = if digits == 0, do: whole, else: whole <> "." <> fraction
      {:ok, "#{String.upcase(currency)} #{formatted} / #{period}"}
    else
      {:error, reason} -> {:error, reason}
      _transform -> {:error, :unsupported_checkout_price}
    end
  end

  defp price_label(_price, _period), do: {:error, :unsupported_checkout_price}

  # Explicit supported currencies avoid guessing minor units for unfamiliar currencies.
  defp currency_digits(currency)
       when currency in ~w(usd eur gbp cad aud nzd chf sek nok dkk pln czk inr brl mxn sgd hkd),
       do: {:ok, 2}

  defp currency_digits(currency)
       when currency in ~w(bif clp djf gnf jpy kmf krw mga pyg rwf ugx vnd vuv xaf xof xpf),
       do: {:ok, 0}

  defp currency_digits(currency) when currency in ~w(bhd jod kwd omr tnd), do: {:ok, 3}
  defp currency_digits(_currency), do: {:error, :unsupported_checkout_currency}

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
      {"payment_method_collection", "always"},
      {"line_items[0][price]", stripe_config!(price_id_key(interval))},
      {"line_items[0][quantity]", "1"},
      {"managed_payments[enabled]", "true"},
      {"success_url", Map.fetch!(return_urls, :success_url)},
      {"cancel_url", Map.fetch!(return_urls, :cancel_url)},
      {"client_reference_id", user.id},
      {"subscription_data[metadata][user_id]", user.id},
      {"subscription_data[metadata][interval]", Atom.to_string(interval)},
      {"metadata[user_id]", user.id},
      {"metadata[interval]", Atom.to_string(interval)}
    ]

    customer_params(customer, user) ++ trial_params(opts) ++ base_params
  end

  defp trial_params(opts) do
    case Keyword.fetch!(opts, :trial_eligible) do
      true ->
        [{"subscription_data[trial_period_days]", Integer.to_string(stripe_config!(:trial_days))}]

      false ->
        []
    end
  end

  defp customer_params(%Customer{stripe_customer_id: customer_id}, _user)
       when is_binary(customer_id) do
    [{"customer", customer_id}]
  end

  defp customer_params(nil, user), do: [{"customer_email", user.email}]

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
