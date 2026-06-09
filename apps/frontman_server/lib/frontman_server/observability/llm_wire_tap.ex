# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Observability.LlmWireTap do
  @moduledoc """
  Runtime-only telemetry tap for LLM wire-level debugging.

  Writes Finch request/response and Swarm LLM call telemetry to
  `jsonl_path` as line-delimited JSON.
  """

  @handler_ids [
    {[:finch, :request, :start], &__MODULE__.handle_finch_request_start/4},
    {[:finch, :request, :stop], &__MODULE__.handle_finch_request_stop/4},
    {[:swarm_ai, :llm, :call, :start], &__MODULE__.handle_llm_call_start/4},
    {[:swarm_ai, :llm, :call, :stop], &__MODULE__.handle_llm_call_stop/4}
  ]

  @doc "Enable capture handlers and clear output file."
  def setup do
    path = Application.fetch_env!(:frontman_server, :llm_wire_tap_path)
    hosts = Application.fetch_env!(:frontman_server, :llm_wire_tap_hosts)

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "")

    config = %{
      path: path,
      hosts: hosts
    }

    Enum.each(@handler_ids, fn {event_name, handler} ->
      :telemetry.attach(
        handler_id(event_name),
        event_name,
        handler,
        config
      )
    end)

    :ok
  end

  def handle_finch_request_start(event, measurements, metadata, %{path: path, hosts: hosts}) do
    if capture_finch?(metadata, hosts) do
      emit_line(path, :finch_request_start, event, measurements, metadata)
    end
  end

  def handle_finch_request_stop(event, measurements, metadata, %{path: path, hosts: hosts}) do
    if capture_finch?(metadata, hosts) do
      emit_line(path, :finch_request_stop, event, measurements, metadata)
    end
  end

  def handle_llm_call_start(event, measurements, metadata, %{path: path}) do
    emit_line(path, :llm_call_start, event, measurements, metadata)
  end

  def handle_llm_call_stop(event, measurements, metadata, %{path: path}) do
    emit_line(path, :llm_call_stop, event, measurements, metadata)
  end

  defp handler_id(event_name) do
    "llm-wire-#{Enum.join(event_name, "-")}"
  end

  defp emit_line(path, kind, event, measurements, metadata) do
    payload =
      Jason.encode_to_iodata!(%{
        at: DateTime.to_iso8601(DateTime.utc_now()),
        kind: kind,
        event: inspect(event),
        measurements: inspect(measurements, limit: :infinity),
        metadata: inspect(metadata, limit: :infinity)
      })

    append_payload(path, payload)
  end

  defp append_payload(path, payload) do
    File.write!(path, [payload, "\n"], [:append])
  end

  defp capture_finch?(metadata, hosts) do
    host = metadata_request_host(metadata)
    hosts == [] or host in hosts
  end

  defp metadata_request_host(metadata) do
    case metadata[:request] do
      %{host: host} when is_binary(host) ->
        host

      %{url: %{host: host}} when is_binary(host) ->
        host

      _ ->
        nil
    end
  end
end
