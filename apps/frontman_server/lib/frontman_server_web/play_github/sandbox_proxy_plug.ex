# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PlayGithub.SandboxProxyPlug do
  @moduledoc """
  Runs sandbox proxying on configured PlayGithub hosts before request parsing.

  This stays at the endpoint layer because sandbox previews need raw request
  bodies and fallback proxying for iframe asset paths that the router cannot
  transparently pass through.
  """

  alias FrontmanServerWeb.PlayGithub.SandboxProxy

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case playgithub_host?(conn.host) do
      true -> conn |> Plug.Conn.fetch_query_params() |> SandboxProxy.dispatch()
      false -> conn
    end
  end

  defp playgithub_host?(host) when is_binary(host) do
    normalized_host = String.downcase(host)

    Enum.any?(playgithub_hosts(), &playgithub_host_matches?(normalized_host, &1))
  end

  defp playgithub_host?(_host), do: false

  defp playgithub_host_matches?(host, configured_host) do
    host == configured_host or String.ends_with?(host, "." <> configured_host)
  end

  defp playgithub_hosts do
    :frontman_server
    |> Application.get_env(:playgithub, [])
    |> Keyword.get(:hosts, [])
    |> Enum.map(&String.downcase/1)
  end
end
