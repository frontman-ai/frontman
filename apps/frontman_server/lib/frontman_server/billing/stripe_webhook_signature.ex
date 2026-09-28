# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Billing.StripeWebhookSignature do
  @moduledoc """
  Verifies Stripe webhook signatures.
  """

  @schema "v1"

  def verify(payload, signature_header, secret, tolerance_seconds)
      when is_binary(signature_header) do
    with {:ok, timestamp, signatures} <- parse(signature_header),
         :ok <- verify_timestamp(timestamp, tolerance_seconds) do
      verify_signature(payload, timestamp, signatures, secret)
    end
  end

  def verify(_payload, _signature_header, _secret, _tolerance_seconds),
    do: {:error, :missing_signature_header}

  def sign(payload, timestamp, secret) do
    "t=#{timestamp},#{@schema}=#{hash(timestamp, payload, secret)}"
  end

  defp parse(signature_header) do
    parts =
      signature_header
      |> String.split(",", trim: true)
      |> Enum.map(fn part -> String.split(part, "=", parts: 2) end)

    timestamp =
      Enum.find_value(parts, fn
        ["t", timestamp] -> timestamp
        _part -> nil
      end)

    signatures =
      for [@schema, signature] <- parts do
        signature
      end

    with timestamp when is_binary(timestamp) <- timestamp,
         [_signature | _signatures] <- signatures,
         {timestamp, ""} <- Integer.parse(timestamp) do
      {:ok, timestamp, signatures}
    else
      _ -> {:error, :invalid_signature_header}
    end
  end

  defp verify_timestamp(timestamp, tolerance_seconds) do
    now = System.system_time(:second)

    if abs(now - timestamp) <= tolerance_seconds do
      :ok
    else
      {:error, :stale_signature}
    end
  end

  defp verify_signature(payload, timestamp, signatures, secret) do
    expected = hash(timestamp, payload, secret)

    if Enum.any?(signatures, &signature_matches?(expected, &1)) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp signature_matches?(expected, signature) do
    byte_size(expected) == byte_size(signature) and
      Plug.Crypto.secure_compare(expected, signature)
  end

  defp hash(timestamp, payload, secret) do
    :crypto.mac(:hmac, :sha256, secret, ["#{timestamp}.", payload])
    |> Base.encode16(case: :lower)
  end
end
