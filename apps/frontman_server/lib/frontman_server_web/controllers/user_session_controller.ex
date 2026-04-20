# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.UserSessionController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.UserAuth

  def new(conn, params) do
    email = get_in(conn.assigns, [:current_scope, Access.key(:user), Access.key(:email)])
    form = Phoenix.Component.to_form(%{"email" => email}, as: "user")

    # Store return_to from query param (for cross-origin redirects like /frontman).
    # Validated by redirect_to_return_path/2 in UserAuth before any redirect happens.
    conn =
      conn
      |> maybe_put_user_return_to(params["return_to"])
      |> maybe_put_signup_framework(params["framework"])

    render(conn, :new, form: form)
  end

  # magic link login
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

  # email + password login
  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      form = Phoenix.Component.to_form(user_params, as: "user")

      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> render(:new, form: form)
    end
  end

  # magic link request
  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    conn
    |> put_flash(:info, info)
    |> redirect(to: ~p"/users/log-in")
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
    case normalize_signup_framework(framework) do
      {:ok, normalized} -> put_session(conn, :signup_framework, normalized)
      :error -> delete_session(conn, :signup_framework)
    end
  end

  defp maybe_put_signup_framework(conn, _), do: delete_session(conn, :signup_framework)

  defp normalize_signup_framework("nextjs"), do: {:ok, "nextjs"}
  defp normalize_signup_framework("vite"), do: {:ok, "vite"}
  defp normalize_signup_framework("astro"), do: {:ok, "astro"}
  defp normalize_signup_framework("wordpress"), do: {:ok, "wordpress"}
  defp normalize_signup_framework(_), do: :error
end
