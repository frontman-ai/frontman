# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Observability.ConsoleHandler do
  @moduledoc """
  Telemetry handler that logs events to console.

  Useful for development to see timing info without needing a tracing backend.
  Uses ETS to track start times for duration calculation.

  Handles Swarm events: run, llm, and tool lifecycle.
  """

  require Logger

  alias FrontmanServer.Providers
  alias SwarmAi.Telemetry.Events, as: SwarmEvents

  @table :frontman_console_timing

  def setup do
    :ets.new(@table, [:named_table, :public, :set])
    attach_handlers()
    :ok
  end

  defp attach_handlers do
    handlers = [
      # Swarm events
      {SwarmEvents.run_start(), &__MODULE__.handle_swarm_run_start/4},
      {SwarmEvents.run_stop(), &__MODULE__.handle_swarm_run_stop/4},
      {SwarmEvents.run_exception(), &__MODULE__.handle_swarm_run_exception/4},
      {SwarmEvents.llm_call_start(), &__MODULE__.handle_swarm_llm_start/4},
      {SwarmEvents.llm_call_stop(), &__MODULE__.handle_swarm_llm_stop/4},
      {SwarmEvents.llm_call_exception(), &__MODULE__.handle_swarm_llm_exception/4},
      {SwarmEvents.tool_execute_start(), &__MODULE__.handle_swarm_tool_start/4},
      {SwarmEvents.tool_execute_stop(), &__MODULE__.handle_swarm_tool_stop/4},
      {SwarmEvents.tool_execute_exception(), &__MODULE__.handle_swarm_tool_exception/4}
    ]

    Enum.each(handlers, fn {event, handler} ->
      handler_id = "frontman_console_#{Enum.join(event, "_")}"
      :telemetry.attach(handler_id, event, handler, nil)
    end)
  end

  # ===========================================================================
  # Swarm Run Lifecycle
  # ===========================================================================

  def handle_swarm_run_start(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, execution_module: execution_module} = metadata
    start_time = System.monotonic_time(:millisecond)
    :ets.insert(@table, {{:swarm_run, loop_id}, start_time, execution_module})

    Logger.info(
      "[swarm] run:start loop=#{short_id(loop_id)} execution=#{inspect(execution_module)}"
    )
  end

  def handle_swarm_run_stop(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, status: status, step_count: step_count} = metadata

    case :ets.lookup(@table, {:swarm_run, loop_id}) do
      [{{:swarm_run, ^loop_id}, start_time, execution_module}] ->
        duration = System.monotonic_time(:millisecond) - start_time
        :ets.delete(@table, {:swarm_run, loop_id})

        status_str = format_status(status)

        Logger.info(
          "[swarm] run:stop  loop=#{short_id(loop_id)} execution=#{inspect(execution_module)} " <>
            "#{status_str} steps=#{step_count} (#{duration}ms)"
        )

      [] ->
        Logger.warning("[swarm] run:stop orphaned loop_id=#{loop_id}")
    end
  end

  def handle_swarm_run_exception(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, kind: kind, reason: reason} = metadata
    :ets.delete(@table, {:swarm_run, loop_id})
    Logger.error("[swarm] run:exception loop=#{short_id(loop_id)} #{kind}: #{inspect(reason)}")
  end

  # ===========================================================================
  # Swarm LLM Calls
  # ===========================================================================

  def handle_swarm_llm_start(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step, model: model} = metadata
    start_time = System.monotonic_time(:millisecond)
    :ets.insert(@table, {{:swarm_llm, loop_id, step}, start_time, model})

    Logger.info(
      "[swarm] llm:start  loop=#{short_id(loop_id)} step=#{step} model=#{format_model(model)}"
    )
  end

  def handle_swarm_llm_stop(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step} = metadata
    input = Map.get(metadata, :input_tokens, 0)
    output = Map.get(metadata, :output_tokens, 0)
    tools = Map.get(metadata, :tool_call_count, 0)

    case :ets.lookup(@table, {:swarm_llm, loop_id, step}) do
      [{{:swarm_llm, ^loop_id, ^step}, start_time, model}] ->
        duration = System.monotonic_time(:millisecond) - start_time
        :ets.delete(@table, {:swarm_llm, loop_id, step})

        Logger.info(
          "[swarm] llm:stop   loop=#{short_id(loop_id)} step=#{step} model=#{format_model(model)} " <>
            "(#{duration}ms) [#{input} in / #{output} out] tools=#{tools}"
        )

      [] ->
        :ok
    end
  end

  def handle_swarm_llm_exception(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step, kind: kind, reason: reason} = metadata
    :ets.delete(@table, {:swarm_llm, loop_id, step})

    Logger.error(
      "[swarm] llm:exception loop=#{short_id(loop_id)} step=#{step} #{kind}: #{inspect(reason)}"
    )
  end

  # ===========================================================================
  # Swarm Tool Execution
  # ===========================================================================

  def handle_swarm_tool_start(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step, tool_id: tool_id, tool_name: tool_name} = metadata
    start_time = System.monotonic_time(:millisecond)
    :ets.insert(@table, {{:swarm_tool, loop_id, tool_id}, start_time, tool_name})
    Logger.info("[swarm] tool:start loop=#{short_id(loop_id)} step=#{step} #{tool_name}")
  end

  def handle_swarm_tool_stop(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, tool_id: tool_id, tool_name: tool_name, is_error: is_error} = metadata

    case :ets.lookup(@table, {:swarm_tool, loop_id, tool_id}) do
      [{{:swarm_tool, ^loop_id, ^tool_id}, start_time, _tool_name}] ->
        duration = System.monotonic_time(:millisecond) - start_time
        :ets.delete(@table, {:swarm_tool, loop_id, tool_id})

        status_str = if is_error, do: "✗", else: "✓"

        Logger.info(
          "[swarm] tool:stop  loop=#{short_id(loop_id)} #{tool_name} #{status_str} (#{duration}ms)"
        )

      [] ->
        Logger.warning("[swarm] tool:stop orphaned tool_id=#{tool_id}")
    end
  end

  def handle_swarm_tool_exception(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, tool_id: tool_id, tool_name: tool_name, kind: kind, reason: reason} =
      metadata

    :ets.delete(@table, {:swarm_tool, loop_id, tool_id})

    Logger.error(
      "[swarm] tool:exception loop=#{short_id(loop_id)} #{tool_name} #{kind}: #{inspect(reason)}"
    )
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  defp short_id(id) when is_binary(id), do: String.slice(id, 0, 8)
  defp short_id(id), do: inspect(id)

  defp format_model(model), do: Providers.display_model_name(model)

  defp format_status(:ok), do: "✓"
  defp format_status(:completed), do: "✓"
  defp format_status(:error), do: "✗"
  defp format_status(status), do: "#{status}"
end
