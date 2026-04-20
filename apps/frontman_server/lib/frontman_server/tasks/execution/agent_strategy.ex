# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.AgentStrategy do
  @moduledoc """
  Frontman's `ExecutionStrategy` implementation.

  Replaces the former `ToolExecutor` closure-based approach with a plain struct
  implementing the `SwarmAi.ExecutionStrategy` behaviour. Fully testable in
  isolation without standing up the Swarm runtime.

  ## Backend tools

  Each backend tool is executed synchronously via its module's `execute/2`
  callback inside the supervised task that `ParallelExecutor` spawns.

  ## MCP tools

  MCP tools block via `SwarmAi.Runtime.await_tool_result/3` until the browser
  client delivers the result through `SwarmAi.Runtime.deliver_tool_result/5`.
  """

  @behaviour SwarmAi.ExecutionStrategy

  require Logger

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Image
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend
  alias SwarmAi.Message.ContentPart

  defstruct [
    :scope,
    :task_id,
    :runtime,
    :backend_module_map,
    :backend_tool_modules,
    :mcp_tool_defs,
    :mcp_tools,
    :llm_opts
  ]

  # --- ExecutionStrategy callbacks ---

  @impl SwarmAi.ExecutionStrategy
  def init(opts) do
    backend_tool_modules = Keyword.fetch!(opts, :backend_tool_modules)

    state = %__MODULE__{
      scope: Keyword.fetch!(opts, :scope),
      task_id: Keyword.fetch!(opts, :task_id),
      runtime: Keyword.fetch!(opts, :runtime),
      backend_tool_modules: backend_tool_modules,
      backend_module_map: Map.new(backend_tool_modules, &{&1.name(), &1}),
      mcp_tool_defs: Keyword.fetch!(opts, :mcp_tool_defs),
      mcp_tools: Keyword.fetch!(opts, :mcp_tools),
      llm_opts: Keyword.fetch!(opts, :llm_opts)
    }

    {:ok, state}
  end

  @impl SwarmAi.ExecutionStrategy
  def execute_tool(state, tool_call) do
    tool_call = SwarmAi.ToolCall.strip_null_arguments(tool_call)

    result =
      case Map.fetch(state.backend_module_map, tool_call.name) do
        {:ok, module} ->
          execute_backend_tool(state, module, tool_call)

        :error ->
          execute_mcp_tool(state, tool_call)
      end

    {result, state}
  end

  @impl SwarmAi.ExecutionStrategy
  def on_deadline(state, tool_call) do
    policy =
      case Map.get(state.backend_module_map, tool_call.name) do
        nil -> find_mcp_policy(tool_call.name, state)
        module -> map_timeout_policy(module.on_timeout())
      end

    {policy, state}
  end

  # --- Backend Tool Execution ---

  defp execute_backend_tool(state, module, tool_call) do
    Logger.info("AgentStrategy: Executing backend tool #{tool_call.name}")

    # Re-fetch task to get latest interactions
    {:ok, task} = Tasks.get_task(state.scope, state.task_id)

    context_messages = Interaction.extract_markdown_messages(task.interactions)

    context = %Backend.Context{
      scope: state.scope,
      task: task,
      tool_executor: build_legacy_executor(state),
      mcp_tools: state.mcp_tools,
      context_messages: context_messages,
      llm_opts: state.llm_opts
    }

    case parse_arguments(tool_call.name, tool_call.arguments) do
      {:error, reason} ->
        Tasks.add_tool_result(
          state.scope,
          state.task_id,
          tool_call_ref(tool_call),
          reason,
          true
        )

        SwarmAi.ToolResult.make(tool_call.id, to_string(reason), true)

      {:ok, args} ->
        run_backend_tool(state, module, args, context, tool_call)
    end
  end

  defp run_backend_tool(state, module, args, context, tool_call) do
    outcome =
      try do
        {:returned, module.execute(args, context)}
      catch
        kind, reason -> {:crashed, {kind, reason}}
      end

    handle_backend_outcome(outcome, state, tool_call)
  end

  defp handle_backend_outcome({:returned, {:ok, value}}, state, tool_call) do
    case Tasks.add_tool_result(state.scope, state.task_id, tool_call_ref(tool_call), value, false) do
      {:ok, _interaction} ->
        result = maybe_enrich_with_images(tool_call.name, {:ok, encode_result(value)})
        {:ok, content} = result
        SwarmAi.ToolResult.make(tool_call.id, content, false)

      {:error, %Ecto.Changeset{} = changeset} ->
        reason =
          "Tool result not JSON-serializable: #{inspect(changeset.errors)}. Tool: #{tool_call.name}"

        Logger.error("AgentStrategy: #{reason}")
        report_tool_sentry("tool_persist_error", tool_call, state.task_id, reason)
        Tasks.add_tool_result(state.scope, state.task_id, tool_call_ref(tool_call), reason, true)
        SwarmAi.ToolResult.make(tool_call.id, reason, true)

      {:error, reason} ->
        Logger.error(
          "AgentStrategy: Failed to persist tool result for #{tool_call.name}: #{inspect(reason)}"
        )

        SwarmAi.ToolResult.make(tool_call.id, inspect(reason), true)
    end
  end

  defp handle_backend_outcome({:returned, {:error, reason}}, state, tool_call) do
    Logger.error("AgentStrategy: Backend tool #{tool_call.name} returned error: #{inspect(reason)}")
    report_tool_sentry("tool_soft_error", tool_call, state.task_id, inspect(reason))
    Tasks.add_tool_result(state.scope, state.task_id, tool_call_ref(tool_call), reason, true)
    SwarmAi.ToolResult.make(tool_call.id, to_string(reason), true)
  end

  defp handle_backend_outcome({:crashed, reason}, state, tool_call) do
    reason_str = inspect(reason)
    Logger.error("AgentStrategy: Backend tool #{tool_call.name} crashed: #{reason_str}")
    report_tool_sentry("tool_crash", tool_call, state.task_id, reason_str)
    Tasks.add_tool_result(state.scope, state.task_id, tool_call_ref(tool_call), reason_str, true)
    SwarmAi.ToolResult.make(tool_call.id, reason_str, true)
  end

  # --- MCP Tool Execution ---

  defp execute_mcp_tool(state, tool_call) do
    Logger.info("AgentStrategy: Routing to MCP tool #{tool_call.name}")

    # Publish tool call to client BEFORE blocking — so the client knows to execute it
    publish_mcp_tool_call(state.scope, state.task_id, tool_call)

    # Block until deliver_tool_result sends the result
    case SwarmAi.Runtime.await_tool_result(state.runtime, tool_call.id) do
      {:ok, content, is_error} ->
        result = maybe_enrich_with_images(tool_call.name, {:ok, content})
        {:ok, enriched} = result
        SwarmAi.ToolResult.make(tool_call.id, enriched, is_error)

      {:error, :timeout} ->
        SwarmAi.ToolResult.make(tool_call.id, "Tool result delivery timed out", true)
    end
  end

  defp publish_mcp_tool_call(%Scope{} = scope, task_id, tool_call) do
    reqllm_tc = ReqLLM.ToolCall.new(tool_call.id, tool_call.name, tool_call.arguments)

    case Tasks.add_tool_call(scope, task_id, reqllm_tc) do
      {:ok, _interaction} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "AgentStrategy: Failed to publish MCP tool call #{tool_call.id}: #{inspect(reason)}"
        )

        raise "Failed to publish MCP tool call: #{inspect(reason)}"
    end
  end

  # --- Helpers ---

  defp find_mcp_policy(tool_name, state) do
    found =
      Enum.find(state.mcp_tool_defs, &(&1.name == tool_name)) ||
        Enum.find(state.mcp_tools, &(&1.name == tool_name))

    case found do
      %{on_timeout: :pause_agent} -> :pause
      _ -> :error
    end
  end

  defp map_timeout_policy(:pause_agent), do: :pause
  defp map_timeout_policy(_), do: :error

  defp tool_call_ref(tool_call), do: %{id: tool_call.id, name: tool_call.name}

  # Build a legacy executor function for Backend.Context.tool_executor
  # (used by backend tools that spawn sub-agents)
  defp build_legacy_executor(state) do
    fn tool_calls ->
      Enum.map(tool_calls, fn tc ->
        tc = SwarmAi.ToolCall.strip_null_arguments(tc)

        case Map.fetch(state.backend_module_map, tc.name) do
          {:ok, module} ->
            %SwarmAi.ToolExecution.Sync{
              tool_call: tc,
              timeout_ms: module.timeout_ms(),
              on_timeout_policy: module.on_timeout(),
              run: {__MODULE__, :run_backend_tool_mfa, [state, module]},
              on_timeout: {__MODULE__, :handle_timeout_mfa, [state, module.on_timeout()]}
            }

          :error ->
            tool_def = find_mcp_tool_def!(tc.name, state)

            %SwarmAi.ToolExecution.Await{
              tool_call: tc,
              timeout_ms: tool_def.timeout_ms,
              on_timeout_policy: tool_def.on_timeout,
              start: {__MODULE__, :start_mcp_tool_mfa, [state]},
              message_key: tc.id,
              on_timeout: {__MODULE__, :handle_timeout_mfa, [state, tool_def.on_timeout]},
              process_result: nil
            }
        end
      end)
    end
  end

  defp find_mcp_tool_def!(tool_name, state) do
    Enum.find(state.mcp_tool_defs, &(&1.name == tool_name)) ||
      Enum.find(state.mcp_tools, &(&1.name == tool_name)) ||
      raise "Unknown tool: #{tool_name}. Not in backend_module_map, mcp_tool_defs, or mcp_tools."
  end

  defp parse_arguments(tool_name, arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, decode_error} ->
        reason =
          "Failed to parse arguments for tool #{tool_name}: #{inspect(decode_error)}, raw: #{String.slice(arguments, 0, 500)}"

        Logger.error("AgentStrategy: #{reason}")

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

  # --- Image Enrichment ---

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
      _non_string_field -> :no_image
    end
  end

  # --- MFA callbacks for legacy executor (sub-agent compatibility) ---

  @doc false
  def run_backend_tool_mfa(state, module, tool_call) do
    execute_backend_tool(state, module, tool_call)
  end

  @doc false
  def start_mcp_tool_mfa(state, tool_call) do
    # Register PE's pid in the Runtime's ToolRegistry BEFORE publishing.
    # self() here = PE's pid (start MFA runs in PE's own process).
    # This lets deliver_tool_result route {:tool_result, ...} back to PE.
    tool_reg = SwarmAi.Runtime.tool_registry_name(state.runtime)
    Registry.register(tool_reg, {:awaiting_result, tool_call.id}, %{})

    publish_mcp_tool_call(state.scope, state.task_id, tool_call)
    :ok
  end

  @doc false
  def handle_timeout_mfa(state, :error, tool_call, :triggered) do
    timeout_msg = "Tool #{tool_call.name} timed out"
    Logger.error("AgentStrategy: #{timeout_msg}")

    Tasks.add_tool_result(
      state.scope,
      state.task_id,
      %{id: tool_call.id, name: tool_call.name},
      timeout_msg,
      true
    )

    :ok
  end

  def handle_timeout_mfa(state, :error, tool_call, :cancelled) do
    cancel_msg = "Tool #{tool_call.name} cancelled (sibling tool paused agent)"
    Logger.info("AgentStrategy: #{cancel_msg}")

    Tasks.add_tool_result(
      state.scope,
      state.task_id,
      %{id: tool_call.id, name: tool_call.name},
      cancel_msg,
      true
    )

    :ok
  end

  def handle_timeout_mfa(_state, :pause_agent, _tool_call, :triggered), do: :ok

  def handle_timeout_mfa(state, :pause_agent, tool_call, :cancelled) do
    cancel_msg = "Tool #{tool_call.name} cancelled (sibling tool paused agent)"

    Tasks.add_tool_result(
      state.scope,
      state.task_id,
      %{id: tool_call.id, name: tool_call.name},
      cancel_msg,
      true
    )

    :ok
  end
end
