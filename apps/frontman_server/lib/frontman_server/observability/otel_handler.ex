defmodule FrontmanServer.Observability.OtelHandler do
  @moduledoc """
  Telemetry handler that creates OpenTelemetry spans.

  Subscribes to telemetry events emitted by TelemetryEvents module and
  translates them into OTEL spans with proper parent-child relationships.

  Uses ETS tables to store span contexts for correlation by domain IDs
  (task_id, agent_id, etc.) rather than passing span_ctx through the call stack.

  ## Span Hierarchy

  ```
  task [top-level container for session]
  └── agent root [lifecycle span]
      └── iteration 1
          ├── chat anthropic [LLM call]
          ├── execute_tool [backend tool]
          └── spawn_sub_agent [figma_breakdown]
              └── agent [sub-agent lifecycle]
      └── iteration 2
          └── chat anthropic
  ```
  """

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias FrontmanServer.Observability.Events
  alias FrontmanServer.Observability.MessageSerializer

  @tables [
    :frontman_spans_task,
    :frontman_spans_agent,
    :frontman_spans_iteration,
    :frontman_spans_tool,
    :frontman_spans_mcp,
    :frontman_spans_llm,
    :frontman_spans_spawn
  ]

  @doc """
  Sets up telemetry handlers and creates ETS tables for span storage.

  Call this early in application startup.
  """
  def setup do
    create_ets_tables()
    attach_handlers()
    :ok
  end

  # No defensive checks - if tables already exist, setup/0 was called twice,
  # which is a bug in application startup. Let it crash.
  defp create_ets_tables do
    Enum.each(@tables, fn table ->
      :ets.new(table, [:named_table, :public, :set, read_concurrency: true])
    end)
  end

  defp attach_handlers do
    handlers = [
      {Events.task_start(), &__MODULE__.handle_task_start/4},
      {Events.task_stop(), &__MODULE__.handle_task_stop/4},
      {Events.agent_start(), &__MODULE__.handle_agent_start/4},
      {Events.agent_stop(), &__MODULE__.handle_agent_stop/4},
      {Events.iteration_start(), &__MODULE__.handle_iteration_start/4},
      {Events.iteration_stop(), &__MODULE__.handle_iteration_stop/4},
      {Events.llm_start(), &__MODULE__.handle_llm_start/4},
      {Events.llm_stop(), &__MODULE__.handle_llm_stop/4},
      {Events.tool_start(), &__MODULE__.handle_tool_start/4},
      {Events.tool_stop(), &__MODULE__.handle_tool_stop/4},
      {Events.mcp_tool_start(), &__MODULE__.handle_mcp_tool_start/4},
      {Events.mcp_tool_stop(), &__MODULE__.handle_mcp_tool_stop/4},
      {Events.spawn_sub_agent_start(), &__MODULE__.handle_spawn_start/4},
      {Events.spawn_sub_agent_stop(), &__MODULE__.handle_spawn_stop/4}
    ]

    Enum.each(handlers, fn {event, handler} ->
      handler_id = "frontman_otel_#{Enum.join(event, "_")}"
      :telemetry.attach(handler_id, event, handler, nil)
    end)
  end

  # -- Task Handlers --
  # These handlers are public for telemetry registration but are not part of the public API.

  @doc false
  def handle_task_start(_event, _measurements, %{task_id: task_id}, _config) do
    span_name = "task"

    attributes = [
      {:"frontman.task.id", task_id},
      {:"gen_ai.operation.name", "task"},
      {:"deployment.environment", deployment_environment()}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)

    span_ctx =
      :otel_tracer.start_span(:otel_ctx.new(), tracer, span_name, %{attributes: attributes})

    :ets.insert(:frontman_spans_task, {task_id, span_ctx})
  end

  @doc false
  def handle_task_stop(_event, _measurements, %{task_id: task_id}, _config) do
    case :ets.lookup(:frontman_spans_task, task_id) do
      [{^task_id, span_ctx}] ->
        Tracer.set_current_span(span_ctx)
        Tracer.end_span()
        :ets.delete(:frontman_spans_task, task_id)

      [] ->
        Logger.error(
          "Orphaned task stop event: task_id=#{task_id} has no span. Start event missing?"
        )
    end
  end

  # -- Agent Handlers --

  @doc false
  def handle_agent_start(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, task_id: task_id} = metadata

    span_name = "agent"

    attributes = [
      {:"frontman.agent.id", agent_id},
      {:"frontman.task.id", task_id},
      {:"gen_ai.operation.name", "invoke_agent"},
      {:"gen_ai.agent.name", "frontman-agent"},
      {:"deployment.environment", deployment_environment()}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)

    # Parent is the task span
    ctx =
      case :ets.lookup(:frontman_spans_task, task_id) do
        [{^task_id, task_span_ctx}] ->
          :otel_tracer.set_current_span(:otel_ctx.new(), task_span_ctx)

        [] ->
          :otel_ctx.new()
      end

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :ets.insert(:frontman_spans_agent, {agent_id, span_ctx})
  end

  @doc false
  def handle_agent_stop(_event, _measurements, %{agent_id: agent_id}, _config) do
    case :ets.lookup(:frontman_spans_agent, agent_id) do
      [{^agent_id, span_ctx}] ->
        Tracer.set_current_span(span_ctx)
        Tracer.end_span()
        :ets.delete(:frontman_spans_agent, agent_id)

      [] ->
        Logger.error("Orphaned agent stop event: agent_id=#{agent_id} has no span")
    end
  end

  # -- Iteration Handlers --

  @doc false
  def handle_iteration_start(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, iteration_number: iteration_number} = metadata

    span_name = "iteration #{iteration_number}"

    attributes = [
      {:"frontman.agent.id", agent_id},
      {:"frontman.iteration.number", iteration_number},
      {:"gen_ai.operation.name", "iteration"}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)

    # Parent is the agent span
    ctx =
      case :ets.lookup(:frontman_spans_agent, agent_id) do
        [{^agent_id, agent_span_ctx}] ->
          :otel_tracer.set_current_span(:otel_ctx.new(), agent_span_ctx)

        [] ->
          :otel_ctx.new()
      end

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_span.add_event(span_ctx, "iteration.started", [])

    # Store with composite key {agent_id, iteration_number}
    :ets.insert(:frontman_spans_iteration, {{agent_id, iteration_number}, span_ctx})

    # Also set as process-level current span for LLM/tool spans
    Tracer.set_current_span(span_ctx)
  end

  @doc false
  def handle_iteration_stop(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, iteration_number: iteration_number, status: status} = metadata
    error = Map.get(metadata, :error)

    key = {agent_id, iteration_number}

    case :ets.lookup(:frontman_spans_iteration, key) do
      [{^key, span_ctx}] ->
        Tracer.set_current_span(span_ctx)

        case status do
          :wait_for_tools ->
            Tracer.add_event("iteration.waiting_for_tools", [])

          :stop ->
            Tracer.add_event("iteration.complete", [])

          :error ->
            Tracer.add_event("iteration.error", [{:reason, inspect(error)}])
            Tracer.set_status(:error, inspect(error))
        end

        Tracer.end_span()
        :ets.delete(:frontman_spans_iteration, key)

      [] ->
        Logger.error(
          "Orphaned iteration stop: agent_id=#{agent_id} iteration=#{iteration_number} has no span"
        )
    end
  end

  # -- LLM Handlers --

  # Content blocks larger than this threshold will be flagged in telemetry
  @large_text_threshold 100_000

  @doc false
  def handle_llm_start(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, task_id: task_id, model: model, messages: messages} = metadata

    {provider, model_name} = parse_model(model)
    span_name = "chat #{provider}"

    attributes = [
      {:"gen_ai.operation.name", "chat"},
      {:"gen_ai.system", provider},
      {:"gen_ai.request.model", model_name},
      {:"gen_ai.input.messages",
       messages |> MessageSerializer.serialize_input() |> Jason.encode!()},
      {:"frontman.agent.id", agent_id},
      {:"frontman.task.id", task_id},
      {:"deployment.environment", deployment_environment()}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)

    # LLM span is child of current iteration span
    ctx =
      case find_latest_iteration_span(agent_id) do
        {:ok, iteration_span_ctx} ->
          :otel_tracer.set_current_span(:otel_ctx.new(), iteration_span_ctx)

        :not_found ->
          :otel_ctx.get_current()
      end

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})

    # Check for large content blocks and add events/attributes
    add_large_content_events(span_ctx, messages)

    :ets.insert(:frontman_spans_llm, {agent_id, span_ctx})
  end

  @doc false
  def handle_llm_stop(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id} = metadata

    case :ets.lookup(:frontman_spans_llm, agent_id) do
      [{^agent_id, span_ctx}] ->
        attributes = build_llm_response_attributes(metadata)
        :otel_span.set_attributes(span_ctx, attributes)

        set_llm_error_status(span_ctx, metadata[:error])

        :otel_span.end_span(span_ctx)
        :ets.delete(:frontman_spans_llm, agent_id)

      [] ->
        Logger.error("Orphaned LLM stop event: agent_id=#{agent_id} has no span")
    end
  end

  defp build_llm_response_attributes(metadata) do
    []
    |> add_response_id(metadata[:response_id])
    |> add_output_attributes(metadata[:output_text], metadata[:tool_calls])
    |> add_usage_attributes(metadata[:usage])
  end

  defp add_response_id(attrs, nil), do: attrs
  defp add_response_id(attrs, response_id), do: [{:"gen_ai.response.id", response_id} | attrs]

  defp add_output_attributes(attrs, nil, _tool_calls), do: attrs

  defp add_output_attributes(attrs, output_text, tool_calls) do
    tool_calls = tool_calls || []
    output = MessageSerializer.serialize_output(output_text, tool_calls)
    finish_reasons = if Enum.empty?(tool_calls), do: ["stop"], else: ["tool_calls"]

    [
      {:"gen_ai.output.messages", Jason.encode!(output)},
      {:"gen_ai.response.finish_reasons", finish_reasons}
      | attrs
    ]
  end

  defp add_usage_attributes(attrs, nil), do: attrs

  defp add_usage_attributes(attrs, %{tokens: tokens} = usage) do
    attrs = [
      {:"gen_ai.usage.input_tokens", tokens[:input] || 0},
      {:"gen_ai.usage.output_tokens", tokens[:output] || 0}
      | attrs
    ]

    case usage[:cost] do
      nil -> attrs
      cost -> [{:"gen_ai.usage.cost", cost} | attrs]
    end
  end

  defp add_usage_attributes(attrs, _), do: attrs

  defp set_llm_error_status(_span_ctx, nil), do: :ok

  defp set_llm_error_status(span_ctx, error),
    do: :otel_span.set_status(span_ctx, :error, inspect(error))

  defp set_tool_error_status(_span_ctx, nil), do: :ok

  defp set_tool_error_status(span_ctx, error) do
    error_str = inspect(error)
    :otel_span.set_attributes(span_ctx, [{:"tool.error", error_str}])
    :otel_span.set_status(span_ctx, :error, error_str)
  end

  # -- Backend Tool Handlers --

  @doc false
  def handle_tool_start(_event, _measurements, metadata, _config) do
    %{
      tool_call_id: tool_call_id,
      tool_name: tool_name,
      agent_id: agent_id,
      task_id: task_id,
      arguments: arguments
    } = metadata

    span_name = "execute_tool #{tool_name}"

    attributes = [
      {:"gen_ai.tool.name", tool_name},
      {:"gen_ai.tool.call.id", tool_call_id},
      {:"gen_ai.tool.type", "function"},
      {:"frontman.tool.type", "backend"},
      {:"frontman.agent.id", agent_id},
      {:"frontman.task.id", task_id},
      {:"gen_ai.tool.arguments", Jason.encode!(arguments)}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)

    # Find parent iteration span for this agent
    # We need to find the latest iteration for this agent
    ctx =
      case find_latest_iteration_span(agent_id) do
        {:ok, iteration_span_ctx} ->
          :otel_tracer.set_current_span(:otel_ctx.new(), iteration_span_ctx)

        :not_found ->
          :otel_ctx.get_current()
      end

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    start_time = System.monotonic_time(:millisecond)

    :ets.insert(:frontman_spans_tool, {tool_call_id, {span_ctx, start_time}})
  end

  @doc false
  def handle_tool_stop(_event, _measurements, metadata, _config) do
    %{tool_call_id: tool_call_id, status: status} = metadata

    case :ets.lookup(:frontman_spans_tool, tool_call_id) do
      [{^tool_call_id, {span_ctx, start_time}}] ->
        duration = System.monotonic_time(:millisecond) - start_time

        :otel_span.set_attributes(span_ctx, [
          {:"tool.duration_ms", duration},
          {:"tool.status", status}
        ])

        set_tool_error_status(span_ctx, metadata[:error])

        :otel_span.end_span(span_ctx)
        :ets.delete(:frontman_spans_tool, tool_call_id)

      [] ->
        Logger.error("Orphaned tool stop event: tool_call_id=#{tool_call_id} has no span")
    end
  end

  # -- MCP Tool Handlers --

  @doc false
  def handle_mcp_tool_start(_event, _measurements, metadata, _config) do
    %{
      request_id: request_id,
      tool_call_id: tool_call_id,
      tool_name: tool_name,
      agent_id: agent_id,
      task_id: task_id,
      arguments: arguments
    } = metadata

    span_name = "mcp_tool #{tool_name}"

    attributes = [
      {:"gen_ai.tool.name", tool_name},
      {:"gen_ai.tool.call.id", tool_call_id},
      {:"gen_ai.tool.type", "function"},
      {:"frontman.tool.type", "mcp"},
      {:"frontman.mcp.request_id", request_id},
      {:"frontman.agent.id", agent_id},
      {:"frontman.task.id", task_id},
      {:"gen_ai.tool.arguments", Jason.encode!(arguments)}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)

    # Find parent iteration span for this agent
    ctx =
      case find_latest_iteration_span(agent_id) do
        {:ok, iteration_span_ctx} ->
          :otel_tracer.set_current_span(:otel_ctx.new(), iteration_span_ctx)

        :not_found ->
          :otel_ctx.get_current()
      end

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_span.add_event(span_ctx, "mcp.request_sent", [])

    start_time = System.monotonic_time(:millisecond)
    :ets.insert(:frontman_spans_mcp, {request_id, {span_ctx, start_time}})
  end

  @doc false
  def handle_mcp_tool_stop(_event, _measurements, metadata, _config) do
    %{request_id: request_id, status: status} = metadata

    case :ets.lookup(:frontman_spans_mcp, request_id) do
      [{^request_id, {span_ctx, start_time}}] ->
        duration = System.monotonic_time(:millisecond) - start_time

        :otel_span.add_event(span_ctx, "mcp.response_received", [])

        :otel_span.set_attributes(span_ctx, [
          {:"tool.duration_ms", duration},
          {:"tool.status", status}
        ])

        set_tool_error_status(span_ctx, metadata[:error])

        :otel_span.end_span(span_ctx)
        :ets.delete(:frontman_spans_mcp, request_id)

      [] ->
        Logger.error("Orphaned MCP tool stop event: request_id=#{request_id} has no span")
    end
  end

  # -- Spawn Sub-Agent Handlers --

  @doc false
  def handle_spawn_start(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, task_id: task_id, role: role} = metadata

    span_name = "spawn_sub_agent #{role}"

    attributes = [
      {:"frontman.sub_agent.id", agent_id},
      {:"frontman.task.id", task_id},
      {:"frontman.sub_agent.role", role},
      {:"gen_ai.operation.name", "spawn_sub_agent"}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)

    # Parent is current context (should be within a tool execution or iteration)
    ctx = :otel_ctx.get_current()
    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})

    start_time = System.monotonic_time(:millisecond)
    :ets.insert(:frontman_spans_spawn, {agent_id, {span_ctx, start_time}})
  end

  @doc false
  def handle_spawn_stop(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, status: status} = metadata

    case :ets.lookup(:frontman_spans_spawn, agent_id) do
      [{^agent_id, {span_ctx, start_time}}] ->
        duration = System.monotonic_time(:millisecond) - start_time

        :otel_span.set_attributes(span_ctx, [
          {:"spawn.duration_ms", duration},
          {:"spawn.status", status}
        ])

        if error = metadata[:error] do
          :otel_span.set_status(span_ctx, :error, inspect(error))
        end

        :otel_span.end_span(span_ctx)
        :ets.delete(:frontman_spans_spawn, agent_id)

      [] ->
        Logger.error("Orphaned spawn stop event: agent_id=#{agent_id} has no span")
    end
  end

  # -- Helpers --

  defp add_large_content_events(span_ctx, messages) do
    large_blocks = find_large_content_blocks(messages)

    if large_blocks != [] do
      max_size = large_blocks |> Enum.map(& &1.size) |> Enum.max()
      total_large = length(large_blocks)

      :otel_span.set_attributes(span_ctx, [
        {:"frontman.content.has_large_blocks", true},
        {:"frontman.content.large_block_count", total_large},
        {:"frontman.content.max_block_size_bytes", max_size}
      ])

      Enum.each(large_blocks, fn block ->
        :otel_span.add_event(span_ctx, "large_content_block", [
          {:message_index, block.msg_idx},
          {:block_index, block.block_idx},
          {:role, block.role},
          {:tool_name, block.tool_name || "N/A"},
          {:size_bytes, block.size},
          {:size_formatted, format_size(block.size)},
          {:preview, block.preview}
        ])
      end)
    end
  end

  defp find_large_content_blocks(messages) do
    messages
    |> Enum.with_index()
    |> Enum.flat_map(fn {msg, msg_idx} ->
      check_message_for_large_content(msg, msg_idx)
    end)
  end

  defp check_message_for_large_content(%{role: role, content: content} = msg, msg_idx)
       when is_list(content) do
    tool_name = Map.get(msg, :name) || Map.get(msg, :tool_name)

    content
    |> Enum.with_index()
    |> Enum.flat_map(fn {block, block_idx} ->
      check_content_block(role, tool_name, msg_idx, block_idx, block)
    end)
  end

  defp check_message_for_large_content(%{role: role, content: content} = msg, msg_idx)
       when is_binary(content) do
    size = byte_size(content)

    if size > @large_text_threshold do
      tool_name = Map.get(msg, :name) || Map.get(msg, :tool_name)

      [
        %{
          msg_idx: msg_idx,
          block_idx: 0,
          role: to_string(role),
          tool_name: tool_name,
          size: size,
          preview: String.slice(content, 0, 200)
        }
      ]
    else
      []
    end
  end

  defp check_message_for_large_content(_msg, _msg_idx), do: []

  defp check_content_block(role, tool_name, msg_idx, block_idx, block) do
    text =
      case block do
        %{type: :text, text: text} when is_binary(text) -> text
        %{text: text} when is_binary(text) -> text
        _ -> nil
      end

    if text && byte_size(text) > @large_text_threshold do
      [
        %{
          msg_idx: msg_idx,
          block_idx: block_idx,
          role: to_string(role),
          tool_name: tool_name,
          size: byte_size(text),
          preview: String.slice(text, 0, 200)
        }
      ]
    else
      []
    end
  end

  defp format_size(bytes) when bytes >= 1_000_000, do: "#{Float.round(bytes / 1_000_000, 2)} MB"
  defp format_size(bytes) when bytes >= 1_000, do: "#{Float.round(bytes / 1_000, 2)} KB"
  defp format_size(bytes), do: "#{bytes} bytes"

  defp find_latest_iteration_span(agent_id) do
    # Find all iteration spans for this agent
    match_spec = [
      {{{agent_id, :"$1"}, :"$2"}, [], [{{:"$1", :"$2"}}]}
    ]

    case :ets.select(:frontman_spans_iteration, match_spec) do
      [] ->
        :not_found

      iterations ->
        # Get the highest iteration number
        {_iteration, span_ctx} = Enum.max_by(iterations, fn {iteration, _} -> iteration end)
        {:ok, span_ctx}
    end
  end

  defp parse_model(model) do
    case String.split(model, ":", parts: 2) do
      [provider, name] -> {provider, name}
      [name] -> {"unknown", name}
    end
  end

  defp deployment_environment do
    case Application.get_env(:opentelemetry, :resource) do
      %{deployment: %{environment: env}} -> env
      _ -> "unknown"
    end
  end
end
