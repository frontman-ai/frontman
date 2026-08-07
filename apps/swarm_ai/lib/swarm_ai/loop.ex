defmodule SwarmAi.Loop do
  alias SwarmAi.Effect
  alias SwarmAi.LLM
  alias SwarmAi.Loop.Config
  alias SwarmAi.Loop.Runner
  alias SwarmAi.Loop.Step
  alias SwarmAi.Message
  alias SwarmAi.ToolCall
  alias SwarmAi.ToolResult

  use TypedStruct

  @type status ::
          :ready
          | :running
          | :waiting_for_tools
          | :completed
          | {:failed, term()}
          | {:paused, term()}

  @type response_event_metadata :: %{ordinal: non_neg_integer(), timestamp: DateTime.t()}

  @type event ::
          {:chunk, response_event_metadata(), term()}
          | {:response, response_event_metadata(), LLM.Response.t()}
          | {:tool_call, ToolCall.t()}
          | :completed
          | {:failed, term()}
          | {:paused, term()}
          | {:cancelled, nil}
          | {:terminated, term()}
          | {:crashed, %{message: String.t()}}

  @type execute_tools ::
          ([ToolCall.t()], pid() | atom() -> {:ok, [ToolResult.t()]} | {:halt, term()})

  typedstruct do
    field(:id, String.t(), enforce: true)
    field(:task_id, String.t(), enforce: true)
    field(:turn_number, pos_integer(), enforce: true)

    field(:messages, [Message.t()], enforce: true)
    field(:llm, LLM.t(), enforce: true)

    field(:execute_tools, execute_tools(), enforce: true)
    field(:dispatch_event, (event() -> term()), enforce: true)

    field(:status, status(), enforce: true)
    field(:steps, [Step.t()], default: [])
    field(:current_step, non_neg_integer(), enforce: true)
    field(:config, Config.t(), enforce: true)
    field(:result, term())
  end

  def new(attrs) do
    %__MODULE__{
      id: generate_id("loop"),
      task_id: Map.fetch!(attrs, :task_id),
      turn_number: Map.fetch!(attrs, :turn_number),
      messages: Map.fetch!(attrs, :messages),
      llm: Map.fetch!(attrs, :llm),
      execute_tools: Map.fetch!(attrs, :execute_tools),
      dispatch_event: Map.fetch!(attrs, :dispatch_event),
      status: :ready,
      steps: [],
      current_step: 0,
      config: Map.get(attrs, :config, %Config{}),
      result: nil
    }
  end

  defp generate_id(prefix) do
    uuid = UUIDv7.generate()
    "#{prefix}_#{uuid}"
  end

  def complete(%__MODULE__{status: :running, steps: steps} = loop, response)
      when steps != [] do
    updated_steps = List.update_at(steps, -1, &Step.record_response(&1, response))

    %{loop | status: :completed, steps: updated_steps, result: response.content}
  end

  def fail(%__MODULE__{} = loop, reason) do
    %{loop | status: {:failed, reason}}
  end

  def pause(%__MODULE__{} = loop, reason) do
    %{loop | status: {:paused, reason}}
  end

  def wait_for_tools(%__MODULE__{status: :running, steps: steps} = loop, response)
      when steps != [] do
    updated_steps = List.update_at(steps, -1, &Step.record_response(&1, response))
    %{loop | status: :waiting_for_tools, steps: updated_steps}
  end

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

  def current_step(%__MODULE__{steps: []}), do: nil
  def current_step(%__MODULE__{steps: steps}), do: List.last(steps)

  def execute(%__MODULE__{status: :ready} = loop) do
    step_number = length(loop.steps) + 1
    step = Step.new(step_number, loop.messages)

    loop = %{
      loop
      | status: :running,
        steps: loop.steps ++ [step],
        current_step: step_number
    }

    {loop, [Effect.call_llm(loop.llm, loop.messages)]}
  end

  def handle_response(%__MODULE__{status: :running} = loop, response) do
    Runner.handle_llm_response(loop, response)
  end

  def handle_error(%__MODULE__{} = loop, error) do
    Runner.handle_llm_error(loop, error)
  end

  def handle_tool_result(%__MODULE__{status: :waiting_for_tools} = loop, result) do
    Runner.handle_tool_result(loop, result)
  end
end
