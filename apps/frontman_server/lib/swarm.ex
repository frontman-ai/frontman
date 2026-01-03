defmodule Swarm do
  @moduledoc """
  Swarm is an agent execution framework with a stream-first, callback-based API.

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

  To stream tokens during LLM calls, provide an `on_chunk` callback:

      Swarm.run(agent, "Hello", %{
        tool_handler: &execute_tool/1,
        on_chunk: fn chunk ->
          case chunk.type do
            :token -> IO.write(chunk.text)
            _ -> :ok
          end
        end
      })

  ## Low-Level API

  For full control over the execution loop, use the Loop module directly:

      loop = Swarm.Loop.make(agent, config)
      {loop, effects} = Swarm.Loop.execute(loop, message)
      # Interpret effects manually...
  """

  alias Swarm.{Loop, Message, Telemetry, ToolResult}

  @typedoc """
  Message input can be a string, a single Message, or a list of Messages.
  Strings are automatically wrapped as user messages.
  """
  @type message_input :: String.t() | Message.t() | [Message.t()]

  @typedoc """
  Callbacks for synchronous execution.

  - `tool_handler` - Required. Called for each tool call, returns result.
  - `on_chunk` - Optional. Called for each stream chunk (tokens, tool calls, etc).
  """
  @type callbacks :: %{
          required(:tool_handler) => (Swarm.ToolCall.t() ->
                                        {:ok, String.t()} | {:error, String.t()}),
          optional(:on_chunk) => (Swarm.LLM.Chunk.t() -> any())
        }

  @doc """
  Run an agent synchronously, blocking until completion.

  ## Arguments

  - `agent` - An agent implementing the `Swarm.Agent` protocol
  - `message` - The user message to start the conversation
  - `callbacks` - Map with `:tool_handler` (required) and optional `:on_chunk`
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

      # With token streaming
      Swarm.run(agent, "Tell me a story", %{
        tool_handler: fn _ -> {:ok, ""} end,
        on_chunk: fn
          %{type: :token, text: text} -> IO.write(text)
          _ -> :ok
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
    agent_module = agent.__struct__

    Telemetry.run_start(loop.id, agent_module)

    try do
      {loop, effects} = Loop.execute(loop, messages)
      {final_loop, result} = process_effects(loop, effects, callbacks, 0, max_steps)

      case result do
        {:ok, _} ->
          Telemetry.run_stop(loop.id,
            status: :completed,
            result: final_loop.result,
            step_count: final_loop.current_step
          )

        {:error, reason} ->
          Telemetry.run_stop(loop.id,
            status: :failed,
            error: reason,
            step_count: final_loop.current_step
          )
      end

      result
    rescue
      e ->
        Telemetry.run_exception(loop.id, :error, e, __STACKTRACE__)
        reraise e, __STACKTRACE__
    end
  end

  defp normalize_messages(msg) when is_binary(msg), do: [Message.user(msg)]
  defp normalize_messages(%Message{} = msg), do: [msg]
  defp normalize_messages(msgs) when is_list(msgs), do: msgs

  # Process effects returned by Loop operations
  # Returns {loop, result} tuple for telemetry access to final state
  defp process_effects(loop, [], _callbacks, _step, _max_steps) do
    result =
      case loop.status do
        :completed -> {:ok, loop.result}
        :failed -> {:error, loop.error}
        :waiting_for_tools -> {:error, :stuck_waiting_for_tools}
        other -> {:error, {:unexpected_status, other}}
      end

    {loop, result}
  end

  defp process_effects(loop, _effects, _callbacks, step, max_steps) when step >= max_steps do
    {loop, {:error, {:max_steps_exceeded, max_steps}}}
  end

  defp process_effects(loop, [{:call_llm, llm, messages} | rest], callbacks, step, max_steps) do
    alias Swarm.LLM.Response

    Telemetry.llm_call_start(loop.id, step + 1, Map.get(llm, :model))
    on_chunk = Map.get(callbacks, :on_chunk)

    result =
      try do
        with {:ok, stream} <- Swarm.LLM.stream(llm, messages, []) do
          response =
            stream
            |> maybe_tap_stream(on_chunk)
            |> Response.from_stream()

          {:ok, response}
        end
      rescue
        e ->
          Telemetry.llm_call_exception(loop.id, step + 1, :error, e, __STACKTRACE__)
          reraise e, __STACKTRACE__
      end

    handle_llm_result(loop, result, rest, callbacks, step, max_steps)
  end

  defp process_effects(loop, [{:execute_tool, tool_call} | rest], callbacks, step, max_steps) do
    Telemetry.tool_execute_start(loop.id, step, tool_call.id, tool_call.name)

    {content, is_error} =
      try do
        case callbacks.tool_handler.(tool_call) do
          {:ok, result} -> {result, false}
          {:error, reason} -> {to_string(reason), true}
        end
      rescue
        e ->
          Telemetry.tool_execute_exception(
            loop.id,
            step,
            tool_call.id,
            tool_call.name,
            :error,
            e,
            __STACKTRACE__
          )

          reraise e, __STACKTRACE__
      end

    Telemetry.tool_execute_stop(loop.id, step, tool_call.id, tool_call.name, is_error: is_error)

    result = %ToolResult{id: tool_call.id, content: content, is_error: is_error}
    {loop, new_effects} = Loop.handle_tool_result(loop, result)
    process_effects(loop, new_effects ++ rest, callbacks, step, max_steps)
  end

  defp process_effects(loop, [{:emit_event, _event} | rest], callbacks, step, max_steps) do
    # Events are informational - skip in sync mode
    process_effects(loop, rest, callbacks, step, max_steps)
  end

  defp process_effects(loop, [{:complete, result} | _rest], _callbacks, _step, _max_steps) do
    {loop, {:ok, result}}
  end

  defp process_effects(loop, [{:fail, error} | _rest], _callbacks, _step, _max_steps) do
    {loop, {:error, error}}
  end

  # --- Helper functions ---

  defp handle_llm_result(loop, {:ok, response}, rest, callbacks, step, max_steps) do
    {input, output} = extract_usage(response)

    Telemetry.llm_call_stop(loop.id, step + 1,
      input_tokens: input,
      output_tokens: output,
      tool_call_count: length(response.tool_calls || [])
    )

    {loop, new_effects} = Loop.handle_response(loop, response)
    process_effects(loop, new_effects ++ rest, callbacks, step + 1, max_steps)
  end

  defp handle_llm_result(loop, {:error, reason}, rest, callbacks, step, max_steps) do
    Telemetry.llm_call_stop(loop.id, step + 1, error: reason)
    {loop, new_effects} = Loop.handle_error(loop, reason)
    process_effects(loop, new_effects ++ rest, callbacks, step, max_steps)
  end

  defp extract_usage(%{usage: %{input_tokens: input, output_tokens: output}}), do: {input, output}
  defp extract_usage(_), do: {0, 0}

  defp maybe_tap_stream(stream, nil), do: stream
  defp maybe_tap_stream(stream, on_chunk), do: Stream.each(stream, on_chunk)
end
