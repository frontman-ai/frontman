# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Plugs.RawBodyReader do
  @moduledoc """
  Preserves raw webhook request bodies before Plug.Parsers decodes them.
  """

  def read_body(conn, opts) do
    read_body(conn, opts, "")
  end

  defp read_body(conn, opts, acc) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        raw_body = acc <> body

        conn =
          if conn.request_path == "/api/stripe/webhook" do
            Plug.Conn.assign(conn, :raw_body, raw_body)
          else
            conn
          end

        {:ok, raw_body, conn}

      {:more, body, conn} ->
        read_body(conn, opts, acc <> body)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
