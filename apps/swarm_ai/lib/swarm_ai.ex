defmodule SwarmAi do
  @moduledoc """
  SwarmAi is a pure functional agent execution framework.

  ## Usage

  ### Simple blocking execution

      {:ok, result, loop_id} = SwarmAi.run_blocking(agent, "Hello", fn tool_call ->
        {:ok, execute_my_tool(tool_call)}
      end)

  ### Streaming execution with callbacks

      {:ok, result, loop_id} = SwarmAi.run_streaming(agent, "Hello",
        tool_executor: fn tool_calls ->
          Enum.map(tool_calls, fn tc ->
            result = execute(tc)
            SwarmAi.ToolResult.make(tc.id, result, false)
          end)
        end,
        on_chunk: fn chunk -> IO.write(chunk.text || "") end,
        on_response: fn response -> Logger.info("Got response") end,
        on_tool_call: fn tc -> Logger.info("Calling \#{tc.name}") end
      )

  The `loop_id` is a unique identifier for each execution, useful for telemetry
  correlation and crash reporting.

  ### Manual control over tool execution

      case SwarmAi.run(agent, "Hello") do
        {:completed, loop} ->
          loop.result

        {:tool_calls, loop, tool_calls} ->
          results = execute_tools(tool_calls)
          SwarmAi.continue(loop, results)

        {:error, loop} ->
          {:error, loop.error}
      end

  """

  alias SwarmAi.{Loop, Message, Telemetry, ToolResult}
  alias SwarmAi.LLM.{Chunk, Response}

  import SwarmAi.Message, only: [is_message: 1]

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
          | {:tool_calls, Loop.t(), [SwarmAi.ToolCall.t()]}
          | {:error, Loop.t()}

  @typedoc """
  A function that executes a batch of tool calls and returns results.

  Receives a list of tool calls and must return a list of ToolResults
  in the same order. The executor controls how tools are executed —
  sequentially, in parallel, or any other strategy.
  """
  @type tool_executor :: ([SwarmAi.ToolCall.t()] -> [SwarmAi.ToolResult.t()])

  @typedoc """
  Callback options for run_streaming/3.

  - `:tool_executor` - Required. Function to execute tool calls.
  - `:on_chunk` - Called for each LLM streaming chunk
  - `:on_response` - Called when LLM response is complete
  - `:on_tool_call` - Called before each tool is executed
  - `:metadata` - Arbitrary map attached to the loop for telemetry correlation
  """
  @type streaming_opts :: [
          {:tool_executor, tool_executor()}
          | {:on_chunk, (Chunk.t() -> any())}
          | {:on_response, (Response.t() -> any())}
          | {:on_tool_call, (SwarmAi.ToolCall.t() -> any())}
          | {:metadata, map()}
        ]

  # =============================================================================
  # Primary API
  # =============================================================================

  @doc """
  Run an agent to completion with streaming callbacks.

  This is the primary API for running agents. It handles the full execution loop,
  calling the tool_executor when tools are needed and emitting callbacks for
  streaming, responses, and tool calls.

  Telemetry is emitted automatically for all LLM calls and tool executions.

  ## Options

  - `:tool_executor` - Required. Function `([ToolCall.t()] -> [ToolResult.t()])`
  - `:on_chunk` - Called for each streaming chunk from LLM
  - `:on_response` - Called when LLM response is complete (before tool execution)
  - `:on_tool_call` - Called before each tool is executed

  ## Returns

  - `{:ok, result, loop_id}` - Agent completed successfully
  - `{:error, reason, loop_id}` - Agent failed

  The `loop_id` is always returned for telemetry correlation and crash reporting.

  ## Examples

      # With streaming
      {:ok, result, loop_id} = SwarmAi.run_streaming(agent, "Analyze this code",
        tool_executor: &execute_tools/1,
        on_chunk: fn chunk -> IO.write(chunk.text || "") end
      )

      # Minimal (no streaming callbacks)
      {:ok, result, _loop_id} = SwarmAi.run_streaming(agent, "Hello",
        tool_executor: fn tcs -> Enum.map(tcs, &ToolResult.make(&1.id, "done", false)) end
      )
  """
  @spec run_streaming(SwarmAi.Agent.t(), message_input(), streaming_opts()) ::
          {:ok, String.t(), SwarmAi.Id.t()}
          | {:error, term(), SwarmAi.Id.t()}
  def run_streaming(agent, message, opts) when is_list(opts) do
    tool_executor = Keyword.fetch!(opts, :tool_executor)
    callbacks = build_callbacks(opts)
    metadata = Keyword.get(opts, :metadata, %{})

    config = %Loop.Config{}
    messages = normalize_messages(message)
    loop = Loop.make(agent, config, metadata: metadata)

    Telemetry.run_span(
      %{
        loop_id: loop.id,
        agent_module: agent.__struct__,
        metadata: loop.metadata,
        input_messages: messages
      },
      fn ->
        {loop, effects} = Loop.execute(loop, messages)
        final_loop = execute_loop(loop, effects, tool_executor, callbacks)

        result =
          case final_loop.status do
            :completed ->
              {:ok, final_loop.result, loop.id}

            :failed ->
              {:error, final_loop.error, loop.id}

            other ->
              {:error, {:unexpected_status, other}, loop.id}
          end

        # Include loop_id, metadata, and output in stop metadata
        {result,
         %{
           loop_id: loop.id,
           status: final_loop.status,
           step_count: length(final_loop.steps),
           metadata: loop.metadata,
           output: final_loop.result
         }}
      end
    )
  end

  @doc """
  Run an agent to completion with a tool executor.

  Convenience wrapper around `run_streaming/3` without streaming callbacks.

  ## Examples

      {:ok, result, loop_id} = SwarmAi.run_blocking(agent, "What's the weather?", fn tool_call ->
        case tool_call.name do
          "get_weather" -> {:ok, "Sunny, 22°C"}
          _ -> {:error, "Unknown tool"}
        end
      end)
  """
  @type single_tool_executor ::
          (SwarmAi.ToolCall.t() -> {:ok, String.t()} | {:error, String.t()})

  @spec run_blocking(SwarmAi.Agent.t(), message_input(), single_tool_executor()) ::
          {:ok, String.t(), SwarmAi.Id.t()}
          | {:error, term(), SwarmAi.Id.t()}
  def run_blocking(agent, message, tool_executor) when is_function(tool_executor, 1) do
    batch_executor = fn tool_calls ->
      Enum.map(tool_calls, fn tc ->
        case tool_executor.(tc) do
          {:ok, content} -> ToolResult.make(tc.id, content, false)
          {:error, reason} -> ToolResult.make(tc.id, to_string(reason), true)
        end
      end)
    end

    run_streaming(agent, message, tool_executor: batch_executor)
  end

  # =============================================================================
  # Manual Control API
  # =============================================================================

  @doc """
  Start agent execution, yielding when tools are needed.

  Use this when you want manual control over tool execution timing and strategy.
  For most cases, prefer `run_streaming/3` or `run_blocking/3`.

  ## Returns

  - `{:completed, loop}` - Agent completed, result in `loop.result`
  - `{:tool_calls, loop, tool_calls}` - Agent needs tools, execute and call `continue/2`
  - `{:error, loop}` - Agent failed, error in `loop.error`

  ## Examples

      case SwarmAi.run(agent, "What's the weather?") do
        {:completed, loop} ->
          IO.puts(loop.result)

        {:tool_calls, loop, tool_calls} ->
          results = Enum.map(tool_calls, &execute_tool/1)
          SwarmAi.continue(loop, results)
      end
  """
  @spec run(SwarmAi.Agent.t(), message_input()) :: run_result()
  @spec run(SwarmAi.Agent.t(), message_input(), keyword()) :: run_result()
  def run(agent, message, opts \\ []) do
    callbacks = build_callbacks(opts)
    metadata = Keyword.get(opts, :metadata, %{})

    config = %Loop.Config{}
    messages = normalize_messages(message)
    loop = Loop.make(agent, config, metadata: metadata)

    Telemetry.run_start(loop.id, agent.__struct__, loop.metadata)

    {loop, effects} = Loop.execute(loop, messages)
    result = execute_until_yield(loop, effects, callbacks)

    emit_run_stop(result)
    result
  end

  @doc """
  Continue agent execution with tool results.

  Call this after executing the tool calls returned by `run/2` or a previous
  `continue/2`.

  ## Examples

      results = Enum.map(tool_calls, &execute_tool/1)

      case SwarmAi.continue(loop, results) do
        {:completed, loop} -> {:ok, loop.result}
        {:tool_calls, loop, more_tools} -> continue_execution(loop, more_tools)
      end
  """
  @spec continue(Loop.t(), [ToolResult.t()]) :: run_result()
  @spec continue(Loop.t(), [ToolResult.t()], keyword()) :: run_result()
  def continue(%Loop{status: :waiting_for_tools} = loop, tool_results, opts \\ [])
      when is_list(tool_results) do
    callbacks = build_callbacks(opts)

    loop =
      Enum.reduce(tool_results, loop, fn result, acc ->
        case Loop.add_tool_result(acc, result) do
          {:ok, updated} -> updated
          {:error, _reason} -> acc
        end
      end)

    {loop, effects} = Loop.Runner.continue(loop)
    result = execute_until_yield(loop, effects, callbacks)

    emit_run_stop(result)
    result
  end

  # =============================================================================
  # Core Execution Loop
  # =============================================================================

  # Execute loop to completion (for run_streaming/run_blocking)
  defp execute_loop(loop, [], _tool_executor, _callbacks), do: loop

  defp execute_loop(loop, [{:call_llm, llm, messages} | rest], tool_executor, callbacks) do
    {updated_loop, new_effects} = execute_llm_call(loop, llm, messages, callbacks)
    execute_loop(updated_loop, new_effects ++ rest, tool_executor, callbacks)
  end

  defp execute_loop(loop, [{:execute_tool, _} | _] = effects, tool_executor, callbacks) do
    {tool_effects, rest} = split_tool_effects(effects)
    tool_calls = Enum.map(tool_effects, fn {:execute_tool, tc} -> tc end)

    Enum.each(tool_calls, callbacks.on_tool_call)

    loop_id = loop.id
    step = loop.current_step
    metadata = loop.metadata

    Enum.each(tool_calls, &emit_tool_start(loop_id, step, &1, metadata))

    results =
      try do
        tool_executor.(tool_calls)
      rescue
        e ->
          Enum.each(tool_calls, &emit_tool_exception(loop_id, step, &1, e, metadata))
          reraise e, __STACKTRACE__
      end

    Enum.zip(tool_calls, results)
    |> Enum.each(fn {tc, result} -> emit_tool_stop(loop_id, step, tc, result, metadata) end)

    {updated_loop, new_effects} =
      Enum.reduce(results, {loop, []}, fn result, {loop_acc, effects_acc} ->
        {l, e} = Loop.handle_tool_result(loop_acc, result)
        {l, effects_acc ++ e}
      end)

    execute_loop(updated_loop, new_effects ++ rest, tool_executor, callbacks)
  end

  defp execute_loop(loop, [{:step_ended, step} | rest], tool_executor, callbacks) do
    Telemetry.step_stop(loop.id, step, loop.metadata)
    execute_loop(loop, rest, tool_executor, callbacks)
  end

  defp execute_loop(loop, [{:complete, _result} | _rest], _tool_executor, _callbacks) do
    # Final step completed - emit step stop
    Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
    loop
  end

  defp execute_loop(loop, [{:fail, _error} | _rest], _tool_executor, _callbacks) do
    # Step failed - emit step stop
    Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
    loop
  end

  # Execute loop until tool_calls are needed (for run/continue)
  defp execute_until_yield(loop, [], _callbacks) do
    case loop.status do
      :completed -> {:completed, loop}
      :failed -> {:error, loop}
      :waiting_for_tools -> {:tool_calls, loop, pending_tool_calls(loop)}
      _other -> {:error, loop}
    end
  end

  defp execute_until_yield(loop, [{:call_llm, llm, messages} | rest], callbacks) do
    {loop, new_effects} = execute_llm_call(loop, llm, messages, callbacks)
    execute_until_yield(loop, new_effects ++ rest, callbacks)
  end

  defp execute_until_yield(loop, [{:execute_tool, _} | _] = effects, _callbacks) do
    # Yield to caller for tool execution
    tool_calls = Enum.map(effects, fn {:execute_tool, tc} -> tc end)
    {:tool_calls, loop, tool_calls}
  end

  defp execute_until_yield(loop, [{:step_ended, step} | rest], callbacks) do
    Telemetry.step_stop(loop.id, step, loop.metadata)
    execute_until_yield(loop, rest, callbacks)
  end

  defp execute_until_yield(loop, [{:complete, _result} | _rest], _callbacks) do
    # Final step completed - emit step stop
    Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
    {:completed, loop}
  end

  defp execute_until_yield(loop, [{:fail, _error} | _rest], _callbacks) do
    # Step failed - emit step stop
    Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
    {:error, loop}
  end

  # =============================================================================
  # LLM Call Execution (shared by both paths)
  # =============================================================================

  defp execute_llm_call(loop, llm, messages, callbacks) do
    loop_id = loop.id
    step = loop.current_step

    # Emit step start event (step spans the LLM call + subsequent tool executions)
    Telemetry.step_start(loop_id, step, loop.metadata)

    Telemetry.llm_span(
      %{
        loop_id: loop_id,
        step: step,
        model: llm.model,
        messages: messages,
        metadata: loop.metadata
      },
      fn ->
        case SwarmAi.LLM.stream(llm, messages, []) do
          {:ok, stream} ->
            try do
              stream_with_callbacks = Stream.each(stream, callbacks.on_chunk)

              response = Response.from_stream(stream_with_callbacks)
              callbacks.on_response.(response)

              {loop, new_effects} = Loop.handle_response(loop, response)
              usage = response.usage || %{}

              # Include loop_id/step in stop metadata for telemetry handlers
              {{loop, new_effects},
               %{
                 loop_id: loop_id,
                 step: step,
                 response: response.content,
                 reasoning_details: response.reasoning_details,
                 tool_calls: response.tool_calls,
                 usage: usage,
                 input_tokens: Map.get(usage, :input_tokens, 0),
                 output_tokens: Map.get(usage, :output_tokens, 0),
                 reasoning_tokens: Map.get(usage, :reasoning_tokens, 0),
                 cached_tokens: Map.get(usage, :cached_tokens, 0),
                 tool_call_count: length(response.tool_calls),
                 metadata: loop.metadata
               }}
            rescue
              e ->
                {loop, new_effects} = Loop.handle_error(loop, e)
                {{loop, new_effects}, %{loop_id: loop_id, step: step, metadata: loop.metadata}}
            catch
              :exit, exit_reason ->
                reason = classify_exit_reason(exit_reason)
                {loop, new_effects} = Loop.handle_error(loop, reason)
                {{loop, new_effects}, %{loop_id: loop_id, step: step, metadata: loop.metadata}}
            end

          {:error, reason} ->
            {loop, new_effects} = Loop.handle_error(loop, reason)
            {{loop, new_effects}, %{loop_id: loop_id, step: step, metadata: loop.metadata}}
        end
      end
    )
  end

  # =============================================================================
  # Helpers
  # =============================================================================

  defp build_callbacks(opts) do
    %{
      on_chunk: Keyword.get(opts, :on_chunk, fn _ -> :ok end),
      on_response: Keyword.get(opts, :on_response, fn _ -> :ok end),
      on_tool_call: Keyword.get(opts, :on_tool_call, fn _ -> :ok end)
    }
  end

  defp normalize_messages(msg) when is_binary(msg), do: [Message.user(msg)]
  defp normalize_messages(msg) when is_message(msg), do: [msg]
  defp normalize_messages(msgs) when is_list(msgs), do: msgs

  defp pending_tool_calls(%Loop{} = loop) do
    case Loop.current_step(loop) do
      nil -> []
      step -> Enum.reject(step.tool_calls, &SwarmAi.ToolCall.completed?/1)
    end
  end

  defp emit_run_stop({:completed, loop}) do
    Telemetry.run_stop(loop.id,
      status: :completed,
      step_count: length(loop.steps),
      metadata: loop.metadata
    )
  end

  defp emit_run_stop({:error, loop}) do
    Telemetry.run_stop(loop.id,
      status: :failed,
      step_count: length(loop.steps),
      error: loop.error,
      metadata: loop.metadata
    )
  end

  defp emit_run_stop({:tool_calls, _loop, _tool_calls}) do
    # Don't emit stop yet - run is still in progress
    :ok
  end

  defp classify_exit_reason({:timeout, {GenServer, :call, _}}), do: :genserver_call_timeout
  defp classify_exit_reason(:timeout), do: :stream_timeout
  defp classify_exit_reason(reason), do: {:exit, reason}

  defp split_tool_effects(effects) do
    Enum.split_while(effects, &match?({:execute_tool, _}, &1))
  end

  # Emit per-tool telemetry before/after batch execution so OTel handlers can
  # create tool spans with correct parent (step) and attributes.
  # Tools in a batch execute in parallel inside tool_executor, so all start
  # events are emitted before the batch and all stop events after it completes.
  # Individual tool durations are measured by the OTel handler via wall-clock
  # (start_span/end_span), not by the telemetry duration measurement here.
  defp emit_tool_start(loop_id, step, tc, metadata) do
    :telemetry.execute(
      [:swarm_ai, :tool, :execute, :start],
      %{system_time: System.system_time()},
      %{
        loop_id: loop_id,
        step: step,
        tool_id: tc.id,
        tool_name: tc.name,
        arguments: tc.arguments,
        metadata: metadata
      }
    )
  end

  defp emit_tool_exception(loop_id, step, tc, exception, metadata) do
    :telemetry.execute(
      [:swarm_ai, :tool, :execute, :exception],
      %{duration: 0},
      %{
        loop_id: loop_id,
        step: step,
        tool_id: tc.id,
        tool_name: tc.name,
        reason: exception,
        metadata: metadata
      }
    )
  end

  defp emit_tool_stop(loop_id, step, tc, result, metadata) do
    :telemetry.execute(
      [:swarm_ai, :tool, :execute, :stop],
      %{duration: 0},
      %{
        loop_id: loop_id,
        step: step,
        tool_id: tc.id,
        tool_name: tc.name,
        is_error: result.is_error,
        output: result.content,
        metadata: metadata
      }
    )
  end
end
