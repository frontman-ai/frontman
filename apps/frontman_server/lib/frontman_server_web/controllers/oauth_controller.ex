defmodule FrontmanServerWeb.OAuthController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.WorkOS.AuthError
  alias FrontmanServerWeb.UserAuth

  import FrontmanServerWeb.UserAuth, only: [require_sudo_mode: 2]

  plug :require_sudo_mode when action in [:link_request, :link_callback, :unlink]

  def request(conn, %{"provider" => provider}) do
    redirect_uri = url(~p"/auth/callback")
    {:ok, url} = Accounts.get_oauth_authorization_url(provider, redirect_uri)
    redirect(conn, external: url)
  end

  def callback(conn, %{"code" => code}) do
    require Logger

    case Accounts.authenticate_with_oauth(code) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome!")
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      {:error, %AuthError{code: "email_verification_required"} = error} ->
        Logger.info("Email verification required, redirecting to verify-email page")

        conn
        |> put_session(:pending_auth_token, error.pending_authentication_token)
        |> put_session(:pending_auth_email, error.email)
        |> redirect(to: ~p"/auth/verify-email")

      {:error, %AuthError{} = error} ->
        Logger.debug("OAuth AuthError: #{inspect(error)}")

        conn
        |> put_flash(:error, error.message || "Authentication failed. Please try again.")
        |> redirect(to: ~p"/users/log-in")

      {:error, reason} ->
        Logger.debug("OAuth unknown error: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Authentication failed. Please try again.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def callback(conn, %{"error" => "access_denied"}) do
    conn
    |> put_flash(:error, "Sign in was cancelled.")
    |> redirect(to: ~p"/users/log-in")
  end

  def verify_email_form(conn, _params) do
    case get_session(conn, :pending_auth_token) do
      nil ->
        conn
        |> put_flash(:error, "No pending verification. Please sign in again.")
        |> redirect(to: ~p"/users/log-in")

      _token ->
        email = get_session(conn, :pending_auth_email)
        render(conn, :verify_email, email: email)
    end
  end

  def verify_email(conn, %{"code" => code}) do
    token = get_session(conn, :pending_auth_token)

    if is_nil(token) do
      conn
      |> put_flash(:error, "No pending verification. Please sign in again.")
      |> redirect(to: ~p"/users/log-in")
    else
      case Accounts.authenticate_with_email_verification(code, token) do
        {:ok, user} ->
          conn
          |> delete_session(:pending_auth_token)
          |> delete_session(:pending_auth_email)
          |> put_flash(:info, "Email verified. Welcome!")
          |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

        {:error, %AuthError{message: message}} ->
          conn
          |> put_flash(:error, message || "Invalid verification code. Please try again.")
          |> redirect(to: ~p"/auth/verify-email")

        {:error, _reason} ->
          conn
          |> put_flash(:error, "Verification failed. Please try again.")
          |> redirect(to: ~p"/auth/verify-email")
      end
    end
  end

  def link_request(%{assigns: %{current_scope: %{user: _user}}} = conn, %{"provider" => provider}) do
    redirect_uri = url(~p"/auth/link/callback")
    state = generate_state_token()
    {:ok, url} = Accounts.get_oauth_authorization_url(provider, redirect_uri, state)

    conn
    |> put_session(:oauth_state, state)
    |> redirect(external: url)
  end

  def link_callback(%{assigns: %{current_scope: %{user: user}}} = conn, %{
        "code" => code,
        "state" => state
      }) do
    ^state = get_session(conn, :oauth_state)
    {:ok, identity} = Accounts.link_oauth_provider(user, code)

    conn
    |> delete_session(:oauth_state)
    |> put_flash(:info, "#{provider_display_name(identity.provider)} connected successfully.")
    |> redirect(to: ~p"/users/settings")
  end

  def link_callback(conn, %{"error" => "access_denied"}) do
    conn
    |> delete_session(:oauth_state)
    |> put_flash(:error, "Connection was cancelled.")
    |> redirect(to: ~p"/users/settings")
  end

  def unlink(%{assigns: %{current_scope: %{user: user}}} = conn, %{"provider" => provider}) do
    {:ok, _identity} = Accounts.unlink_oauth_provider(user, provider)

    conn
    |> put_flash(:info, "#{provider_display_name(provider)} disconnected.")
    |> redirect(to: ~p"/users/settings")
  end

  defp generate_state_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp provider_display_name("github"), do: "GitHub"
  defp provider_display_name("google"), do: "Google"
end
