defmodule FrontmanServer.Observability.SwarmOtelHandler do
  @moduledoc """
  Creates OpenTelemetry spans from Swarm telemetry events.

  Swarm emits telemetry events for agent execution (loop, step, llm, tool, child).
  This handler translates those into OTEL spans with proper parent-child relationships.

  The `task_id` comes from `loop.metadata` which is passed by FrontmanServer when
  starting agent execution. This allows correlation back to the task span.

  ## Span Hierarchy

  ```
  task [created by OtelHandler]
  └── loop [swarm:run]
      └── step 1 [swarm:step]
          ├── llm call [swarm:llm:call]
          ├── tool execution [swarm:tool:execute]
          └── child spawn [swarm:child:spawn]
              └── child loop [nested swarm:run]
      └── step 2
          └── llm call
  ```

  ## ETS Tables

  Uses same tables as OtelHandler for task span lookup:
  - `:frontman_spans_task` - task spans keyed by task_id

  Creates additional tables for Swarm spans:
  - `:frontman_spans_loop` - loop spans keyed by loop_id
  - `:frontman_spans_swarm_step` - step spans keyed by {loop_id, step}
  """

  require Logger

  @tables [
    :frontman_spans_loop,
    :frontman_spans_swarm_step,
    :frontman_spans_llm,
    :frontman_spans_tool,
    :frontman_spans_spawn
  ]

  @doc """
  Sets up telemetry handlers and creates ETS tables.
  Call this after OtelHandler.setup/0 in application startup.
  """
  def setup do
    create_ets_tables()
    attach_handlers()
    :ok
  end

  defp create_ets_tables do
    Enum.each(@tables, fn table ->
      :ets.new(table, [:named_table, :public, :set, read_concurrency: true])
    end)
  end

  defp attach_handlers do
    handlers = [
      # Run (loop) events
      {[:swarm, :run, :start], &__MODULE__.handle_run_start/4},
      {[:swarm, :run, :stop], &__MODULE__.handle_run_stop/4},
      {[:swarm, :run, :exception], &__MODULE__.handle_run_exception/4},
      # Step events
      {[:swarm, :step, :start], &__MODULE__.handle_step_start/4},
      {[:swarm, :step, :stop], &__MODULE__.handle_step_stop/4},
      {[:swarm, :step, :exception], &__MODULE__.handle_step_exception/4},
      # LLM events
      {[:swarm, :llm, :call, :start], &__MODULE__.handle_llm_start/4},
      {[:swarm, :llm, :call, :stop], &__MODULE__.handle_llm_stop/4},
      {[:swarm, :llm, :call, :exception], &__MODULE__.handle_llm_exception/4},
      # Tool events
      {[:swarm, :tool, :execute, :start], &__MODULE__.handle_tool_start/4},
      {[:swarm, :tool, :execute, :stop], &__MODULE__.handle_tool_stop/4},
      {[:swarm, :tool, :execute, :exception], &__MODULE__.handle_tool_exception/4},
      # Child spawn events
      {[:swarm, :child, :spawn, :start], &__MODULE__.handle_child_start/4},
      {[:swarm, :child, :spawn, :stop], &__MODULE__.handle_child_stop/4},
      {[:swarm, :child, :spawn, :exception], &__MODULE__.handle_child_exception/4}
    ]

    Enum.each(handlers, fn {event, handler} ->
      handler_id = "swarm_otel_#{Enum.join(event, "_")}"
      :telemetry.attach(handler_id, event, handler, nil)
    end)
  end

  # =============================================================================
  # Run (Loop) Handlers
  # =============================================================================

  @doc false
  def handle_run_start(_event, _measurements, metadata, _config) do
    loop_id = metadata.loop_id
    agent_module = metadata.agent_module
    loop_meta = Map.get(metadata, :metadata, %{})
    task_id = Map.get(loop_meta, :task_id)
    parent_agent_module = Map.get(loop_meta, :parent_agent_module)
    input_messages = Map.get(metadata, :input_messages, [])

    span_name = "agent"

    base_attributes = [
      {:"openinference.span.kind", "AGENT"},
      {:"agent.name", inspect(agent_module)},
      # Arize agent graph attributes - use "agent" as node_id, steps reference this
      {:"graph.node.id", "agent"}
    ]

    # Add parent reference for child agents (enables Arize agent graph visualization)
    base_attributes =
      if parent_agent_module do
        [{:"graph.node.parent_id", "agent"} | base_attributes]
      else
        base_attributes
      end

    base_attributes =
      if task_id, do: [{:"session.id", task_id} | base_attributes], else: base_attributes

    attributes = base_attributes ++ flatten_input_messages(input_messages)

    tracer = :opentelemetry.get_tracer(:frontman_server)
    ctx = with_parent_span(:frontman_spans_task, task_id)

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_loop, loop_id, span_ctx)
  end

  @doc false
  def handle_run_stop(_event, _measurements, metadata, _config) do
    loop_id = metadata.loop_id
    output = Map.get(metadata, :output)

    case lookup_span(:frontman_spans_loop, loop_id) do
      {:ok, span_ctx} ->
        if output do
          :otel_span.set_attributes(span_ctx, [
            {:"output.value", truncate(to_string(output), 10_000)}
          ])
        end

        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_loop, loop_id)

      :not_found ->
        Logger.warning("Orphaned agent stop event: loop_id=#{loop_id} has no span")
    end
  end

  @doc false
  def handle_run_exception(_event, _measurements, metadata, _config) do
    loop_id = metadata.loop_id

    case lookup_span(:frontman_spans_loop, loop_id) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "Exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_loop, loop_id)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # Step Handlers
  # =============================================================================

  @doc false
  def handle_step_start(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step} = metadata

    span_name = "step #{step}"

    attributes = [
      {:"openinference.span.kind", "CHAIN"},
      {:"graph.node.id", "step_#{step}"},
      {:"graph.node.parent_id", "agent"}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)
    ctx = with_parent_span(:frontman_spans_loop, loop_id)

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_swarm_step, {loop_id, step}, span_ctx)
  end

  @doc false
  def handle_step_stop(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step} = metadata
    key = {loop_id, step}

    case lookup_span(:frontman_spans_swarm_step, key) do
      {:ok, span_ctx} ->
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_swarm_step, key)

      :not_found ->
        Logger.warning("Orphaned step stop event: loop_id=#{loop_id} step=#{step} has no span")
    end
  end

  @doc false
  def handle_step_exception(_event, _measurements, metadata, _config) do
    loop_id = metadata.loop_id
    step = metadata.step
    key = {loop_id, step}

    case lookup_span(:frontman_spans_swarm_step, key) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "Exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_swarm_step, key)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # LLM Handlers
  # =============================================================================

  @doc false
  def handle_llm_start(_event, _measurements, metadata, _config) do
    # model_ref: the original model value from metadata — either a string like "openai:gpt-4"
    # or an LLMDB.Model struct (from Codex/resolved models). Needed by llm_system_from_model
    # and llm_provider_from_model which pattern-match on both shapes.
    # model_name: the display string extracted via format_model_name, used for span names/attributes.
    %{loop_id: loop_id, step: step, model: model_ref} = metadata
    input_messages = Map.get(metadata, :messages, [])

    model_name = format_model_name(model_ref)
    span_name = "chat #{model_name}"

    attributes =
      [
        {:"openinference.span.kind", "LLM"},
        {:"llm.model_name", model_name},
        {:"llm.system", llm_system_from_model(model_ref)},
        {:"llm.provider", llm_provider_from_model(model_ref)},
        {:"graph.node.id", "llm"},
        {:"graph.node.parent_id", "step_#{step}"}
      ] ++ flatten_input_messages(input_messages)

    tracer = :opentelemetry.get_tracer(:frontman_server)
    ctx = with_parent_span(:frontman_spans_swarm_step, {loop_id, step})

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_llm, {loop_id, step}, span_ctx)
  end

  @doc false
  def handle_llm_stop(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step} = metadata
    key = {loop_id, step}

    case lookup_span(:frontman_spans_llm, key) do
      {:ok, span_ctx} ->
        # Token usage (OpenInference format)
        if usage = metadata[:usage] do
          prompt_tokens = Map.get(usage, :input_tokens, 0)
          completion_tokens = Map.get(usage, :output_tokens, 0)
          reasoning_tokens = Map.get(usage, :reasoning_tokens, 0)
          cached_tokens = Map.get(usage, :cached_tokens, 0)

          :otel_span.set_attributes(span_ctx, [
            {:"llm.token_count.prompt", prompt_tokens},
            {:"llm.token_count.completion", completion_tokens},
            {:"llm.token_count.reasoning", reasoning_tokens},
            {:"llm.token_count.cached", cached_tokens},
            {:"llm.token_count.total", prompt_tokens + completion_tokens + reasoning_tokens}
          ])
        end

        # Output messages (flattened format)
        output_attrs = flatten_output_messages(metadata[:response], metadata[:tool_calls])
        :otel_span.set_attributes(span_ctx, output_attrs)

        # Reasoning details (thinking text)
        reasoning_attrs = flatten_reasoning_details(metadata[:reasoning_details])
        :otel_span.set_attributes(span_ctx, reasoning_attrs)

        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_llm, key)

      :not_found ->
        Logger.warning("Orphaned LLM stop event: loop_id=#{loop_id} step=#{step} has no span")
    end
  end

  @doc false
  def handle_llm_exception(_event, _measurements, metadata, _config) do
    loop_id = metadata.loop_id
    step = metadata.step
    key = {loop_id, step}

    case lookup_span(:frontman_spans_llm, key) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "LLM exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_llm, key)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # Tool Handlers
  # =============================================================================

  @doc false
  def handle_tool_start(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step, tool_id: tool_id, tool_name: tool_name} = metadata
    arguments = Map.get(metadata, :arguments)

    span_name = "tool #{tool_name}"

    attributes = [
      {:"openinference.span.kind", "TOOL"},
      {:"tool.name", tool_name},
      {:"graph.node.id", "tool_#{tool_name}"},
      {:"graph.node.parent_id", "step_#{step}"}
    ]

    attributes =
      if arguments do
        [{:"tool.parameters", Jason.encode!(arguments)} | attributes]
      else
        attributes
      end

    tracer = :opentelemetry.get_tracer(:frontman_server)
    ctx = with_parent_span(:frontman_spans_swarm_step, {loop_id, step})

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_tool, tool_id, span_ctx)
  end

  @doc false
  def handle_tool_stop(_event, _measurements, metadata, _config) do
    tool_id = metadata.tool_id
    is_error = Map.get(metadata, :is_error, false)
    output = Map.get(metadata, :output)

    case lookup_span(:frontman_spans_tool, tool_id) do
      {:ok, span_ctx} ->
        if output do
          text_output = extract_text_content(output)

          :otel_span.set_attributes(span_ctx, [
            {:"tool.output", text_output}
          ])
        end

        if is_error do
          :otel_span.set_status(span_ctx, :error, "Tool returned error")
        end

        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_tool, tool_id)

      :not_found ->
        Logger.warning("Orphaned tool stop event: tool_id=#{tool_id} has no span")
    end
  end

  @doc false
  def handle_tool_exception(_event, _measurements, metadata, _config) do
    tool_id = metadata.tool_id

    case lookup_span(:frontman_spans_tool, tool_id) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "Tool exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_tool, tool_id)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # Child Spawn Handlers
  # =============================================================================

  @doc false
  def handle_child_start(_event, _measurements, metadata, _config) do
    %{
      parent_loop_id: parent_loop_id,
      parent_step: parent_step,
      tool_call_id: tool_call_id,
      task: task
    } = metadata

    span_name = "spawn_child"

    attributes = [
      {:"openinference.span.kind", "CHAIN"},
      {:"input.value", truncate(task, 2000)}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)
    ctx = with_parent_span(:frontman_spans_swarm_step, {parent_loop_id, parent_step})

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_spawn, tool_call_id, span_ctx)
  end

  @doc false
  def handle_child_stop(_event, _measurements, metadata, _config) do
    tool_call_id = metadata.tool_call_id
    output = Map.get(metadata, :output)

    case lookup_span(:frontman_spans_spawn, tool_call_id) do
      {:ok, span_ctx} ->
        if output do
          :otel_span.set_attributes(span_ctx, [
            {:"output.value", truncate(to_string(output), 10_000)}
          ])
        end

        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_spawn, tool_call_id)

      :not_found ->
        Logger.warning("Orphaned child stop event: tool_call_id=#{tool_call_id} has no span")
    end
  end

  @doc false
  def handle_child_exception(_event, _measurements, metadata, _config) do
    tool_call_id = metadata.tool_call_id

    case lookup_span(:frontman_spans_spawn, tool_call_id) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "Child exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_spawn, tool_call_id)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # Helpers
  # =============================================================================

  # Look up parent span from ETS and create context with it as current span.
  defp with_parent_span(table, key) do
    case :ets.lookup(table, key) do
      [{^key, parent_span}] ->
        ctx = :otel_ctx.new()
        :otel_tracer.set_current_span(ctx, parent_span)

      [] ->
        :otel_ctx.get_current()
    end
  end

  defp store_span(table, key, span_ctx), do: :ets.insert(table, {key, span_ctx})

  defp lookup_span(table, key) do
    case :ets.lookup(table, key) do
      [{^key, span_ctx}] -> {:ok, span_ctx}
      [] -> :not_found
    end
  end

  defp delete_span(table, key), do: :ets.delete(table, key)

  # =============================================================================
  # OpenInference Message Flattening
  # =============================================================================
  # OpenInference uses flattened attribute names with indices:
  # llm.input_messages.0.message.role, llm.input_messages.0.message.content, etc.

  defp flatten_input_messages(messages) when is_list(messages) do
    messages
    |> Enum.with_index()
    |> Enum.flat_map(fn {msg, idx} -> flatten_message(msg, "llm.input_messages.#{idx}") end)
  end

  defp flatten_input_messages(_), do: []

  defp flatten_output_messages(response, tool_calls) do
    role_attr = {:"llm.output_messages.0.message.role", "assistant"}

    content_attr =
      if response && response != "" do
        [{:"llm.output_messages.0.message.content", truncate(response, 10_000)}]
      else
        []
      end

    tool_attrs = flatten_tool_calls(tool_calls || [])

    [role_attr | content_attr] ++ tool_attrs
  end

  defp flatten_message(%{role: role} = msg, prefix) do
    base = [
      {String.to_atom("#{prefix}.message.role"), to_string(role)},
      {String.to_atom("#{prefix}.message.content"), extract_text_content(Map.get(msg, :content))}
    ]

    base ++ flatten_msg_tool_calls(msg, prefix)
  end

  defp flatten_message(%{"role" => role, "content" => content}, prefix) do
    [
      {String.to_atom("#{prefix}.message.role"), to_string(role)},
      {String.to_atom("#{prefix}.message.content"), extract_text_content(content)}
    ]
  end

  defp flatten_message(_, _), do: []

  defp flatten_msg_tool_calls(%{role: :assistant, tool_calls: tcs}, prefix)
       when is_list(tcs) and tcs != [] do
    Enum.flat_map(Enum.with_index(tcs), fn {tc, idx} ->
      tc_prefix = "#{prefix}.message.tool_calls.#{idx}"

      [
        {String.to_atom("#{tc_prefix}.tool_call.function.name"), tool_call_name(tc)},
        {String.to_atom("#{tc_prefix}.tool_call.function.arguments"), tool_call_args(tc)}
      ]
    end)
  end

  defp flatten_msg_tool_calls(_, _), do: []

  defp flatten_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.with_index()
    |> Enum.flat_map(fn {tc, idx} ->
      prefix = "llm.output_messages.0.message.tool_calls.#{idx}"

      [
        {String.to_atom("#{prefix}.tool_call.function.name"), tool_call_name(tc)},
        {String.to_atom("#{prefix}.tool_call.function.arguments"), tool_call_args(tc)}
      ]
    end)
  end

  defp flatten_tool_calls(_), do: []

  # Flatten reasoning_details into OTel attributes
  # Each entry has "text", "index", and possibly "type" (e.g. "reasoning.encrypted")
  defp flatten_reasoning_details(nil), do: []
  defp flatten_reasoning_details([]), do: []

  defp flatten_reasoning_details(details) when is_list(details) do
    # Separate plain thinking text from encrypted signatures
    {plain, encrypted} =
      Enum.split_with(details, fn entry ->
        Map.get(entry, "type") != "reasoning.encrypted"
      end)

    plain_text =
      plain
      |> Enum.sort_by(&Map.get(&1, "index", 0))
      |> Enum.map_join("\n", &Map.get(&1, "text", ""))

    attrs = []

    # Add plain thinking text if present
    attrs =
      if plain_text != "" do
        [{:"llm.reasoning", truncate(plain_text, 10_000)} | attrs]
      else
        attrs
      end

    # Track if encrypted signatures are present (don't log the actual signatures)
    attrs =
      if encrypted != [] do
        [{:"llm.reasoning.has_encrypted_signature", true} | attrs]
      else
        attrs
      end

    attrs
  end

  defp flatten_reasoning_details(_), do: []

  defp tool_call_name(%ReqLLM.ToolCall{} = tc), do: ReqLLM.ToolCall.name(tc)
  defp tool_call_name(%Swarm.ToolCall{name: name}), do: name
  defp tool_call_name(%{tool_name: name}), do: name
  defp tool_call_name(%{name: name}), do: name
  defp tool_call_name(%{"function" => %{"name" => name}}), do: name
  defp tool_call_name(_), do: "unknown"

  defp tool_call_args(%ReqLLM.ToolCall{} = tc), do: ReqLLM.ToolCall.args_json(tc)
  defp tool_call_args(%Swarm.ToolCall{arguments: args}), do: args
  defp tool_call_args(%{arguments: args}) when is_binary(args), do: args
  defp tool_call_args(%{arguments: args}), do: Jason.encode!(args)
  defp tool_call_args(%{"function" => %{"arguments" => args}}), do: args
  defp tool_call_args(_), do: "{}"

  defp extract_text_content(content) when is_binary(content), do: truncate(content, 10_000)

  defp extract_text_content(content) when is_list(content) do
    content
    |> Enum.filter(&text_content?/1)
    |> Enum.map_join("\n", &get_text/1)
    |> truncate(10_000)
  end

  defp extract_text_content(_), do: ""

  defp text_content?(%{type: :text}), do: true
  defp text_content?(%{"type" => "text"}), do: true
  defp text_content?(_), do: false

  defp get_text(%{text: text}), do: text
  defp get_text(%{"text" => text}), do: text
  defp get_text(_), do: ""

  # =============================================================================
  # Model Detection
  # =============================================================================

  # Format model to a string for span names and attributes.
  # Handles LLMDB.Model structs (from Codex/resolved models) and plain strings.
  defp format_model_name(model) when is_binary(model), do: model
  defp format_model_name(%{id: id}) when is_binary(id), do: id
  defp format_model_name(nil), do: "unknown"
  defp format_model_name(model), do: inspect(model)

  defp llm_system_from_model(model) when is_binary(model) do
    cond do
      String.contains?(model, "claude") -> "anthropic"
      String.contains?(model, "gpt") -> "openai"
      String.contains?(model, "gemini") -> "google"
      String.contains?(model, "grok") -> "xai"
      true -> "unknown"
    end
  end

  defp llm_system_from_model(%{id: id}) when is_binary(id), do: llm_system_from_model(id)
  defp llm_system_from_model(_), do: "unknown"

  defp llm_provider_from_model(model) when is_binary(model) do
    cond do
      String.contains?(model, "claude") -> "anthropic"
      String.contains?(model, "gpt") -> "openai"
      String.contains?(model, "gemini") -> "google"
      String.contains?(model, "grok") -> "xai"
      true -> "unknown"
    end
  end

  defp llm_provider_from_model(%{id: id}) when is_binary(id), do: llm_provider_from_model(id)
  defp llm_provider_from_model(_), do: "unknown"

  defp truncate(string, max_length) when is_binary(string) do
    if String.length(string) > max_length do
      String.slice(string, 0, max_length) <> "..."
    else
      string
    end
  end

  defp truncate(other, _), do: inspect(other)
end
