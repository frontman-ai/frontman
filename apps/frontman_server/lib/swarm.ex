defmodule Swarm do
  @moduledoc """
  Swarm is a pure functional agent execution framework.

  ## Usage

  The primary entry points are `run/2` and `continue/2`:

      case Swarm.run(agent, "Hello") do
        {:completed, loop} ->
          loop.result

        {:tool_calls, loop, tool_calls} ->
          results = execute_tools(tool_calls)
          Swarm.continue(loop, results)
      end

  The caller controls tool execution - sync, async, concurrent, or any strategy.

  ## Low-Level API

  For full control over the execution loop, use the Loop module directly:

      loop = Swarm.Loop.make(agent, config)
      {loop, effects} = Swarm.Loop.execute(loop, messages)
      # Interpret effects manually...
  """

  alias Swarm.{Loop, Message, ToolResult}
  alias Swarm.LLM.Response

  @typedoc """
  Message input can be a string, a single Message, or a list of Messages.
  Strings are automatically wrapped as user messages.
  """
  @type message_input :: String.t() | Message.t() | [Message.t()]

  @typedoc """
  Result of run/2 and continue/2.

  - `{:completed, loop}` - Agent finished, result in `loop.result`
  - `{:tool_calls, loop, tool_calls}` - Agent needs tools executed
  - `{:error, loop}` - Agent failed, error in `loop.error`
  """
  @type run_result ::
          {:completed, Loop.t()}
          | {:tool_calls, Loop.t(), [Swarm.ToolCall.t()]}
          | {:error, Loop.t()}

  @doc """
  Start agent execution with messages.

  Returns immediately when the agent needs tools executed, giving the caller
  full control over how to execute them.

  ## Arguments

  - `agent` - An agent implementing the `Swarm.Agent` protocol
  - `message` - The user message(s) to start the conversation

  ## Returns

  - `{:completed, loop}` - Agent completed, result in `loop.result`
  - `{:tool_calls, loop, tool_calls}` - Agent needs tools, execute and call `continue/2`
  - `{:error, loop}` - Agent failed, error in `loop.error`

  ## Examples

      case Swarm.run(agent, "What's the weather?") do
        {:completed, loop} ->
          IO.puts(loop.result)

        {:tool_calls, loop, tool_calls} ->
          results = Enum.map(tool_calls, &execute_tool/1)
          Swarm.continue(loop, results)
      end
  """
  @spec run(Swarm.Agent.t(), message_input()) :: run_result()
  def run(agent, message) do
    config = %Loop.Config{}
    messages = normalize_messages(message)
    loop = Loop.make(agent, config)

    {loop, effects} = Loop.execute(loop, messages)
    process_until_yield(loop, effects)
  end

  @doc """
  Continue agent execution with tool results.

  Call this after executing the tool calls returned by `run/2` or a previous
  `continue/2`. The loop tracks which tools are pending.

  ## Arguments

  - `loop` - The loop returned by `run/2` or `continue/2`
  - `tool_results` - List of `Swarm.ToolResult` structs with results

  ## Returns

  Same as `run/2`:
  - `{:completed, loop}` - Agent completed
  - `{:tool_calls, loop, tool_calls}` - Agent needs more tools
  - `{:error, loop}` - Agent failed

  ## Examples

      # Execute tools concurrently
      results =
        tool_calls
        |> Task.async_stream(&execute_tool/1)
        |> Enum.map(fn {:ok, r} -> r end)

      case Swarm.continue(loop, results) do
        {:completed, loop} -> {:ok, loop.result}
        {:tool_calls, loop, more_tools} -> continue_execution(loop, more_tools)
      end
  """
  @spec continue(Loop.t(), [ToolResult.t()]) :: run_result()
  def continue(%Loop{status: :waiting_for_tools} = loop, tool_results) when is_list(tool_results) do
    # Add all results to the loop
    loop =
      Enum.reduce(tool_results, loop, fn result, acc ->
        case Loop.add_tool_result(acc, result) do
          {:ok, updated} -> updated
          {:error, _reason} -> acc
        end
      end)

    # Continue execution
    {loop, effects} = Loop.Runner.continue(loop)
    process_until_yield(loop, effects)
  end

  @typedoc """
  A function that executes a single tool call and returns the result.
  """
  @type tool_executor :: (Swarm.ToolCall.t() -> {:ok, String.t()} | {:error, String.t()})

  @doc """
  Run an agent to completion, using the provided executor for tool calls.

  This is a convenience function that handles the run/continue loop internally.
  It blocks until the agent completes or fails.

  ## Arguments

  - `agent` - An agent implementing the `Swarm.Agent` protocol
  - `message` - The user message(s) to start the conversation
  - `tool_executor` - A function that takes a ToolCall and returns `{:ok, result}` or `{:error, reason}`

  ## Returns

  - `{:ok, result}` - Agent completed successfully
  - `{:error, reason}` - Agent failed

  ## Examples

      Swarm.run_blocking(agent, "What's the weather?", fn tool_call ->
        case tool_call.name do
          "get_weather" -> {:ok, "Sunny, 22°C"}
          _ -> {:error, "Unknown tool"}
        end
      end)
  """
  @spec run_blocking(Swarm.Agent.t(), message_input(), tool_executor()) ::
          {:ok, String.t()} | {:error, term()}
  def run_blocking(agent, message, tool_executor) when is_function(tool_executor, 1) do
    case run(agent, message) do
      {:completed, loop} ->
        {:ok, loop.result}

      {:tool_calls, loop, tool_calls} ->
        results = execute_tools_with_executor(tool_calls, tool_executor)
        continue_blocking(loop, results, tool_executor)

      {:error, loop} ->
        {:error, loop.error}
    end
  end

  defp continue_blocking(loop, results, tool_executor) do
    case continue(loop, results) do
      {:completed, loop} ->
        {:ok, loop.result}

      {:tool_calls, loop, tool_calls} ->
        results = execute_tools_with_executor(tool_calls, tool_executor)
        continue_blocking(loop, results, tool_executor)

      {:error, loop} ->
        {:error, loop.error}
    end
  end

  defp execute_tools_with_executor(tool_calls, executor) do
    Enum.map(tool_calls, fn tc ->
      case executor.(tc) do
        {:ok, content} -> %ToolResult{id: tc.id, content: content, is_error: false}
        {:error, reason} -> %ToolResult{id: tc.id, content: to_string(reason), is_error: true}
      end
    end)
  end

  # --- Private helpers ---

  defp normalize_messages(msg) when is_binary(msg), do: [Message.user(msg)]
  defp normalize_messages(%Message{} = msg), do: [msg]
  defp normalize_messages(msgs) when is_list(msgs), do: msgs

  # Process effects until we need to yield to caller (tool calls) or complete
  defp process_until_yield(loop, []) do
    case loop.status do
      :completed -> {:completed, loop}
      :failed -> {:error, loop}
      :waiting_for_tools -> {:tool_calls, loop, pending_tool_calls(loop)}
      _other -> {:error, loop}
    end
  end

  defp process_until_yield(loop, [{:call_llm, llm, messages} | rest]) do
    case Swarm.LLM.stream(llm, messages, []) do
      {:ok, stream} ->
        response = Response.from_stream(stream)
        {loop, new_effects} = Loop.handle_response(loop, response)
        process_until_yield(loop, new_effects ++ rest)

      {:error, reason} ->
        {loop, new_effects} = Loop.handle_error(loop, reason)
        process_until_yield(loop, new_effects ++ rest)
    end
  end

  defp process_until_yield(loop, [{:execute_tool, _} | _] = effects) do
    # Don't execute tools - yield to caller
    tool_calls = Enum.map(effects, fn {:execute_tool, tc} -> tc end)
    {:tool_calls, loop, tool_calls}
  end

  defp process_until_yield(loop, [{:complete, _result} | _rest]) do
    {:completed, loop}
  end

  defp process_until_yield(loop, [{:fail, _error} | _rest]) do
    {:error, loop}
  end

  defp process_until_yield(loop, [{:emit_event, _event} | rest]) do
    # Events are informational - skip
    process_until_yield(loop, rest)
  end

  defp pending_tool_calls(%Loop{} = loop) do
    case Loop.current_step(loop) do
      nil -> []
      step -> Enum.reject(step.tool_calls, &Swarm.ToolCall.completed?/1)
    end
  end
end
