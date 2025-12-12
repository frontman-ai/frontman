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
          └── spawn_sub_agent
              └── agent research [sub-agent lifecycle]
                  └── iteration 1
                      └── chat anthropic
      └── iteration 2
          └── chat anthropic
  ```
  """

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

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

  Call this during application startup, after OTelSetup.configure().
  """
  def setup do
    create_ets_tables()
    attach_handlers()
    :ok
  end

  defp create_ets_tables do
    Enum.each(@tables, fn table ->
      if :ets.whereis(table) == :undefined do
        :ets.new(table, [:named_table, :public, :set, read_concurrency: true])
      end
    end)
  end

  defp attach_handlers do
    events = [
      {[:frontman, :task, :start], &handle_task_start/4},
      {[:frontman, :task, :stop], &handle_task_stop/4},
      {[:frontman, :agent, :start], &handle_agent_start/4},
      {[:frontman, :agent, :stop], &handle_agent_stop/4},
      {[:frontman, :iteration, :start], &handle_iteration_start/4},
      {[:frontman, :iteration, :stop], &handle_iteration_stop/4},
      {[:frontman, :llm, :start], &handle_llm_start/4},
      {[:frontman, :llm, :stop], &handle_llm_stop/4},
      {[:frontman, :tool, :start], &handle_tool_start/4},
      {[:frontman, :tool, :stop], &handle_tool_stop/4},
      {[:frontman, :mcp_tool, :start], &handle_mcp_tool_start/4},
      {[:frontman, :mcp_tool, :stop], &handle_mcp_tool_stop/4},
      {[:frontman, :spawn_sub_agent, :start], &handle_spawn_start/4},
      {[:frontman, :spawn_sub_agent, :stop], &handle_spawn_stop/4}
    ]

    Enum.each(events, fn {event, handler} ->
      handler_id = "frontman_otel_#{Enum.join(event, "_")}"
      :telemetry.attach(handler_id, event, handler, nil)
    end)
  end

  # -- Task Handlers --

  defp handle_task_start(_event, _measurements, %{task_id: task_id}, _config) do
    span_name = "task"

    attributes = [
      {:"frontman.task.id", task_id},
      {:"gen_ai.operation.name", "task"},
      {:"deployment.environment", deployment_environment()}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)
    span_ctx = :otel_tracer.start_span(:otel_ctx.new(), tracer, span_name, %{attributes: attributes})

    :ets.insert(:frontman_spans_task, {task_id, span_ctx})
  end

  defp handle_task_stop(_event, _measurements, %{task_id: task_id}, _config) do
    case :ets.lookup(:frontman_spans_task, task_id) do
      [{^task_id, span_ctx}] ->
        Tracer.set_current_span(span_ctx)
        Tracer.end_span()
        :ets.delete(:frontman_spans_task, task_id)

      [] ->
        :ok
    end
  end

  # -- Agent Handlers --

  defp handle_agent_start(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, task_id: task_id, parent_agent_id: parent_agent_id, role: role} = metadata

    role_str = if role, do: Atom.to_string(role), else: "root"
    span_name = "agent #{role_str}"

    attributes =
      [
        {:"frontman.agent.id", agent_id},
        {:"frontman.task.id", task_id},
        {:"gen_ai.operation.name", "invoke_agent"},
        {:"gen_ai.agent.name", "frontman-agent"},
        {:"deployment.environment", deployment_environment()}
      ]
      |> maybe_add_attribute(parent_agent_id, "frontman.agent.parent_id")
      |> maybe_add_attribute(role_str, "frontman.agent.role")

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

  defp handle_agent_stop(_event, _measurements, %{agent_id: agent_id}, _config) do
    case :ets.lookup(:frontman_spans_agent, agent_id) do
      [{^agent_id, span_ctx}] ->
        Tracer.set_current_span(span_ctx)
        Tracer.end_span()
        :ets.delete(:frontman_spans_agent, agent_id)

      [] ->
        :ok
    end
  end

  # -- Iteration Handlers --

  defp handle_iteration_start(_event, _measurements, metadata, _config) do
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

  defp handle_iteration_stop(_event, _measurements, metadata, _config) do
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
        :ok
    end
  end

  # -- LLM Handlers --

  defp handle_llm_start(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, task_id: task_id, model: model, messages: messages} = metadata

    {provider, model_name} = parse_model(model)
    span_name = "chat #{provider}"

    attributes = [
      {:"gen_ai.operation.name", "chat"},
      {:"gen_ai.system", provider},
      {:"gen_ai.request.model", model_name},
      {:"gen_ai.input.messages", messages |> MessageSerializer.serialize_input() |> Jason.encode!()},
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
    :ets.insert(:frontman_spans_llm, {agent_id, span_ctx})
  end

  defp handle_llm_stop(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id} = metadata

    case :ets.lookup(:frontman_spans_llm, agent_id) do
      [{^agent_id, span_ctx}] ->
        # Record response details
        if response_id = metadata[:response_id] do
          :otel_span.set_attributes(span_ctx, [{:"gen_ai.response.id", response_id}])
        end

        if output_text = metadata[:output_text] do
          tool_calls = metadata[:tool_calls] || []
          output = MessageSerializer.serialize_output(output_text, tool_calls)
          finish_reasons = if Enum.empty?(tool_calls), do: ["stop"], else: ["tool_calls"]

          :otel_span.set_attributes(span_ctx, [
            {:"gen_ai.output.messages", Jason.encode!(output)},
            {:"gen_ai.response.finish_reasons", finish_reasons}
          ])
        end

        if usage = metadata[:usage] do
          record_usage_on_span(span_ctx, usage)
        end

        if error = metadata[:error] do
          :otel_span.set_status(span_ctx, :error, inspect(error))
        end

        :otel_span.end_span(span_ctx)
        :ets.delete(:frontman_spans_llm, agent_id)

      [] ->
        :ok
    end
  end

  # -- Backend Tool Handlers --

  defp handle_tool_start(_event, _measurements, metadata, _config) do
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

  defp handle_tool_stop(_event, _measurements, metadata, _config) do
    %{tool_call_id: tool_call_id, status: status} = metadata
    error = Map.get(metadata, :error)

    case :ets.lookup(:frontman_spans_tool, tool_call_id) do
      [{^tool_call_id, {span_ctx, start_time}}] ->
        duration = System.monotonic_time(:millisecond) - start_time

        :otel_span.set_attributes(span_ctx, [
          {:"tool.duration_ms", duration},
          {:"tool.status", status}
        ])

        if status == "error" and error do
          :otel_span.set_attributes(span_ctx, [{:"tool.error", inspect(error)}])
          :otel_span.set_status(span_ctx, :error, inspect(error))
        end

        :otel_span.end_span(span_ctx)
        :ets.delete(:frontman_spans_tool, tool_call_id)

      [] ->
        :ok
    end
  end

  # -- MCP Tool Handlers --

  defp handle_mcp_tool_start(_event, _measurements, metadata, _config) do
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

  defp handle_mcp_tool_stop(_event, _measurements, metadata, _config) do
    %{request_id: request_id, status: status} = metadata
    error = Map.get(metadata, :error)

    case :ets.lookup(:frontman_spans_mcp, request_id) do
      [{^request_id, {span_ctx, start_time}}] ->
        duration = System.monotonic_time(:millisecond) - start_time

        :otel_span.add_event(span_ctx, "mcp.response_received", [])
        :otel_span.set_attributes(span_ctx, [
          {:"tool.duration_ms", duration},
          {:"tool.status", status}
        ])

        if status == "error" and error do
          :otel_span.set_attributes(span_ctx, [{:"tool.error", error}])
          :otel_span.set_status(span_ctx, :error, error)
        end

        :otel_span.end_span(span_ctx)
        :ets.delete(:frontman_spans_mcp, request_id)

      [] ->
        :ok
    end
  end

  # -- Spawn Sub-Agent Handlers --

  defp handle_spawn_start(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id, task_id: task_id, role: role, task_description: task_description} = metadata

    role_str = Atom.to_string(role)
    span_name = "spawn_sub_agent #{role_str}"

    attributes = [
      {:"frontman.agent.id", agent_id},
      {:"frontman.task.id", task_id},
      {:"frontman.sub_agent.role", role_str},
      {:"frontman.sub_agent.task", task_description},
      {:"gen_ai.operation.name", "spawn_sub_agent"}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)

    # Parent is current iteration span
    ctx =
      case find_latest_iteration_span(agent_id) do
        {:ok, iteration_span_ctx} ->
          :otel_tracer.set_current_span(:otel_ctx.new(), iteration_span_ctx)

        :not_found ->
          :otel_ctx.get_current()
      end

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :ets.insert(:frontman_spans_spawn, {agent_id, span_ctx})
  end

  defp handle_spawn_stop(_event, _measurements, metadata, _config) do
    %{agent_id: agent_id} = metadata

    case :ets.lookup(:frontman_spans_spawn, agent_id) do
      [{^agent_id, span_ctx}] ->
        if sub_agent_id = metadata[:sub_agent_id] do
          :otel_span.set_attributes(span_ctx, [
            {:"frontman.sub_agent.id", sub_agent_id},
            {:"spawn.status", "success"}
          ])
          :otel_span.add_event(span_ctx, "sub_agent.spawned", [{:sub_agent_id, sub_agent_id}])
        end

        if error = metadata[:error] do
          :otel_span.set_attributes(span_ctx, [{:"spawn.status", "error"}])
          :otel_span.set_status(span_ctx, :error, inspect(error))
          :otel_span.add_event(span_ctx, "sub_agent.spawn_failed", [{:reason, inspect(error)}])
        end

        :otel_span.end_span(span_ctx)
        :ets.delete(:frontman_spans_spawn, agent_id)

      [] ->
        :ok
    end
  end

  # -- Helpers --

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

  defp maybe_add_attribute(attributes, nil, _attr_name), do: attributes

  defp maybe_add_attribute(attributes, value, attr_name) do
    [{String.to_atom(attr_name), value} | attributes]
  end

  defp record_usage_on_span(span_ctx, %{tokens: tokens} = usage) do
    attributes = [
      {:"gen_ai.usage.input_tokens", tokens[:input] || 0},
      {:"gen_ai.usage.output_tokens", tokens[:output] || 0}
    ]

    attributes =
      if cost = usage[:cost] do
        [{:"gen_ai.usage.cost", cost} | attributes]
      else
        attributes
      end

    :otel_span.set_attributes(span_ctx, attributes)
  end

  defp record_usage_on_span(_span_ctx, _), do: :ok

  defp deployment_environment do
    case Application.get_env(:opentelemetry, :resource) do
      %{deployment: %{environment: env}} -> env
      _ -> "unknown"
    end
  end
end
