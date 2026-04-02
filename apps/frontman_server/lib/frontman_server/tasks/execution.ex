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
  alias FrontmanServer.Tasks.Execution.{Framework, LLMError, RootAgent, ToolExecutor}
  alias FrontmanServer.Tasks.{Interaction, StreamStallTimeout, Task}
  alias FrontmanServer.Tools
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
        agent = build_agent(task, tools, opts, api_key_info)

        messages =
          task.interactions
          |> Interaction.to_llm_messages()
          |> Enum.map(&to_swarm_message/1)
          |> maybe_constrain_images(api_key_info.provider)

        mcp_tool_defs = Keyword.get(opts, :mcp_tool_defs, [])

        backend_tool_modules =
          Keyword.get(opts, :backend_tool_modules, Tools.backend_tool_modules())

        submit_to_runtime(scope, agent, task_id, messages,
          api_key_info: api_key_info,
          mcp_tool_defs: mcp_tool_defs,
          backend_tool_modules: backend_tool_modules
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Notifies that a tool result has arrived.

  Routes the result to the blocking executor via Registry metadata.
  Called by the Tasks facade after persisting the tool result interaction.
  Returns `:notified` when the result was delivered to a live executor,
  `:no_executor` when no executor was waiting (e.g., server restarted).
  """
  @spec notify_tool_result(Scope.t(), String.t(), term(), boolean()) :: :notified | :no_executor
  def notify_tool_result(%Scope{}, tool_call_id, result, is_error) do
    case Elixir.Registry.lookup(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id}) do
      [{_pid, %{caller_pid: caller}}] ->
        encoded = encode_result_for_swarm(result)
        send(caller, {:tool_result, tool_call_id, encoded, is_error})
        :notified

      [] ->
        :no_executor
    end
  end

  # --- Event Handling ---

  @doc """
  Translates a SwarmAi event to a transport-level action for the channel.

  Called by the TaskChannel from `handle_info({:swarm_event, event})`.

  **Persistence is handled by SwarmDispatcher** (runs in the Runtime Task
  process). This function only determines what the channel should push to
  the client — if the channel is dead, no data is lost.
  """
  @spec handle_swarm_event(Scope.t(), String.t(), term()) :: term()
  def handle_swarm_event(_scope, _task_id, {:response, _response}), do: :ok

  def handle_swarm_event(_scope, _task_id, {:completed, {:ok, _result, _loop_id}}),
    do: :agent_completed

  def handle_swarm_event(_scope, _task_id, {:failed, {:error, reason, _loop_id}}) do
    {msg, category, retryable} = classify_error(reason)
    {:agent_error, %{message: msg, category: category, retryable: retryable}}
  end

  def handle_swarm_event(_scope, _task_id, {:crashed, %{reason: reason}}) do
    msg = humanize_crash(reason)
    {:agent_error, %{message: msg, category: "unknown", retryable: false}}
  end

  def handle_swarm_event(_scope, _task_id, {:cancelled, _}),
    do: :agent_cancelled

  def handle_swarm_event(_scope, _task_id, {:terminated, _}),
    do: :agent_cancelled

  # Paused — ToolResult and AgentPaused already persisted by SwarmDispatcher.
  # Return :agent_paused so the channel can resolve the pending prompt and notify the client.
  def handle_swarm_event(_scope, _task_id, {:paused, _}), do: :agent_paused

  # Tool calls are persisted by ToolExecutor; no channel action needed.
  def handle_swarm_event(_scope, _task_id, {:tool_call, _}), do: :ok

  @doc """
  Classifies an error reason into `{message, category, retryable}`.

  `category` is one of: "auth", "billing", "rate_limit", "overload",
  "payload_too_large", "output_truncated", "unknown".
  """
  @spec classify_error(term()) :: {String.t(), String.t(), boolean()}
  def classify_error(%LLMError{message: msg, category: cat, retryable: r}), do: {msg, cat, r}

  def classify_error(%StreamStallTimeout.Error{}) do
    {"The AI provider stopped responding mid-reply. " <>
       "This usually happens when the provider is temporarily overloaded. " <>
       "Try sending your message again.", "overload", true}
  end

  def classify_error(:genserver_call_timeout) do
    {"The request to the AI provider timed out. " <>
       "This can happen during high traffic. Try again in a moment.", "overload", true}
  end

  def classify_error(:stream_timeout) do
    {"The request to the AI provider timed out. " <>
       "This can happen during high traffic. Try again in a moment.", "overload", true}
  end

  def classify_error(:output_truncated) do
    {"The AI response was too long and got cut off. " <>
       "This usually happens when writing large files. " <>
       "Try asking the AI to write the file in smaller sections.", "output_truncated", false}
  end

  def classify_error({:exit, reason}) do
    {"Something went wrong while communicating with the AI provider: #{inspect(reason)}",
     "unknown", false}
  end

  def classify_error(reason) when is_exception(reason),
    do: {Exception.message(reason), "unknown", false}

  def classify_error(reason) when is_binary(reason), do: {reason, "unknown", false}
  def classify_error(reason), do: {inspect(reason), "unknown", false}

  # --- Private ---

  # Dialyzer warning suppressed: protocol dispatch on Agent can't be statically proven.
  @dialyzer {:nowarn_function, submit_to_runtime: 5}
  defp submit_to_runtime(scope, agent, task_id, messages, opts) do
    %ResolvedKey{} = resolved_key = Keyword.fetch!(opts, :api_key_info)

    mcp_tools = Map.get(agent, :tools, [])
    mcp_tool_defs = Keyword.get(opts, :mcp_tool_defs, [])
    backend_tool_modules = Keyword.fetch!(opts, :backend_tool_modules)

    llm_opts =
      [api_key: resolved_key.api_key, model: resolved_key.model]
      |> maybe_enable_prompt_cache(resolved_key.provider)

    tool_executor =
      ToolExecutor.make_executor(scope, task_id,
        backend_tool_modules: backend_tool_modules,
        mcp_tools: mcp_tools,
        mcp_tool_defs: mcp_tool_defs,
        llm_opts: llm_opts
      )

    # Emit task start telemetry BEFORE Runtime.run to avoid race with task_stop
    # in event handlers — the agent may complete before this line returns.
    TelemetryEvents.task_start(task_id)

    case SwarmAi.Runtime.run(FrontmanServer.AgentRuntime, task_id, agent, messages,
           metadata: %{task_id: task_id, resolved_key: resolved_key, scope: scope},
           tool_executor: tool_executor
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, :already_running} ->
        TelemetryEvents.task_stop(task_id)
        {:ok, :already_running}

      error ->
        TelemetryEvents.task_stop(task_id)
        error
    end
  end

  defp maybe_enable_prompt_cache(opts, "anthropic"),
    do: Keyword.put(opts, :anthropic_prompt_cache, true)

  defp maybe_enable_prompt_cache(opts, _provider), do: opts

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

        max_tokens = Application.fetch_env!(:frontman_server, :llm_max_tokens)
        {model_spec, llm_opts} = ResolvedKey.to_llm_args(resolved_key, max_tokens: max_tokens)

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

  defp encode_result_for_swarm(value) when is_binary(value), do: value
  defp encode_result_for_swarm(value), do: Jason.encode!(value)

  # --- SwarmAi Message Conversion ---

  defp to_swarm_message(%ReqLLM.Message{role: :system} = msg) do
    %Message.System{content: convert_content(msg.content)}
  end

  defp to_swarm_message(%ReqLLM.Message{role: :user} = msg) do
    %Message.User{content: convert_content(msg.content)}
  end

  defp to_swarm_message(%ReqLLM.Message{role: :assistant} = msg) do
    %Message.Assistant{
      content: convert_content(msg.content),
      tool_calls: to_swarm_tool_calls(msg.tool_calls),
      metadata: %{}
    }
  end

  defp to_swarm_message(%ReqLLM.Message{role: :tool} = msg) do
    %Message.Tool{
      content: convert_content(msg.content),
      tool_call_id: msg.tool_call_id,
      name: msg.name,
      metadata: %{}
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

  # Translates internal error reasons into user-friendly messages.
  # Delegates to classify_error/1 to keep message strings in one place.
  defp humanize_error(reason) do
    {message, _category, _retryable} = classify_error(reason)
    message
  end

  # Like humanize_error, but prefixes unknown/fallback reasons with crash context.
  defp humanize_crash(reason) when is_exception(reason), do: humanize_error(reason)
  defp humanize_crash(reason) when is_atom(reason), do: "Execution crashed: #{inspect(reason)}"
  defp humanize_crash(reason), do: "Execution crashed: #{humanize_error(reason)}"
end
