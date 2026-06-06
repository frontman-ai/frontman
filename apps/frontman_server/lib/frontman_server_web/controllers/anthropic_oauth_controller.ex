# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.AnthropicOAuthController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers

  @doc """
  Generates a PKCE challenge and returns the authorization URL.

  The client should store the verifier and pass it back when exchanging the code.
  """
  def authorize_url(conn, _params) do
    json(conn, Providers.start_anthropic_oauth())
  end

  @doc """
  Exchanges an authorization code for tokens and stores them.

  Expects:
  - code: The authorization code (may contain #state_part)
  - verifier: The PKCE verifier from authorize_url
  """
  def exchange(conn, %{"code" => code, "verifier" => verifier}) do
    scope = conn.assigns.current_scope

    case Providers.connect_anthropic_oauth(scope, code, verifier) do
      {:ok, expires_at} ->
        json(conn, %{
          status: "ok",
          expires_at: DateTime.to_iso8601(expires_at)
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", error: translate_errors(changeset)})

      {:error, {:token_exchange_failed, status, body}} ->
        error_message =
          extract_error_message(body) || "Token exchange failed with status #{status}"

        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", error: error_message})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", error: "Failed to exchange code: #{inspect(reason)}"})
    end
  end

  def exchange(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", error: "Missing required parameters: code, verifier"})
  end

  @doc """
  Disconnects the Anthropic OAuth connection by removing stored tokens.
  """
  def disconnect(conn, _params) do
    scope = conn.assigns.current_scope

    case Providers.delete_oauth_token(scope, "anthropic") do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :not_found} ->
        # Token didn't exist, but that's fine - user is disconnected either way
        json(conn, %{status: "ok"})
    end
  end

  @doc """
  Returns the current OAuth connection status.
  """
  def status(conn, _params) do
    json(conn, Providers.oauth_connection_status(conn.assigns.current_scope, "anthropic"))
  end

  # Private helpers

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end

  defp extract_error_message(%{"error" => %{"message" => message}}), do: message
  defp extract_error_message(%{"error_description" => desc}), do: desc
  defp extract_error_message(%{"error" => error}) when is_binary(error), do: error
  defp extract_error_message(_), do: nil
end
