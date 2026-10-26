# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.OAuthController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.WorkOS.AuthError
  alias FrontmanServerWeb.UserAuth

  import FrontmanServerWeb.UserAuth, only: [require_sudo_mode: 2]

  plug(:require_sudo_mode when action in [:link_request, :link_callback, :unlink])

  def request(conn, %{"provider" => provider}) do
    authorize(conn, provider, url(~p"/auth/callback"), :oauth_signin_state)
  end

  def callback(conn, params) do
    if valid_state?(conn, params, :oauth_signin_state),
      do: complete_sign_in(delete_session(conn, :oauth_signin_state), params),
      else: complete_sign_in(conn, %{})
  end

  defp complete_sign_in(conn, %{"code" => code}) do
    require Logger

    signup_framework = get_session(conn, :signup_framework)

    case Accounts.authenticate_with_oauth(code, signup_framework) do
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

      {:error, reason} ->
        Logger.debug("OAuth error: #{inspect(reason)}")
        complete_sign_in(conn, %{})
    end
  end

  defp complete_sign_in(conn, %{"error" => "access_denied"}) do
    conn
    |> put_flash(:error, "Sign in was cancelled.")
    |> redirect(to: ~p"/users/log-in")
  end

  defp complete_sign_in(conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed. Please try again.")
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
    signup_framework = get_session(conn, :signup_framework)

    if is_nil(token) do
      conn
      |> put_flash(:error, "No pending verification. Please sign in again.")
      |> redirect(to: ~p"/users/log-in")
    else
      case Accounts.authenticate_with_email_verification(code, token, signup_framework) do
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

  def link_request(conn, %{"provider" => provider}) do
    authorize(conn, provider, url(~p"/auth/link/callback"), :oauth_state)
  end

  def link_callback(conn, params) do
    if valid_state?(conn, params, :oauth_state),
      do: complete_link(delete_session(conn, :oauth_state), params),
      else: complete_link(conn, %{})
  end

  defp complete_link(conn, %{"code" => code}) do
    user = Accounts.scope_user(conn.assigns.current_scope)

    case Accounts.link_oauth_provider(user, code) do
      {:ok, identity} ->
        conn
        |> put_flash(:info, "#{provider_display_name(identity.provider)} connected successfully.")
        |> redirect(to: ~p"/users/settings")

      {:error, %error{}} when error in [AuthError, Req.TransportError, Ecto.Changeset] ->
        complete_link(conn, %{})

      {:error, {tag, _detail}}
      when tag in [
             :invalid_argument,
             :invalid_auth_response,
             :invalid_auth_response_field,
             :invalid_authentication_method
           ] ->
        complete_link(conn, %{})
    end
  end

  defp complete_link(conn, %{"error" => "access_denied"}) do
    conn
    |> put_flash(:error, "Connection was cancelled.")
    |> redirect(to: ~p"/users/settings")
  end

  defp complete_link(conn, _params) do
    conn
    |> put_flash(:error, "Connection failed. Please try again.")
    |> redirect(to: ~p"/users/settings")
  end

  def unlink(conn, %{"provider" => provider}) do
    user = Accounts.scope_user(conn.assigns.current_scope)

    case Accounts.unlink_oauth_provider(user, provider) do
      {:ok, _identity} ->
        conn
        |> put_flash(:info, "#{provider_display_name(provider)} disconnected.")
        |> redirect(to: ~p"/users/settings")

      {:error, reason} when reason in [:not_found, :unsupported_provider] ->
        send_resp(conn, :not_found, "Not Found")
    end
  end

  defp authorize(conn, provider, redirect_uri, key) do
    state = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    case Accounts.get_oauth_authorization_url(provider, redirect_uri, state) do
      {:ok, url} ->
        conn |> put_session(key, state) |> redirect(external: url)

      {:error, :unsupported_provider} ->
        send_resp(conn, :not_found, "Not Found")
    end
  end

  defp valid_state?(_conn, %{"state" => ""}, _key), do: false

  defp valid_state?(conn, %{"state" => state}, key) when is_binary(state),
    do: state == get_session(conn, key)

  defp valid_state?(_conn, _params, _key), do: false

  defp provider_display_name("github"), do: "GitHub"
  defp provider_display_name("google"), do: "Google"
end
