# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PlayGithub.SandboxProxy.Vite do
  @moduledoc false

  import Plug.Conn, only: [get_req_header: 2]

  alias Plug.Conn.Utils, as: ConnUtils

  @hmr_protocol "vite-hmr"
  @dev_asset_path_prefixes MapSet.new([
                             "@fs",
                             "@id",
                             "@vite",
                             "node_modules",
                             "src",
                             "_astro",
                             "_image"
                           ])

  def websocket_protocol, do: @hmr_protocol

  def websocket_request?(%{method: "GET"} = conn) do
    case header_contains?(conn, "connection", "upgrade") do
      true -> websocket_upgrade_with_hmr_protocol?(conn)
      false -> false
    end
  end

  def websocket_request?(_conn), do: false

  def dev_asset_path?([prefix | _path]) do
    MapSet.member?(@dev_asset_path_prefixes, prefix)
  end

  def dev_asset_path?([]), do: false

  def put_websocket_protocol_header(headers) do
    List.keystore(
      headers,
      "sec-websocket-protocol",
      0,
      {"sec-websocket-protocol", @hmr_protocol}
    )
  end

  def rewrite_client_websocket_host(body, target_url, conn) do
    case client_url?(target_url) do
      true -> replace_client_hmr_host(body, proxy_hmr_host(conn))
      false -> body
    end
  end

  defp websocket_upgrade_with_hmr_protocol?(conn) do
    case header_contains?(conn, "upgrade", "websocket") do
      true -> header_contains?(conn, "sec-websocket-protocol", @hmr_protocol)
      false -> false
    end
  end

  defp header_contains?(conn, header, needle) do
    conn
    |> get_req_header(header)
    |> Enum.flat_map(&ConnUtils.list/1)
    |> Enum.any?(&(String.downcase(&1, :ascii) == needle))
  end

  defp client_url?(target_url) do
    case URI.parse(target_url) do
      %URI{path: "/@vite/client"} -> true
      _ -> false
    end
  end

  defp replace_client_hmr_host(body, hmr_host) do
    body
    |> replace_regex(~r/const serverHost = "[^"]*";/, ~s(const serverHost = "#{hmr_host}";))
    |> replace_regex(~r/const socketHost = .+?;/, ~s(const socketHost = "#{hmr_host}";))
    |> replace_regex(
      ~r/const directSocketHost = "[^"]*";/,
      ~s(const directSocketHost = "#{hmr_host}";)
    )
  end

  defp replace_regex(body, regex, replacement), do: Regex.replace(regex, body, replacement)

  defp proxy_hmr_host(conn) do
    conn.host <> hmr_port(conn.port, Atom.to_string(conn.scheme)) <> "/"
  end

  defp hmr_port(nil, _scheme), do: ""
  defp hmr_port(443, "https"), do: ""
  defp hmr_port(80, "http"), do: ""
  defp hmr_port(port, _scheme), do: ":" <> Integer.to_string(port)
end
