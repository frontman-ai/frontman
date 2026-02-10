defmodule FrontmanServerWeb.ChatGPTOAuthController do
  @moduledoc """
  Handles the ChatGPT Pro/Plus OAuth flow using the Device Auth flow.

  Flow:
  1. Client calls `POST /api/oauth/chatgpt/initiate`
     → Server requests a device code from OpenAI, stores device_auth_id in ETS,
       returns user_code + verification_url to the client
  2. Client shows the user_code and opens the verification URL
  3. User enters the code at auth.openai.com/codex/device
  4. Client polls `POST /api/oauth/chatgpt/poll`
     → Server polls OpenAI on each request. When authorized, exchanges code for tokens,
       extracts chatgpt_account_id from JWT, stores tokens, returns success
  5. Client can also check `GET /api/oauth/chatgpt/status` for connection state

  The device auth flow is required because the OpenAI public client_id
  (app_EMoamEEZ73f0CkXaXp7hrann) only allows http://localhost:* redirect URIs.
  """

  use FrontmanServerWeb, :controller

  require Logger

  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.{ChatGPTOAuth, OAuthHelpers, OAuthToken}

  # ETS table for device auth state storage
  # Key: user_id → {device_auth_id, user_code, expires_at}
  @ets_table :chatgpt_oauth_state
  # 15 minute TTL for device auth sessions (matches OpenAI's device code expiry)
  @state_ttl_seconds 900

  @doc """
  Ensures the ETS table for device auth state storage exists.
  Called from Application startup.
  """
  def ensure_ets_table do
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [:named_table, :public, :set])

      _ref ->
        @ets_table
    end
  end

  @doc """
  Initiates the device auth flow by requesting a device code from OpenAI.

  Returns the user_code and verification_url for the client to display.
  The device_auth_id is stored server-side in ETS keyed by user_id.

  POST /api/oauth/chatgpt/initiate
  """
  def initiate(conn, _params) do
    scope = conn.assigns.current_scope
    user_id = scope.user.id

    case ChatGPTOAuth.request_device_code() do
      {:ok, %{device_auth_id: device_auth_id, user_code: user_code, interval: _interval}} ->
        # Store device auth session in ETS keyed by user_id
        expires_at = System.monotonic_time(:second) + @state_ttl_seconds
        ensure_ets_table()
        :ets.insert(@ets_table, {user_id, device_auth_id, user_code, expires_at})

        # Clean up expired entries opportunistically
        cleanup_expired_entries()

        json(conn, %{
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

  This is called by the client at regular intervals. On each call, the server
  polls OpenAI's device token endpoint. If authorized, exchanges the code for
  tokens and stores them.

  POST /api/oauth/chatgpt/poll
  """
  def poll(conn, _params) do
    scope = conn.assigns.current_scope
    user_id = scope.user.id

    ensure_ets_table()

    case :ets.lookup(@ets_table, user_id) do
      [{^user_id, device_auth_id, user_code, expires_at}] ->
        if System.monotonic_time(:second) > expires_at do
          :ets.delete(@ets_table, user_id)
          conn |> put_status(410) |> json(%{status: "expired"})
        else
          handle_poll(conn, user_id, device_auth_id, user_code)
        end

      [] ->
        conn |> put_status(404) |> json(%{status: "no_session"})
    end
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

  defp handle_poll(conn, user_id, device_auth_id, user_code) do
    case ChatGPTOAuth.poll_device_token(device_auth_id, user_code) do
      {:ok, %{authorization_code: auth_code, code_verifier: code_verifier}} ->
        # User authorized! Clean up ETS entry
        :ets.delete(@ets_table, user_id)
        # Exchange for tokens
        handle_device_exchange(conn, auth_code, code_verifier, user_id)

      {:pending} ->
        json(conn, %{status: "pending"})

      {:error, :authorization_declined} ->
        :ets.delete(@ets_table, user_id)

        conn
        |> put_status(403)
        |> json(%{status: "declined", error: "Authorization was declined."})

      {:error, reason} ->
        Logger.error("ChatGPT device poll error: #{inspect(reason)}")
        json(conn, %{status: "pending"})
    end
  end

  defp handle_device_exchange(conn, authorization_code, code_verifier, user_id) do
    case ChatGPTOAuth.exchange_device_code(authorization_code, code_verifier) do
      {:ok, tokens} ->
        # Extract account_id from JWT tokens
        account_id = ChatGPTOAuth.extract_account_id_from_tokens(tokens)

        # Calculate expiry (default to 1 hour if not provided)
        expires_in = tokens.expires_in || 3600
        expires_at = OAuthHelpers.calculate_expires_at(expires_in)

        # Build scope from user_id for upsert
        scope = build_scope_from_user_id(user_id)

        metadata = if account_id, do: %{"account_id" => account_id}, else: %{}

        case Providers.upsert_oauth_token_with_metadata(
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

  defp build_scope_from_user_id(user_id) do
    user = FrontmanServer.Repo.get!(FrontmanServer.Accounts.User, user_id)
    %FrontmanServer.Accounts.Scope{user: user}
  end

  defp cleanup_expired_entries do
    now = System.monotonic_time(:second)

    # Use match_spec to find and delete expired entries
    # Pattern: {user_id, device_auth_id, user_code, expires_at} where expires_at < now
    :ets.select_delete(@ets_table, [
      {{:_, :_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])
  rescue
    _ -> :ok
  end
end
