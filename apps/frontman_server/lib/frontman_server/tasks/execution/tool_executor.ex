# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.ToolExecutor do
  @moduledoc """
  Builds `ToolExecution` descriptions for both backend and MCP tools.

  `make_executor/3` returns a single function `[ToolCall.t()] -> [ToolExecution.t()]`.
  `SwarmAi.ParallelExecutor` is the sole execution authority — this module only
  describes how tools should run.

  ## Backend tools

  Each backend tool becomes a `ToolExecution.Sync` struct whose `run` MFA calls
  `run_backend_tool/5` in the spawned task.

  ## MCP tools

  Each MCP tool becomes a `ToolExecution.Await` struct whose `start` MFA calls
  `start_mcp_tool/3` in PE's own process (so PE's pid is registered in
  `ToolCallRegistry`, enabling `{:tool_result, ...}` routing back to PE).

  ## Callbacks

  `run_backend_tool/5`, `start_mcp_tool/3`, and `handle_timeout/5` are public
  so PE can call them via MFA. They are not part of the public API.
  """

  require Logger

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Image
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend
  alias SwarmAi.Message.ContentPart
  alias SwarmAi.ToolExecution

  @doc """
  Returns an executor function for use with `SwarmAi.ParallelExecutor`.

  The returned function maps `[ToolCall.t()]` to `[ToolExecution.t()]`.

  ## Options

  - `:backend_tool_modules` - List of backend tool modules (required)
  - `:mcp_tools` - List of `SwarmAi.Tool.t()` for sub-agents (required)
  - `:mcp_tool_defs` - List of `FrontmanServer.Tools.MCP.t()` with timeout/policy (required)
  - `:llm_opts` - Keyword list with `:api_key` and `:model` (required)
  """
  @spec make_executor(Accounts.scope(), String.t(), keyword()) ::
          ([SwarmAi.ToolCall.t()] -> [ToolExecution.Sync.t() | ToolExecution.Await.t()])
  def make_executor(%Scope{} = scope, task_id, opts) do
    exec_opts = build_exec_opts(opts)

    fn tool_calls ->
      Enum.map(tool_calls, fn tc ->
        tc = strip_null_arguments(tc)
        build_execution(tc, scope, task_id, exec_opts)
      end)
    end
  end

  defp build_execution(tool_call, scope, task_id, exec_opts) do
    case Map.fetch(exec_opts.backend_module_map, tool_call.name) do
      {:ok, module} ->
        %ToolExecution.Sync{
          tool_call: tool_call,
          timeout_ms: module.timeout_ms(),
          on_timeout_policy: module.on_timeout(),
          run: {__MODULE__, :run_backend_tool, [scope, module, task_id, exec_opts]},
          on_timeout: {__MODULE__, :handle_timeout, [scope, task_id, module.on_timeout()]}
        }

      :error ->
        tool_def = find_mcp_tool_def!(tool_call.name, exec_opts)

        %ToolExecution.Await{
          tool_call: tool_call,
          timeout_ms: tool_def.timeout_ms,
          on_timeout_policy: tool_def.on_timeout,
          start: {__MODULE__, :start_mcp_tool, [scope, task_id]},
          message_key: tool_call.id,
          on_timeout: {__MODULE__, :handle_timeout, [scope, task_id, tool_def.on_timeout]},
          process_result: {__MODULE__, :make_mcp_tool_result, [tool_call.name]}
        }
    end
  end

  # --- PE Callbacks (public for MFA dispatch) ---

  @doc false
  @spec run_backend_tool(Accounts.scope(), module(), String.t(), map(), SwarmAi.ToolCall.t()) ::
          SwarmAi.ToolResult.t()
  def run_backend_tool(%Scope{} = scope, module, task_id, exec_opts, tool_call) do
    result = execute_backend_tool(scope, module, tool_call, task_id, exec_opts)
    result = maybe_enrich_with_images(tool_call.name, result)

    case result do
      {:ok, content} -> SwarmAi.ToolResult.make(tool_call.id, content, false)
      {:error, reason} -> SwarmAi.ToolResult.make(tool_call.id, to_string(reason), true)
    end
  end

  @doc false
  @spec start_mcp_tool(Accounts.scope(), String.t(), SwarmAi.ToolCall.t()) :: :ok
  def start_mcp_tool(%Scope{} = scope, task_id, tool_call) do
    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    # Register BEFORE publishing to prevent a race where the client responds
    # before PE is listening. self() here = PE's pid.
    register_mcp_tool(tool_call)
    publish_mcp_tool_call(scope, task_id, tool_call)
    :ok
  end

  @doc false
  @spec make_mcp_tool_result(String.t(), SwarmAi.ToolCall.t(), term(), boolean()) ::
          SwarmAi.ToolResult.t()
  def make_mcp_tool_result(tool_name, tool_call, content, is_error) do
    {:ok, enriched} = maybe_enrich_with_images(tool_name, {:ok, content})
    SwarmAi.ToolResult.make(tool_call.id, enriched, is_error)
  end

  @doc false
  @spec handle_timeout(
          Accounts.scope(),
          String.t(),
          :error | :pause_agent,
          SwarmAi.ToolCall.t(),
          :triggered | :cancelled
        ) ::
          :ok
  def handle_timeout(%Scope{} = scope, task_id, :error, tool_call, :triggered) do
    timeout_msg = "Tool #{tool_call.name} timed out"
    Logger.error("ToolExecutor: #{timeout_msg}")
    report_tool_timeout_sentry(tool_call, task_id)

    Tasks.add_tool_result(
      scope,
      task_id,
      %{id: tool_call.id, name: tool_call.name},
      timeout_msg,
      true
    )

    :ok
  end

  def handle_timeout(%Scope{} = scope, task_id, :error, tool_call, :cancelled) do
    # Sibling tool triggered :pause_agent, so cancel_remaining cancelled this one.
    # No Sentry report — this is expected cascade behaviour, not a timeout.
    cancel_msg = "Tool #{tool_call.name} cancelled (sibling tool paused agent)"
    Logger.info("ToolExecutor: #{cancel_msg}")

    Tasks.add_tool_result(
      scope,
      task_id,
      %{id: tool_call.id, name: tool_call.name},
      cancel_msg,
      true
    )

    :ok
  end

  def handle_timeout(_scope, _task_id, :pause_agent, _tool_call, :triggered) do
    # SwarmDispatcher persists the ToolResult for the triggered tool via the
    # {:paused, {:timeout, ...}} event. Nothing to do here.
    :ok
  end

  def handle_timeout(%Scope{} = scope, task_id, :pause_agent, tool_call, :cancelled) do
    # Sibling cancelled by cancel_remaining — SwarmDispatcher never sees this tool,
    # so we must persist here to satisfy the ToolCall→ToolResult DB invariant.
    cancel_msg = "Tool #{tool_call.name} cancelled (sibling tool paused agent)"

    Tasks.add_tool_result(
      scope,
      task_id,
      %{id: tool_call.id, name: tool_call.name},
      cancel_msg,
      true
    )

    :ok
  end

  # --- Internal ---

  # Looks up a tool by name for timeout/policy config. Checks mcp_tool_defs
  # (FrontmanServer.Tools.MCP.t()) first, then mcp_tools (SwarmAi.Tool.t()).
  # Both structs have timeout_ms and on_timeout fields.
  defp find_mcp_tool_def!(tool_name, exec_opts) do
    found =
      Enum.find(exec_opts.mcp_tool_defs, &(&1.name == tool_name)) ||
        Enum.find(exec_opts.mcp_tools, &(&1.name == tool_name))

    found ||
      raise "Unknown tool: #{tool_name}. Not a backend tool and not in mcp_tool_defs or mcp_tools."
  end

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
    executor =
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
        do_run_backend_tool(scope, module, args, context, tool_call, task_id)
    end
  end

  defp do_run_backend_tool(scope, module, args, context, tool_call, task_id) do
    outcome =
      try do
        {:returned, module.execute(args, context)}
      catch
        kind, reason -> {:crashed, {kind, reason}}
      end

    handle_backend_outcome(outcome, scope, tool_call, task_id)
  end

  defp handle_backend_outcome({:returned, {:ok, value}}, scope, tool_call, task_id) do
    case Tasks.add_tool_result(scope, task_id, tool_call_ref(tool_call), value, false) do
      {:ok, _interaction, _executor_status} ->
        {:ok, encode_result(value)}

      {:error, %Ecto.Changeset{} = changeset} ->
        reason =
          "Tool result not JSON-serializable: #{inspect(changeset.errors)}. Tool: #{tool_call.name}"

        Logger.error("ToolExecutor: #{reason}")
        report_tool_sentry("tool_persist_error", tool_call, task_id, reason)
        Tasks.add_tool_result(scope, task_id, tool_call_ref(tool_call), reason, true)
        {:error, reason}

      {:error, reason} ->
        Logger.error(
          "ToolExecutor: Failed to persist tool result for #{tool_call.name}: #{inspect(reason)}"
        )

        {:error, inspect(reason)}
    end
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
