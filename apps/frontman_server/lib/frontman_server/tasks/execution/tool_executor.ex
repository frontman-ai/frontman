# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.ToolExecutor do
  @moduledoc false

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.MCPConnection
  alias FrontmanServer.Observability.SentryContext
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.CanonicalToolResult
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend
  alias ModelContextProtocol, as: MCP
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
    executions =
      Enum.map(
        tool_calls,
        &build_execution(
          &1,
          scope,
          task_id,
          turn_number,
          backend_tool_modules,
          mcp_tool_defs
        )
      )

    case execution_mode do
      :serial -> SwarmAi.ParallelExecutor.run_serial(executions, task_supervisor)
      :parallel -> SwarmAi.ParallelExecutor.run(executions, task_supervisor)
    end
  end

  defp build_execution(tool_call, scope, task_id, turn_number, backend_modules, mcp_tools) do
    case Enum.find(backend_modules, &(&1.name() == tool_call.name)) do
      nil ->
        build_external_execution(tool_call, scope, task_id, turn_number, mcp_tools)

      module when is_atom(module) ->
        %ToolExecution.Sync{
          tool_call: tool_call,
          timeout_ms: module.timeout_ms(),
          on_timeout_policy: module.on_timeout(),
          run: {__MODULE__, :run_backend_tool, [scope, module, task_id, turn_number]},
          on_timeout:
            {__MODULE__, :handle_timeout, [scope, task_id, turn_number, module.on_timeout()]}
        }
    end
  end

  defp build_external_execution(tool_call, scope, task_id, turn_number, mcp_tools) do
    mcp_tool = Enum.find(mcp_tools, &(&1.name == tool_call.name))

    case {Tools.find_tool(tool_call.name), mcp_tool} do
      {{:ok, _filtered_backend_module}, _mcp_tool} ->
        build_unavailable_execution(tool_call, scope, task_id, turn_number)

      {:not_found, nil} ->
        build_unavailable_execution(tool_call, scope, task_id, turn_number)

      {:not_found, tool_def} ->
        %ToolExecution.Await{
          tool_call: tool_call,
          timeout_ms: tool_def.timeout_ms,
          on_timeout_policy: tool_def.on_timeout,
          start:
            {__MODULE__, :start_mcp_tool, [scope, task_id, turn_number, tool_def.output_schema]},
          on_timeout:
            {__MODULE__, :handle_timeout, [scope, task_id, turn_number, tool_def.on_timeout]}
        }
    end
  end

  defp build_unavailable_execution(tool_call, scope, task_id, turn_number) do
    %ToolExecution.Sync{
      tool_call: tool_call,
      timeout_ms: 5_000,
      on_timeout_policy: :error,
      run: {__MODULE__, :reject_unavailable_tool, [scope, task_id, turn_number]},
      on_timeout: {__MODULE__, :handle_timeout, [scope, task_id, turn_number, :error]}
    }
  end

  @doc false
  def run_backend_tool(%Scope{} = scope, module, task_id, turn_number, tool_call)
      when is_integer(turn_number) and turn_number > 0 do
    SentryContext.set_task_scope_context(scope, task_id)

    result =
      execute_backend_tool(scope, module, tool_call, task_id, turn_number)

    to_swarm_tool_result(tool_call, result)
  end

  @doc false
  def reject_unavailable_tool(%Scope{} = scope, task_id, turn_number, tool_call)
      when is_integer(turn_number) and turn_number > 0 do
    SentryContext.set_task_scope_context(scope, task_id)

    Logger.warning(
      "Model requested unavailable tool #{inspect(tool_call.name)} (#{inspect(tool_call.id)})",
      task_id: task_id
    )

    result =
      persist_error_tool_result(
        scope,
        task_id,
        turn_number,
        tool_call,
        "Tool #{tool_call.name} is unavailable to the current agent"
      )

    to_swarm_tool_result(tool_call, result)
  end

  @doc false
  def start_mcp_tool(%Scope{} = scope, task_id, turn_number, output_schema, tool_call)
      when is_integer(turn_number) and turn_number > 0 do
    SentryContext.set_task_scope_context(scope, task_id)

    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    register_mcp_tool(task_id, tool_call)

    {reference, persisted_tool_call} =
      publish_mcp_tool_call(scope, task_id, turn_number, tool_call, output_schema)

    case MCPConnection.execute_tool(scope, reference, persisted_tool_call) do
      :ok -> :ok
      :unavailable -> raise "No browser MCP connection is available"
    end

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

    persist_unclaimed_cancellation(
      scope,
      task_id,
      turn_number,
      tool_call,
      "Tool timed out",
      timeout_msg
    )

    :ok
  end

  def handle_timeout(%Scope{} = scope, task_id, turn_number, :error, tool_call, :cancelled)
      when is_integer(turn_number) and turn_number > 0 do
    cancel_msg = "Tool #{tool_call.name} cancelled (sibling tool paused agent)"
    Logger.info("ToolExecutor: #{cancel_msg}")

    persist_unclaimed_cancellation(
      scope,
      task_id,
      turn_number,
      tool_call,
      cancel_msg,
      cancel_msg
    )

    :ok
  end

  def handle_timeout(_scope, _task_id, turn_number, :pause_agent, _tool_call, :triggered)
      when is_integer(turn_number) and turn_number > 0 do
    :ok
  end

  def handle_timeout(%Scope{} = scope, task_id, turn_number, :pause_agent, tool_call, :cancelled)
      when is_integer(turn_number) and turn_number > 0 do
    cancel_msg = "Tool #{tool_call.name} cancelled (sibling tool paused agent)"

    persist_unclaimed_cancellation(
      scope,
      task_id,
      turn_number,
      tool_call,
      cancel_msg,
      cancel_msg
    )

    :ok
  end

  defp to_swarm_tool_result(tool_call, %{"content" => _content} = result) do
    is_error = MCP.error?(result)

    SwarmAi.ToolResult.make(
      tool_call.id,
      CanonicalToolResult.to_swarm_content(result),
      is_error
    )
  end

  defp register_mcp_tool(task_id, tool_call) do
    key = {:tool_call, task_id, tool_call.id}

    case Registry.register(FrontmanServer.ToolCallRegistry, key, %{caller_pid: self()}) do
      {:ok, _owner} ->
        :ok

      {:error, {:already_registered, owner}} ->
        raise "Tool call #{inspect(key)} is already registered to #{inspect(owner)}"
    end
  end

  defp publish_mcp_tool_call(
         %Scope{} = scope,
         task_id,
         turn_number,
         tool_call,
         output_schema
       ) do
    case Tasks.request_client_tool_with_reference(
           scope,
           task_id,
           turn_number,
           tool_call,
           output_schema
         ) do
      {:ok, reference, persisted_tool_call} ->
        {reference, persisted_tool_call}

      {:error, reason} ->
        Logger.error(
          "ToolExecutor: Failed to publish MCP tool call #{tool_call.id}: #{inspect(reason)}"
        )

        raise "Failed to publish MCP tool call: #{inspect(reason)}"
    end
  end

  defp execute_backend_tool(scope, module, tool_call, task_id, turn_number) do
    Logger.debug("ToolExecutor: Executing backend tool #{tool_call.name}")
    {:ok, task} = Tasks.get_task(scope, task_id)
    tool_call = SwarmAi.ToolCall.strip_null_arguments(tool_call)

    context = %Backend.Context{
      task: task
    }

    case SwarmAi.ToolCall.parse_arguments(tool_call) do
      {:error, _message} ->
        metadata = [
          error_type: "tool_parse_error",
          tool_name: tool_call.name,
          tool_call_id: tool_call.id,
          task_id: task_id
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
          args,
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
    case result["isError"] do
      true ->
        metadata = [
          error_type: "tool_soft_error",
          tool_name: tool_call.name,
          tool_call_id: tool_call.id,
          task_id: task_id
        ]

        Logger.error("Tool execution failed", metadata)

      _not_error ->
        :ok
    end

    persist_tool_result(scope, task_id, turn_number, tool_call, result)
    result
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

  defp persist_unclaimed_cancellation(
         scope,
         task_id,
         turn_number,
         tool_call,
         cancellation_reason,
         result_reason
       ) do
    case MCPConnection.cancel_tool(scope, task_id, tool_call.id, cancellation_reason) do
      :claimed_cancelled ->
        :ok

      status when status in [:not_found, :unavailable] ->
        persist_claimed_or_legacy_cancellation(
          scope,
          task_id,
          turn_number,
          tool_call,
          result_reason
        )
    end
  end

  defp persist_claimed_or_legacy_cancellation(scope, task_id, turn_number, tool_call, reason) do
    case Tasks.cancel_current_claimed_tool_call(scope, task_id, turn_number, tool_call, reason) do
      {:ok, _result, _executor_status} ->
        :ok

      {:error, error} when error in [:unclaimed, :not_found] ->
        persist_error_tool_result(scope, task_id, turn_number, tool_call, reason)

      {:error, error} ->
        raise "Failed to cancel durable MCP tool claim: #{inspect(error)}"
    end
  end

  defp persist_tool_result(scope, task_id, turn_number, tool_call, result) do
    {:ok, _interaction, _executor_status} =
      Tasks.resolve_tool_request(scope, task_id, tool_call, result, turn_number: turn_number)

    result
  end
end
