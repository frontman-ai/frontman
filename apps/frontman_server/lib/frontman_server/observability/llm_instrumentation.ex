defmodule FrontmanServer.Observability.LLMInstrumentation do
  @moduledoc """
  OpenTelemetry instrumentation for LLM operations.

  Provides spans following OpenTelemetry GenAI semantic conventions
  for chat operations, tool executions, and agent lifecycle tracking.

  ## Span Hierarchy

  ```
  agent [lifecycle span]
  └── iteration 1
      ├── chat anthropic [LLM call]
      ├── execute_tool [backend tool]
      └── spawn_sub_agent
  └── iteration 2
      └── chat anthropic
  ```
  """

  require OpenTelemetry.Tracer, as: Tracer

  alias FrontmanServer.Observability.MessageSerializer

  # -- Agent Lifecycle Spans --

  @doc """
  Starts an agent lifecycle span. Returns span context to store in state.

  This span lives for the entire agent lifecycle (init → terminate).
  Call `end_agent_span/1` when the agent terminates.
  """
  @spec start_agent_span(String.t(), String.t(), String.t() | nil, atom() | nil) ::
          OpenTelemetry.span_ctx()
  def start_agent_span(agent_id, task_id, parent_agent_id \\ nil, role \\ nil) do
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
      |> maybe_add_attribute(:parent_agent_id, parent_agent_id, "frontman.agent.parent_id")
      |> maybe_add_attribute(:role, role_str, "frontman.agent.role")

    Tracer.start_span(span_name, %{attributes: attributes})
  end

  @doc """
  Ends an agent lifecycle span. Call from terminate/2.
  """
  @spec end_agent_span(OpenTelemetry.span_ctx()) :: :ok
  def end_agent_span({:span_ctx, _, _, _, _, _, _, _, _, _, _} = span_ctx) do
    Tracer.set_current_span(span_ctx)
    Tracer.end_span()
    :ok
  end

  @doc """
  Adds an event to the agent span (e.g., state transitions).
  """
  @spec add_agent_event(OpenTelemetry.span_ctx(), String.t(), keyword()) :: :ok
  def add_agent_event(span_ctx, event_name, attributes \\ []) do
    Tracer.set_current_span(span_ctx)
    Tracer.add_event(event_name, attributes)
    :ok
  end

  # -- Iteration Spans --

  @doc """
  Wraps an iteration with an OpenTelemetry span.

  Creates a span named "iteration {n}" as a child of the agent span.
  """
  @spec with_iteration_span(
          OpenTelemetry.span_ctx(),
          String.t(),
          pos_integer(),
          String.t(),
          (-> result)
        ) :: result
        when result: term()
  def with_iteration_span(agent_span_ctx, agent_id, iteration_number, trigger, callback)
      when is_function(callback, 0) do
    span_name = "iteration #{iteration_number}"

    # Create a context with the agent span as parent
    ctx = :otel_tracer.set_current_span(:otel_ctx.new(), agent_span_ctx)

    attributes = [
      {:"frontman.agent.id", agent_id},
      {:"frontman.iteration.number", iteration_number},
      {:"frontman.iteration.trigger", trigger},
      {:"gen_ai.operation.name", "iteration"}
    ]

    Tracer.with_span ctx, span_name, %{attributes: attributes} do
      Tracer.add_event("iteration.started", [])
      result = callback.()

      case result do
        {:wait_for_tools, _state} ->
          Tracer.add_event("iteration.waiting_for_tools", [])

        {:stop, _state} ->
          Tracer.add_event("iteration.complete", [])

        {:error, reason, _state} ->
          Tracer.add_event("iteration.error", [{:reason, inspect(reason)}])
      end

      result
    end
  end

  @doc """
  Records that the iteration is now waiting for tools/sub-agents.
  """
  @spec record_waiting_for_tools(non_neg_integer()) :: :ok
  def record_waiting_for_tools(pending_count) do
    Tracer.add_event("iteration.waiting_for_tools", [{:pending_count, pending_count}])
    :ok
  end

  @doc """
  Wraps an LLM call with an OpenTelemetry span.

  Creates a span named "chat {provider}" with GenAI semantic attributes.

  ## Options

  - `:agent_id` - Optional agent ID for additional context
  - `:task_id` - Optional task ID for additional context

  ## Example

      LLMInstrumentation.with_llm_span(
        "anthropic:claude-sonnet-4",
        messages,
        [agent_id: "agent-123"],
        fn ->
          ReqLLM.stream_text(model, messages, opts)
        end
      )
  """
  @spec with_llm_span(String.t(), list(), keyword(), (-> result)) :: result when result: term()
  def with_llm_span(model, messages, opts \\ [], callback) when is_function(callback, 0) do
    {provider, model_name} = parse_model(model)
    span_name = "chat #{provider}"

    attributes =
      [
        {:"gen_ai.operation.name", "chat"},
        {:"gen_ai.system", provider},
        {:"gen_ai.request.model", model_name},
        {:"gen_ai.input.messages", messages |> MessageSerializer.serialize_input() |> Jason.encode!()},
        {:"deployment.environment", deployment_environment()}
      ]
      |> maybe_add_attribute(:agent_id, opts[:agent_id], "frontman.agent.id")
      |> maybe_add_attribute(:task_id, opts[:task_id], "frontman.task.id")

    Tracer.with_span span_name, %{attributes: attributes} do
      callback.()
    end
  end

  @doc """
  Creates a child span for tool execution.

  Creates a span named "execute_tool {tool_name}" with tool-specific attributes.

  ## Options

  - `:agent_id` - Agent ID for context
  - `:task_id` - Task ID for context
  - `:tool_type` - "backend" or "mcp" (defaults to "backend")
  - `:arguments` - Tool input arguments (map)

  ## Example

      LLMInstrumentation.with_tool_span("list_todos", "call_123", [agent_id: "agent_123", arguments: %{"list_id" => "123"}], fn ->
        execute_tool(tool, arguments)
      end)
  """
  @spec with_tool_span(String.t(), String.t(), keyword(), (-> result)) :: result
        when result: term()
  def with_tool_span(tool_name, tool_call_id, opts \\ [], callback) when is_function(callback, 0) do
    span_name = "execute_tool #{tool_name}"

    attributes =
      [
        {:"gen_ai.tool.name", tool_name},
        {:"gen_ai.tool.call.id", tool_call_id},
        {:"gen_ai.tool.type", "function"},
        {:"frontman.tool.type", Keyword.get(opts, :tool_type, "backend")}
      ]
      |> maybe_add_attribute(:agent_id, opts[:agent_id], "frontman.agent.id")
      |> maybe_add_attribute(:task_id, opts[:task_id], "frontman.task.id")
      |> maybe_add_json_attribute(:arguments, opts[:arguments], "gen_ai.tool.arguments")

    Tracer.with_span span_name, %{attributes: attributes} do
      start_time = System.monotonic_time(:millisecond)
      result = callback.()
      duration = System.monotonic_time(:millisecond) - start_time

      Tracer.set_attribute(:"tool.duration_ms", duration)

      case result do
        {:ok, _} ->
          Tracer.set_attribute(:"tool.status", "success")

        {:error, reason} ->
          Tracer.set_attribute(:"tool.status", "error")
          Tracer.set_attribute(:"tool.error", inspect(reason))
      end

      result
    end
  end

  @doc """
  Records token usage on the current span.

  Call this after receiving the LLM response with usage data.
  """
  @spec record_usage(map()) :: :ok
  def record_usage(%{tokens: tokens} = usage) do
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

    Tracer.set_attributes(attributes)
    :ok
  end

  def record_usage(_), do: :ok

  @doc """
  Records output messages and finish reason on current span.

  Call this after processing the LLM response.
  """
  @spec record_output(String.t(), list()) :: :ok
  def record_output(text, tool_calls) do
    output = MessageSerializer.serialize_output(text, tool_calls)
    finish_reasons = if Enum.empty?(tool_calls), do: ["stop"], else: ["tool_calls"]

    Tracer.set_attributes([
      {:"gen_ai.output.messages", Jason.encode!(output)},
      {:"gen_ai.response.finish_reasons", finish_reasons}
    ])

    :ok
  end

  @doc """
  Records the response ID on current span.
  """
  @spec record_response_id(String.t() | nil) :: :ok
  def record_response_id(nil), do: :ok

  def record_response_id(response_id) do
    Tracer.set_attribute(:"gen_ai.response.id", response_id)
    :ok
  end

  @doc """
  Records an error on the current span.
  """
  @spec record_error(term()) :: :ok
  def record_error(reason) do
    Tracer.set_status(:error, inspect(reason))
    :ok
  end

  # -- Sub-Agent Spans --

  alias FrontmanServer.Agents.Agent

  @doc """
  Wraps sub-agent spawn with an OpenTelemetry span.

  Creates a span named "spawn_sub_agent {role}" capturing the spawn decision and outcome.
  - `parent` - The agent that is spawning the sub-agent
  - `role` - The role atom for the sub-agent (:research, :planning, :validator)
  - `sub_agent_task_description` - String describing what the sub-agent should do
  """
  @spec with_spawn_sub_agent_span(Agent.t(), atom(), String.t(), (-> result)) :: result
        when result: term()
  def with_spawn_sub_agent_span(
        %Agent{id: agent_id, task_id: task_id},
        role,
        sub_agent_task_description,
        callback
      )
      when is_function(callback, 0) do
    role_str = Atom.to_string(role)
    span_name = "spawn_sub_agent #{role_str}"

    attributes = [
      {:"frontman.agent.id", agent_id},
      {:"frontman.task.id", task_id},
      {:"frontman.sub_agent.role", role_str},
      {:"frontman.sub_agent.task", sub_agent_task_description},
      {:"gen_ai.operation.name", "spawn_sub_agent"}
    ]

    Tracer.with_span span_name, %{attributes: attributes} do
      result = callback.()

      case result do
        {:ok, sub_agent} ->
          Tracer.set_attributes([
            {:"frontman.sub_agent.id", sub_agent.id},
            {:"spawn.status", "success"}
          ])
          Tracer.add_event("sub_agent.spawned", [{:sub_agent_id, sub_agent.id}])

        {:error, _role, _task, reason} ->
          Tracer.set_attributes([{:"spawn.status", "error"}])
          Tracer.set_status(:error, inspect(reason))
          Tracer.add_event("sub_agent.spawn_failed", [{:reason, inspect(reason)}])
      end

      result
    end
  end

  # -- MCP Tool Spans --

  @doc """
  Starts a span for an MCP (remote) tool call.

  Returns a map containing span context and start time for later completion.
  Store this in pending_mcp_calls and pass to `end_mcp_tool_span/3` when response arrives.

  The optional `parent_span_ctx` is used to make this span a child of the iteration
  span that triggered the tool call.
  """
  @spec start_mcp_tool_span(String.t(), String.t(), String.t(), String.t(), integer(), map(), term()) ::
          map()
  def start_mcp_tool_span(tool_name, tool_call_id, agent_id, task_id, request_id, arguments, parent_span_ctx \\ nil) do
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

    # Create context with parent span if provided
    ctx =
      if parent_span_ctx do
        :otel_tracer.set_current_span(:otel_ctx.new(), parent_span_ctx)
      else
        :otel_ctx.get_current()
      end

    span_ctx = Tracer.start_span(ctx, span_name, %{attributes: attributes})
    Tracer.set_current_span(span_ctx)
    Tracer.add_event("mcp.request_sent", [])

    %{
      span_ctx: span_ctx,
      start_time: System.monotonic_time(:millisecond)
    }
  end

  @doc """
  Ends an MCP tool span with success status.
  """
  @spec end_mcp_tool_span_success(map()) :: :ok
  def end_mcp_tool_span_success(%{span_ctx: span_ctx, start_time: start_time}) do
    duration = System.monotonic_time(:millisecond) - start_time

    Tracer.set_current_span(span_ctx)
    Tracer.add_event("mcp.response_received", [])
    Tracer.set_attributes([
      {:"tool.duration_ms", duration},
      {:"tool.status", "success"}
    ])
    Tracer.end_span()
    :ok
  end

  @doc """
  Ends an MCP tool span with error status.
  """
  @spec end_mcp_tool_span_error(map(), String.t()) :: :ok
  def end_mcp_tool_span_error(%{span_ctx: span_ctx, start_time: start_time}, error_message) do
    duration = System.monotonic_time(:millisecond) - start_time

    Tracer.set_current_span(span_ctx)
    Tracer.add_event("mcp.response_received", [])
    Tracer.set_attributes([
      {:"tool.duration_ms", duration},
      {:"tool.status", "error"},
      {:"tool.error", error_message}
    ])
    Tracer.set_status(:error, error_message)
    Tracer.end_span()
    :ok
  end

  # Parses model string like "anthropic:claude-sonnet-4" into {provider, model_name}
  @doc false
  def parse_model(model) do
    case String.split(model, ":", parts: 2) do
      [provider, name] -> {provider, name}
      [name] -> {"unknown", name}
    end
  end

  defp maybe_add_attribute(attributes, _key, nil, _attr_name), do: attributes

  defp maybe_add_attribute(attributes, _key, value, attr_name) do
    [{String.to_atom(attr_name), value} | attributes]
  end

  defp maybe_add_json_attribute(attributes, _key, nil, _attr_name), do: attributes

  defp maybe_add_json_attribute(attributes, _key, value, attr_name) do
    [{String.to_atom(attr_name), Jason.encode!(value)} | attributes]
  end

  defp deployment_environment do
    case Application.get_env(:opentelemetry, :resource) do
      %{deployment: %{environment: env}} -> env
      _ -> "unknown"
    end
  end
end
