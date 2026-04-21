# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.UserAuth do
  @moduledoc """
  Handles user authentication via session tokens and remember-me cookies.
  """

  use FrontmanServerWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope

  # Make the remember me cookie valid for 14 days. This should match
  # the session validity setting in UserToken.
  @max_cookie_age_in_days 14
  @remember_me_cookie "_frontman_server_web_user_remember_me"
  @remember_me_options [
    sign: true,
    max_age: @max_cookie_age_in_days * 24 * 60 * 60,
    same_site: "Lax"
  ]

  # How old the session token should be before a new one is issued. When a request is made
  # with a session token older than this value, then a new session token will be created
  # and the session and remember-me cookies (if set) will be updated with the new token.
  # Lowering this value will result in more tokens being created by active users. Increasing
  # it will result in less time before a session token expires for a user to get issued a new
  # token. This can be set to a value greater than `@max_cookie_age_in_days` to disable
  # the reissuing of tokens completely.
  @session_reissue_age_in_days 7

  @doc """
  Logs the user in.

  Redirects to the session's `:user_return_to` path
  or falls back to the `signed_in_path/1`.
  """
  def log_in_user(conn, user, params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> create_or_extend_session(user, params)
    |> redirect_to_return_path(user_return_to)
  end

  defp redirect_to_return_path(conn, nil) do
    redirect(conn, to: signed_in_path(conn))
  end

  defp redirect_to_return_path(conn, url) when is_binary(url) do
    if String.starts_with?(url, "/") and not String.starts_with?(url, "//") do
      redirect(conn, to: url)
    else
      case safe_return_url?(url) do
        true -> redirect(conn, external: url)
        false -> redirect(conn, to: signed_in_path(conn))
      end
    end
  end

  # Validates that an absolute URL belongs to an allowed domain to prevent open redirects.
  # Allows: frontman.sh, *.frontman.sh, *.com, *.com.au, *.net, *.org,
  # category-creation.com, *.category-creation.com, frontman.local (any port),
  # localhost (any port).
  defp safe_return_url?(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        allowed_return_host?(host)

      _ ->
        false
    end
  end

  defp allowed_return_host?(host) do
    exact_return_host?(host) or subdomain_return_host?(host)
  end

  defp exact_return_host?(host) do
    host in ["frontman.sh", "category-creation.com", "frontman.local", "localhost", "127.0.0.1"]
  end

  defp subdomain_return_host?(host) do
    String.ends_with?(host, ".com") or
      String.ends_with?(host, ".com.au") or
      String.ends_with?(host, ".net") or
      String.ends_with?(host, ".org") or
      String.ends_with?(host, ".frontman.sh") or
      String.ends_with?(host, ".category-creation.com") or
      String.ends_with?(host, ".frontman.local")
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.

  Accepts an optional `return_to` URL that is forwarded to the login page
  so the user is redirected back after re-authenticating.
  """
  def log_out_user(conn, return_to \\ nil) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      FrontmanServerWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    redirect_url =
      case return_to do
        nil -> ~p"/users/log-in"
        url -> ~p"/users/log-in?#{%{"return_to" => url}}"
      end

    conn
    |> renew_session(nil)
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: redirect_url)
  end

  @doc """
  Authenticates the user by looking into the session and remember me token.

  Will reissue the session token if it is older than the configured age.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    case ensure_user_token(conn) do
      {token, conn} ->
        case Accounts.get_user_by_session_token(token) do
          {user, token_inserted_at} ->
            conn
            |> assign(:current_scope, Scope.for_user(user))
            |> maybe_reissue_user_session_token(user, token_inserted_at)

          nil ->
            conn
            |> clear_stale_session_token()
            |> authenticate_from_remember_me(token)
        end

      nil ->
        assign(conn, :current_scope, Scope.for_user(nil))
    end
  end

  defp clear_stale_session_token(conn) do
    conn
    |> delete_session(:user_token)
    |> delete_session(:user_remember_me)
  end

  defp authenticate_from_remember_me(conn, stale_token) do
    conn = fetch_cookies(conn, signed: [@remember_me_cookie])

    case find_valid_remember_me_session(conn, stale_token) do
      {:ok, token, user, token_inserted_at} ->
        conn
        |> put_token_in_session(token)
        |> put_session(:user_remember_me, true)
        |> assign(:current_scope, Scope.for_user(user))
        |> maybe_reissue_user_session_token(user, token_inserted_at)

      :error ->
        conn
        |> delete_resp_cookie(@remember_me_cookie)
        |> assign(:current_scope, Scope.for_user(nil))
    end
  end

  defp find_valid_remember_me_session(conn, stale_token) do
    conn
    |> remember_me_candidate_tokens()
    |> Enum.reject(&(&1 == stale_token))
    |> Enum.find_value(:error, fn token ->
      case Accounts.get_user_by_session_token(token) do
        {user, token_inserted_at} ->
          {:ok, token, user, token_inserted_at}

        nil ->
          nil
      end
    end)
  end

  defp remember_me_candidate_tokens(conn) do
    fetched_cookie_token =
      case conn.cookies[@remember_me_cookie] do
        token when is_binary(token) -> [token]
        _ -> []
      end

    raw_cookie_tokens =
      conn
      |> remember_me_signed_values_from_raw_header()
      |> Enum.map(&decode_signed_remember_me_token(conn, &1))
      |> Enum.filter(&is_binary/1)

    (fetched_cookie_token ++ raw_cookie_tokens)
    |> Enum.uniq()
  end

  defp remember_me_signed_values_from_raw_header(conn) do
    conn
    |> get_req_header("cookie")
    |> Enum.flat_map(&String.split(&1, ";"))
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(fn cookie ->
      case String.split(cookie, "=", parts: 2) do
        [@remember_me_cookie, value] -> [value]
        _ -> []
      end
    end)
  end

  defp decode_signed_remember_me_token(conn, signed_value) do
    conn
    |> conn_with_cookie_header("#{@remember_me_cookie}=#{signed_value}")
    |> fetch_cookies(signed: [@remember_me_cookie])
    |> Map.get(:cookies)
    |> Map.get(@remember_me_cookie)
  end

  defp conn_with_cookie_header(conn, cookie_header) do
    updated_headers = [
      {"cookie", cookie_header} | Enum.reject(conn.req_headers, &match?({"cookie", _}, &1))
    ]

    %{
      conn
      | req_headers: updated_headers,
        req_cookies: %Plug.Conn.Unfetched{aspect: :cookies},
        cookies: %Plug.Conn.Unfetched{aspect: :cookies}
    }
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, conn |> put_token_in_session(token) |> put_session(:user_remember_me, true)}
      else
        nil
      end
    end
  end

  # Reissue the session token if it is older than the configured reissue age.
  defp maybe_reissue_user_session_token(conn, user, token_inserted_at) do
    token_age = DateTime.diff(DateTime.utc_now(:second), token_inserted_at, :day)

    if token_age >= @session_reissue_age_in_days do
      create_or_extend_session(conn, user, %{})
    else
      conn
    end
  end

  # This function is the one responsible for creating session tokens
  # and storing them safely in the session and cookies. It may be called
  # either when logging in, during sudo mode, or to renew a session which
  # will soon expire.
  #
  # When the session is created, rather than extended, the renew_session
  # function will clear the session to avoid fixation attacks. See the
  # renew_session function to customize this behaviour.
  defp create_or_extend_session(conn, user, params) do
    token = Accounts.generate_user_session_token(user)
    remember_me = get_session(conn, :user_remember_me)

    conn
    |> renew_session(user)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params, remember_me)
  end

  # Do not renew session if the user is already logged in
  # to prevent CSRF errors or data being lost in tabs that are still open
  defp renew_session(conn, user) when conn.assigns.current_scope.user.id == user.id do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn, _user) do
  #       delete_csrf_token()
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn, _user) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}, _),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, token, _params, true),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, _token, _params, _), do: conn

  defp write_remember_me_cookie(conn, token) do
    conn
    |> put_session(:user_remember_me, true)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  defp put_token_in_session(conn, token) do
    put_session(conn, :user_token, token)
  end

  @doc """
  Plug for routes that require sudo mode.
  """
  def require_sudo_mode(conn, _opts) do
    if Accounts.sudo_mode?(conn.assigns.current_scope.user, -10) do
      conn
    else
      conn
      |> put_flash(:error, "You must re-authenticate to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  @doc """
  Plug for routes that require the user to not be authenticated.

  If a `return_to` query parameter is present and the user is authenticated,
  redirects to that URL instead of the default signed-in path.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns.current_scope do
      return_to = conn.params["return_to"]

      conn
      |> redirect_to_return_path(return_to)
      |> halt()
    else
      conn
    end
  end

  defp signed_in_path(_conn), do: ~p"/"

  @doc """
  Plug for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  @doc """
  Plug for API routes that require the user to be authenticated.
  Returns JSON error instead of redirect.
  """
  def require_authenticated_user_api(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.json(%{error: "authentication_required"})
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
