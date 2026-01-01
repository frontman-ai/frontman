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

  alias Swarm.{Loop, Agent, Effect, Events, LLM}

  @doc """
  Starts the execution loop with an initial message.

  Builds messages, starts the loop, and returns effects to emit the Started
  event and call the LLM.

  ## Example

      {loop, effects} = Runner.start(loop, agent, "Hello")
      loop.status # => :running
      effects     # => [{:emit_event, %Started{}}, {:call_llm, llm, messages}]
  """
  @spec start(Loop.t(), Agent.t(), String.t()) :: {Loop.t(), [Effect.t()]}
  def start(%Loop{status: :ready} = loop, agent, message) do
    system_prompt = Agent.system_prompt(agent)
    llm = Agent.llm(agent)

    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: message}
    ]

    loop = Loop.start(loop, messages)

    effects = [
      {:emit_event, %Events.Started{execution_id: loop.id, message: message}},
      {:call_llm, llm, messages}
    ]

    {loop, effects}
  end

  @doc """
  Handles successful LLM response.

  Completes the loop and returns effects to emit the Completed event
  and complete execution.

  ## Example

      response = %LLM.Response{content: "Hello!", usage: %{...}}
      {loop, effects} = Runner.handle_llm_response(loop, response)
      loop.status  # => :completed
      loop.result  # => "Hello!"
  """
  @spec handle_llm_response(Loop.t(), LLM.Response.t()) :: {Loop.t(), [Effect.t()]}
  def handle_llm_response(%Loop{status: :running} = loop, %LLM.Response{} = response) do
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
