defmodule Swarm do
  @moduledoc """
  Swarm is an agent execution framework with a synchronous, callback-based API.

  ## Usage

  The primary entry point is `run/4`, which executes an agent synchronously:

      result = Swarm.run(agent, "Hello", %{
        tool_handler: fn tool_call ->
          case tool_call.name do
            "get_weather" -> {:ok, "Sunny, 22°C"}
            _ -> {:error, "Unknown tool"}
          end
        end
      })

  ## Streaming

  To stream tokens during LLM calls, provide an `on_llm_call` callback:

      Swarm.run(agent, "Hello", %{
        tool_handler: &execute_tool/1,
        on_llm_call: fn llm, messages ->
          stream_with_tokens(llm, messages, fn token ->
            IO.write(token)
          end)
        end
      })

  ## Low-Level API

  For full control over the execution loop, use the Loop module directly:

      loop = Swarm.Loop.make(agent, config)
      {loop, effects} = Swarm.Loop.execute(loop, message)
      # Interpret effects manually...
  """

  alias Swarm.{Loop, Message, ToolResult}

  @typedoc """
  Message input can be a string, a single Message, or a list of Messages.
  Strings are automatically wrapped as user messages.
  """
  @type message_input :: String.t() | Message.t() | [Message.t()]

  @typedoc """
  Callbacks for synchronous execution.

  - `tool_handler` - Required. Called for each tool call, returns result.
  - `on_llm_call` - Optional. Called before each LLM call for custom execution (e.g., streaming).
                    Return `{:ok, response}` to use custom result, or `:default` to use standard call.
  """
  @type callbacks :: %{
          required(:tool_handler) =>
            (Swarm.ToolCall.t() -> {:ok, String.t()} | {:error, String.t()}),
          optional(:on_llm_call) =>
            (Swarm.LLM.t(), [map()] -> {:ok, Swarm.LLM.Response.t()} | :default | {:error, term()})
        }

  @doc """
  Run an agent synchronously, blocking until completion.

  ## Arguments

  - `agent` - An agent implementing the `Swarm.Agent` protocol
  - `message` - The user message to start the conversation
  - `callbacks` - Map with `:tool_handler` (required) and optional `:on_llm_call`
  - `opts` - Options:
    - `:max_steps` - Maximum LLM iterations (default: 10)

  ## Returns

  - `{:ok, result}` - Agent completed successfully
  - `{:error, reason}` - Agent failed

  ## Examples

      # Simple execution
      Swarm.run(agent, "What's 2+2?", %{
        tool_handler: fn tc ->
          case tc.name do
            "calculate" -> {:ok, "4"}
            _ -> {:error, "Unknown tool"}
          end
        end
      })

      # With streaming
      Swarm.run(agent, "Tell me a story", %{
        tool_handler: fn _ -> {:ok, ""} end,
        on_llm_call: fn llm, messages ->
          # Custom LLM call with streaming
          stream_response(llm, messages, &IO.write/1)
        end
      })
  """
  @spec run(Swarm.Agent.t(), message_input(), callbacks(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def run(agent, message, callbacks, opts \\ []) do
    max_steps = Keyword.get(opts, :max_steps, 10)
    config = %Loop.Config{max_steps: max_steps}
    messages = normalize_messages(message)

    loop = Loop.make(agent, config)
    {loop, effects} = Loop.execute(loop, messages)
    process_effects(loop, effects, callbacks, 0, max_steps)
  end

  defp normalize_messages(msg) when is_binary(msg), do: [Message.user(msg)]
  defp normalize_messages(%Message{} = msg), do: [msg]
  defp normalize_messages(msgs) when is_list(msgs), do: msgs

  # Process effects returned by Loop operations
  defp process_effects(loop, [], _callbacks, _step, _max_steps) do
    case loop.status do
      :completed -> {:ok, loop.result}
      :failed -> {:error, loop.error}
      :waiting_for_tools -> {:error, :stuck_waiting_for_tools}
      other -> {:error, {:unexpected_status, other}}
    end
  end

  defp process_effects(_loop, _effects, _callbacks, step, max_steps) when step >= max_steps do
    {:error, {:max_steps_exceeded, max_steps}}
  end

  defp process_effects(loop, [{:call_llm, llm, messages} | rest], callbacks, step, max_steps) do
    result =
      case Map.get(callbacks, :on_llm_call) do
        nil ->
          Swarm.LLM.call(llm, messages, [])

        handler ->
          case handler.(llm, messages) do
            :default -> Swarm.LLM.call(llm, messages, [])
            {:ok, _} = ok -> ok
            {:error, _} = err -> err
          end
      end

    case result do
      {:ok, response} ->
        {loop, new_effects} = Loop.handle_response(loop, response)
        process_effects(loop, new_effects ++ rest, callbacks, step + 1, max_steps)

      {:error, reason} ->
        {loop, new_effects} = Loop.handle_error(loop, reason)
        process_effects(loop, new_effects ++ rest, callbacks, step, max_steps)
    end
  end

  defp process_effects(loop, [{:execute_tool, tool_call} | rest], callbacks, step, max_steps) do
    {content, is_error} =
      case callbacks.tool_handler.(tool_call) do
        {:ok, result} -> {result, false}
        {:error, reason} -> {to_string(reason), true}
      end

    result = %ToolResult{id: tool_call.id, content: content, is_error: is_error}
    {loop, new_effects} = Loop.handle_tool_result(loop, result)
    process_effects(loop, new_effects ++ rest, callbacks, step, max_steps)
  end

  defp process_effects(loop, [{:emit_event, _event} | rest], callbacks, step, max_steps) do
    # Events are informational - skip in sync mode
    process_effects(loop, rest, callbacks, step, max_steps)
  end

  defp process_effects(_loop, [{:complete, result} | _rest], _callbacks, _step, _max_steps) do
    {:ok, result}
  end

  defp process_effects(_loop, [{:fail, error} | _rest], _callbacks, _step, _max_steps) do
    {:error, error}
  end
end
