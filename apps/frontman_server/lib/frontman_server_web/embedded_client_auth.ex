# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.EmbeddedClientAuth do
  @moduledoc """
  Shared session contract for embedded client authorization requests.
  """

  import Plug.Conn

  alias FrontmanServerWeb.EmbeddedClientOrigin

  @pending_session_key :embedded_client_auth_request

  def pending_session_key, do: @pending_session_key

  def put_pending_request(
        conn,
        %{"embedded_state" => state, "embedded_origin" => origin}
      )
      when is_binary(state) and byte_size(state) > 0 and is_binary(origin) do
    case EmbeddedClientOrigin.normalize(origin) do
      {:ok, normalized_origin} ->
        conn =
          put_session(conn, @pending_session_key, %{
            "state" => state,
            "origin" => normalized_origin
          })

        {:ok, conn}

      {:error, :invalid_origin} ->
        conn =
          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(:bad_request, "Invalid embedded origin")
          |> halt()

        {:error, conn}
    end
  end

  def put_pending_request(conn, _params), do: {:ok, conn}
end
