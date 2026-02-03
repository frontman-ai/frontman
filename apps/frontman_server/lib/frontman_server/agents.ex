defmodule FrontmanServer.Agents do
  @moduledoc """
  Public API for agent management.

  Agents process user messages and generate responses using LLM.
  Swarm generates a unique loop_id for each agent run.

  This module handles:
  - Starting and executing agents using Swarm's public API
  - Routing tool result notifications to waiting executors
  - Translating agent events to Tasks operations and transport broadcasts

  ## Telemetry

  All agent telemetry is emitted by Swarm. FrontmanServer passes `task_id` via
  metadata, which flows through all Swarm telemetry events. This allows
  correlation without FrontmanServer needing to track agent IDs.
  """

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Agents.{RootAgent, ToolExecutor}
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.ResolvedKey
  alias FrontmanServer.Tasks
  alias Swarm.LLM.Chunk
  alias Swarm.Message

  @doc """
  Checks if an agent is currently running for the given task.
  """
  @spec agent_running?(String.t()) :: boolean()
  def agent_running?(task_id) do
    case Registry.lookup(FrontmanServer.AgentRegistry, {:running_agent, task_id}) do
      [{_pid, _metadata}] -> true
      [] -> false
    end
  end

  @doc """
  Starts a new agent for the given task and begins execution.

  Spawns a supervised task that runs the agent using Swarm's public API.
  Swarm generates the loop_id internally; task_id is passed via metadata
  for telemetry correlation.

  API key resolution happens here at the domain layer, before any LLM calls.
  Usage is tracked after a successful agent run.

  ## Options
  - `:tools` - List of tool definitions for LLM (default: [])
  - `:model` - LLM model spec (defaults to provider default)
  - `:env_api_key` - Map of provider => api_key from client's environment
  - `:agent` - Custom agent struct implementing Swarm.Agent (for testing)

  ## Returns
  - `{:ok, pid}` - Agent started successfully
  - `{:error, :no_api_key}` - No API key available
  - `{:error, :usage_limit_exceeded}` - Server key quota exhausted
  """
  @spec start_agent(Scope.t(), String.t(), keyword()) ::
          {:ok, pid()} | {:error, :no_api_key | :usage_limit_exceeded | term()}
  def start_agent(%Scope{} = scope, task_id, opts \\ []) do
    tools = Keyword.get(opts, :tools, [])
    model_config = Keyword.get(opts, :model)
    env_api_key = Keyword.get(opts, :env_api_key, %{})

    # Build model string from config: "provider:model_value"
    # e.g., %{provider: "openrouter", value: "google/gemini-3-flash-preview"}
    #    -> "openrouter:google/gemini-3-flash-preview"
    model = build_model_string(model_config)

    # Resolve API key at the domain layer (earliest point)
    case Providers.prepare_api_key(scope, model, env_api_key) do
      {:ok, api_key_info} ->
        on_event = build_event_handler(scope, task_id)
        agent = build_agent(scope, task_id, tools, opts, api_key_info)
        messages = build_messages(scope, task_id)

        run_agent(scope, agent, task_id, messages,
          on_event: on_event,
          api_key_info: api_key_info
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Runs an agent in a supervised Task with streaming callbacks.
  # Uses start_child (fire-and-forget) since all communication happens via PubSub events.
  #
  # Dialyzer warning suppressed: the anonymous function calls execute_agent which
  # has the same protocol dispatch issue. See execute_agent comment for details.
  @dialyzer {:nowarn_function, run_agent: 5}
  @spec run_agent(Scope.t(), Swarm.Agent.t(), String.t(), [Message.t()], keyword()) ::
          {:ok, pid()} | {:error, term()}
  defp run_agent(scope, agent, task_id, messages, opts) do
    on_event = Keyword.fetch!(opts, :on_event)
    api_key_info = Keyword.fetch!(opts, :api_key_info)
    registry_key = {:running_agent, task_id}

    Task.Supervisor.start_child(
      FrontmanServer.TaskSupervisor,
      fn ->
        # Register that an agent is running for this task
        Registry.register(FrontmanServer.AgentRegistry, registry_key, %{})

        # Monitor this execution for crashes - broadcasts error if we crash unexpectedly
        Tasks.ExecutionMonitor.watch(task_id, topic: Tasks.topic(task_id))

        try do
          # registry_key passed for explicit cleanup timing (must unregister before completion event)
          execute_agent(scope, agent, task_id, messages, registry_key, on_event, api_key_info)
        after
          # Safety net for crashes - idempotent if already unregistered in execute_agent
          Registry.unregister(FrontmanServer.AgentRegistry, registry_key)
        end
      end
    )
  end

  defp build_agent(scope, task_id, tools, opts, %ResolvedKey{} = resolved_key) do
    case Keyword.get(opts, :agent) do
      nil ->
        # Build context for dynamic system prompt
        has_figma = Tasks.has_figma_context?(scope, task_id)
        has_selected_component = Tasks.has_selected_component?(scope, task_id)
        figma_node_id = Tasks.get_figma_node_id(scope, task_id)
        framework = get_framework(scope, task_id)

        # Fetch discovered project rules (AGENTS.md, etc.)
        project_rules =
          case Tasks.get_discovered_project_rules(scope, task_id) do
            {:ok, rules} -> rules
            {:error, _} -> []
          end

        # Build llm_opts with resolved key info
        # LLM transformation flags (requires_mcp_prefix, identity_override) come from ResolvedKey
        # oauth_mode tells ReqLLM to use Bearer token auth instead of x-api-key
        llm_opts = [
          api_key: resolved_key.api_key,
          requires_mcp_prefix: resolved_key.requires_mcp_prefix,
          identity_override: resolved_key.identity_override,
          oauth_mode: resolved_key.oauth_mode
        ]

        has_typescript_react = framework in ["nextjs"]

        # Create RootAgent with context
        # API key is passed via llm_opts - no scope/env_api_key needed
        RootAgent.new(
          tools: tools,
          has_figma_context: has_figma,
          has_selected_component: has_selected_component,
          has_typescript_react: has_typescript_react,
          figma_node_id: figma_node_id,
          framework: framework,
          model: resolved_key.model,
          llm_opts: llm_opts,
          project_rules: project_rules
        )

      custom_agent ->
        custom_agent
    end
  end

  @doc """
  Notifies the agent that a tool result has arrived.

  Called by Tasks when a tool result is added.
  Routes to the blocking caller via Registry metadata.
  """
  @spec notify_tool_result(String.t(), String.t(), term(), boolean()) :: :ok
  def notify_tool_result(_task_id, tool_call_id, result, is_error) do
    case Registry.lookup(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}) do
      [{_pid, %{caller_pid: caller}}] ->
        # MCP tool - send result to waiting executor
        # Encode non-string results since Swarm.Message.ContentPart.text/1 requires strings
        encoded = encode_result_for_swarm(result)
        send(caller, {:tool_result, tool_call_id, encoded, is_error})
        :ok

      [] ->
        # No waiter - this is normal for backend tools (they execute synchronously)
        :ok
    end
  end

  @doc """
  Notifies that a user message has been added.

  Called by Tasks when a user message is added.
  Spawns a new agent if none exists.

  ## Options
  - `:tools` - List of tool definitions for LLM (default: [])
  - `:agent` - Custom agent struct implementing Swarm.Agent (for testing)
  """
  @spec notify_user_message(Scope.t(), String.t(), list(FrontmanServer.Tools.MCP.t()), keyword()) ::
          :ok
  def notify_user_message(%Scope{} = scope, task_id, tools, opts \\ []) do
    if agent_running?(task_id) do
      :ok
    else
      case start_agent(scope, task_id, Keyword.merge([tools: tools], opts)) do
        {:ok, _pid} ->
          :ok

        {:error, reason} ->
          broadcast(task_id, {:agent_error, error_message(reason)})
          :ok
      end
    end
  end

  defp error_message(:usage_limit_exceeded),
    do: "Free requests exhausted. Add your API key in Settings to continue."

  defp error_message(:no_api_key),
    do: "No API key available for this request."

  defp error_message(reason),
    do: inspect(reason)

  # Build model string from config map: "provider:model_value"
  # e.g., %{provider: "openrouter", value: "google/gemini-3-flash-preview"}
  #    -> "openrouter:google/gemini-3-flash-preview"
  defp build_model_string(%{provider: provider, value: value})
       when is_binary(provider) and is_binary(value) do
    "#{provider}:#{value}"
  end

  defp build_model_string(_), do: nil

  # Private Functions

  defp build_event_handler(scope, task_id) do
    fn event -> handle_agent_event(scope, task_id, event) end
  end

  defp handle_agent_event(scope, task_id, event) do
    case event do
      {:token, token} ->
        broadcast(task_id, {:stream_token, token})

      {:thinking, text} ->
        broadcast(task_id, {:stream_thinking, text})

      {:response, text, metadata} ->
        Tasks.add_agent_response(scope, task_id, text, metadata)

      :completed ->
        Tasks.add_agent_completed(scope, task_id)
        broadcast(task_id, :agent_completed)

      {:error, reason} ->
        broadcast(task_id, {:agent_error, inspect(reason)})
    end
  end

  defp build_messages(scope, task_id) do
    case Tasks.get_llm_messages(scope, task_id) do
      {:ok, messages} -> Enum.map(messages, &to_swarm_message/1)
      {:error, _} -> []
    end
  end

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

  defp convert_content(text) when is_binary(text), do: [Message.ContentPart.text(text)]
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
      %Swarm.ToolCall{
        id: tc.id,
        name: ReqLLM.ToolCall.name(tc),
        arguments: ReqLLM.ToolCall.args_json(tc)
      }
    end)
  end

  defp get_framework(scope, task_id) do
    case Tasks.get_task(scope, task_id) do
      {:ok, task} -> task.framework
      {:error, _} -> nil
    end
  end

  defp broadcast(task_id, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), message)
  end

  # Encode non-string results to JSON for Swarm.Message.ContentPart.text/1
  defp encode_result_for_swarm(value) when is_binary(value), do: value
  defp encode_result_for_swarm(value), do: Jason.encode!(value)

  # --- Agent Execution ---

  # Note: registry_key is passed for explicit cleanup timing.
  # We MUST unregister BEFORE broadcasting completion so consumers
  # checking agent_running? see consistent state.
  #
  # Dialyzer thinks this has no return because it can't prove protocol dispatch
  # won't use the Any fallback (which raises). At runtime, RootAgent is always used.
  # Exceptions are intentionally not rescued - they propagate to error monitoring.
  @dialyzer {:nowarn_function, execute_agent: 7}
  defp execute_agent(
         scope,
         agent,
         task_id,
         messages,
         registry_key,
         on_event,
         %ResolvedKey{} = resolved_key
       ) do
    # Build tool executor that handles both backend and MCP tools.
    # ToolExecutor owns interaction publishing for MCP tools internally.
    # Pass MCP tools and llm_opts so backend tools that spawn sub-agents can use them.
    mcp_tools = Map.get(agent, :tools, [])

    # Build flat llm_opts from resolved_key for sub-agents
    llm_opts = [api_key: resolved_key.api_key, model: resolved_key.model]

    tool_executor =
      ToolExecutor.make_executor(scope, task_id, mcp_tools: mcp_tools, llm_opts: llm_opts)

    Logger.info("Starting agent execution for task #{task_id} via Swarm.run_streaming")

    # Emit task start telemetry - creates the root OTEL span for this task
    TelemetryEvents.task_start(task_id)

    # Use Swarm's public API with streaming callbacks.
    # Pass task_id in metadata for telemetry correlation.
    # Swarm returns loop_id for execution identification and crash reporting.
    result =
      Swarm.run_streaming(agent, messages,
        metadata: %{task_id: task_id},
        tool_executor: tool_executor,
        on_chunk: fn chunk ->
          case chunk do
            %Chunk{type: :token, text: text} when is_binary(text) and text != "" ->
              on_event.({:token, text})

            %Chunk{type: :thinking, text: text} when is_binary(text) and text != "" ->
              on_event.({:thinking, text})

            _ ->
              :ok
          end
        end,
        on_response: fn response ->
          metadata = build_response_metadata(response)
          on_event.({:response, response.content || "", metadata})
        end
      )

    # Unregister BEFORE broadcasting completion so consumers see consistent state.
    # This is intentionally explicit (not just in after block) because the
    # timing matters for agent handoff.
    Registry.unregister(FrontmanServer.AgentRegistry, registry_key)

    case result do
      {:ok, _result, loop_id} ->
        # Track usage only on successful agent run
        Providers.record_usage(scope, resolved_key)
        on_event.(:completed)
        Logger.debug("Agent completed for task #{task_id}, loop_id: #{loop_id}")

      {:error, reason, loop_id} ->
        on_event.({:error, reason})

        Logger.warning(
          "Agent failed for task #{task_id}, loop_id: #{loop_id}, reason: #{inspect(reason)}"
        )
    end

    # Emit task stop telemetry - closes the root OTEL span
    TelemetryEvents.task_stop(task_id)

    result
  end

  defp build_response_metadata(%Swarm.LLM.Response{} = response) do
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

  defp to_reqllm_tool_call(%Swarm.ToolCall{} = tc) do
    ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
  end
end
