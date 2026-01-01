defmodule Swarm.ExecutionProcess do
  @moduledoc """
  GenServer that interprets effects and manages execution lifecycle.

  This is the "effect interpreter" that executes the side effects returned by
  Loop. It bridges the pure functional loop logic to the real world.

  ## Responsibilities

  - Spawns async tasks for LLM calls
  - Emits events via callback
  - Replies to caller on completion/failure
  - Handles task crashes gracefully

  ## Flow

      1. Client calls run(agent, message, opts) → starts process and blocks
      2. Server calls Loop.execute → gets effects
      3. Server interprets effects:
         - {:call_llm, ...} → Task.async
         - {:emit_event, ...} → callback
         - {:complete, ...} → reply and stop
         - {:fail, ...} → reply and stop
      4. LLM task finishes → handle_info
      5. Server calls Loop.handle_response → gets effects
      6. Repeat step 3
  """

  use GenServer, restart: :temporary

  alias Swarm.{Loop, LLM}

  defstruct [:loop, :agent, :opts, :caller, :message]

  # --- Public API ---

  @doc """
  Executes an agent with a message and blocks until complete.

  Starts a process under the supervisor, runs the execution, and returns
  the result. The process terminates after completion.

  Returns {:ok, result} on success or {:error, reason} on failure.
  """
  def run(agent, message, opts) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        Swarm.ExecutionSupervisor,
        {__MODULE__, %{agent: agent, message: message, opts: opts}}
      )

    GenServer.call(pid, :run, :infinity)
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # --- Server Callbacks ---

  @impl true
  def init(%{agent: agent, message: message, opts: opts}) do
    config = %Loop.Config{
      max_steps: opts.max_steps,
      timeout_ms: opts.timeout_ms,
      step_timeout_ms: opts.step_timeout_ms
    }

    state = %__MODULE__{
      loop: Loop.make(agent, config),
      agent: agent,
      opts: opts,
      message: message
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:run, from, state) do
    {loop, effects} = Loop.execute(state.loop, state.agent, state.message)
    state = %{state | loop: loop, caller: from}
    process_effects(effects, state)
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
    state.opts.on_event.(event)
    {:continue, state}
  end

  defp execute_effect({:complete, result}, state) do
    GenServer.reply(state.caller, {:ok, result})
    {:stop, :normal, state}
  end

  defp execute_effect({:fail, error}, state) do
    GenServer.reply(state.caller, {:error, error})
    {:stop, :normal, state}
  end
end
