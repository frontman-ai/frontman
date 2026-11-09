# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.EmbeddedClientAuth do
  @moduledoc """
  Reads the embedded request displayed by, and submitted with, the login form.
  """

  import Plug.Conn

  alias FrontmanServerWeb.EmbeddedClientOrigin

  def init(opts), do: opts

  def call(conn, _opts) do
    case request(conn.params) do
      {:ok, request} ->
        assign(conn, :embedded_request, request)

      {:error, :invalid_origin} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:bad_request, "Invalid embedded origin")
        |> halt()
    end
  end

  defp request(%{"embedded_state" => state, "embedded_origin" => origin})
       when is_binary(state) and byte_size(state) in 1..512 do
    with {:ok, origin} <- EmbeddedClientOrigin.normalize(origin) do
      {:ok, %{"origin" => origin, "state" => state}}
    end
  end

  defp request(%{"embedded_origin" => _}), do: {:error, :invalid_origin}
  defp request(%{"embedded_state" => _}), do: {:error, :invalid_origin}
  defp request(_params), do: {:ok, nil}
end
