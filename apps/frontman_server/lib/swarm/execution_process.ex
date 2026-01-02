defmodule Swarm.ExecutionProcess do
  @moduledoc """
  GenServer that interprets effects and manages execution lifecycle.

  This is the "effect interpreter" that executes the side effects returned by
  Loop. It bridges the pure functional loop logic to the real world.

  ## Responsibilities

  - Spawns async tasks for LLM calls
  - Sends events as messages to subscriber
  - Handles task crashes gracefully

  ## Flow

      1. Client calls start_async/4 → starts process, returns handle
      2. Client casts :run → triggers execution
      3. Server calls Loop.execute → gets effects
      4. Server interprets effects:
         - {:call_llm, ...} → Task.async
         - {:emit_event, ...} → send message to subscriber
         - {:complete, ...} → stop
         - {:fail, ...} → stop
      5. LLM task finishes → handle_info
      6. Server calls Loop.handle_response → gets effects
      7. Repeat step 4
  """

  use GenServer, restart: :temporary

  alias Swarm.{Loop, LLM}

  defstruct [:loop, :opts, :message, :subscriber]

  # --- Public API ---

  @doc """
  Starts an execution asynchronously.

  Spawns a supervised process, retrieves the execution_id, and triggers
  execution via cast. Returns immediately with pid and execution_id.

  Events are sent to the subscriber as `{:swarm, execution_id, event}` messages.
  """
  def start_async(agent, message, opts, subscriber) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        Swarm.ExecutionSupervisor,
        {__MODULE__, %{agent: agent, message: message, opts: opts, subscriber: subscriber}}
      )

    # Get execution_id synchronously before triggering async execution
    execution_id = GenServer.call(pid, :get_execution_id)

    # Trigger execution asynchronously
    GenServer.cast(pid, :run)

    {:ok, %{pid: pid, execution_id: execution_id}}
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # --- Server Callbacks ---

  @impl true
  def init(%{agent: agent, message: message, opts: opts, subscriber: subscriber}) do
    config = %Loop.Config{
      max_steps: opts.max_steps,
      timeout_ms: opts.timeout_ms,
      step_timeout_ms: opts.step_timeout_ms
    }

    state = %__MODULE__{
      loop: Loop.make(agent, config),
      opts: opts,
      message: message,
      subscriber: subscriber
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_execution_id, _from, state) do
    {:reply, state.loop.id, state}
  end

  @impl true
  def handle_cast(:run, state) do
    {loop, effects} = Loop.execute(state.loop, state.message)
    process_effects(effects, %{state | loop: loop})
  end

  # Handle successful LLM response
  @impl true
  def handle_info({ref, {:ok, %LLM.Response{} = response}}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {loop, effects} = Loop.handle_response(state.loop, response)
    process_effects(effects, %{state | loop: loop})
  end

  # Handle LLM error
  @impl true
  def handle_info({ref, {:error, error}}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {loop, effects} = Loop.handle_error(state.loop, error)
    process_effects(effects, %{state | loop: loop})
  end

  # Handle task crash
  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    {loop, effects} = Loop.handle_error(state.loop, {:llm_crashed, reason})
    process_effects(effects, %{state | loop: loop})
  end

  # Handle tool result
  @impl true
  def handle_info({:tool_result, %Swarm.ToolResult{} = result}, state) do
    {loop, effects} = Loop.handle_tool_result(state.loop, result)
    process_effects(effects, %{state | loop: loop})
  end

  # --- Effect Interpreter ---

  defp process_effects([], state), do: {:noreply, state}

  defp process_effects([effect | rest], state) do
    case execute_effect(effect, state) do
      {:continue, new_state} -> process_effects(rest, new_state)
      {:stop, reason, new_state} -> {:stop, reason, new_state}
    end
  end

  defp execute_effect({:call_llm, client, messages}, state) do
    Task.async(fn -> LLM.call(client, messages, []) end)
    {:continue, state}
  end

  defp execute_effect({:emit_event, event}, state) do
    send(state.subscriber, {:swarm, state.loop.id, event})
    {:continue, state}
  end

  defp execute_effect({:execute_tool, %Swarm.ToolCall{} = tool_call}, state) do
    event = %Swarm.Events.ToolCallRequested{
      execution_id: state.loop.id,
      tool_call: tool_call
    }

    send(state.subscriber, {:swarm, state.loop.id, event})
    {:continue, state}
  end

  defp execute_effect({:complete, _result}, state) do
    {:stop, :normal, state}
  end

  defp execute_effect({:fail, _error}, state) do
    {:stop, :normal, state}
  end
end
