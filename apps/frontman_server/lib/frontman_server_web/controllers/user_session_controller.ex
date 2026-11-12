# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.UserSessionController do
  use FrontmanServerWeb, :controller

  require Logger

  alias FrontmanServer.Accounts
  alias FrontmanServer.Frameworks
  alias FrontmanServerWeb.ConnectHandoff
  alias FrontmanServerWeb.EmbeddedClientAuth
  alias FrontmanServerWeb.UserAuth

  plug(EmbeddedClientAuth when action in [:new, :create, :confirm])
  plug(ConnectHandoff when action in [:new, :create, :confirm])

  def new(conn, params) do
    email = get_in(conn.assigns, [:current_scope, Access.key(:user), Access.key(:email)])
    form = Phoenix.Component.to_form(%{"email" => email}, as: "user")

    conn =
      conn
      |> maybe_put_user_return_to(params["return_to"])
      |> maybe_put_signup_framework(params["framework"])

    render(conn, :new,
      form: form,
      page_title:
        if(conn.assigns.assistant_connection,
          do: "Edit your WordPress site, your way",
          else: "Sign in to Frontman"
        )
    )
  end

  def create(conn, %{"_action" => "connect"} = params) do
    user_id = params["user_id"]

    case {conn.assigns.current_scope, conn.assigns.embedded_request} do
      {%{user: %{id: ^user_id} = user}, %{"origin" => _}} -> UserAuth.log_in_user(conn, user)
      _ -> send_resp(conn, :unauthorized, "Sign in to connect this site")
    end
  end

  def create(conn, %{"user" => %{"token" => token} = user_params} = params) do
    info =
      case params do
        %{"_action" => "confirmed"} -> "User confirmed successfully."
        _ -> "Welcome back!"
      end

    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, _expired_tokens}} ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> render(:new, form: Phoenix.Component.to_form(%{}, as: "user"))
    end
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      form = Phoenix.Component.to_form(user_params, as: "user")

      conn
      |> put_flash(:error, "Invalid email or password")
      |> render(:new, form: form)
    end
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      case Accounts.deliver_login_instructions(
             user,
             &url(~p"/users/log-in/#{&1}")
           ) do
        {:ok, _email} -> :ok
        {:error, _reason} -> Logger.error("Login email delivery failed")
      end
    end

    info =
      "If your email is in our system, check your inbox for sign-in instructions. If no email arrives, try again later."

    redirect_path =
      case conn.assigns.embedded_request do
        %{"origin" => origin, "state" => state} ->
          ~p"/users/log-in?#{%{embedded_origin: origin, embedded_state: state}}"

        nil ->
          ~p"/users/log-in"
      end

    conn
    |> put_flash(:info, info)
    |> redirect(to: redirect_path)
  end

  def confirm(conn, %{"token" => token}) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = Phoenix.Component.to_form(%{"token" => token}, as: "user")

      conn
      |> assign(:user, user)
      |> assign(:form, form)
      |> render(:confirm)
    else
      conn
      |> put_flash(:error, "Magic link is invalid or it has expired.")
      |> redirect(to: ~p"/users/log-in")
    end
  end

  @doc """
  GET /users/log-out — renders a CSRF-protected confirmation page that auto-submits
  a DELETE form. This prevents forced-logout via `<img src="/users/log-out">` since
  the GET only returns HTML; the actual session destruction requires the DELETE with
  a valid CSRF token.
  """
  def confirm_logout(conn, params) do
    render(conn, :confirm_logout, return_to: params["return_to"])
  end

  def popup_complete(conn, _params) do
    conn |> put_resp_header("cache-control", "no-store") |> render(:popup_missing)
  end

  def delete(conn, params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user(params["return_to"])
  end

  defp maybe_put_user_return_to(conn, nil), do: conn

  defp maybe_put_user_return_to(conn, return_to) when is_binary(return_to) do
    put_session(conn, :user_return_to, return_to)
  end

  defp maybe_put_user_return_to(conn, _), do: conn

  defp maybe_put_signup_framework(conn, framework) when is_binary(framework) do
    case Frameworks.valid_signup_id?(framework) do
      true -> put_session(conn, :signup_framework, framework)
      false -> delete_session(conn, :signup_framework)
    end
  end

  defp maybe_put_signup_framework(conn, _), do: delete_session(conn, :signup_framework)
end
