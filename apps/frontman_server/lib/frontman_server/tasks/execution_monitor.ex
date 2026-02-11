defmodule FrontmanServer.Tasks.ExecutionMonitor do
  @moduledoc """
  Monitors task executions and broadcasts errors on unexpected crashes.

  Ensures users are notified when a task execution (agent) crashes unexpectedly,
  rather than being left waiting indefinitely. Follows OTP "let it crash" philosophy -
  we don't prevent crashes, we just make sure they're reported.

  ## Domain Model

  - A **Task** is a conversation/session (persisted, has `task_id`)
  - An **Execution** is a single agent run for a task (ephemeral, has `loop_id`)
  - Each task can have many executions over its lifetime

  ## Design

  - Uses synchronous registration to avoid race conditions
  - Recovers state on restart by scanning AgentRegistry
  - Caller provides the broadcast topic (no dependency on Tasks module)

  ## Usage

  Called from agent tasks before execution begins:

      ExecutionMonitor.watch(task_id, topic: Tasks.topic(task_id))
  """
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Watch a task execution process for crashes. Blocks until monitor is established.

  Must be called from the execution process itself (uses `self()`).

  ## Parameters

  - `task_id` - The task this execution belongs to (for logging/telemetry)

  ## Options

  - `:topic` - Required. The PubSub topic to broadcast errors to.
  """
  @spec watch(String.t(), keyword()) :: :ok
  def watch(task_id, opts) do
    topic = Keyword.fetch!(opts, :topic)
    GenServer.call(__MODULE__, {:watch, self(), task_id, topic})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    # On startup (including after crash/restart), rebuild state from Registry.
    # Note: We can't recover topics on restart since they were provided at watch time.
    # Executions that were running during monitor restart will be orphaned.
    # This is acceptable - the window is tiny and we'll catch future crashes.
    state = rebuild_monitors_from_registry()

    if map_size(state.monitors) > 0 do
      Logger.info(
        "ExecutionMonitor started, recovered #{map_size(state.monitors)} existing executions"
      )
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:watch, pid, task_id, topic}, _from, state) do
    ref = Process.monitor(pid)
    {:reply, :ok, put_in(state, [:monitors, ref], {task_id, topic})}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    {execution_info, monitors} = Map.pop(state.monitors, ref)

    case execution_info do
      {task_id, topic} when not is_nil(task_id) ->
        cond do
          cancelled?(reason) ->
            Logger.info("Task execution cancelled", task_id: task_id, pid: inspect(pid))
            broadcast_cancelled(topic)

          abnormal_exit?(reason) ->
            Logger.warning("Task execution crashed",
              task_id: task_id,
              pid: inspect(pid),
              reason: inspect(reason)
            )

            broadcast_error(topic, reason)
            emit_telemetry(task_id, pid, reason)

          true ->
            :ok
        end

      _ ->
        :ok
    end

    {:noreply, %{state | monitors: monitors}}
  end

  # --- Private Functions ---

  defp rebuild_monitors_from_registry do
    # AgentRegistry stores {:running_agent, task_id} => pid
    # On restart, we re-monitor existing executions but without topics.
    # We store {task_id, nil} - these will log but not broadcast on crash.
    monitors =
      FrontmanServer.AgentRegistry
      |> Registry.select([
        {{{:running_agent, :"$1"}, :"$2", :_}, [], [{{:"$1", :"$2"}}]}
      ])
      |> Enum.reduce(%{}, fn {task_id, pid}, acc ->
        if Process.alive?(pid) do
          ref = Process.monitor(pid)
          # No topic available on recovery - will log but not broadcast
          Map.put(acc, ref, {task_id, nil})
        else
          acc
        end
      end)

    %{monitors: monitors}
  end

  defp cancelled?(:cancelled), do: true
  defp cancelled?(_), do: false

  defp abnormal_exit?(:normal), do: false
  defp abnormal_exit?(:shutdown), do: false
  defp abnormal_exit?({:shutdown, _}), do: false
  defp abnormal_exit?(:cancelled), do: false
  defp abnormal_exit?(_), do: true

  defp broadcast_cancelled(nil), do: :ok

  defp broadcast_cancelled(topic) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, topic, :agent_cancelled)
  end

  defp broadcast_error(nil, _reason), do: :ok

  defp broadcast_error(topic, reason) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      topic,
      {:agent_error, format_reason(reason)}
    )
  end

  defp format_reason({exception, _stacktrace}) when is_exception(exception) do
    Exception.message(exception)
  end

  defp format_reason(reason) do
    "Execution crashed: #{inspect(reason)}"
  end

  defp emit_telemetry(task_id, pid, reason) do
    :telemetry.execute(
      [:frontman, :task, :execution, :crash],
      %{count: 1},
      %{task_id: task_id, pid: pid, reason: reason}
    )
  end
end
