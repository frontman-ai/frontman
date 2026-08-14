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
        session_id = FrontmanServer.Accounts.user_session_id(session_token)
        token = Phoenix.Token.sign(conn, "user socket", {user_id, session_id})
        json(conn, %{token: token})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end
end
