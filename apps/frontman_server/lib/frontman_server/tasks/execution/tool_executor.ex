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
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend
  alias SwarmAi.Message.ContentPart

  @tool_timeout_ms 60_000
  # Interactive tools (e.g., question) may wait hours for a human response.
  # This timeout is a safety net to prevent permanent process leaks if the
  # user abandons the session and the server never restarts.
  @interactive_tool_timeout_ms :timer.hours(24)

  @doc """
  Returns a tool executor function for use with Swarm execution.

  The returned function:
  1. Tries to execute as a backend tool first
  2. Falls back to MCP routing if not a backend tool

  For MCP tools, the executor automatically publishes interactions to enable
  routing through TaskChannel. Callers don't need to handle this.

  ## Options

  - `:mcp_tools` - List of SwarmAi.Tool.t() for sub-agents to use (default: [])
  - `:mcp_tool_defs` - List of FrontmanServer.Tools.MCP.t() for execution mode lookups (default: [])
  - `:llm_opts` - Keyword list with :api_key and :model for sub-agents

  ## Examples

      executor = ToolExecutor.make_executor(scope, task_id, mcp_tools: mcp_tools, llm_opts: llm_opts)
      SwarmAi.run_blocking(agent, messages, executor)
  """
  @spec make_executor(Scope.t(), String.t(), keyword()) ::
          (SwarmAi.ToolCall.t() -> {:ok, String.t()} | {:error, String.t()})
  def make_executor(%Scope{} = scope, task_id, opts \\ []) do
    mcp_tools = Keyword.get(opts, :mcp_tools, [])
    mcp_tool_defs = Keyword.get(opts, :mcp_tool_defs, [])
    llm_opts = Keyword.fetch!(opts, :llm_opts)

    fn tool_call ->
      # Strip null values from arguments. OpenAI strict mode makes optional fields
      # nullable (anyOf: [type, null]), so the model sends null instead of omitting.
      # Tools expect missing keys, not null values.
      tool_call = strip_null_arguments(tool_call)

      execute_tool_call(scope, task_id, tool_call,
        mcp_tools: mcp_tools,
        mcp_tool_defs: mcp_tool_defs,
        llm_opts: llm_opts
      )
    end
  end

  defp execute_tool_call(scope, task_id, tool_call, opts) do
    case Tools.execution_target(tool_call.name) do
      :mcp ->
        # Register BEFORE publishing to prevent a race where the client
        # responds before the executor is listening.
        register_mcp_tool(tool_call)
        publish_mcp_tool_call(scope, task_id, tool_call)
        execute_and_enrich(scope, tool_call, task_id, opts)

      :backend ->
        execute_and_enrich(scope, tool_call, task_id, opts)
    end
  end

  defp execute_and_enrich(scope, tool_call, task_id, opts) do
    result =
      execute(scope, tool_call, task_id,
        mcp_tools: Keyword.get(opts, :mcp_tools, []),
        mcp_tool_defs: Keyword.get(opts, :mcp_tool_defs, []),
        llm_opts: Keyword.fetch!(opts, :llm_opts)
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
    - `:mcp_tools` - List of SwarmAi.Tool.t() for sub-agents to use (default: [])
    - `:llm_opts` - Keyword list with :api_key and :model for sub-agents
  """
  @spec execute(Scope.t(), SwarmAi.ToolCall.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def execute(scope, tool_call, task_id, opts \\ []) do
    mcp_tools = Keyword.get(opts, :mcp_tools, [])
    mcp_tool_defs = Keyword.get(opts, :mcp_tool_defs, [])
    llm_opts = Keyword.fetch!(opts, :llm_opts)

    case Tools.find_tool(tool_call.name) do
      {:ok, module} ->
        execute_backend_tool(
          scope,
          module,
          tool_call,
          task_id,
          mcp_tools,
          mcp_tool_defs,
          llm_opts
        )

      :not_found ->
        execute_mcp_tool(scope, tool_call, task_id, mcp_tool_defs)
    end
  end

  # --- Backend Tool Execution ---

  defp execute_backend_tool(scope, module, tool_call, task_id, mcp_tools, mcp_tool_defs, llm_opts) do
    Logger.info("ToolExecutor: Executing backend tool #{tool_call.name}")

    # Re-fetch task from DB to get latest interactions. The task captured at
    # execution start becomes stale as earlier tool calls in the same run add
    # new interactions. Without a fresh fetch, sub-agents spawned by later
    # backend tools would miss context from earlier tool results.
    {:ok, task} = Tasks.get_task(scope, task_id)

    # Pass the executor itself so backend tools can spawn sub-agents
    executor =
      make_executor(scope, task_id,
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

    args = parse_arguments(tool_call.arguments)

    result = module.execute(args, context)

    case result do
      {:ok, value} ->
        encoded = encode_result(value)

        # Store tool result for interaction history and UI notification
        Tasks.add_tool_result(
          scope,
          task_id,
          %{id: tool_call.id, name: tool_call.name},
          value,
          false
        )

        {:ok, encoded}

      {:error, reason} ->
        Logger.error("ToolExecutor: Backend tool #{tool_call.name} failed: #{inspect(reason)}")

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

        # Store error result for interaction history and UI notification
        Tasks.add_tool_result(
          scope,
          task_id,
          %{id: tool_call.id, name: tool_call.name},
          reason,
          true
        )

        {:error, reason}
    end
  end

  defp strip_null_arguments(tool_call) do
    SwarmAi.ToolCall.strip_null_arguments(tool_call)
  end

  defp parse_arguments(arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, decoded} ->
        decoded

      {:error, decode_error} ->
        Logger.error(
          "ToolExecutor: Failed to parse tool arguments: #{inspect(decode_error)}, raw: #{String.slice(arguments, 0, 500)}"
        )

        Sentry.capture_message("Tool argument parse failure",
          level: :error,
          tags: %{error_type: "tool_parse_error"},
          extra: %{
            raw_arguments: String.slice(arguments, 0, 500),
            decode_error: inspect(decode_error)
          }
        )

        %{}
    end
  end

  defp parse_arguments(arguments) when is_map(arguments), do: arguments
  defp parse_arguments(_), do: %{}

  defp encode_result(value) when is_binary(value), do: value
  defp encode_result(value), do: Jason.encode!(value)

  # --- MCP Tool Execution ---

  defp execute_mcp_tool(scope, tool_call, task_id, mcp_tool_defs) do
    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    tool_call_id = tool_call.id

    if Tools.MCP.interactive_by_name?(mcp_tool_defs, tool_call.name) do
      # Interactive tools (e.g., question) block for up to 24 hours. The user
      # may take minutes or hours to respond. The executor unblocks when:
      #   - The user responds (normal MCP tool result flow)
      #   - The channel disconnects (terminate/2 sends an error result)
      #   - The server restarts (process dies; reconnect re-dispatches)
      #   - The safety-net timeout fires (prevents permanent process leaks)
      receive do
        {:tool_result, ^tool_call_id, content, is_error} ->
          Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
          if is_error, do: {:error, content}, else: {:ok, content}
      after
        @interactive_tool_timeout_ms ->
          Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})

          Logger.error(
            "ToolExecutor: Interactive tool #{tool_call.name} timed out (safety net) after 24h"
          )

          error_msg = "Interactive tool abandoned: #{tool_call.name}"

          Tasks.add_tool_result(
            scope,
            task_id,
            %{id: tool_call_id, name: tool_call.name},
            error_msg,
            true
          )

          {:error, error_msg}
      end
    else
      # Non-interactive MCP tools (navigate, screenshot, etc.) should respond
      # quickly. Timeout is a legitimate error signal.
      receive do
        {:tool_result, ^tool_call_id, content, is_error} ->
          Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
          if is_error, do: {:error, content}, else: {:ok, content}
      after
        @tool_timeout_ms ->
          Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})

          Logger.error(
            "ToolExecutor: MCP tool #{tool_call.name} timed out after #{@tool_timeout_ms}ms"
          )

          Sentry.capture_message("MCP tool timeout",
            level: :error,
            tags: %{error_type: "tool_timeout"},
            extra: %{
              tool_name: tool_call.name,
              tool_call_id: tool_call_id,
              task_id: task_id,
              timeout_ms: @tool_timeout_ms
            }
          )

          error_msg = "Tool timeout: #{tool_call.name}"

          # Persist the timeout error as a ToolResult so the DB is consistent
          # (every ToolCall has a matching ToolResult). Without this, reconnect
          # shows the tool as perpetually in-progress.
          Tasks.add_tool_result(
            scope,
            task_id,
            %{id: tool_call_id, name: tool_call.name},
            error_msg,
            true
          )

          {:error, error_msg}
      end
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
      _ -> :no_image
    end
  end
end
