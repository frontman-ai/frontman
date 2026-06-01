# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.ToolExecutor do
  @moduledoc """
  Builds `ToolExecution` descriptions for both backend and MCP tools.

  `make/4` returns `%{build: fun, execution_mode: mode}`.
  `SwarmAi.ParallelExecutor` is the sole execution authority — this module only
  describes how tools should run.

  ## Backend tools

  Each backend tool becomes a `ToolExecution.Sync` struct whose `run` MFA calls
  `run_backend_tool/4` in the supervised task.

  ## MCP tools

  Each MCP tool becomes a `ToolExecution.Await` struct whose `start` MFA calls
  `start_mcp_tool/3` in PE's own process (so PE's pid is registered in
  `ToolCallRegistry`, enabling `{:tool_result, ...}` routing back to PE).

  ## Callbacks

  `run_backend_tool/5`, `start_mcp_tool/4`, and `handle_timeout/6` are public
  so PE can call them via MFA. They are not part of the public API.
  """

  require Logger

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.Backend
  alias SwarmAi.ToolExecution

  @doc """
  Returns a tool executor config for use with `SwarmAi.ParallelExecutor`.

  The `:build` function maps `[ToolCall.t()]` to `[ToolExecution.t()]`.

  ## Options

  - `:backend_tool_modules` - List of backend tool modules (required)
  - `:mcp_tool_defs` - List of `FrontmanServer.Tools.MCP.t()` with timeout/policy (required)
  - `:execution_mode` - `:parallel` or `:serial` (required)
  """
  @spec make(Accounts.scope(), String.t(), pos_integer(), map()) :: SwarmAi.Agent.tool_executor()
  def make(%Scope{} = scope, task_id, turn_number, opts)
      when is_integer(turn_number) and turn_number > 0 and is_map(opts) do
    exec_opts = build_exec_opts(opts)

    %{
      build: fn tool_calls ->
        Enum.map(tool_calls, &build_execution(&1, scope, task_id, turn_number, exec_opts))
      end,
      execution_mode: Map.fetch!(opts, :execution_mode)
    }
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
        tool_def = find_mcp_tool_def!(tool_call.name, exec_opts)

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
  @spec run_backend_tool(
          Accounts.scope(),
          module(),
          String.t(),
          pos_integer(),
          SwarmAi.ToolCall.t()
        ) ::
          SwarmAi.ToolResult.t()
  def run_backend_tool(%Scope{} = scope, module, task_id, turn_number, tool_call)
      when is_integer(turn_number) and turn_number > 0 do
    case execute_backend_tool(scope, module, tool_call, task_id, turn_number) do
      {:ok, content} ->
        SwarmAi.ToolResult.make(tool_call.id, content, false)

      {:error, reason} ->
        SwarmAi.ToolResult.make(tool_call.id, to_string(reason), true)
    end
  end

  @doc false
  @spec start_mcp_tool(Accounts.scope(), String.t(), pos_integer(), SwarmAi.ToolCall.t()) :: :ok
  def start_mcp_tool(%Scope{} = scope, task_id, turn_number, tool_call)
      when is_integer(turn_number) and turn_number > 0 do
    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    # Register BEFORE publishing to prevent a race where the client responds
    # before PE is listening. self() here = PE's pid.
    register_mcp_tool(tool_call)
    publish_mcp_tool_call(scope, task_id, turn_number, tool_call)
    :ok
  end

  @doc false
  @spec handle_timeout(
          Accounts.scope(),
          String.t(),
          pos_integer(),
          :error | :pause_agent,
          SwarmAi.ToolCall.t(),
          :triggered | :cancelled
        ) ::
          :ok
  def handle_timeout(%Scope{} = scope, task_id, turn_number, :error, tool_call, :triggered)
      when is_integer(turn_number) and turn_number > 0 do
    timeout_msg = "Tool #{tool_call.name} timed out"

    metadata = [
      error_type: "tool_timeout",
      tool_name: tool_call.name,
      tool_call_id: tool_call.id,
      task_id: task_id
    ]

    Logger.error("Backend tool timeout", metadata)

    persist_error_tool_result(scope, task_id, turn_number, tool_call, timeout_msg)
  end

  def handle_timeout(%Scope{} = scope, task_id, turn_number, :error, tool_call, :cancelled)
      when is_integer(turn_number) and turn_number > 0 do
    # Sibling tool triggered :pause_agent, so cancel_remaining cancelled this one.
    # No Sentry report — this is expected cascade behaviour, not a timeout.
    cancel_msg = "Tool #{tool_call.name} cancelled (sibling tool paused agent)"
    Logger.info("ToolExecutor: #{cancel_msg}")

    persist_error_tool_result(scope, task_id, turn_number, tool_call, cancel_msg)
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
  end

  # --- Internal ---

  # Looks up an MCP tool by name for timeout/policy config.
  defp find_mcp_tool_def!(tool_name, exec_opts) do
    found = Enum.find(exec_opts.mcp_tool_defs, &(&1.name == tool_name))

    found ||
      raise "Unknown tool: #{tool_name}. Not a backend tool and not in mcp_tool_defs."
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
    Logger.info("ToolExecutor: Executing backend tool #{tool_call.name}")

    # Re-fetch task from DB so backend tools see latest persisted interactions.
    {:ok, task} = Tasks.get_task(scope, task_id)

    context = %Backend.Context{
      task: task
    }

    case SwarmAi.ToolCall.parse_arguments(tool_call) do
      {:error, message} ->
        raw_arguments = String.slice(tool_call.arguments, 0, 500)

        reason =
          "Failed to parse arguments for tool #{tool_call.name}: #{message}, raw: #{raw_arguments}"

        metadata = [
          error_type: "tool_parse_error",
          tool_name: tool_call.name,
          tool_call_id: tool_call.id,
          task_id: task_id,
          raw_arguments: raw_arguments,
          decode_error: message
        ]

        Logger.error("Tool argument parse failure", metadata)

        persist_error_tool_result(scope, task_id, turn_number, tool_call, reason)
        {:error, reason}

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

  defp handle_backend_outcome({:returned, {:ok, value}}, scope, tool_call, task_id, turn_number) do
    case Tasks.resolve_tool_request(scope, task_id, tool_call, value, false,
           turn_number: turn_number
         ) do
      {:ok, _interaction, _executor_status} ->
        {:ok, encode_result(value)}

      {:error, %Ecto.Changeset{} = changeset} ->
        reason =
          "Tool result not JSON-serializable: #{inspect(changeset.errors)}. Tool: #{tool_call.name}"

        metadata = [
          error_type: "tool_persist_error",
          tool_name: tool_call.name,
          tool_call_id: tool_call.id,
          task_id: task_id,
          reason: reason
        ]

        Logger.error("Tool execution failed", metadata)

        persist_error_tool_result(scope, task_id, turn_number, tool_call, reason)
        {:error, reason}

      {:error, reason} ->
        Logger.error(
          "ToolExecutor: Failed to persist tool result for #{tool_call.name}: #{inspect(reason)}"
        )

        {:error, inspect(reason)}
    end
  end

  defp handle_backend_outcome(
         {:returned, {:error, reason}},
         scope,
         tool_call,
         task_id,
         turn_number
       ) do
    metadata = [
      error_type: "tool_soft_error",
      tool_name: tool_call.name,
      tool_call_id: tool_call.id,
      task_id: task_id,
      reason: inspect(reason)
    ]

    Logger.error("Tool execution failed", metadata)

    persist_error_tool_result(scope, task_id, turn_number, tool_call, reason)
    {:error, reason}
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
    {:error, reason_str}
  end

  defp persist_error_tool_result(scope, task_id, turn_number, tool_call, reason) do
    case Tasks.resolve_tool_request(scope, task_id, tool_call, reason, true,
           turn_number: turn_number
         ) do
      {:ok, _interaction, _executor_status} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "ToolExecutor: Failed to persist error tool result for #{tool_call.name}: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp encode_result(value) when is_binary(value), do: value
  defp encode_result(value), do: Jason.encode!(value)
end
