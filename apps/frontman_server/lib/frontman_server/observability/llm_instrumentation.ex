defmodule FrontmanServer.Observability.LLMInstrumentation do
  @moduledoc """
  OpenTelemetry instrumentation for LLM operations.

  Provides spans following OpenTelemetry GenAI semantic conventions
  for chat operations and tool executions.
  """

  require OpenTelemetry.Tracer, as: Tracer

  alias FrontmanServer.Observability.MessageSerializer

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

  ## Example

      LLMInstrumentation.with_tool_span("list_todos", "call_123", fn ->
        execute_tool(tool, arguments)
      end)
  """
  @spec with_tool_span(String.t(), String.t(), (-> result)) :: result when result: term()
  def with_tool_span(tool_name, tool_call_id, callback) when is_function(callback, 0) do
    span_name = "execute_tool #{tool_name}"

    attributes = [
      {:"gen_ai.tool.name", tool_name},
      {:"gen_ai.tool.call.id", tool_call_id},
      {:"gen_ai.tool.type", "function"}
    ]

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

  defp deployment_environment do
    case Application.get_env(:opentelemetry, :resource) do
      %{deployment: %{environment: env}} -> env
      _ -> "unknown"
    end
  end
end
