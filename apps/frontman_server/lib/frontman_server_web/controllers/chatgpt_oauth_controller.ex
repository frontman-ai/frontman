defmodule FrontmanServerWeb.ChatGPTOAuthController do
  @moduledoc """
  Handles the ChatGPT Pro/Plus OAuth flow with a server-side callback.

  Flow:
  1. Client calls `GET /api/oauth/chatgpt/authorize-url`
     → Server generates PKCE, stores `{state → {verifier, user_id}}` in ETS, returns URL
  2. Client opens the authorization URL in a new browser tab
  3. User authenticates at auth.openai.com
  4. OpenAI redirects to `GET /api/oauth/chatgpt/callback?code=...&state=...`
     → Server looks up verifier from ETS, exchanges code for tokens,
       extracts `chatgpt_account_id` from JWT, stores tokens, renders success HTML
  5. Original client tab polls `GET /api/oauth/chatgpt/status` to detect completion
  """

  use FrontmanServerWeb, :controller

  require Logger

  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.{ChatGPTOAuth, OAuthHelpers, OAuthToken}

  # ETS table for PKCE state storage (state → {verifier, user_id, expires_at})
  @ets_table :chatgpt_oauth_state
  # 10 minute TTL for PKCE state entries
  @state_ttl_seconds 600

  @doc """
  Ensures the ETS table for PKCE state storage exists.
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
  Generates a PKCE challenge and returns the authorization URL.

  The PKCE verifier is stored server-side in ETS (keyed by the state parameter).
  The client should open the returned URL in a new browser tab.
  OpenAI will redirect back to our callback endpoint with the code and state.

  GET /api/oauth/chatgpt/authorize-url
  """
  def authorize_url(conn, _params) do
    scope = conn.assigns.current_scope
    user_id = scope.user.id

    {verifier, challenge} = OAuthHelpers.generate_pkce()
    state = OAuthHelpers.generate_state()

    # Build the callback URL for this server
    redirect_uri = callback_url(conn)
    authorize_url = ChatGPTOAuth.build_authorize_url(challenge, state, redirect_uri)

    # Store state → {verifier, user_id, expires_at} in ETS
    expires_at = System.monotonic_time(:second) + @state_ttl_seconds
    ensure_ets_table()
    :ets.insert(@ets_table, {state, verifier, user_id, expires_at})

    # Clean up expired entries opportunistically
    cleanup_expired_entries()

    json(conn, %{
      authorize_url: authorize_url
    })
  end

  @doc """
  Server-side OAuth callback from OpenAI.

  OpenAI redirects the user's browser here after authorization.
  We look up the PKCE verifier from ETS, exchange the code for tokens,
  extract the account_id, store everything, and render a success page.

  GET /api/oauth/chatgpt/callback?code=...&state=...
  """
  def callback(conn, %{"code" => code, "state" => state}) do
    ensure_ets_table()

    case :ets.lookup(@ets_table, state) do
      [{^state, verifier, user_id, expires_at}] ->
        # Delete the entry immediately (one-time use)
        :ets.delete(@ets_table, state)

        # Check expiry
        if System.monotonic_time(:second) > expires_at do
          render_callback_error(conn, "Authorization session expired. Please try again.")
        else
          handle_code_exchange(conn, code, verifier, user_id)
        end

      [] ->
        render_callback_error(conn, "Invalid or expired authorization session. Please try again.")
    end
  end

  def callback(conn, _params) do
    render_callback_error(conn, "Missing authorization code or state parameter.")
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

  defp handle_code_exchange(conn, code, verifier, user_id) do
    redirect_uri = callback_url(conn)

    case ChatGPTOAuth.exchange_code(code, verifier, redirect_uri) do
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
            render_callback_success(conn)

          {:error, changeset} ->
            Logger.error("Failed to store ChatGPT OAuth token: #{inspect(changeset)}")
            render_callback_error(conn, "Failed to save tokens. Please try again.")
        end

      {:error, reason} ->
        Logger.error("ChatGPT OAuth code exchange failed: #{inspect(reason)}")
        render_callback_error(conn, "Failed to exchange authorization code. Please try again.")
    end
  end

  defp build_scope_from_user_id(user_id) do
    user = FrontmanServer.Repo.get!(FrontmanServer.Accounts.User, user_id)
    %FrontmanServer.Accounts.Scope{user: user}
  end

  defp callback_url(_conn) do
    FrontmanServerWeb.Endpoint.url() <> "/api/oauth/chatgpt/callback"
  end

  defp cleanup_expired_entries do
    now = System.monotonic_time(:second)

    # Use match_spec to find and delete expired entries
    # Pattern: {state, verifier, user_id, expires_at} where expires_at < now
    :ets.select_delete(@ets_table, [
      {{:_, :_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])
  rescue
    _ -> :ok
  end

  defp render_callback_success(conn) do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Connected - Frontman</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #0a0a0a;
          color: #e4e4e7;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          margin: 0;
        }
        .container {
          text-align: center;
          padding: 2rem;
        }
        .check {
          width: 64px;
          height: 64px;
          border-radius: 50%;
          background: rgba(16, 185, 129, 0.2);
          display: flex;
          align-items: center;
          justify-content: center;
          margin: 0 auto 1.5rem;
          font-size: 2rem;
        }
        h1 { font-size: 1.5rem; margin: 0 0 0.5rem; }
        p { color: #71717a; font-size: 0.875rem; margin: 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="check">&#10003;</div>
        <h1>ChatGPT Connected</h1>
        <p>You can close this tab and return to Frontman.</p>
      </div>
      <script>
        // Auto-close after 3 seconds
        setTimeout(function() { window.close(); }, 3000);
      </script>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp render_callback_error(conn, message) do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Error - Frontman</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #0a0a0a;
          color: #e4e4e7;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          margin: 0;
        }
        .container {
          text-align: center;
          padding: 2rem;
        }
        .error-icon {
          width: 64px;
          height: 64px;
          border-radius: 50%;
          background: rgba(239, 68, 68, 0.2);
          display: flex;
          align-items: center;
          justify-content: center;
          margin: 0 auto 1.5rem;
          font-size: 2rem;
        }
        h1 { font-size: 1.5rem; margin: 0 0 0.5rem; }
        p { color: #71717a; font-size: 0.875rem; margin: 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="error-icon">&#10007;</div>
        <h1>Connection Failed</h1>
        <p>#{message}</p>
      </div>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(400, html)
  end
end
