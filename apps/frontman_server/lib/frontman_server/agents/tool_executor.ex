defmodule FrontmanServer.Agents.ToolExecutor do
  @moduledoc """
  Unified tool execution for both backend and MCP tools.

  Backend tools are executed directly server-side.
  MCP tools use Registry-based result routing to wait for client execution.

  ## MCP Tool Routing

  For MCP tools, the executor handles the complete routing flow:
  1. Registers in AgentRegistry (for receiving response)
  2. Publishes interaction via Tasks.add_tool_call (for TaskChannel routing)
  3. Waits for client response via receive

  This ensures MCP tools work correctly for both main agents and sub-agents
  without requiring callers to handle interaction publishing.

  ## Telemetry

  Tool execution telemetry is handled by Swarm. This module focuses only
  on executing tools.
  """

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Agents.SchemaTransformer
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend
  alias SwarmAi.Message.ContentPart

  @tool_timeout_ms 60_000

  @doc """
  Returns a tool executor function for use with Swarm execution.

  The returned function:
  1. Tries to execute as a backend tool first
  2. Falls back to MCP routing if not a backend tool

  For MCP tools, the executor automatically publishes interactions to enable
  routing through TaskChannel. Callers don't need to handle this.

  ## Options

  - `:mcp_tools` - List of SwarmAi.Tool.t() for sub-agents to use (default: [])
  - `:llm_opts` - Keyword list with :api_key and :model for sub-agents

  ## Examples

      executor = ToolExecutor.make_executor(scope, task_id, mcp_tools: mcp_tools, llm_opts: llm_opts)
      SwarmAi.run_blocking(agent, messages, executor)
  """
  @spec make_executor(Scope.t(), String.t(), keyword()) ::
          (SwarmAi.ToolCall.t() -> {:ok, String.t()} | {:error, String.t()})
  def make_executor(%Scope{} = scope, task_id, opts \\ []) do
    mcp_tools = Keyword.get(opts, :mcp_tools, [])
    llm_opts = Keyword.fetch!(opts, :llm_opts)

    fn tool_call ->
      # Strip null values from arguments. OpenAI strict mode makes optional fields
      # nullable (anyOf: [type, null]), so the model sends null instead of omitting.
      # Tools expect missing keys, not null values.
      tool_call = strip_null_arguments(tool_call)

      is_mcp_tool = register_if_mcp_tool(tool_call)

      # For MCP tools, publish interaction so TaskChannel can route to client.
      # This must happen AFTER registration to prevent race conditions.
      if is_mcp_tool do
        publish_mcp_tool_call(scope, task_id, tool_call)
      end

      result = execute(scope, tool_call, task_id, mcp_tools: mcp_tools, llm_opts: llm_opts)

      # Convert tool results containing image data (e.g. screenshots) to multimodal
      # content parts so the LLM receives proper image content instead of base64 text.
      maybe_enrich_with_images(tool_call.name, result)
    end
  end

  # Returns true if this is an MCP tool (registered for response), false for backend tools
  defp register_if_mcp_tool(tool_call) do
    case Tools.execution_target(tool_call.name) do
      :backend ->
        false

      :mcp ->
        Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call.id}, %{
          caller_pid: self()
        })

        true
    end
  end

  defp publish_mcp_tool_call(scope, task_id, tool_call) do
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
    llm_opts = Keyword.fetch!(opts, :llm_opts)

    case Tools.find_tool(tool_call.name) do
      {:ok, module} ->
        execute_backend_tool(scope, module, tool_call, task_id, mcp_tools, llm_opts)

      :not_found ->
        execute_mcp_tool(tool_call, task_id)
    end
  end

  # --- Backend Tool Execution ---

  defp execute_backend_tool(scope, module, tool_call, task_id, mcp_tools, llm_opts) do
    Logger.info("ToolExecutor: Executing backend tool #{tool_call.name}")

    case Tasks.get_task(scope, task_id) do
      {:ok, task} ->
        # Pass the executor itself so backend tools can spawn sub-agents
        executor = make_executor(scope, task_id, mcp_tools: mcp_tools, llm_opts: llm_opts)

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

      {:error, _} ->
        {:error, "Task not found or unauthorized"}
    end
  end

  defp strip_null_arguments(%SwarmAi.ToolCall{arguments: arguments} = tool_call)
       when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, args} when is_map(args) ->
        %{tool_call | arguments: Jason.encode!(SchemaTransformer.strip_nulls(args))}

      _ ->
        tool_call
    end
  end

  defp strip_null_arguments(tool_call), do: tool_call

  defp parse_arguments(arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{}
    end
  end

  defp parse_arguments(arguments) when is_map(arguments), do: arguments
  defp parse_arguments(_), do: %{}

  defp encode_result(value) when is_binary(value), do: value
  defp encode_result(value), do: Jason.encode!(value)

  # --- MCP Tool Execution ---

  defp execute_mcp_tool(tool_call, _task_id) do
    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    # Registration already happened in register_if_mcp_tool before broadcast
    tool_call_id = tool_call.id

    receive do
      {:tool_result, ^tool_call_id, content, is_error} ->
        Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id})
        if is_error, do: {:error, content}, else: {:ok, content}
    after
      @tool_timeout_ms ->
        Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id})
        {:error, "Tool timeout: #{tool_call.name}"}
    end
  end

  # --- Image Enrichment ---
  #
  # Tools that return images (e.g. take_screenshot) send base64 data URLs as JSON text.
  # The LLM can't "see" images encoded as text in tool outputs — it needs proper image
  # content parts. This mirrors the same extraction logic in Interaction.to_llm_message.

  # {image_field, extra_text_fields} - same config as Interaction
  @image_tool_configs %{
    "take_screenshot" => {:screenshot, []}
  }

  defp maybe_enrich_with_images(tool_name, {:ok, content} = result) when is_binary(content) do
    canonical_name = String.replace_prefix(tool_name, "mcp_", "")

    case Map.get(@image_tool_configs, canonical_name) do
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
         {:ok, binary, mime} <- decode_data_url(data_url) do
      {:ok, [ContentPart.image(binary, mime)]}
    else
      _ -> :no_image
    end
  end

  defp decode_data_url(data_url) do
    with [_, mime_type, base64] <- Regex.run(~r/^data:([^;]+);base64,(.+)$/s, data_url),
         {:ok, binary} <- Base.decode64(base64) do
      {:ok, binary, mime_type}
    else
      _ -> :error
    end
  end
end
