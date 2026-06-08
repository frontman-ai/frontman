# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.OpenAIOAuthController do
  @moduledoc """
  Handles the OpenAI OAuth flow using the Device Auth flow.

  Flow:
  1. Client calls `POST /api/oauth/openai/initiate`
     → Server requests a device code from OpenAI,
       returns device_auth_id + user_code + verification_url to the client
  2. Client shows the user_code and opens the verification URL
  3. User enters the code at auth.openai.com/codex/device
  4. Client polls `POST /api/oauth/openai/poll` with device_auth_id + user_code
     → Server polls OpenAI on each request. When authorized, exchanges code for tokens,
       extracts chatgpt_account_id from JWT, stores tokens, returns success
  5. Client can also check `GET /api/oauth/openai/status` for connection state

  The flow is fully stateless on the server — the client holds the device_auth_id
  and user_code and passes them back on each poll request.

  The device auth flow is required because the OpenAI public client_id
  (app_EMoamEEZ73f0CkXaXp7hrann) only allows http://localhost:* redirect URIs.
  """

  use FrontmanServerWeb, :controller

  require Logger

  alias FrontmanServer.Providers

  @doc """
  Initiates the device auth flow by requesting a device code from OpenAI.

  Returns the device_auth_id, user_code, and verification_url for the client
  to store and display. The client must pass device_auth_id and user_code back
  when polling.

  POST /api/oauth/openai/initiate
  """
  def initiate(conn, _params) do
    case Providers.start_openai_oauth() do
      {:ok, device_auth} ->
        json(conn, device_auth)

      {:error, :device_auth_not_enabled} ->
        conn
        |> put_status(503)
        |> json(%{error: "Device auth is not currently available. Please try again later."})

      {:error, reason} ->
        Logger.error("OpenAI device code request failed: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{error: "Failed to initiate authentication. Please try again."})
    end
  end

  @doc """
  Polls OpenAI to check if the user has completed authorization.

  The client passes the device_auth_id and user_code received from initiate.
  On each call, the server polls OpenAI's device token endpoint.
  If authorized, exchanges the code for tokens and stores them.

  POST /api/oauth/openai/poll
  Expects: {"device_auth_id": "...", "user_code": "..."}
  """
  def poll(conn, %{"device_auth_id" => device_auth_id, "user_code" => user_code})
      when is_binary(device_auth_id) and is_binary(user_code) do
    case Providers.poll_openai_oauth(conn.assigns.current_scope, device_auth_id, user_code) do
      {:connected, expires_at} ->
        json(conn, %{
          status: "connected",
          expires_at: DateTime.to_iso8601(expires_at)
        })

      {:pending} ->
        json(conn, %{status: "pending"})

      {:error, :authorization_declined} ->
        conn
        |> put_status(403)
        |> json(%{status: "declined", error: "Authorization was declined."})

      {:exchange_error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to store OpenAI OAuth token: #{inspect(changeset)}")

        conn
        |> put_status(500)
        |> json(%{status: "error", error: "Failed to save tokens. Please try again."})

      {:exchange_error, reason} ->
        Logger.error("OpenAI device code exchange failed: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{status: "error", error: "Failed to exchange authorization code."})

      {:error, reason} ->
        Logger.error("OpenAI device poll error: #{inspect(reason)}")
        json(conn, %{status: "pending"})
    end
  end

  def poll(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required parameters: device_auth_id, user_code"})
  end

  @doc """
  Disconnects the OpenAI OAuth connection by removing stored tokens.

  DELETE /api/oauth/openai/disconnect
  """
  def disconnect(conn, _params) do
    scope = conn.assigns.current_scope

    case Providers.delete_oauth_token(scope, "openai_codex") do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :not_found} ->
        # Token didn't exist, but that's fine - user is disconnected either way
        json(conn, %{status: "ok"})
    end
  end

  @doc """
  Returns the current OpenAI OAuth connection status.

  GET /api/oauth/openai/status
  """
  def status(conn, _params) do
    json(conn, Providers.oauth_connection_status(conn.assigns.current_scope, "openai_codex"))
  end
end
