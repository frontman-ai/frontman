defmodule FrontmanServer.Tasks.Execution do
  @moduledoc """
  Orchestrates agent execution for tasks.

  This module handles the mechanics of running an LLM agent loop:
  - Building agent configuration from task data
  - Submitting runs to SwarmAi.Runtime
  - Translating agent events to persistence calls and PubSub broadcasts
  - Routing tool result notifications to waiting executors

  ## Telemetry

  All agent telemetry is emitted by Swarm. This module passes `task_id` via
  metadata, which flows through all Swarm telemetry events.
  """

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Image
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.{Model, Registry, ResolvedKey}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.{Framework, RootAgent, ToolExecutor}
  alias FrontmanServer.Tasks.{Interaction, Task}
  alias SwarmAi.LLM.Chunk
  alias SwarmAi.Message

  @doc """
  Cancels a running execution for the given task.

  Returns `:ok` if the execution was cancelled, `{:error, :not_running}` if none is running.
  """
  @spec cancel(Scope.t(), String.t()) :: :ok | {:error, :not_running}
  def cancel(%Scope{}, task_id) do
    SwarmAi.Runtime.cancel(FrontmanServer.AgentRuntime, task_id)
  end

  @doc """
  Returns true if an execution is currently running for the given task.
  """
  @spec running?(Scope.t(), String.t()) :: boolean()
  def running?(%Scope{}, task_id) do
    SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)
  end

  @doc """
  Runs an agent execution for a task.

  Resolves the API key, builds the agent configuration from the task,
  and submits the run to SwarmAi.Runtime.

  ## Options
  - `:tools` - List of tool definitions for LLM (default: [])
  - `:model` - LLM model spec (defaults to provider default)
  - `:env_api_key` - Map of provider => api_key from client's environment
  - `:agent` - Custom agent struct implementing SwarmAi.Agent (for testing)

  ## Returns
  - `{:ok, pid}` - Execution started successfully
  - `{:ok, :already_running}` - An execution is already running for this task
  - `{:error, :no_api_key}` - No API key available
  - `{:error, :usage_limit_exceeded}` - Server key quota exhausted
  """
  @spec run(Scope.t(), Task.t(), keyword()) ::
          {:ok, pid() | :already_running} | {:error, :no_api_key | :usage_limit_exceeded | term()}
  def run(%Scope{} = scope, %Task{} = task, opts \\ []) do
    tools = Keyword.get(opts, :tools, [])
    env_api_key = Keyword.get(opts, :env_api_key, %{})
    model = opts |> Keyword.get(:model) |> Model.resolve_string()

    # Resolve API key at the domain layer (earliest point)
    case Providers.prepare_api_key(scope, model, env_api_key) do
      {:ok, api_key_info} ->
        task_id = task.task_id
        topic = Tasks.topic(task_id)
        agent = build_agent(task, tools, opts, api_key_info)

        messages =
          task.interactions
          |> Interaction.to_llm_messages()
          |> Enum.map(&to_swarm_message/1)
          |> maybe_constrain_images(api_key_info.provider)

        mcp_tool_defs = Keyword.get(opts, :mcp_tool_defs, [])

        submit_to_runtime(scope, agent, task_id, topic, messages,
          api_key_info: api_key_info,
          mcp_tool_defs: mcp_tool_defs
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Notifies that a tool result has arrived.

  Routes the result to the blocking executor via Registry metadata.
  Called by the Tasks facade after persisting the tool result interaction.
  No-ops when no executor is waiting (backend tools execute synchronously).
  """
  @spec notify_tool_result(Scope.t(), String.t(), term(), boolean()) :: :ok
  def notify_tool_result(%Scope{}, tool_call_id, result, is_error) do
    case Elixir.Registry.lookup(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id}) do
      [{_pid, %{caller_pid: caller}}] ->
        encoded = encode_result_for_swarm(result)
        send(caller, {:tool_result, tool_call_id, encoded, is_error})
        :ok

      [] ->
        :ok
    end
  end

  # --- Private ---

  # Submits an agent to SwarmAi.Runtime with lifecycle callbacks.
  #
  # Dialyzer warning suppressed: protocol dispatch on Agent can't be statically proven.
  @dialyzer {:nowarn_function, submit_to_runtime: 6}
  defp submit_to_runtime(scope, agent, task_id, topic, messages, opts) do
    %ResolvedKey{} = resolved_key = Keyword.fetch!(opts, :api_key_info)

    # Build tool executor that handles both backend and MCP tools.
    mcp_tools = Map.get(agent, :tools, [])
    mcp_tool_defs = Keyword.get(opts, :mcp_tool_defs, [])
    llm_opts = [api_key: resolved_key.api_key, model: resolved_key.model]

    tool_executor =
      ToolExecutor.make_executor(scope, task_id,
        mcp_tools: mcp_tools,
        mcp_tool_defs: mcp_tool_defs,
        llm_opts: llm_opts
      )

    # Emit task start telemetry BEFORE Runtime.run to avoid race with task_stop
    # in callbacks — the agent may complete before this line returns.
    TelemetryEvents.task_start(task_id)

    SwarmAi.Runtime.run(FrontmanServer.AgentRuntime, task_id, agent, messages,
      metadata: %{task_id: task_id},
      tool_executor: tool_executor,
      on_chunk: &handle_stream_chunk(&1, topic),
      on_response: fn response ->
        metadata = build_response_metadata(response)
        Tasks.add_agent_response(scope, task_id, response.content || "", metadata)
      end,
      on_complete: fn {:ok, _result, loop_id} ->
        Providers.record_usage(scope, resolved_key)
        Tasks.add_agent_completed(scope, task_id)
        broadcast(topic, :agent_completed)
        Logger.debug("Execution completed for task #{task_id}, loop_id: #{loop_id}")
        TelemetryEvents.task_stop(task_id)
      end,
      on_error: fn {:error, reason, loop_id} ->
        Logger.error(
          "Execution failed for task #{task_id}, loop_id: #{loop_id}, reason: #{inspect(reason)}"
        )

        Sentry.capture_message("Agent execution failed",
          level: :error,
          tags: %{error_type: "agent_execution_error"},
          extra: %{
            task_id: task_id,
            loop_id: loop_id,
            reason: inspect(reason)
          }
        )

        broadcast(topic, {:agent_error, inspect(reason)})
        TelemetryEvents.task_stop(task_id)
      end,
      on_crash: fn {reason, stacktrace} ->
        Logger.error("Execution crashed for task #{task_id}, reason: #{inspect(reason)}")

        if is_exception(reason) do
          Sentry.capture_exception(reason,
            stacktrace: stacktrace,
            tags: %{error_type: "agent_crash"},
            extra: %{task_id: task_id}
          )
        else
          Sentry.capture_message("Agent execution crashed",
            level: :error,
            tags: %{error_type: "agent_crash"},
            extra: %{
              task_id: task_id,
              reason: inspect(reason)
            }
          )
        end

        broadcast(topic, {:agent_error, format_crash_reason(reason)})
        TelemetryEvents.task_stop(task_id)
      end,
      on_cancelled: fn ->
        broadcast(topic, :agent_cancelled)
        TelemetryEvents.task_stop(task_id)
      end
    )
    |> case do
      {:ok, pid} ->
        {:ok, pid}

      {:error, :already_running} ->
        # No agent launched — close the telemetry span we opened
        TelemetryEvents.task_stop(task_id)
        {:ok, :already_running}

      error ->
        # Telemetry was started but agent failed to launch — stop span
        TelemetryEvents.task_stop(task_id)
        error
    end
  end

  defp build_agent(%Task{} = task, tools, opts, %ResolvedKey{} = resolved_key) do
    case Keyword.get(opts, :agent) do
      nil ->
        fw = Framework.from_string(task.framework)
        has_typescript_react = Framework.has_typescript_react?(fw)

        # Derive prompt data from task interactions
        project_rules =
          task.interactions
          |> Enum.filter(&match?(%Interaction.DiscoveredProjectRule{}, &1))

        project_structure =
          task.interactions
          |> Enum.find(&match?(%Interaction.DiscoveredProjectStructure{}, &1))
          |> case do
            nil -> nil
            struct -> struct.summary
          end

        {model_spec, llm_opts} = ResolvedKey.to_llm_args(resolved_key, max_tokens: 16_384)

        RootAgent.new(
          tools: tools,
          has_annotations: Interaction.has_annotations?(task.interactions),
          has_typescript_react: has_typescript_react,
          framework: fw,
          model: model_spec,
          llm_opts: llm_opts,
          project_rules: project_rules,
          project_structure: project_structure
        )

      custom_agent ->
        custom_agent
    end
  end

  # Providers that declare a max_image_dimension hard-reject images exceeding
  # that limit (e.g. Anthropic at 7680px). Others auto-resize so we skip.
  defp maybe_constrain_images(messages, provider) do
    case Registry.max_image_dimension(provider) do
      nil -> messages
      max -> Enum.map(messages, &constrain_message_images(&1, max))
    end
  end

  defp constrain_message_images(msg, max) do
    %{msg | content: Enum.map(msg.content, &constrain_image_part(&1, max))}
  end

  defp constrain_image_part(%Message.ContentPart{type: :image, data: data} = part, max) do
    case Image.check_dimensions(data, max) do
      :ok ->
        part

      {:too_large, width, height} ->
        Sentry.capture_message("Image exceeded provider dimension limit",
          level: :warning,
          extra: %{width: width, height: height, max_dimension: max}
        )

        Logger.warning("Stripping oversized image (#{width}x#{height}px, max #{max}px)")

        Message.ContentPart.text(
          "[Image removed: dimensions #{width}x#{height}px exceed the #{max}px provider limit]"
        )
    end
  end

  defp constrain_image_part(part, _max), do: part

  defp broadcast(topic, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, topic, message)
  end

  defp encode_result_for_swarm(value) when is_binary(value), do: value
  defp encode_result_for_swarm(value), do: Jason.encode!(value)

  defp format_crash_reason(exception) when is_exception(exception) do
    Exception.message(exception)
  end

  defp format_crash_reason(reason) do
    "Execution crashed: #{inspect(reason)}"
  end

  defp handle_stream_chunk(chunk, topic) do
    case chunk do
      %Chunk{type: :token, text: text} when is_binary(text) and text != "" ->
        broadcast(topic, {:stream_token, text})

      %Chunk{type: :thinking, text: text} when is_binary(text) and text != "" ->
        broadcast(topic, {:stream_thinking, text})

      %Chunk{type: :tool_call_start, tool_call_id: id, tool_call_name: name}
      when is_binary(id) and is_binary(name) ->
        broadcast(topic, {:tool_call_start, id, name})

      _ ->
        :ok
    end
  end

  defp build_response_metadata(%SwarmAi.LLM.Response{} = response) do
    metadata = %{}

    metadata =
      if response.tool_calls && response.tool_calls != [] do
        Map.put(metadata, :tool_calls, Enum.map(response.tool_calls, &to_reqllm_tool_call/1))
      else
        metadata
      end

    metadata =
      if response.reasoning_details && response.reasoning_details != [] do
        Map.put(metadata, :reasoning_details, response.reasoning_details)
      else
        metadata
      end

    metadata
  end

  defp to_reqllm_tool_call(%SwarmAi.ToolCall{} = tc) do
    ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
  end

  # --- SwarmAi Message Conversion ---

  defp to_swarm_message(%ReqLLM.Message{} = msg) do
    content = convert_content(msg.content)

    %Message{
      role: msg.role,
      content: content,
      tool_calls: to_swarm_tool_calls(msg.tool_calls),
      tool_call_id: msg.tool_call_id,
      name: msg.name
    }
  end

  defp convert_content(text) when is_binary(text),
    do: [Message.ContentPart.text(text)]

  defp convert_content(nil), do: []

  defp convert_content(parts) when is_list(parts) do
    Enum.flat_map(parts, &unwrap_content_part/1)
  end

  defp unwrap_content_part(part) do
    case to_swarm_content_part(part) do
      {:ok, content_part} -> [content_part]
      :skip -> []
    end
  end

  defp to_swarm_content_part(%ReqLLM.Message.ContentPart{type: :text, text: text}) do
    {:ok, Message.ContentPart.text(text)}
  end

  defp to_swarm_content_part(%ReqLLM.Message.ContentPart{
         type: :image,
         data: data,
         media_type: mt
       }) do
    {:ok, Message.ContentPart.image(data, mt)}
  end

  defp to_swarm_content_part(%ReqLLM.Message.ContentPart{type: :image_url, url: url}) do
    {:ok, Message.ContentPart.image_url(url)}
  end

  # Intentionally skip - these are transient/internal types not needed in conversation
  defp to_swarm_content_part(%ReqLLM.Message.ContentPart{type: :thinking}), do: :skip
  defp to_swarm_content_part(%ReqLLM.Message.ContentPart{type: :file}), do: :skip

  defp to_swarm_tool_calls(nil), do: []
  defp to_swarm_tool_calls([]), do: []

  defp to_swarm_tool_calls(tool_calls) do
    Enum.map(tool_calls, fn tc ->
      %SwarmAi.ToolCall{
        id: tc.id,
        name: ReqLLM.ToolCall.name(tc),
        arguments: ReqLLM.ToolCall.args_json(tc)
      }
    end)
  end

  @doc false
  def error_message(%Scope{}, :usage_limit_exceeded),
    do: "Free requests exhausted. Add your API key in Settings to continue."

  def error_message(%Scope{}, :no_api_key),
    do: "No API key available for this request."

  def error_message(%Scope{}, :registration_timeout),
    do: "Agent failed to start. Please try again."

  def error_message(%Scope{}, reason),
    do: inspect(reason)
end
