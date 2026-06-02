# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.SwarmDispatcher do
  @moduledoc """
  Bridges SwarmAi Runtime events to persistence and Phoenix PubSub.

  Configured as the `event_dispatcher` MFA for `SwarmAi.Runtime`.

  ## Persist-then-broadcast

  All agent lifecycle events are **persisted to the database first** (from the
  Runtime Task process), then broadcast on PubSub for real-time UI updates.

  This ensures data survives client disconnects — the channel process is only
  needed for live pushes, never for persistence.
  """

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.ExecutionEvent

  def dispatch(key, event, metadata) do
    scope = Map.get(metadata, :scope)
    task_id = to_string(key)

    # 1. Persist (runs in the Runtime Task process — channel-independent)
    persist(scope, task_id, event, metadata)

    # 2. Broadcast as a domain event (ACL boundary).
    topic = Tasks.topic(task_id)
    {type, payload} = event

    domain_event = %ExecutionEvent{
      type: type,
      payload: payload,
      caused_by: metadata[:interaction_id]
    }

    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, topic, {:execution_event, domain_event})
  end

  # --- Persistence ---

  # Scope may be nil for recovered processes after a monitor restart.
  # In that case we can only broadcast, not persist — but the data was
  # likely already persisted before the restart.
  defp persist(nil, _task_id, _event, _metadata), do: :ok

  # Agent produced a response (may include tool calls in metadata).
  # Previously this only happened inside the channel's handle_info.
  defp persist(%Scope{} = scope, task_id, {:response, response}, _metadata) do
    metadata = response_metadata(response)
    Tasks.add_agent_response(scope, task_id, response.content || "", metadata)
  end

  # Agent turn completed successfully.
  defp persist(%Scope{} = scope, task_id, {:completed, {:ok, _result, loop_id}}, metadata) do
    resolved_key = Map.get(metadata, :resolved_key)
    if resolved_key, do: Providers.record_usage(scope, resolved_key)
    Tasks.add_agent_completed(scope, task_id)
    Logger.debug("Execution completed for task #{task_id}, loop_id: #{loop_id}")
    TelemetryEvents.task_stop(task_id)
  end

  # Agent turn failed (LLM error, tool error, etc.)
  defp persist(%Scope{} = scope, task_id, {:failed, {:error, reason, loop_id}}, _metadata) do
    {reason_str, category, retryable} = ExecutionEvent.classify_error(reason)

    metadata = [
      error_type: "agent_execution_error",
      task_id: task_id,
      loop_id: loop_id,
      reason: reason_str
    ]

    Logger.error("Agent execution failed", metadata)

    Tasks.add_agent_error(scope, task_id, reason_str, "failed", retryable, category)
    TelemetryEvents.task_stop(task_id)
  end

  # Agent process crashed unexpectedly.
  defp persist(
         %Scope{} = scope,
         task_id,
         {:crashed, %{reason: reason, stacktrace: stacktrace}},
         _metadata
       ) do
    metadata = [
      crash_reason: {reason, stacktrace},
      error_type: "agent_crash",
      task_id: task_id,
      reason: inspect(reason)
    ]

    Logger.error("Agent execution crashed", metadata)

    Tasks.add_agent_error(
      scope,
      task_id,
      format_crash_reason(reason),
      "crashed",
      false,
      "unknown"
    )

    TelemetryEvents.task_stop(task_id)
  end

  # Agent was cancelled (user requested cancel).
  defp persist(%Scope{} = scope, task_id, {:cancelled, _}, _metadata) do
    Tasks.add_agent_error(scope, task_id, "Cancelled", "cancelled", false, "unknown")
    TelemetryEvents.task_stop(task_id)
  end

  # Agent was terminated by supervisor (e.g. :rest_for_one restart).
  # Not a crash (nothing broke) and not a cancellation (user didn't ask).
  # No Sentry alert — this is infrastructure recovery, not a bug.
  defp persist(%Scope{} = scope, task_id, {:terminated, _}, _metadata) do
    Logger.info("Execution terminated by supervisor for task #{task_id}")
    Tasks.add_agent_error(scope, task_id, "Terminated by supervisor", "terminated")
    TelemetryEvents.task_stop(task_id)
  end

  # Agent loop paused due to a tool's on_timeout: :pause_agent.
  # Persist a timeout ToolResult first (DB invariant: every ToolCall has a matching
  # ToolResult), then AgentPaused so reconnecting clients know why the agent stopped.
  defp persist(
         %Scope{} = scope,
         task_id,
         {:paused, {:timeout, tool_call_id, tool_name, timeout_ms}},
         _metadata
       ) do
    reason = "Tool #{tool_name} timed out after #{timeout_ms}ms (on_timeout: :pause_agent)"
    Tasks.add_tool_result(scope, task_id, %{id: tool_call_id, name: tool_name}, reason, true)
    Tasks.add_agent_paused(scope, task_id, tool_name, timeout_ms)
    TelemetryEvents.task_stop(task_id)
  end

  # Streaming chunks — ephemeral, no persistence needed.
  defp persist(_scope, _task_id, {:chunk, _}, _metadata), do: :ok

  # Tool call announced — already persisted by ToolExecutor directly.
  defp persist(_scope, _task_id, {:tool_call, _}, _metadata), do: :ok

  # --- Helpers ---

  defp response_metadata(response) do
    meta = Map.get(response, :metadata) || %{}
    response_id = meta[:response_id]
    phase = meta[:phase]

    %{
      "tool_calls" => stored_tool_calls(Map.get(response, :tool_calls)),
      "reasoning_details" => non_empty(Map.get(response, :reasoning_details)),
      "response_id" => if(is_binary(response_id), do: response_id),
      "phase" => if(is_binary(phase), do: phase),
      "phase_items" => non_empty(meta[:phase_items])
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp stored_tool_calls(tool_calls) when is_list(tool_calls) and tool_calls != [] do
    Enum.map(tool_calls, fn %SwarmAi.ToolCall{id: id, name: name, arguments: arguments} ->
      %{"id" => id, "name" => name, "arguments" => arguments}
    end)
  end

  defp stored_tool_calls(_tool_calls), do: nil

  defp non_empty(list) when is_list(list) and list != [], do: list
  defp non_empty(_list), do: nil

  defp format_crash_reason(reason) do
    "Execution crashed: #{format_error_reason(reason)}"
  end

  defp format_error_reason(reason) when is_exception(reason), do: Exception.message(reason)
  defp format_error_reason(reason) when is_binary(reason), do: reason
  defp format_error_reason(reason), do: inspect(reason)
end
