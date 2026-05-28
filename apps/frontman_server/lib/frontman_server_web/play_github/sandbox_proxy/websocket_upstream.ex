# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PlayGithub.SandboxProxy.WebSocket.Upstream do
  @moduledoc false

  use WebSockex

  @connect_timeout_ms 5_000
  @recv_timeout_ms 5_000

  def start(target_url, owner_pid, headers) do
    WebSockex.start(
      target_url,
      __MODULE__,
      %{owner_pid: owner_pid},
      websocket_options(target_url, headers)
    )
  end

  @impl true
  def handle_frame({:text, message}, %{owner_pid: owner_pid} = state) do
    send(owner_pid, {:sandbox_proxy_upstream_frame, {:text, message}})
    {:ok, state}
  end

  def handle_frame({:binary, message}, %{owner_pid: owner_pid} = state) do
    send(owner_pid, {:sandbox_proxy_upstream_frame, {:binary, message}})
    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{reason: reason}, %{owner_pid: owner_pid} = state) do
    send(owner_pid, {:sandbox_proxy_upstream_disconnected, reason})
    {:ok, state}
  end

  @impl true
  def handle_cast(:close, state) do
    {:close, state}
  end

  defp websocket_options(target_url, headers) do
    [
      extra_headers: headers,
      socket_connect_timeout: @connect_timeout_ms,
      socket_recv_timeout: @recv_timeout_ms
    ]
    |> put_ssl_options(target_url)
  end

  defp put_ssl_options(options, target_url) do
    case URI.parse(target_url) do
      %URI{scheme: "wss", host: host} when is_binary(host) ->
        Keyword.put(options, :ssl_options, ssl_options(host))

      _ ->
        options
    end
  end

  defp ssl_options(host) do
    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end
end
