defmodule FrontmanServer.Observability.ConsoleHandler do
  @moduledoc """
  Telemetry handler that logs events to console.

  Useful for development to see timing info without needing a tracing backend.
  Uses ETS to track start times for duration calculation.
  """

  require Logger

  alias FrontmanServer.Observability.Events

  @table :frontman_console_timing

  def setup do
    :ets.new(@table, [:named_table, :public, :set])
    attach_handlers()
    :ok
  end

  defp attach_handlers do
    handlers = [
      {Events.mcp_tool_start(), &__MODULE__.handle_mcp_tool_start/4},
      {Events.mcp_tool_stop(), &__MODULE__.handle_mcp_tool_stop/4},
      {Events.tool_start(), &__MODULE__.handle_tool_start/4},
      {Events.tool_stop(), &__MODULE__.handle_tool_stop/4},
      {Events.llm_start(), &__MODULE__.handle_llm_start/4},
      {Events.llm_stop(), &__MODULE__.handle_llm_stop/4}
    ]

    Enum.each(handlers, fn {event, handler} ->
      handler_id = "frontman_console_#{Enum.join(event, "_")}"
      :telemetry.attach(handler_id, event, handler, nil)
    end)
  end

  # MCP Tools

  def handle_mcp_tool_start(_event, _measurements, metadata, _config) do
    %{request_id: request_id, tool_name: tool_name} = metadata
    start_time = System.monotonic_time(:millisecond)
    :ets.insert(@table, {{:mcp, request_id}, start_time, tool_name})
    Logger.info("[telemetry] mcp_tool:start #{tool_name}")
  end

  def handle_mcp_tool_stop(_event, _measurements, metadata, _config) do
    %{request_id: request_id, status: status} = metadata

    case :ets.lookup(@table, {:mcp, request_id}) do
      [{{:mcp, ^request_id}, start_time, tool_name}] ->
        duration = System.monotonic_time(:millisecond) - start_time
        :ets.delete(@table, {:mcp, request_id})

        status_str = if status == "success", do: "✓", else: "✗ #{status}"
        Logger.info("[telemetry] mcp_tool:stop  #{tool_name} #{status_str} (#{duration}ms)")

      [] ->
        Logger.warning("[telemetry] mcp_tool:stop orphaned request_id=#{request_id}")
    end
  end

  # Backend Tools

  def handle_tool_start(_event, _measurements, metadata, _config) do
    %{tool_call_id: tool_call_id, tool_name: tool_name} = metadata
    start_time = System.monotonic_time(:millisecond)
    :ets.insert(@table, {{:tool, tool_call_id}, start_time, tool_name})
    Logger.info("[telemetry] tool:start #{tool_name}")
  end

  def handle_tool_stop(_event, _measurements, metadata, _config) do
    %{tool_call_id: tool_call_id, status: status} = metadata

    case :ets.lookup(@table, {:tool, tool_call_id}) do
      [{{:tool, ^tool_call_id}, start_time, tool_name}] ->
        duration = System.monotonic_time(:millisecond) - start_time
        :ets.delete(@table, {:tool, tool_call_id})

        status_str = if status == "success", do: "✓", else: "✗ #{status}"
        Logger.info("[telemetry] tool:stop  #{tool_name} #{status_str} (#{duration}ms)")

      [] ->
        Logger.warning("[telemetry] tool:stop orphaned tool_call_id=#{tool_call_id}")
    end
  end

  # LLM Calls

  def handle_llm_start(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, model: model} = metadata
    start_time = System.monotonic_time(:millisecond)
    :ets.insert(@table, {{:llm, agent_id}, start_time, model})
    Logger.info("[telemetry] llm:start #{model || "unknown"}")
  end

  def handle_llm_stop(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id} = metadata

    case :ets.lookup(@table, {:llm, agent_id}) do
      [{{:llm, ^agent_id}, start_time, model}] ->
        duration = System.monotonic_time(:millisecond) - start_time
        :ets.delete(@table, {:llm, agent_id})

        usage = format_usage(metadata[:usage])
        Logger.info("[telemetry] llm:stop  #{model || "unknown"} (#{duration}ms)#{usage}")

      [] ->
        # LLM stop without start can happen if multiple LLM calls for same agent
        :ok
    end
  end

  defp format_usage(nil), do: ""

  defp format_usage(usage) when is_map(usage) do
    input = Map.get(usage, :input_tokens) || Map.get(usage, "input_tokens")
    output = Map.get(usage, :output_tokens) || Map.get(usage, "output_tokens")

    if input || output do
      " [#{input || 0} in / #{output || 0} out]"
    else
      ""
    end
  end

  defp format_usage(_), do: ""
end
