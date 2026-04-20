# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.SandboxPreviewSocket do
  @moduledoc false

  @behaviour WebSock

  defstruct [
    :upstream_conn_pid,
    :upstream_stream_ref,
    :upstream_host,
    :upstream_port,
    :upstream_path,
    :upstream_query,
    :upstream_headers
  ]

  @gun_connect_timeout_ms 5_000
  @gun_upgrade_timeout_ms 5_000

  @impl true
  def init(state) do
    connect_timeout_ms = Map.get(state, :connect_timeout_ms, @gun_connect_timeout_ms)
    upgrade_timeout_ms = Map.get(state, :upgrade_timeout_ms, @gun_upgrade_timeout_ms)

    case connect_upstream(state, connect_timeout_ms, upgrade_timeout_ms) do
      {:ok, conn_pid, stream_ref} ->
        {:ok,
         %__MODULE__{
           upstream_conn_pid: conn_pid,
           upstream_stream_ref: stream_ref,
           upstream_host: state.upstream_host,
           upstream_port: state.upstream_port,
           upstream_path: state.upstream_path,
           upstream_query: state.upstream_query,
           upstream_headers: state.upstream_headers
         }}

      {:error, reason} ->
        {:stop, reason, %__MODULE__{}}
    end
  end

  @impl true
  def handle_in({payload, opcode: :text}, state) do
    :ok = :gun.ws_send(state.upstream_conn_pid, state.upstream_stream_ref, {:text, payload})
    {:ok, state}
  end

  def handle_in({payload, opcode: :binary}, state) do
    :ok = :gun.ws_send(state.upstream_conn_pid, state.upstream_stream_ref, {:binary, payload})
    {:ok, state}
  end

  def handle_in({payload, opcode: :ping}, state) do
    :ok = :gun.ws_send(state.upstream_conn_pid, state.upstream_stream_ref, {:ping, payload})
    {:ok, state}
  end

  def handle_in({payload, opcode: :pong}, state) do
    :ok = :gun.ws_send(state.upstream_conn_pid, state.upstream_stream_ref, {:pong, payload})
    {:ok, state}
  end

  def handle_in({_payload, opcode: :close}, state) do
    :ok = :gun.ws_send(state.upstream_conn_pid, state.upstream_stream_ref, :close)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:gun_ws, conn_pid, stream_ref, {:text, payload}}, state)
      when conn_pid == state.upstream_conn_pid and stream_ref == state.upstream_stream_ref do
    {:push, {:text, payload}, state}
  end

  def handle_info({:gun_ws, conn_pid, stream_ref, {:binary, payload}}, state)
      when conn_pid == state.upstream_conn_pid and stream_ref == state.upstream_stream_ref do
    {:push, {:binary, payload}, state}
  end

  def handle_info({:gun_ws, conn_pid, stream_ref, {:ping, payload}}, state)
      when conn_pid == state.upstream_conn_pid and stream_ref == state.upstream_stream_ref do
    {:push, {:ping, payload}, state}
  end

  def handle_info({:gun_ws, conn_pid, stream_ref, {:pong, payload}}, state)
      when conn_pid == state.upstream_conn_pid and stream_ref == state.upstream_stream_ref do
    {:push, {:pong, payload}, state}
  end

  def handle_info({:gun_ws, conn_pid, stream_ref, {:close, code, reason}}, state)
      when conn_pid == state.upstream_conn_pid and stream_ref == state.upstream_stream_ref do
    {:stop, {:upstream_closed, code, reason}, state}
  end

  def handle_info(
        {:gun_down, conn_pid, _protocol, reason, _killed_streams, _unprocessed_streams},
        state
      )
      when conn_pid == state.upstream_conn_pid do
    {:stop, {:upstream_down, reason}, state}
  end

  def handle_info({:gun_error, conn_pid, stream_ref, reason}, state)
      when conn_pid == state.upstream_conn_pid and stream_ref == state.upstream_stream_ref do
    {:stop, {:upstream_error, reason}, state}
  end

  def handle_info(_message, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    if is_pid(state.upstream_conn_pid) do
      :gun.close(state.upstream_conn_pid)
    end

    :ok
  end

  defp connect_upstream(state, connect_timeout_ms, upgrade_timeout_ms) do
    case :gun.open(String.to_charlist(state.upstream_host), state.upstream_port) do
      {:ok, conn_pid} ->
        with :ok <- await_connection_up(conn_pid, connect_timeout_ms),
             stream_ref <-
               :gun.ws_upgrade(
                 conn_pid,
                 upgrade_path(state.upstream_path, state.upstream_query),
                 state.upstream_headers
               ),
             :ok <- await_upgrade(conn_pid, stream_ref, upgrade_timeout_ms) do
          {:ok, conn_pid, stream_ref}
        else
          {:error, reason} ->
            :gun.close(conn_pid)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp await_connection_up(conn_pid, timeout_ms) do
    receive do
      {:gun_up, ^conn_pid, _protocol} -> :ok
      {:gun_error, ^conn_pid, reason} -> {:error, reason}
    after
      timeout_ms -> {:error, :connect_timeout}
    end
  end

  defp await_upgrade(conn_pid, stream_ref, timeout_ms) do
    receive do
      {:gun_upgrade, ^conn_pid, ^stream_ref, ["websocket"], _headers} ->
        :ok

      {:gun_response, ^conn_pid, ^stream_ref, _fin, status, _headers} ->
        {:error, {:upgrade_rejected, status}}

      {:gun_error, ^conn_pid, ^stream_ref, reason} ->
        {:error, reason}
    after
      timeout_ms -> {:error, :upgrade_timeout}
    end
  end

  defp upgrade_path(path, ""), do: path
  defp upgrade_path(path, query), do: "#{path}?#{query}"
end
