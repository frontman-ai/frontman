defmodule FrontmanServerWeb.ChatGPTOAuthController do
  @moduledoc """
  Handles the ChatGPT Pro/Plus OAuth flow using the Device Auth flow.

  Flow:
  1. Client calls `POST /api/oauth/chatgpt/initiate`
     → Server requests a device code from OpenAI,
       returns device_auth_id + user_code + verification_url to the client
  2. Client shows the user_code and opens the verification URL
  3. User enters the code at auth.openai.com/codex/device
  4. Client polls `POST /api/oauth/chatgpt/poll` with device_auth_id + user_code
     → Server polls OpenAI on each request. When authorized, exchanges code for tokens,
       extracts chatgpt_account_id from JWT, stores tokens, returns success
  5. Client can also check `GET /api/oauth/chatgpt/status` for connection state

  The flow is fully stateless on the server — the client holds the device_auth_id
  and user_code and passes them back on each poll request.

  The device auth flow is required because the OpenAI public client_id
  (app_EMoamEEZ73f0CkXaXp7hrann) only allows http://localhost:* redirect URIs.
  """

  use FrontmanServerWeb, :controller

  require Logger

  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.{ChatGPTOAuth, OAuthToken}

  @doc """
  Initiates the device auth flow by requesting a device code from OpenAI.

  Returns the device_auth_id, user_code, and verification_url for the client
  to store and display. The client must pass device_auth_id and user_code back
  when polling.

  POST /api/oauth/chatgpt/initiate
  """
  def initiate(conn, _params) do
    case ChatGPTOAuth.request_device_code() do
      {:ok, %{device_auth_id: device_auth_id, user_code: user_code, interval: _interval}} ->
        json(conn, %{
          device_auth_id: device_auth_id,
          user_code: user_code,
          verification_url: ChatGPTOAuth.verification_url()
        })

      {:error, :device_auth_not_enabled} ->
        conn
        |> put_status(503)
        |> json(%{error: "Device auth is not currently available. Please try again later."})

      {:error, reason} ->
        Logger.error("ChatGPT device code request failed: #{inspect(reason)}")

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

  POST /api/oauth/chatgpt/poll
  Expects: {"device_auth_id": "...", "user_code": "..."}
  """
  def poll(conn, %{"device_auth_id" => device_auth_id, "user_code" => user_code})
      when is_binary(device_auth_id) and is_binary(user_code) do
    case ChatGPTOAuth.poll_device_token(device_auth_id, user_code) do
      {:ok, %{authorization_code: auth_code, code_verifier: code_verifier}} ->
        handle_device_exchange(conn, auth_code, code_verifier)

      {:pending} ->
        json(conn, %{status: "pending"})

      {:error, :authorization_declined} ->
        conn
        |> put_status(403)
        |> json(%{status: "declined", error: "Authorization was declined."})

      {:error, reason} ->
        Logger.error("ChatGPT device poll error: #{inspect(reason)}")
        json(conn, %{status: "pending"})
    end
  end

  def poll(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required parameters: device_auth_id, user_code"})
  end

  @doc """
  Disconnects the ChatGPT OAuth connection by removing stored tokens.

  DELETE /api/oauth/chatgpt/disconnect
  """
  def disconnect(conn, _params) do
    scope = conn.assigns.current_scope

    case Providers.delete_oauth_token(scope, "chatgpt") do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :not_found} ->
        # Token didn't exist, but that's fine - user is disconnected either way
        json(conn, %{status: "ok"})
    end
  end

  @doc """
  Returns the current ChatGPT OAuth connection status.

  GET /api/oauth/chatgpt/status
  """
  def status(conn, _params) do
    scope = conn.assigns.current_scope

    case Providers.get_oauth_token(scope, "chatgpt") do
      nil ->
        json(conn, %{connected: false})

      token ->
        json(conn, %{
          connected: true,
          expires_at: DateTime.to_iso8601(token.expires_at),
          expired: OAuthToken.expired?(token)
        })
    end
  end

  # Private helpers

  defp handle_device_exchange(conn, authorization_code, code_verifier) do
    scope = conn.assigns.current_scope

    case ChatGPTOAuth.exchange_device_code(authorization_code, code_verifier) do
      {:ok, tokens} ->
        # Extract account_id from JWT tokens
        account_id = ChatGPTOAuth.extract_account_id_from_tokens(tokens)

        # Calculate expiry (default to 1 hour if not provided)
        expires_in = tokens.expires_in || 3600
        expires_at = OAuthToken.calculate_expires_at(expires_in)

        metadata = if account_id, do: %{"account_id" => account_id}, else: %{}

        case Providers.upsert_oauth_token(
               scope,
               "chatgpt",
               tokens.access_token,
               tokens.refresh_token,
               expires_at,
               metadata
             ) do
          {:ok, _token} ->
            json(conn, %{
              status: "connected",
              expires_at: DateTime.to_iso8601(expires_at)
            })

          {:error, changeset} ->
            Logger.error("Failed to store ChatGPT OAuth token: #{inspect(changeset)}")

            conn
            |> put_status(500)
            |> json(%{status: "error", error: "Failed to save tokens. Please try again."})
        end

      {:error, reason} ->
        Logger.error("ChatGPT device code exchange failed: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{status: "error", error: "Failed to exchange authorization code."})
    end
  end
end
