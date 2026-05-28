# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PlayGithub.SandboxProxy.WebSocket do
  @moduledoc false

  @behaviour WebSock

  alias FrontmanServerWeb.PlayGithub.SandboxProxy.WebSocket.Upstream

  require Logger

  @upstream_send_timeout_ms 5_000
  @close_upstream_timeout_ms 1_000

  @impl true
  def init(%{target_url: target_url, upstream_headers: upstream_headers} = state) do
    case Upstream.start(
           target_url,
           self(),
           upstream_headers
         ) do
      {:ok, upstream_pid} ->
        {:ok,
         state
         |> Map.put(:upstream_pid, upstream_pid)
         |> Map.put(:upstream_ref, Process.monitor(upstream_pid))}

      {:error, reason} ->
        Logger.warning("Sandbox websocket upstream connect failed: #{inspect(reason)}")

        {:stop, {:upstream_connect_failed, reason}, {1011, "Sandbox websocket unavailable"},
         state}
    end
  end

  @impl true
  def handle_in({message, opcode: :text}, %{upstream_pid: upstream_pid} = state) do
    send_upstream_frame(upstream_pid, {:text, message}, state)
  end

  def handle_in({message, opcode: :binary}, %{upstream_pid: upstream_pid} = state) do
    send_upstream_frame(upstream_pid, {:binary, message}, state)
  end

  @impl true
  def handle_info({:sandbox_proxy_upstream_frame, {:text, message}}, state) do
    {:push, {:text, message}, state}
  end

  def handle_info({:sandbox_proxy_upstream_frame, {:binary, message}}, state) do
    {:push, {:binary, message}, state}
  end

  def handle_info({:sandbox_proxy_upstream_disconnected, reason}, state) do
    Logger.debug("Sandbox websocket upstream disconnected: #{inspect(reason)}")
    {:stop, {:upstream_disconnected, reason}, state}
  end

  def handle_info({:DOWN, upstream_ref, :process, upstream_pid, reason}, state) do
    case upstream_down?(state, upstream_ref, upstream_pid) do
      true -> {:stop, {:upstream_down, reason}, state}
      false -> {:ok, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    close_upstream(state)
  end

  defp send_upstream_frame(upstream_pid, frame, state) do
    case WebSockex.send_frame(upstream_pid, frame, @upstream_send_timeout_ms) do
      :ok -> {:ok, state}
      {:error, reason} -> {:stop, {:upstream_send_failed, reason}, state}
    end
  end

  defp upstream_down?(%{upstream_ref: upstream_ref, upstream_pid: upstream_pid}, ref, pid) do
    case ref do
      ^upstream_ref -> pid == upstream_pid
      _ -> false
    end
  end

  defp upstream_down?(_state, _ref, _pid), do: false

  defp close_upstream(%{upstream_pid: upstream_pid}) do
    WebSockex.cast(upstream_pid, :close)

    receive do
      {:DOWN, _ref, :process, ^upstream_pid, _reason} -> :ok
    after
      @close_upstream_timeout_ms -> :ok
    end
  end

  defp close_upstream(_state), do: :ok
end
