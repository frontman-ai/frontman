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

      executor = ToolExecutor.make_executor(scope, task_id,
        backend_tool_modules: Tools.backend_tool_modules(),
        mcp_tools: mcp_tools,
        mcp_tool_defs: mcp_tool_defs,
        llm_opts: llm_opts
      )
      SwarmAi.run_streaming(agent, messages, tool_executor: executor)
  """
  @spec make_executor(Scope.t(), String.t(), keyword()) ::
          ([SwarmAi.ToolCall.t()] -> [SwarmAi.ToolResult.t()])
  def make_executor(%Scope{} = scope, task_id, opts) do
    backend_tool_modules = Keyword.fetch!(opts, :backend_tool_modules)
    mcp_tools = Keyword.fetch!(opts, :mcp_tools)
    mcp_tool_defs = Keyword.fetch!(opts, :mcp_tool_defs)
    llm_opts = Keyword.fetch!(opts, :llm_opts)

    backend_module_map = Map.new(backend_tool_modules, fn mod -> {mod.name(), mod} end)

    fn tool_calls ->
      Enum.map(
        tool_calls,
        &build_tool_result(
          &1,
          scope,
          task_id,
          backend_tool_modules,
          backend_module_map,
          mcp_tools,
          mcp_tool_defs,
          llm_opts
        )
      )
    end
  end

  defp build_tool_result(
         tool_call,
         scope,
         task_id,
         backend_tool_modules,
         backend_module_map,
         mcp_tools,
         mcp_tool_defs,
         llm_opts
       ) do
    # Strip null values from arguments. OpenAI strict mode makes optional fields
    # nullable (anyOf: [type, null]), so the model sends null instead of omitting.
    # Tools expect missing keys, not null values.
    tool_call = strip_null_arguments(tool_call)

    result =
      execute_tool_call(
        scope,
        task_id,
        tool_call,
        backend_tool_modules,
        backend_module_map,
        mcp_tools,
        mcp_tool_defs,
        llm_opts
      )

    case result do
      {:ok, content} -> SwarmAi.ToolResult.make(tool_call.id, content, false)
      {:error, reason} -> SwarmAi.ToolResult.make(tool_call.id, to_string(reason), true)
    end
  end

  defp execute_tool_call(
         scope,
         task_id,
         tool_call,
         backend_tool_modules,
         backend_module_map,
         mcp_tools,
         mcp_tool_defs,
         llm_opts
       ) do
    case Map.fetch(backend_module_map, tool_call.name) do
      :error ->
        # Register BEFORE publishing to prevent a race where the client
        # responds before the executor is listening.
        register_mcp_tool(tool_call)
        publish_mcp_tool_call(scope, task_id, tool_call)

      {:ok, _module} ->
        :ok
    end

    result =
      execute(scope, tool_call, task_id,
        backend_tool_modules: backend_tool_modules,
        mcp_tools: mcp_tools,
        mcp_tool_defs: mcp_tool_defs,
        llm_opts: llm_opts
      )

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
  def execute(scope, tool_call, task_id, opts) do
    backend_tool_modules = Keyword.fetch!(opts, :backend_tool_modules)
    mcp_tools = Keyword.fetch!(opts, :mcp_tools)
    mcp_tool_defs = Keyword.fetch!(opts, :mcp_tool_defs)
    llm_opts = Keyword.fetch!(opts, :llm_opts)

    backend_module_map = Map.new(backend_tool_modules, fn mod -> {mod.name(), mod} end)

    case Map.fetch(backend_module_map, tool_call.name) do
      {:ok, module} ->
        execute_backend_tool(
          scope,
          module,
          tool_call,
          task_id,
          backend_tool_modules,
          mcp_tools,
          mcp_tool_defs,
          llm_opts
        )

      :error ->
        execute_mcp_tool(scope, tool_call, task_id, mcp_tool_defs)
    end
  end

  # --- Backend Tool Execution ---

  defp execute_backend_tool(
         scope,
         module,
         tool_call,
         task_id,
         backend_tool_modules,
         mcp_tools,
         mcp_tool_defs,
         llm_opts
       ) do
    Logger.info("ToolExecutor: Executing backend tool #{tool_call.name}")

    # Re-fetch task from DB to get latest interactions. The task captured at
    # execution start becomes stale as earlier tool calls in the same run add
    # new interactions. Without a fresh fetch, sub-agents spawned by later
    # backend tools would miss context from earlier tool results.
    {:ok, task} = Tasks.get_task(scope, task_id)

    # Pass the executor itself so backend tools can spawn sub-agents
    executor =
      make_executor(scope, task_id,
        backend_tool_modules: backend_tool_modules,
        mcp_tools: mcp_tools,
        mcp_tool_defs: mcp_tool_defs,
        llm_opts: llm_opts
      )

    # Pre-compute context messages from read_file results for sub-agents
    context_messages =
      Interaction.extract_markdown_messages(task.interactions)

    context = %Backend.Context{
      scope: scope,
      task: task,
      tool_executor: executor,
      mcp_tools: mcp_tools,
      context_messages: context_messages,
      llm_opts: llm_opts
    }

    case parse_arguments(tool_call.name, tool_call.arguments) do
      {:error, reason} ->
        # parse_arguments already reported to Sentry and logged — just record
        # the error result for interaction history and return
        Tasks.add_tool_result(
          scope,
          task_id,
          %{id: tool_call.id, name: tool_call.name},
          reason,
          true
        )

        {:error, reason}

      {:ok, args} ->
        run_backend_tool(scope, module, args, context, tool_call, task_id)
    end
  end

  # Runs a backend tool in a linked async task with trap_exit enabled so we can
  # distinguish inner crashes from ParallelExecutor kills.
  #
  # Three outcomes:
  #   {:returned, value}     — module.execute returned normally
  #   {:crashed, reason}     — module.execute raised or exited
  #   {:outer_killed, reason} — ParallelExecutor killed this task (on_timeout: :error)
  #
  # For :outer_killed, we persist a ToolResult then re-exit so ParallelExecutor
  # gets the expected DOWN message. The :shutdown → :kill grace period (OTP
  # default 5 s) is sufficient for a single DB write.
  defp run_backend_tool(scope, module, args, context, tool_call, task_id) do
    Process.flag(:trap_exit, true)
    task = Task.async(fn -> module.execute(args, context) end)
    task_ref = task.ref
    task_pid = task.pid

    outcome =
      receive do
        {^task_ref, value} ->
          # Normal return — demonitor to drop any pending :DOWN, drain linked EXIT.
          Process.demonitor(task_ref, [:flush])

          receive do
            {:EXIT, ^task_pid, :normal} -> :ok
          after
            0 -> :ok
          end

          {:returned, value}

        {:EXIT, ^task_pid, reason} ->
          # Inner task crashed via link (trap_exit converted EXIT to message).
          # Drain the :DOWN that follows.
          receive do
            {:DOWN, ^task_ref, :process, _, _} -> :ok
          after
            0 -> :ok
          end

          {:crashed, reason}

        {:DOWN, ^task_ref, :process, _, reason} ->
          # DOWN arrived before EXIT (less common but possible). Drain linked EXIT.
          receive do
            {:EXIT, ^task_pid, _} -> :ok
          after
            0 -> :ok
          end

          {:crashed, reason}

        {:EXIT, _from, reason} ->
          # ParallelExecutor killed this task — kill the inner task and clean up.
          Process.exit(task_pid, :kill)

          receive do
            {:DOWN, ^task_ref, :process, _, _} -> :ok
          after
            5_000 -> :ok
          end

          {:outer_killed, reason}
      end

    Process.flag(:trap_exit, false)

    case outcome do
      {:returned, {:ok, value}} ->
        encoded = encode_result(value)

        Tasks.add_tool_result(
          scope,
          task_id,
          %{id: tool_call.id, name: tool_call.name},
          value,
          false
        )

        {:ok, encoded}

      {:returned, {:error, reason}} ->
        Logger.error(
          "ToolExecutor: Backend tool #{tool_call.name} returned error: #{inspect(reason)}"
        )

        Sentry.capture_message("Tool execution failed",
          level: :error,
          tags: %{error_type: "tool_soft_error"},
          extra: %{
            tool_name: tool_call.name,
            tool_call_id: tool_call.id,
            task_id: task_id,
            reason: inspect(reason)
          }
        )

        Tasks.add_tool_result(
          scope,
          task_id,
          %{id: tool_call.id, name: tool_call.name},
          reason,
          true
        )

        {:error, reason}

      {:crashed, reason} ->
        reason_str = inspect(reason)

        Logger.error("ToolExecutor: Backend tool #{tool_call.name} crashed: #{reason_str}")

        Sentry.capture_message("Tool execution failed",
          level: :error,
          tags: %{error_type: "tool_crash"},
          extra: %{
            tool_name: tool_call.name,
            tool_call_id: tool_call.id,
            task_id: task_id,
            reason: reason_str
          }
        )

        Tasks.add_tool_result(
          scope,
          task_id,
          %{id: tool_call.id, name: tool_call.name},
          reason_str,
          true
        )

        {:error, reason_str}

      {:outer_killed, reason} ->
        timeout_msg = "Backend tool #{tool_call.name} timed out"

        Logger.error("ToolExecutor: #{timeout_msg}")

        Sentry.capture_message("Backend tool timeout",
          level: :error,
          tags: %{error_type: "tool_timeout"},
          extra: %{
            tool_name: tool_call.name,
            tool_call_id: tool_call.id,
            task_id: task_id
          }
        )

        Tasks.add_tool_result(
          scope,
          task_id,
          %{id: tool_call.id, name: tool_call.name},
          timeout_msg,
          true
        )

        # Re-exit so ParallelExecutor receives the expected DOWN message.
        exit(reason)
    end
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

  defp execute_mcp_tool(scope, tool_call, task_id, mcp_tool_defs) do
    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    tool_call_id = tool_call.id

    # Resolve the tool's on_timeout policy so the EXIT handler knows whether to
    # persist a ToolResult. Both :error and :pause_agent deadlines arrive as
    # :shutdown EXIT signals — they're indistinguishable at the OS level.
    #
    # on_timeout: :error — EXIT handler must persist; SwarmDispatcher never sees
    #   a :paused event for this case.
    # on_timeout: :pause_agent — SwarmDispatcher owns persistence via the
    #   {:paused, {:timeout, ...}} event. EXIT handler must skip to avoid a
    #   double-persist (unique DB index rejects the second write, losing the
    #   richer SwarmDispatcher message).
    on_timeout =
      case Enum.find(mcp_tool_defs, &(&1.name == tool_call.name)) do
        %{on_timeout: policy} -> policy
        nil -> :error
      end

    # Trap exits so we can persist a ToolResult when ParallelExecutor terminates
    # this task on an on_timeout: :error deadline. async_nolink tasks shut down
    # via :shutdown (5 s grace period), which is trappable — :kill is not, but
    # that only fires if cleanup exceeds the grace period.
    Process.flag(:trap_exit, true)

    result =
      receive do
        {:tool_result, ^tool_call_id, content, is_error} ->
          Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
          if is_error, do: {:error, content}, else: {:ok, content}

        {:EXIT, _from, reason} ->
          # ParallelExecutor killed this task via deadline.
          # Only persist for :error — :pause_agent is handled by SwarmDispatcher.
          if on_timeout == :error do
            Tasks.add_tool_result(
              scope,
              task_id,
              tool_call,
              "Tool #{tool_call.name} timed out",
              true
            )
          end

          exit(reason)
      end

    Process.flag(:trap_exit, false)
    result
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
      _ -> :no_image
    end
  end
end
