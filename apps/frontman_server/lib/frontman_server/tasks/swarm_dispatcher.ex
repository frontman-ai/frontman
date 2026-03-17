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

  def dispatch(key, event, metadata) do
    scope = Map.get(metadata, :scope)
    task_id = to_string(key)

    # 1. Persist (runs in the Runtime Task process — channel-independent)
    persist(scope, task_id, event, metadata)

    # 2. Broadcast for real-time UI (ephemeral, OK to lose if channel is dead)
    topic = Tasks.topic(task_id)
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, topic, {:swarm_event, event})
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
    Logger.error(
      "Execution failed for task #{task_id}, loop_id: #{loop_id}, reason: #{inspect(reason)}"
    )

    Sentry.capture_message("Agent execution failed",
      level: :error,
      tags: %{error_type: "agent_execution_error"},
      extra: %{task_id: task_id, loop_id: loop_id, reason: inspect(reason)}
    )

    Tasks.add_agent_error(scope, task_id, inspect(reason), "failed")
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

    Tasks.add_agent_error(scope, task_id, format_crash_reason(reason), "crashed")
    TelemetryEvents.task_stop(task_id)
  end

  # Agent was cancelled (user requested cancel).
  defp persist(%Scope{} = scope, task_id, {:cancelled, _}, _metadata) do
    Tasks.add_agent_error(scope, task_id, "Cancelled", "cancelled")
    TelemetryEvents.task_stop(task_id)
  end

  # Streaming chunks — ephemeral, no persistence needed.
  defp persist(_scope, _task_id, {:chunk, _}, _metadata), do: :ok

  # Tool call announced — already persisted by ToolExecutor directly.
  defp persist(_scope, _task_id, {:tool_call, _}, _metadata), do: :ok

  # Fallback for any future event types — log and skip.
  defp persist(_scope, _task_id, event, _metadata) do
    Logger.debug("SwarmDispatcher: unhandled event type #{inspect(event)}")
  end

  # --- Helpers ---

  defp build_response_metadata(response) do
    tool_calls = Map.get(response, :tool_calls)
    reasoning_details = Map.get(response, :reasoning_details)

    metadata = %{}

    metadata =
      if tool_calls && tool_calls != [] do
        Map.put(metadata, :tool_calls, Enum.map(tool_calls, &to_reqllm_tool_call/1))
      else
        metadata
      end

    if reasoning_details && reasoning_details != [] do
      Map.put(metadata, :reasoning_details, reasoning_details)
    else
      metadata
    end
  end

  defp to_reqllm_tool_call(%SwarmAi.ToolCall{} = tc) do
    ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
  end

  defp format_crash_reason(exception) when is_exception(exception) do
    Exception.message(exception)
  end

  defp format_crash_reason(reason) do
    "Execution crashed: #{inspect(reason)}"
  end
end
