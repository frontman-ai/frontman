# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.EmbeddedClientAuthController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.EmbeddedClientAuth

  plug(:put_no_store)

  def show(conn, _params) do
    pending_request = get_session(conn, EmbeddedClientAuth.pending_session_key())

    case {current_user(conn), pending_request} do
      {nil, _request} ->
        redirect(conn, to: ~p"/users/log-in?#{%{"return_to" => "/users/popup-complete"}}")

      {_user, %{"origin" => origin}} ->
        render(conn, :show, origin: origin)

      {_user, _request} ->
        render(conn, :missing)
    end
  end

  def approve(conn, _params) do
    pending_request = get_session(conn, EmbeddedClientAuth.pending_session_key())

    case {current_user(conn), pending_request} do
      {%{} = user, %{"origin" => origin, "state" => state}} ->
        token = Accounts.generate_embedded_client_token(user, origin)

        conn
        |> delete_session(EmbeddedClientAuth.pending_session_key())
        |> render(:complete, origin: origin, state: state, token: token)

      {nil, _request} ->
        conn
        |> put_status(:unauthorized)
        |> render(:missing)

      {_user, _request} ->
        conn
        |> put_status(:bad_request)
        |> render(:missing)
    end
  end

  defp current_user(conn), do: get_in(conn.assigns, [:current_scope, Access.key(:user)])

  defp put_no_store(conn, _opts) do
    put_resp_header(conn, "cache-control", "no-store")
  end
end
