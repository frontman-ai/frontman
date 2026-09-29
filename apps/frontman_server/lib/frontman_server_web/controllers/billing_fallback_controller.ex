# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.BillingFallbackController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Accounts.Scope
  alias Plug.Conn.Status

  def call(conn, {:error, {:billing, :checkout, :subscription_already_active}}) do
    render_error(conn, :conflict, "You already have an active subscription.")
  end

  def call(conn, {:error, {:billing, :customer_portal, :billing_customer_missing}}) do
    render_error(conn, :unprocessable_entity, "There is no billing account to manage yet.")
  end

  def call(conn, {:error, {:billing, operation, reason}})
      when operation in [:checkout, :customer_portal] do
    event = %{
      Sentry.Event.create_event(message: "Billing request failed", level: :error)
      | request: nil,
        user: %{id: Scope.user_id(conn.assigns.current_scope)},
        tags: %{error_type: "billing_failure", billing_operation: operation},
        extra: Map.put(error_details(reason), :request_id, request_id(conn)),
        fingerprint: ["billing_failure", to_string(operation)],
        breadcrumbs: [],
        attachments: []
    }

    Sentry.send_event(event)

    render_error(
      conn,
      :bad_gateway,
      "We could not open Stripe. Please try again later or contact support."
    )
  end

  defp render_error(conn, status, message) do
    conn
    |> put_status(status)
    |> put_view(html: FrontmanServerWeb.ErrorHTML, json: FrontmanServerWeb.ErrorJSON)
    |> render("#{Status.code(status)}.#{get_format(conn)}",
      message: message,
      request_id: request_id(conn)
    )
  end

  defp request_id(conn), do: conn |> get_resp_header("x-request-id") |> List.first()

  defp error_details({:customer_portal_url_failed, reason}), do: error_details(reason)

  defp error_details({:stripe_error, status, body, request_ids}) when is_integer(status) do
    %{
      upstream_status: status,
      stripe_code: stripe_code(body),
      stripe_request_id: stripe_request_id(request_ids)
    }
  end

  defp error_details(%Req.TransportError{reason: :timeout}), do: %{failure: "timeout"}
  defp error_details(%Req.TransportError{}), do: %{failure: "transport_error"}
  defp error_details(_reason), do: %{failure: "unexpected_provider_error"}

  defp stripe_code(%{"error" => %{"code" => code}})
       when code in [
              "api_key_expired",
              "rate_limit",
              "resource_missing",
              "parameter_invalid_integer",
              "parameter_missing"
            ] do
    code
  end

  defp stripe_code(_body), do: nil

  defp stripe_request_id([request_id]) when is_binary(request_id) do
    case Regex.match?(~r/\Areq_[a-zA-Z0-9]{1,64}\z/, request_id) do
      true -> request_id
      false -> nil
    end
  end

  defp stripe_request_id(_request_ids), do: nil
end
