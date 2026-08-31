# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.ClientTokenController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.Endpoint

  def delete(conn, _params) do
    case conn.assigns do
      %{embedded_client_token_id: token_id} when is_binary(token_id) ->
        Accounts.delete_embedded_client_token(token_id)
        Endpoint.broadcast("client_token:#{token_id}", "disconnect", %{})
        send_resp(conn, :no_content, "")

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end
end
