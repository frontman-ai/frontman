# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Plugs.CORS do
  @moduledoc """
  CORS plug for cross-origin API requests.

  When used at the endpoint level, handles OPTIONS preflight requests
  before they reach the router.

  ## Options

    * `:path_prefix` - Only apply CORS to paths starting with this prefix.
      Defaults to "/api".
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    path_prefix = Keyword.get(opts, :path_prefix, "/api")

    if String.starts_with?(conn.request_path, path_prefix) do
      origin = get_origin(conn)

      conn
      |> put_resp_header("vary", "origin")
      |> put_resp_header("access-control-allow-origin", origin)
      |> put_resp_header("access-control-allow-credentials", "true")
      |> put_resp_header("access-control-allow-methods", "GET, POST, DELETE, OPTIONS")
      |> put_resp_header("access-control-allow-headers", "content-type")
      |> handle_preflight()
    else
      conn
    end
  end

  defp get_origin(conn) do
    case get_req_header(conn, "origin") do
      [origin] -> origin
      _ -> "*"
    end
  end

  defp handle_preflight(%{method: "OPTIONS"} = conn) do
    conn
    |> send_resp(204, "")
    |> halt()
  end

  defp handle_preflight(conn), do: conn
end
