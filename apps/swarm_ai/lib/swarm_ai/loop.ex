defmodule SwarmAi.Loop do
  @moduledoc """
  Represents an agent loop as an explicit, inspectable data structure.

  The loop continues until a termination condition is met:
  - No more tool calls (LLM responds without requesting tools)
  - Max steps reached
  - LLM returns an error
  """

  alias SwarmAi.Agent
  alias SwarmAi.Loop.Config
  alias SwarmAi.Loop.Runner
  alias SwarmAi.Loop.Step
  alias SwarmAi.Message
  use TypedStruct

  @type fail_reason ::
          :max_steps
          | :output_truncated
          | :genserver_call_timeout
          | :stream_timeout
          | {:exit, term()}
          | {:tool_result_error, term()}
          | {:exception, Exception.t()}
          | {:llm_error, term()}

  @type pause_reason :: term()

  @type status ::
          :ready
          | :running
          | :waiting_for_tools
          | :completed
          | {:failed, fail_reason()}
          | {:paused, pause_reason()}

  typedstruct do
    field(:id, SwarmAi.Id.t(), enforce: true)
    field(:agent, SwarmAi.Agent.t(), enforce: true)
    field(:runtime, atom(), enforce: true)
    field(:dispatch_event, (term() -> term()), enforce: true)
    field(:status, status(), enforce: true)
    field(:steps, [Step.t()], default: [])
    field(:config, Config.t(), enforce: true)
    field(:result, term())
  end

  @doc """
  Creates a new loop for the given agent and configuration.
  """
  def make(%{
        agent: agent,
        runtime: runtime,
        dispatch_event: dispatch_event,
        config: %Config{} = config
      }) do
    %__MODULE__{
      id: SwarmAi.Id.generate("loop"),
      agent: agent,
      runtime: runtime,
      dispatch_event: dispatch_event,
      status: :ready,
      steps: [],
      config: config,
      result: nil
    }
  end

  @doc """
  Starts the loop with the given messages.
  Creates a step internally, updates status to :running.
  Only works when loop is in :ready status.
  """
  def start(%__MODULE__{status: :ready} = loop, messages) do
    step_number = length(loop.steps) + 1
    step = Step.new(step_number, messages)

    %{loop | status: :running, steps: loop.steps ++ [step]}
  end

  @doc """
  Completes the loop with LLM response data.
  Updates the current step and sets status to :completed.
  Only works when loop is in :running status.
  """
  def complete(%__MODULE__{status: :running, steps: steps} = loop, response) when steps != [] do
    now = DateTime.utc_now()

    # Update the last step with response data
    updated_steps =
      List.update_at(steps, -1, fn step ->
        %{
          step
          | content: response.content,
            reasoning_details: response.reasoning_details,
            usage: response.usage,
            completed_at: now,
            duration_ms: DateTime.diff(now, step.started_at, :millisecond)
        }
      end)

    %{loop | status: :completed, steps: updated_steps, result: response.content}
  end

  @doc """
  Marks the loop as failed with the given reason.
  """
  def fail(%__MODULE__{} = loop, reason) do
    %{loop | status: {:failed, reason}}
  end

  @doc """
  Pauses the loop with the given reason.
  """
  def pause(%__MODULE__{} = loop, reason) do
    %{loop | status: {:paused, reason}}
  end

  @doc """
  Transitions to :waiting_for_tools with tool calls from the response.
  """
  def wait_for_tools(%__MODULE__{status: :running, steps: steps} = loop, response)
      when steps != [] do
    updated_steps = List.update_at(steps, -1, &Step.record_response(&1, response))
    %{loop | status: :waiting_for_tools, steps: updated_steps}
  end

  @doc """
  Adds a tool result to the current step.
  """
  def add_tool_result(%__MODULE__{status: :waiting_for_tools, steps: steps} = loop, result)
      when steps != [] do
    current_step = current_step(loop)

    case Step.add_tool_result(current_step, result) do
      {:ok, updated_step} ->
        updated_steps = List.replace_at(steps, -1, updated_step)
        {:ok, %{loop | steps: updated_steps}}

      {:error, _} = error ->
        error
    end
  end

  def add_tool_result(%__MODULE__{status: status}, _result) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Returns the most recent `Step.t()` struct from the loop, or `nil` if no steps exist.
  """
  def current_step(%__MODULE__{steps: steps}), do: List.last(steps)

  # --- Public API for Execution ---

  @doc """
  Starts execution with messages and returns effects to execute.

  This is the public API for starting a loop. Returns updated loop and effects.
  """
  def execute(%__MODULE__{status: :ready, agent: agent} = loop) do
    system_prompt = Agent.system_prompt(agent)
    llm = Agent.llm_client(agent)

    messages = [Message.system(system_prompt) | Agent.messages(agent)]
    loop = start(loop, messages)
    effects = [{:call_llm, llm, messages}]

    {loop, effects}
  end

  @doc """
  Handles successful LLM response and returns effects.

  This is the public API for processing LLM responses.
  """
  def handle_response(%__MODULE__{status: :running} = loop, response) do
    Runner.handle_llm_response(loop, response)
  end

  @doc """
  Handles LLM error and returns effects.

  This is the public API for processing errors.
  """
  def handle_error(%__MODULE__{} = loop, error) do
    Runner.handle_llm_error(loop, error)
  end

  @doc """
  Handles a tool result and returns effects.

  This is the public API for processing tool results.
  """
  def handle_tool_result(%__MODULE__{status: :waiting_for_tools} = loop, result) do
    Runner.handle_tool_result(loop, result)
  end
end
