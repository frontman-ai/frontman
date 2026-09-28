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
  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend
  alias FrontmanServer.Tools.MCP, as: MCPTool
  alias SwarmAi.ToolExecution

  def callback(%Scope{} = scope, tools, execution_mode, task_id, turn_number)
      when is_map(tools) and is_binary(task_id) and is_integer(turn_number) and turn_number > 0 do
    turn_ref = %{task_id: task_id, turn_number: turn_number}

    fn tool_calls, task_supervisor ->
      executions = Enum.map(tool_calls, &build_execution(scope, turn_ref, &1, tools))

      case execution_mode do
        :serial -> SwarmAi.ParallelExecutor.run_serial(executions, task_supervisor)
        :parallel -> SwarmAi.ParallelExecutor.run(executions, task_supervisor)
      end
    end
  end

  defp build_execution(scope, turn_ref, tool_call, tools) do
    %{task_id: task_id, turn_number: turn_number} = turn_ref

    case Map.get(tools, tool_call.name) do
      nil ->
        build_rejected_execution(scope, turn_ref, tool_call)

      %MCPTool{} = tool ->
        %ToolExecution.Await{
          tool_call: tool_call,
          timeout_ms: tool.timeout_ms,
          start:
            {__MODULE__, :start_mcp_tool, [scope, task_id, turn_number, tool.execution_mode]},
          on_error: {__MODULE__, :handle_error, [scope, task_id, turn_number]}
        }

      module when is_atom(module) ->
        %ToolExecution.Sync{
          tool_call: tool_call,
          timeout_ms: module.timeout_ms(),
          run: {__MODULE__, :run_backend_tool, [scope, module, task_id, turn_number]},
          on_error: {__MODULE__, :handle_error, [scope, task_id, turn_number]}
        }
    end
  end

  defp build_rejected_execution(scope, turn_ref, tool_call) do
    %{task_id: task_id, turn_number: turn_number} = turn_ref

    %ToolExecution.Sync{
      tool_call: tool_call,
      timeout_ms: 5_000,
      run: {__MODULE__, :reject_unavailable_tool, [scope, task_id, turn_number]},
      on_error: {__MODULE__, :handle_error, [scope, task_id, turn_number]}
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
  def start_mcp_tool(%Scope{} = scope, task_id, turn_number, execution_mode, tool_call)
      when is_integer(turn_number) and turn_number > 0 do
    SentryContext.set_task_scope_context(scope, task_id)

    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    register_mcp_tool(task_id, tool_call)
    publish_mcp_tool_call(scope, task_id, turn_number, tool_call, execution_mode)
    :ok
  end

  @doc false
  def handle_error(%Scope{} = scope, task_id, turn_number, reason, tool_call)
      when is_integer(turn_number) and turn_number > 0 do
    SentryContext.set_task_scope_context(scope, task_id)

    {error_type, message} =
      case reason do
        :timeout ->
          {"tool_timeout",
           "Tool #{tool_call.name} timed out. Execution may still be in progress; " <>
             "do not blindly retry mutations."}

        {:crashed, exit_reason} ->
          {"tool_crash", "Tool #{tool_call.name} crashed: #{inspect(exit_reason)}"}
      end

    metadata = [
      error_type: error_type,
      tool_name: tool_call.name,
      tool_call_id: tool_call.id,
      task_id: task_id
    ]

    Logger.error("Tool execution failed", metadata)

    result = persist_error_tool_result(scope, task_id, turn_number, tool_call, message)
    to_swarm_tool_result(tool_call, result)
  end

  defp to_swarm_tool_result(tool_call, result) do
    SwarmAi.ToolResult.make(
      tool_call.id,
      Interaction.tool_result_content_parts(result),
      MCP.error?(result)
    )
  end

  @doc """
  Notifies that a tool result has arrived.

  Routes the result to the blocking executor via Registry metadata.
  Returns `:notified` when the result was delivered to a live executor,
  `:no_executor` when no executor was waiting (e.g., server restarted).
  """
  def notify_tool_result(task_id, %Interaction.ToolResult{
        tool_call_id: tool_call_id,
        result: %{"content" => content} = result,
        is_error: is_error
      })
      when is_list(content) do
    case Registry.lookup(
           FrontmanServer.ProcessRegistry,
           tool_registry_key(task_id, tool_call_id)
         ) do
      [{_pid, %{caller_pid: caller}}] ->
        content_parts = Interaction.tool_result_content_parts(result)
        send(caller, {:tool_result, tool_call_id, content_parts, is_error})
        :notified

      [] ->
        :no_executor
    end
  end

  def notify_tool_result(_task_id, %Interaction.ToolResult{}), do: :no_executor

  defp register_mcp_tool(task_id, tool_call) do
    case Registry.register(
           FrontmanServer.ProcessRegistry,
           tool_registry_key(task_id, tool_call.id),
           %{
             caller_pid: self()
           }
         ) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_registered, _pid}} ->
        raise "Duplicate MCP tool executor registration for task #{task_id}, call #{tool_call.id}"
    end
  end

  defp tool_registry_key(task_id, tool_call_id), do: {:tool_call, task_id, tool_call_id}

  defp publish_mcp_tool_call(%Scope{} = scope, task_id, turn_number, tool_call, execution_mode) do
    case Tasks.request_client_tool(scope, task_id, turn_number, tool_call, execution_mode) do
      {:ok, _interaction} ->
        :ok

      {:error, {:invalid_tool_arguments, _message}} ->
        Logger.error("Tool argument parse failure", tool_parse_metadata(tool_call, task_id))

        persist_error_tool_result(
          scope,
          task_id,
          turn_number,
          tool_call,
          "Failed to parse arguments for tool"
        )

      {:error, reason} ->
        Logger.error(
          "ToolExecutor: Failed to publish MCP tool call #{tool_call.id}: #{inspect(reason)}"
        )

        raise "Failed to publish MCP tool call: #{inspect(reason)}"
    end
  end

  defp execute_backend_tool(scope, module, tool_call, task_id, turn_number) do
    Logger.debug("ToolExecutor: Executing backend tool #{tool_call.name}")
    {:ok, task} = Tasks.get_task_with_history(scope, task_id)
    tool_call = SwarmAi.ToolCall.strip_null_arguments(tool_call)

    context = %Backend.Context{
      task: task,
      scope: scope
    }

    case SwarmAi.ToolCall.parse_arguments(tool_call) do
      {:error, _message} ->
        Logger.error("Tool argument parse failure", tool_parse_metadata(tool_call, task_id))

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

  defp tool_parse_metadata(tool_call, task_id) do
    [
      error_type: "tool_parse_error",
      tool_name: tool_call.name,
      tool_call_id: tool_call.id,
      task_id: task_id
    ]
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
  end

  defp handle_backend_outcome(
         {:returned, _invalid},
         scope,
         tool_call,
         task_id,
         turn_number
       ) do
    Logger.error("Incorrect tool result")
    persist_error_tool_result(scope, task_id, turn_number, tool_call, "Invalid tool result")
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
    {:ok, interaction, _status} =
      Tasks.resolve_tool_request(scope, task_id, tool_call, result, turn_number: turn_number)

    interaction.result
  end
end
