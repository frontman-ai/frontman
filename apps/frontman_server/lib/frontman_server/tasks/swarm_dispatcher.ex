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
    response_metadata = build_response_metadata(response)
    Tasks.add_agent_response(scope, task_id, response.content || "", response_metadata)
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

    Logger.error(
      "Execution failed for task #{task_id}, loop_id: #{loop_id}, reason: #{reason_str}"
    )

    Sentry.capture_message("Agent execution failed",
      level: :error,
      tags: %{error_type: "agent_execution_error"},
      extra: %{task_id: task_id, loop_id: loop_id, reason: reason_str}
    )

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
    Logger.error("Execution crashed for task #{task_id}, reason: #{inspect(reason)}")

    if is_exception(reason) do
      Sentry.capture_exception(reason,
        stacktrace: stacktrace,
        tags: %{error_type: "agent_crash"},
        extra: %{task_id: task_id}
      )
    else
      Sentry.capture_message("Agent execution crashed",
        level: :error,
        tags: %{error_type: "agent_crash"},
        extra: %{task_id: task_id, reason: inspect(reason)}
      )
    end

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

  defp build_response_metadata(response) do
    tool_calls = Map.get(response, :tool_calls)
    reasoning_details = Map.get(response, :reasoning_details)
    response_meta = Map.get(response, :metadata) || %{}

    %{}
    |> maybe_put_tool_calls(tool_calls)
    |> maybe_put_reasoning_details(reasoning_details)
    |> maybe_put_string_metadata(:response_id, get_response_meta(response_meta, :response_id))
    |> maybe_put_string_metadata(:phase, get_response_meta(response_meta, :phase))
    |> maybe_put_phase_items(get_response_meta(response_meta, :phase_items))
  end

  defp maybe_put_tool_calls(metadata, tool_calls) when is_list(tool_calls) and tool_calls != [] do
    Map.put(metadata, :tool_calls, Enum.map(tool_calls, &to_reqllm_tool_call/1))
  end

  defp maybe_put_tool_calls(metadata, _tool_calls), do: metadata

  defp maybe_put_reasoning_details(metadata, details) when is_list(details) and details != [] do
    Map.put(metadata, :reasoning_details, details)
  end

  defp maybe_put_reasoning_details(metadata, _details), do: metadata

  defp maybe_put_string_metadata(metadata, key, value) when is_binary(value) do
    Map.put(metadata, key, value)
  end

  defp maybe_put_string_metadata(metadata, _key, _value), do: metadata

  defp maybe_put_phase_items(metadata, phase_items)
       when is_list(phase_items) and phase_items != [] do
    Map.put(metadata, :phase_items, phase_items)
  end

  defp maybe_put_phase_items(metadata, _phase_items), do: metadata

  defp get_response_meta(metadata, key) when is_map(metadata) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp get_response_meta(_metadata, _key), do: nil

  defp to_reqllm_tool_call(%SwarmAi.ToolCall{} = tc) do
    ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
  end

  defp format_crash_reason(reason) do
    "Execution crashed: #{format_error_reason(reason)}"
  end

  defp format_error_reason(reason) when is_exception(reason), do: Exception.message(reason)
  defp format_error_reason(reason) when is_binary(reason), do: reason
  defp format_error_reason(reason), do: inspect(reason)
end
