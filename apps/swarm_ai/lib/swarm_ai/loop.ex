defmodule SwarmAi.Loop do
  @moduledoc """
  Represents an agentic execution loop as an explicit, inspectable data structure.

  The loop continues until a termination condition is met:
  - No more tool calls (default)
  - Max steps reached
  - Custom condition from the agent
  - Explicit stop signal from a tool
  """

  alias SwarmAi.Loop.Config
  alias SwarmAi.Loop.Runner
  alias SwarmAi.Loop.Step
  use TypedStruct

  @type status ::
          :ready | :running | :waiting_for_tools | :completed | :failed | :paused | :max_steps
  typedstruct do
    field(:id, SwarmAi.Id.t(), enforce: true)
    field(:agent, SwarmAi.Agent.t(), enforce: true)
    field(:status, status(), enforce: true)
    field(:steps, [Step.t()], default: [])
    field(:current_step, non_neg_integer(), enforce: true)
    field(:config, Config.t(), enforce: true)
    field(:result, term())
    field(:error, term())
    field(:parent_id, SwarmAi.Id.t())
    field(:parent_step, pos_integer())
    field(:metadata, map(), default: %{})
  end

  @spec make(SwarmAi.Agent.t(), Config.t(), keyword()) :: t()
  def make(agent, %Config{} = config, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    %__MODULE__{
      id: SwarmAi.Id.generate("loop"),
      agent: agent,
      status: :ready,
      steps: [],
      current_step: 0,
      config: config,
      result: nil,
      error: nil,
      parent_id: nil,
      parent_step: nil,
      metadata: metadata
    }
  end

  @doc """
  Creates a child loop linked to a parent.

  The child inherits metadata from the parent loop by default.
  Additional metadata can be passed via opts to merge or override.
  """
  @spec make_child(SwarmAi.Agent.t(), Config.t(), t(), keyword()) :: t()
  def make_child(agent, %Config{} = config, parent_loop, opts \\ []) do
    child_metadata = Keyword.get(opts, :metadata, %{})
    # Merge parent metadata with child metadata (child overrides)
    metadata = Map.merge(parent_loop.metadata, child_metadata)

    %__MODULE__{
      id: SwarmAi.Id.generate("loop"),
      agent: agent,
      status: :ready,
      steps: [],
      current_step: 0,
      config: config,
      result: nil,
      error: nil,
      parent_id: parent_loop.id,
      parent_step: parent_loop.current_step,
      metadata: metadata
    }
  end

  @doc """
  Starts the loop with the given messages.
  Creates a step internally, updates status to :running.
  Only works when loop is in :ready status.
  """
  @spec start(__MODULE__.t(), [SwarmAi.Message.t()]) :: __MODULE__.t()
  def start(%__MODULE__{status: :ready} = loop, messages) do
    step_number = length(loop.steps) + 1
    step = Step.new(step_number, messages)

    %{loop | status: :running, steps: loop.steps ++ [step], current_step: step_number}
  end

  @doc """
  Completes the loop with LLM response data.
  Updates the current step and sets status to :completed.
  Only works when loop is in :running status.
  """
  @spec complete(__MODULE__.t(), SwarmAi.LLM.Response.t()) :: __MODULE__.t()
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
  Marks the loop as failed with the given error.
  """
  @spec fail(__MODULE__.t(), term()) :: __MODULE__.t()
  def fail(%__MODULE__{} = loop, error) do
    %{loop | status: :failed, error: error}
  end

  @doc """
  Transitions to :waiting_for_tools with tool calls from the response.
  """
  @spec wait_for_tools(__MODULE__.t(), SwarmAi.LLM.Response.t()) :: __MODULE__.t()
  def wait_for_tools(%__MODULE__{status: :running, steps: steps} = loop, response)
      when steps != [] do
    updated_steps = List.update_at(steps, -1, &Step.record_response(&1, response))
    %{loop | status: :waiting_for_tools, steps: updated_steps}
  end

  @doc """
  Adds a tool result to the current step.
  """
  @spec add_tool_result(__MODULE__.t(), SwarmAi.ToolResult.t()) ::
          {:ok, __MODULE__.t()} | {:error, term()}
  def add_tool_result(%__MODULE__{status: :waiting_for_tools, steps: steps} = loop, result)
      when steps != [] do
    current_step = List.last(steps)

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
  Returns the current step.
  """
  @spec current_step(__MODULE__.t()) :: Step.t() | nil
  def current_step(%__MODULE__{steps: []}), do: nil
  def current_step(%__MODULE__{steps: steps}), do: List.last(steps)

  # --- Public API for Execution ---

  @doc """
  Starts execution with messages and returns effects to execute.

  This is the public API for starting a loop. Returns updated loop and effects.
  """
  @spec execute(__MODULE__.t(), [SwarmAi.Message.t()]) :: {__MODULE__.t(), [SwarmAi.Effect.t()]}
  def execute(%__MODULE__{status: :ready} = loop, messages) when is_list(messages) do
    Runner.start(loop, messages)
  end

  @doc """
  Handles successful LLM response and returns effects.

  This is the public API for processing LLM responses.
  """
  @spec handle_response(__MODULE__.t(), SwarmAi.LLM.Response.t()) ::
          {__MODULE__.t(), [SwarmAi.Effect.t()]}
  def handle_response(%__MODULE__{status: :running} = loop, response) do
    Runner.handle_llm_response(loop, response)
  end

  @doc """
  Handles LLM error and returns effects.

  This is the public API for processing errors.
  """
  @spec handle_error(__MODULE__.t(), term()) :: {__MODULE__.t(), [SwarmAi.Effect.t()]}
  def handle_error(%__MODULE__{} = loop, error) do
    Runner.handle_llm_error(loop, error)
  end

  @doc """
  Handles a tool result and returns effects.

  This is the public API for processing tool results.
  """
  @spec handle_tool_result(__MODULE__.t(), SwarmAi.ToolResult.t()) ::
          {__MODULE__.t(), [SwarmAi.Effect.t()]}
  def handle_tool_result(%__MODULE__{status: :waiting_for_tools} = loop, result) do
    Runner.handle_tool_result(loop, result)
  end
end
