# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.SocketTokenController do
  use FrontmanServerWeb, :controller

  def show(conn, _params) do
    case {conn.assigns[:current_scope], get_session(conn, :user_token)} do
      {%{user: %{id: user_id}}, session_token} when is_binary(session_token) ->
        case FrontmanServer.Accounts.get_socket_session(session_token) do
          {%{id: ^user_id}, user_token_id} ->
            {conn, browser_session_id} = ensure_browser_session_id(conn)

            token =
              Phoenix.Token.sign(
                conn,
                "user socket",
                {user_id, user_token_id, browser_session_id}
              )

            json(conn, %{token: token})

          nil ->
            unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp ensure_browser_session_id(conn) do
    case get_session(conn, :socket_session_id) do
      nil ->
        session_id = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
        {put_session(conn, :socket_session_id, session_id), session_id}

      session_id ->
        {conn, session_id}
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Not authenticated"})
  end
end
