defmodule Swarm.Loop.Runner do
  @moduledoc """
  Pure functional loop runner. No side effects.

  Takes loop state in, returns updated loop + effects to execute.
  The ExecutionProcess interprets effects.

  ## Flow

      start/3
        → {:call_llm, messages}

      handle_llm_response/2
        → if no tool calls: {:complete, result}
        → if tool calls: [{:execute_tool, call}, ...]

      handle_tool_result/3
        → if spawn: {:spawn_child, id, spawn_req}
        → if all complete: {:call_llm, messages}
        → if pending: [] (wait for more)
  """

  alias Swarm.{Agent, Effect, Events, LLM, Loop, Message}

  @doc """
  Starts the execution loop with user messages.

  Prepends the system prompt, starts the loop, and returns effects to emit
  the Started event and call the LLM.

  ## Example

      {loop, effects} = Runner.start(loop, [Message.user("Hello")])
      loop.status # => :running
      effects     # => [{:emit_event, %Started{}}, {:call_llm, llm, messages}]
  """
  @spec start(Loop.t(), [Message.t()]) :: {Loop.t(), [Effect.t()]}
  def start(%Loop{status: :ready, agent: agent} = loop, user_messages)
      when is_list(user_messages) do
    system_prompt = Agent.system_prompt(agent)
    llm = Agent.llm(agent)

    messages = [Message.system(system_prompt) | user_messages]

    loop = Loop.start(loop, messages)

    effects = [
      {:emit_event, %Events.Started{execution_id: loop.id}},
      {:call_llm, llm, messages}
    ]

    {loop, effects}
  end

  @doc """
  Handles successful LLM response.

  If the response contains tool calls, emits `{:execute_tool, tool_call}` effects.
  Otherwise completes the loop.

  ## Example

      response = %LLM.Response{content: "Hello!", usage: %{...}}
      {loop, effects} = Runner.handle_llm_response(loop, response)
      loop.status  # => :completed
      loop.result  # => "Hello!"
  """
  @spec handle_llm_response(Loop.t(), LLM.Response.t()) :: {Loop.t(), [Effect.t()]}
  def handle_llm_response(%Loop{status: :running} = loop, %LLM.Response{} = response) do
    if LLM.Response.has_tool_calls?(response) do
      handle_tool_calls(loop, response)
    else
      handle_completion(loop, response)
    end
  end

  defp handle_completion(loop, response) do
    loop = Loop.complete(loop, response)

    effects = [
      {:emit_event,
       %Events.Completed{
         execution_id: loop.id,
         result: response.content
       }},
      {:complete, response.content}
    ]

    {loop, effects}
  end

  defp handle_tool_calls(loop, response) do
    loop = Loop.wait_for_tools(loop, response)
    tool_effects = Enum.map(response.tool_calls, &{:execute_tool, &1})

    {loop, tool_effects}
  end

  @doc """
  Continues execution after all tool results have been added to the loop.

  Returns effects to call LLM with the accumulated tool results.
  If not all tools are complete, returns empty effects.
  """
  @spec continue(Loop.t()) :: {Loop.t(), [Effect.t()]}
  def continue(%Loop{status: :waiting_for_tools} = loop) do
    step = Loop.current_step(loop)

    if Loop.Step.all_tools_complete?(step) do
      continue_after_tools(loop, step)
    else
      {loop, []}
    end
  end

  @doc """
  Handles a tool result. Adds it to the current step.
  If all tools complete, starts a new LLM call with tool results.
  """
  @spec handle_tool_result(Loop.t(), Swarm.ToolResult.t()) :: {Loop.t(), [Effect.t()]}
  def handle_tool_result(
        %Loop{status: :waiting_for_tools, steps: [_ | _]} = loop,
        %Swarm.ToolResult{} = result
      ) do
    case Loop.add_tool_result(loop, result) do
      {:ok, updated_loop} ->
        %Loop.Step{tool_calls: [_ | _]} = step = Loop.current_step(updated_loop)

        if Loop.Step.all_tools_complete?(step) do
          continue_after_tools(updated_loop, step)
        else
          {updated_loop, []}
        end

      {:error, reason} ->
        {loop, [{:fail, {:tool_result_error, reason}}]}
    end
  end

  defp continue_after_tools(
         %Loop{agent: agent, steps: steps} = loop,
         %Loop.Step{
           input_messages: input_msgs,
           tool_calls: tool_calls,
           content: content,
           response_metadata: response_metadata
         }
       ) do
    llm = Agent.llm(agent)
    completed_step = loop.current_step

    assistant_msg = Message.assistant(content, tool_calls, response_metadata)
    tool_msgs = Enum.map(tool_calls, &format_tool_result/1)
    messages = input_msgs ++ [assistant_msg | tool_msgs]

    new_step = Loop.Step.new(length(steps) + 1, messages)
    loop = %{loop | status: :running, steps: steps ++ [new_step], current_step: new_step.number}

    # Emit step_ended before starting the new LLM call
    {loop, [{:step_ended, completed_step}, {:call_llm, llm, messages}]}
  end

  defp format_tool_result(%Swarm.ToolCall{
         id: id,
         name: name,
         result: %Swarm.ToolResult{content: content}
       }) do
    Message.tool_result(name, id, content)
  end

  @doc """
  Handles LLM errors.

  Marks loop as failed and returns effects to emit the Failed event
  and fail the execution.

  ## Example

      {loop, effects} = Runner.handle_llm_error(loop, :timeout)
      loop.status # => :failed
      loop.error  # => :timeout
  """
  @spec handle_llm_error(Loop.t(), term()) :: {Loop.t(), [Effect.t()]}
  def handle_llm_error(%Loop{} = loop, error) do
    loop = Loop.fail(loop, error)

    effects = [
      {:emit_event, %Events.Failed{execution_id: loop.id, error: error}},
      {:fail, error}
    ]

    {loop, effects}
  end
end
