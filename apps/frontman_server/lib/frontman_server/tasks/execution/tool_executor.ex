defmodule FrontmanServer.Tasks.Execution.ToolExecutor do
  @moduledoc """
  Unified tool execution for both backend and MCP tools.

  Backend tools are executed directly server-side.
  MCP tools use Registry-based result routing to wait for client execution.

  ## MCP Tool Routing

  For MCP tools, the executor handles the complete routing flow:
  1. Registers in ToolCallRegistry (for receiving response)
  2. Publishes interaction via Tasks (for TaskChannel routing)
  3. Waits for client response via receive

  This ensures MCP tools work correctly for both main agents and sub-agents
  without requiring callers to handle interaction publishing.

  ## Telemetry

  Tool execution telemetry is handled by Swarm. This module focuses only
  on executing tools.
  """

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Image
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend
  alias SwarmAi.Message.ContentPart

  @doc """
  Returns a tool executor function for use with Swarm execution.

  The returned function:
  1. Tries to execute as a backend tool first
  2. Falls back to MCP routing if not a backend tool

  For MCP tools, the executor automatically publishes interactions to enable
  routing through TaskChannel. Callers don't need to handle this.

  ## Options

  - `:backend_tool_modules` - List of backend tool modules (required)
  - `:mcp_tools` - List of SwarmAi.Tool.t() for sub-agents to use (required)
  - `:mcp_tool_defs` - List of FrontmanServer.Tools.MCP.t() for execution mode lookups (required)
  - `:llm_opts` - Keyword list with :api_key and :model for sub-agents (required)

  ## Examples

      {executor, on_deadline} = ToolExecutor.make_executor(scope, task_id,
        backend_tool_modules: Tools.backend_tool_modules(),
        mcp_tools: mcp_tools,
        mcp_tool_defs: mcp_tool_defs,
        llm_opts: llm_opts
      )
      SwarmAi.run_streaming(agent, messages, tool_executor: executor, on_deadline: on_deadline)
  """
  @spec make_executor(Scope.t(), String.t(), keyword()) ::
          {([SwarmAi.ToolCall.t()] -> [SwarmAi.ToolResult.t()]), (SwarmAi.ToolCall.t() -> :ok)}
  def make_executor(%Scope{} = scope, task_id, opts) do
    exec_opts = build_exec_opts(opts)

    executor = fn tool_calls ->
      Enum.map(tool_calls, &build_tool_result(&1, scope, task_id, exec_opts))
    end

    on_deadline = fn tc ->
      policy = resolve_timeout_policy(tc, exec_opts)

      case policy do
        :error ->
          timeout_msg = "Tool #{tc.name} timed out"
          Logger.error("ToolExecutor: #{timeout_msg}")
          report_tool_timeout_sentry(tc, task_id)
          Tasks.add_tool_result(scope, task_id, %{id: tc.id, name: tc.name}, timeout_msg, true)

        :pause_agent ->
          :ok
      end
    end

    {executor, on_deadline}
  end

  @doc """
  Execute a single tool, trying backend first then MCP.

  ## Options
    - `:backend_tool_modules` - List of backend tool modules (required)
    - `:mcp_tools` - List of SwarmAi.Tool.t() for sub-agents to use (required)
    - `:mcp_tool_defs` - List of FrontmanServer.Tools.MCP.t() for execution mode lookups (required)
    - `:llm_opts` - Keyword list with :api_key and :model for sub-agents (required)
  """
  @spec execute(Scope.t(), SwarmAi.ToolCall.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def execute(%Scope{} = scope, tool_call, task_id, opts) do
    exec_opts = build_exec_opts(opts)

    case Map.fetch(exec_opts.backend_module_map, tool_call.name) do
      {:ok, module} ->
        execute_backend_tool(scope, module, tool_call, task_id, exec_opts)

      :error ->
        register_mcp_tool(tool_call)
        publish_mcp_tool_call(scope, task_id, tool_call)
        execute_mcp_tool(scope, tool_call, task_id, exec_opts)
    end
  end

  # Determines the timeout policy for a tool call, checking MCP tool defs first,
  # then backend tool modules. Falls back to :error for unknown tools.
  defp resolve_timeout_policy(tc, exec_opts) do
    case Enum.find(exec_opts.mcp_tool_defs, &(&1.name == tc.name)) do
      %{on_timeout: policy} ->
        policy

      nil ->
        # Look up backend tool's on_timeout/0. Falls back to :error for
        # unknown tools, which should not occur in practice.
        case Map.get(exec_opts.backend_module_map, tc.name) do
          nil -> :error
          module -> module.on_timeout()
        end
    end
  end

  # Builds the internal execution opts map from keyword opts, including a
  # pre-computed module map for O(1) backend tool lookup.
  defp build_exec_opts(opts) do
    backend_tool_modules = Keyword.fetch!(opts, :backend_tool_modules)

    %{
      backend_tool_modules: backend_tool_modules,
      backend_module_map: Map.new(backend_tool_modules, &{&1.name(), &1}),
      mcp_tools: Keyword.fetch!(opts, :mcp_tools),
      mcp_tool_defs: Keyword.fetch!(opts, :mcp_tool_defs),
      llm_opts: Keyword.fetch!(opts, :llm_opts)
    }
  end

  defp build_tool_result(tool_call, scope, task_id, exec_opts) do
    # Strip null values from arguments. OpenAI strict mode makes optional fields
    # nullable (anyOf: [type, null]), so the model sends null instead of omitting.
    # Tools expect missing keys, not null values.
    tool_call = strip_null_arguments(tool_call)

    result = execute_tool_call(tool_call, scope, task_id, exec_opts)

    case result do
      {:ok, content} -> SwarmAi.ToolResult.make(tool_call.id, content, false)
      {:error, reason} -> SwarmAi.ToolResult.make(tool_call.id, to_string(reason), true)
    end
  end

  defp execute_tool_call(tool_call, scope, task_id, exec_opts) do
    result =
      case Map.fetch(exec_opts.backend_module_map, tool_call.name) do
        {:ok, module} ->
          execute_backend_tool(scope, module, tool_call, task_id, exec_opts)

        :error ->
          # Register BEFORE publishing to prevent a race where the client
          # responds before the executor is listening.
          register_mcp_tool(tool_call)
          publish_mcp_tool_call(scope, task_id, tool_call)
          execute_mcp_tool(scope, tool_call, task_id, exec_opts)
      end

    # Convert tool results containing image data (e.g. screenshots) to multimodal
    # content parts so the LLM receives proper image content instead of base64 text.
    maybe_enrich_with_images(tool_call.name, result)
  end

  # Registers an MCP tool call in the ToolCallRegistry so the executor process
  # can receive the result when the browser client responds.
  defp register_mcp_tool(tool_call) do
    Registry.register(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call.id}, %{
      caller_pid: self()
    })
  end

  defp publish_mcp_tool_call(%Scope{} = scope, task_id, tool_call) do
    reqllm_tc = to_reqllm_tool_call(tool_call)

    case Tasks.add_tool_call(scope, task_id, reqllm_tc) do
      {:ok, _interaction} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "ToolExecutor: Failed to publish MCP tool call #{tool_call.id}: #{inspect(reason)}"
        )

        raise "Failed to publish MCP tool call: #{inspect(reason)}"
    end
  end

  defp to_reqllm_tool_call(%SwarmAi.ToolCall{} = tc) do
    ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
  end

  # --- Backend Tool Execution ---

  defp execute_backend_tool(scope, module, tool_call, task_id, opts) do
    Logger.info("ToolExecutor: Executing backend tool #{tool_call.name}")

    # Re-fetch task from DB to get latest interactions. The task captured at
    # execution start becomes stale as earlier tool calls in the same run add
    # new interactions. Without a fresh fetch, sub-agents spawned by later
    # backend tools would miss context from earlier tool results.
    {:ok, task} = Tasks.get_task(scope, task_id)

    # Pass the executor itself so backend tools can spawn sub-agents.
    {executor, _on_deadline} =
      make_executor(scope, task_id,
        backend_tool_modules: opts.backend_tool_modules,
        mcp_tools: opts.mcp_tools,
        mcp_tool_defs: opts.mcp_tool_defs,
        llm_opts: opts.llm_opts
      )

    context_messages = Interaction.extract_markdown_messages(task.interactions)

    context = %Backend.Context{
      scope: scope,
      task: task,
      tool_executor: executor,
      mcp_tools: opts.mcp_tools,
      context_messages: context_messages,
      llm_opts: opts.llm_opts
    }

    case parse_arguments(tool_call.name, tool_call.arguments) do
      {:error, reason} ->
        # parse_arguments already reported to Sentry and logged — just record
        # the error result for interaction history and return.
        Tasks.add_tool_result(scope, task_id, tool_call_ref(tool_call), reason, true)
        {:error, reason}

      {:ok, args} ->
        run_backend_tool(scope, module, args, context, tool_call, task_id)
    end
  end

  defp run_backend_tool(scope, module, args, context, tool_call, task_id) do
    outcome =
      try do
        {:returned, module.execute(args, context)}
      catch
        kind, reason -> {:crashed, {kind, reason}}
      end

    handle_backend_outcome(outcome, scope, tool_call, task_id)
  end

  defp handle_backend_outcome({:returned, {:ok, value}}, scope, tool_call, task_id) do
    Tasks.add_tool_result(scope, task_id, tool_call_ref(tool_call), value, false)
    {:ok, encode_result(value)}
  end

  defp handle_backend_outcome({:returned, {:error, reason}}, scope, tool_call, task_id) do
    Logger.error(
      "ToolExecutor: Backend tool #{tool_call.name} returned error: #{inspect(reason)}"
    )

    report_tool_sentry("tool_soft_error", tool_call, task_id, inspect(reason))
    Tasks.add_tool_result(scope, task_id, tool_call_ref(tool_call), reason, true)
    {:error, reason}
  end

  defp handle_backend_outcome({:crashed, reason}, scope, tool_call, task_id) do
    reason_str = inspect(reason)
    Logger.error("ToolExecutor: Backend tool #{tool_call.name} crashed: #{reason_str}")
    report_tool_sentry("tool_crash", tool_call, task_id, reason_str)
    Tasks.add_tool_result(scope, task_id, tool_call_ref(tool_call), reason_str, true)
    {:error, reason_str}
  end

  defp tool_call_ref(tool_call), do: %{id: tool_call.id, name: tool_call.name}

  defp report_tool_sentry(error_type, tool_call, task_id, reason) do
    Sentry.capture_message("Tool execution failed",
      level: :error,
      tags: %{error_type: error_type},
      extra: %{
        tool_name: tool_call.name,
        tool_call_id: tool_call.id,
        task_id: task_id,
        reason: reason
      }
    )
  end

  defp report_tool_timeout_sentry(tool_call, task_id) do
    Sentry.capture_message("Backend tool timeout",
      level: :error,
      tags: %{error_type: "tool_timeout"},
      extra: %{
        tool_name: tool_call.name,
        tool_call_id: tool_call.id,
        task_id: task_id
      }
    )
  end

  defp strip_null_arguments(tool_call) do
    SwarmAi.ToolCall.strip_null_arguments(tool_call)
  end

  defp parse_arguments(tool_name, arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, decode_error} ->
        reason =
          "Failed to parse arguments for tool #{tool_name}: #{inspect(decode_error)}, raw: #{String.slice(arguments, 0, 500)}"

        Logger.error("ToolExecutor: #{reason}")

        Sentry.capture_message("Tool argument parse failure",
          level: :error,
          tags: %{error_type: "tool_parse_error", tool_name: tool_name},
          extra: %{
            tool_name: tool_name,
            raw_arguments: String.slice(arguments, 0, 500),
            decode_error: inspect(decode_error)
          }
        )

        {:error, reason}
    end
  end

  defp parse_arguments(_tool_name, arguments) when is_map(arguments), do: {:ok, arguments}
  defp parse_arguments(_tool_name, _), do: {:ok, %{}}

  defp encode_result(value) when is_binary(value), do: value
  defp encode_result(value), do: Jason.encode!(value)

  # --- MCP Tool Execution ---

  defp execute_mcp_tool(scope, tool_call, task_id, _opts) do
    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    tool_call_id = tool_call.id

    # Block until the browser client sends the result back via TaskChannel.
    # Deadline enforcement and cleanup are handled by ParallelExecutor via the
    # on_deadline callback — no trap_exit needed here.
    receive do
      {:tool_result, ^tool_call_id, content, false} ->
        Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
        {:ok, content}

      {:tool_result, ^tool_call_id, content, true} ->
        Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
        {:error, content}
    after
      600_000 ->
        # Safety net: 10-minute hard cap. Should not fire under normal operation
        # since ParallelExecutor enforces per-tool deadlines before this point.
        Logger.error("ToolExecutor: MCP tool #{tool_call.name} receive timed out (safety net)")

        Tasks.add_tool_result(
          scope,
          task_id,
          tool_call,
          "Tool #{tool_call.name} receive timed out",
          true
        )

        exit(:timeout)
    end
  end

  # --- Image Enrichment ---
  #
  # Tools that return images (e.g. take_screenshot) send base64 data URLs as JSON text.
  # The LLM can't "see" images encoded as text in tool outputs — it needs proper image
  # content parts. This mirrors the same extraction logic in Interaction.to_llm_message.

  defp maybe_enrich_with_images(tool_name, {:ok, content} = result) when is_binary(content) do
    case Image.image_tool_config(tool_name) do
      nil ->
        result

      {image_field, _text_fields} ->
        case extract_image_content(content, image_field) do
          {:ok, content_parts} -> {:ok, content_parts}
          :no_image -> result
        end
    end
  end

  defp maybe_enrich_with_images(_tool_name, result), do: result

  defp extract_image_content(json_string, image_field) do
    field_name = Atom.to_string(image_field)

    with {:ok, decoded} when is_map(decoded) <- Jason.decode(json_string),
         data_url when is_binary(data_url) <- Map.get(decoded, field_name),
         {:ok, binary, mime} <- Image.decode_data_url(data_url) do
      {:ok, [ContentPart.image(binary, mime)]}
    else
      {:error, _json_error} -> :no_image
      {:ok, _not_a_map} -> :no_image
      nil -> :no_image
      # Image field present but not a string (e.g. integer, list).
      _non_string_field -> :no_image
    end
  end
end
