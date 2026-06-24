# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.ToolExecutor do
  @moduledoc false

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Observability.SentryContext
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.Backend
  alias ModelContextProtocol, as: MCP
  alias SwarmAi.Message.ContentPart
  alias SwarmAi.ToolExecution

  def execute(%Scope{} = scope, %{
        task_id: task_id,
        turn_number: turn_number,
        tool_calls: tool_calls,
        task_supervisor: task_supervisor,
        backend_tool_modules: backend_tool_modules,
        mcp_tool_defs: mcp_tool_defs,
        execution_mode: execution_mode
      }) do
    exec_opts =
      build_exec_opts(%{
        backend_tool_modules: backend_tool_modules,
        mcp_tool_defs: mcp_tool_defs
      })

    executions =
      Enum.map(tool_calls, &build_execution(&1, scope, task_id, turn_number, exec_opts))

    case execution_mode do
      :serial -> SwarmAi.ParallelExecutor.run_serial(executions, task_supervisor)
      :parallel -> SwarmAi.ParallelExecutor.run(executions, task_supervisor)
    end
  end

  defp build_execution(tool_call, scope, task_id, turn_number, exec_opts) do
    case Map.fetch(exec_opts.backend_module_map, tool_call.name) do
      {:ok, module} ->
        %ToolExecution.Sync{
          tool_call: tool_call,
          timeout_ms: module.timeout_ms(),
          on_timeout_policy: module.on_timeout(),
          run: {__MODULE__, :run_backend_tool, [scope, module, task_id, turn_number]},
          on_timeout:
            {__MODULE__, :handle_timeout, [scope, task_id, turn_number, module.on_timeout()]}
        }

      :error ->
        {:ok, tool_def} = find_mcp_tool_def(tool_call.name, exec_opts)

        %ToolExecution.Await{
          tool_call: tool_call,
          timeout_ms: tool_def.timeout_ms,
          on_timeout_policy: tool_def.on_timeout,
          start: {__MODULE__, :start_mcp_tool, [scope, task_id, turn_number]},
          on_timeout:
            {__MODULE__, :handle_timeout, [scope, task_id, turn_number, tool_def.on_timeout]}
        }
    end
  end

  # --- PE Callbacks (public for MFA dispatch) ---

  @doc false
  def run_backend_tool(%Scope{} = scope, module, task_id, turn_number, tool_call)
      when is_integer(turn_number) and turn_number > 0 do
    SentryContext.set_task_scope_context(scope, task_id)

    %{"content" => content} =
      result =
      execute_backend_tool(scope, module, tool_call, task_id, turn_number)

    is_error = MCP.error?(result)

    SwarmAi.ToolResult.make(
      tool_call.id,
      Enum.map(content, fn
        %{"type" => "text", "text" => text} ->
          ContentPart.text(text)

        %{"type" => "image", "data" => data, "mimeType" => mime_type} ->
          ContentPart.image(Base.decode64!(data), mime_type)
      end),
      is_error
    )
  end

  @doc false
  def start_mcp_tool(%Scope{} = scope, task_id, turn_number, tool_call)
      when is_integer(turn_number) and turn_number > 0 do
    SentryContext.set_task_scope_context(scope, task_id)

    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    # Register BEFORE publishing to prevent a race where the client responds
    # before PE is listening. self() here = PE's pid.
    register_mcp_tool(tool_call)
    publish_mcp_tool_call(scope, task_id, turn_number, tool_call)
    :ok
  end

  @doc false
  def handle_timeout(%Scope{} = scope, task_id, turn_number, :error, tool_call, :triggered)
      when is_integer(turn_number) and turn_number > 0 do
    SentryContext.set_task_scope_context(scope, task_id)

    timeout_msg = "Tool #{tool_call.name} timed out"

    metadata = [
      error_type: "tool_timeout",
      tool_name: tool_call.name,
      tool_call_id: tool_call.id,
      task_id: task_id
    ]

    Logger.error("Backend tool timeout", metadata)

    persist_error_tool_result(scope, task_id, turn_number, tool_call, timeout_msg)
    :ok
  end

  def handle_timeout(%Scope{} = scope, task_id, turn_number, :error, tool_call, :cancelled)
      when is_integer(turn_number) and turn_number > 0 do
    # Sibling tool triggered :pause_agent, so cancel_remaining cancelled this one.
    # No Sentry report — this is expected cascade behaviour, not a timeout.
    cancel_msg = "Tool #{tool_call.name} cancelled (sibling tool paused agent)"
    Logger.info("ToolExecutor: #{cancel_msg}")

    persist_error_tool_result(scope, task_id, turn_number, tool_call, cancel_msg)
    :ok
  end

  def handle_timeout(_scope, _task_id, turn_number, :pause_agent, _tool_call, :triggered)
      when is_integer(turn_number) and turn_number > 0 do
    # Tasks persists the ToolResult for the triggered tool via the
    # {:paused, {:timeout, ...}} event. Nothing to do here.
    :ok
  end

  def handle_timeout(%Scope{} = scope, task_id, turn_number, :pause_agent, tool_call, :cancelled)
      when is_integer(turn_number) and turn_number > 0 do
    # Sibling cancelled by cancel_remaining -- no Swarm event is emitted for this tool,
    # so we must persist here to satisfy the ToolCall→ToolResult DB invariant.
    cancel_msg = "Tool #{tool_call.name} cancelled (sibling tool paused agent)"

    persist_error_tool_result(scope, task_id, turn_number, tool_call, cancel_msg)
    :ok
  end

  # --- Internal ---

  defp find_mcp_tool_def(tool_name, exec_opts) do
    found = Enum.find(exec_opts.mcp_tool_defs, &(&1.name == tool_name))

    if found do
      {:ok, found}
    else
      {:error, :not_found}
    end
  end

  defp build_exec_opts(opts) do
    backend_tool_modules = Map.fetch!(opts, :backend_tool_modules)

    %{
      backend_module_map: Map.new(backend_tool_modules, &{&1.name(), &1}),
      mcp_tool_defs: Map.fetch!(opts, :mcp_tool_defs)
    }
  end

  defp register_mcp_tool(tool_call) do
    Registry.register(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call.id}, %{
      caller_pid: self()
    })
  end

  defp publish_mcp_tool_call(%Scope{} = scope, task_id, turn_number, tool_call) do
    case Tasks.request_client_tool(scope, task_id, turn_number, tool_call) do
      {:ok, _interaction} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "ToolExecutor: Failed to publish MCP tool call #{tool_call.id}: #{inspect(reason)}"
        )

        raise "Failed to publish MCP tool call: #{inspect(reason)}"
    end
  end

  # --- Backend Tool Execution ---

  defp execute_backend_tool(scope, module, tool_call, task_id, turn_number) do
    Logger.debug("ToolExecutor: Executing backend tool #{tool_call.name}")
    {:ok, task} = Tasks.get_task(scope, task_id)

    context = %Backend.Context{
      task: task
    }

    case SwarmAi.ToolCall.parse_arguments(tool_call) do
      {:error, message} ->
        metadata = [
          error_type: "tool_parse_error",
          tool_name: tool_call.name,
          tool_call_id: tool_call.id,
          task_id: task_id,
          raw_arguments: String.slice(tool_call.arguments, 0, 500),
          decode_error: message
        ]

        Logger.error("Tool argument parse failure", metadata)

        persist_error_tool_result(
          scope,
          task_id,
          turn_number,
          tool_call,
          "Failed to parse arguments for tool"
        )

      {:ok, args} ->
        do_run_backend_tool(
          scope,
          module,
          SwarmAi.SchemaTransformer.strip_nulls(args),
          context,
          tool_call,
          task_id,
          turn_number
        )
    end
  end

  defp do_run_backend_tool(scope, module, args, context, tool_call, task_id, turn_number) do
    outcome =
      try do
        {:returned, module.execute(args, context)}
      catch
        kind, reason -> {:crashed, {kind, reason}}
      end

    handle_backend_outcome(outcome, scope, tool_call, task_id, turn_number)
  end

  defp handle_backend_outcome(
         {:returned, %{"content" => content} = result},
         scope,
         tool_call,
         task_id,
         turn_number
       )
       when is_list(content) do
    is_error = MCP.error?(result)

    if is_error do
      metadata = [
        error_type: "tool_soft_error",
        tool_name: tool_call.name,
        tool_call_id: tool_call.id,
        task_id: task_id,
        reason: MCP.extract_content_text(result)
      ]

      Logger.error("Tool execution failed", metadata)
    end

    persist_tool_result(scope, task_id, turn_number, tool_call, result)
  end

  defp handle_backend_outcome(
         {:returned, result},
         scope,
         tool_call,
         task_id,
         turn_number
       ) do
    Logger.error("Incorrect tool result")
    persist_tool_result(scope, task_id, turn_number, tool_call, result)
  end

  defp handle_backend_outcome({:crashed, reason}, scope, tool_call, task_id, turn_number) do
    reason_str = inspect(reason)

    metadata = [
      error_type: "tool_crash",
      tool_name: tool_call.name,
      tool_call_id: tool_call.id,
      task_id: task_id,
      reason: reason_str
    ]

    Logger.error("Tool execution failed", metadata)

    persist_error_tool_result(scope, task_id, turn_number, tool_call, reason_str)
  end

  defp persist_error_tool_result(scope, task_id, turn_number, tool_call, reason) do
    persist_tool_result(scope, task_id, turn_number, tool_call, MCP.tool_result_error(reason))
  end

  defp persist_tool_result(scope, task_id, turn_number, tool_call, result) do
    {:ok, _interaction, _executor_status} =
      Tasks.resolve_tool_request(scope, task_id, tool_call, result, MCP.error?(result),
        turn_number: turn_number
      )

    result
  end
end
