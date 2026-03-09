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
        tool_executor: fn tc -> {:ok, execute(tc)} end,
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

  ## Sub-Agent Spawning

  Tools can delegate work to child agents by returning `{:spawn, request}`:

      def my_tool_executor(tc) do
        case tc.name do
          "deep_analysis" ->
            {:spawn, SpawnChildAgent.new(child_agent, tc.arguments["task"])}

          "simple_tool" ->
            {:ok, do_work(tc.arguments)}
        end
      end

  The `run_streaming/3` and `run_blocking/3` functions handle spawns automatically
  when the tool_executor returns `{:spawn, request}`.
  """

  alias SwarmAi.{ChildResult, Loop, Message, SpawnChildAgent, Telemetry, ToolResult}
  alias SwarmAi.LLM.{Chunk, Response}

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
  A function that executes a single tool call and returns the result.

  Returns:
  - `{:ok, content}` - Tool executed successfully
  - `{:error, reason}` - Tool failed
  - `{:spawn, request}` - Delegate to a child agent
  - `:suspended` - Tool is waiting for external input (e.g., user interaction)
  """
  @type tool_executor ::
          (SwarmAi.ToolCall.t() ->
             {:ok, String.t()}
             | {:error, String.t()}
             | {:spawn, SwarmAi.SpawnChildAgent.t()}
             | :suspended)

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

  Telemetry is emitted automatically for all LLM calls, tool executions, and
  child agent spawns.

  ## Options

  - `:tool_executor` - Required. Function `(ToolCall.t() -> {:ok, result} | {:error, reason} | {:spawn, request})`
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
        tool_executor: &execute_tool/1,
        on_chunk: fn chunk -> IO.write(chunk.text || "") end
      )

      # Minimal (no streaming callbacks)
      {:ok, result, _loop_id} = SwarmAi.run_streaming(agent, "Hello", tool_executor: fn _ -> {:ok, "done"} end)
  """
  @spec run_streaming(SwarmAi.Agent.t(), message_input(), streaming_opts()) ::
          {:ok, String.t(), SwarmAi.Id.t()}
          | {:error, term(), SwarmAi.Id.t()}
          | {:suspended, SwarmAi.Id.t()}
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

            :waiting_for_tools ->
              step = Loop.current_step(final_loop)

              if step && SwarmAi.Loop.Step.has_suspended_tools?(step) do
                {:suspended, loop.id}
              else
                {:error, {:unexpected_status, :waiting_for_tools}, loop.id}
              end

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
  @spec run_blocking(SwarmAi.Agent.t(), message_input(), tool_executor()) ::
          {:ok, String.t(), SwarmAi.Id.t()}
          | {:error, term(), SwarmAi.Id.t()}
          | {:suspended, SwarmAi.Id.t()}
  def run_blocking(agent, message, tool_executor) when is_function(tool_executor, 1) do
    run_streaming(agent, message, tool_executor: tool_executor)
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
  # Child Agent Execution
  # =============================================================================

  @doc """
  Runs a child agent and returns ChildResult.

  Used internally by `run_streaming/3` when a tool returns `{:spawn, request}`.
  Can also be called directly for manual child agent management.

  Telemetry is automatically emitted for the child's lifecycle.
  """
  @spec run_child(Loop.t(), String.t(), SpawnChildAgent.t(), tool_executor()) ::
          ChildResult.t()
  def run_child(
        parent_loop,
        tool_call_id,
        %SpawnChildAgent{} = spawn_request,
        tool_executor
      ) do
    config = %Loop.Config{
      max_steps: spawn_request.max_steps || 20,
      timeout_ms: spawn_request.timeout_ms || 300_000
    }

    # Child loop inherits metadata from parent, plus parent_agent_module for graph tracking
    child_loop =
      Loop.make_child(spawn_request.agent, config, parent_loop,
        metadata: %{parent_agent_module: parent_loop.agent.__struct__}
      )

    callbacks = %{
      on_chunk: fn _ -> :ok end,
      on_response: fn _ -> :ok end,
      on_tool_call: fn _ -> :ok end
    }

    Telemetry.child_span(
      %{
        parent_loop_id: parent_loop.id,
        parent_step: parent_loop.current_step,
        tool_call_id: tool_call_id,
        child_agent_module: spawn_request.agent.__struct__,
        task: spawn_request.task,
        metadata: parent_loop.metadata
      },
      fn ->
        messages = [Message.user(spawn_request.task)]
        {child_loop, effects} = Loop.execute(child_loop, messages)
        final_loop = execute_loop(child_loop, effects, tool_executor, callbacks)

        child_result = %ChildResult{
          child_loop_id: child_loop.id,
          status: if(final_loop.status == :completed, do: :completed, else: :failed),
          result: final_loop.result,
          error: final_loop.error,
          step_count: length(final_loop.steps),
          total_tokens: sum_tokens(final_loop.steps),
          duration_ms: 0,
          loop: final_loop
        }

        {child_result,
         %{
           parent_loop_id: parent_loop.id,
           tool_call_id: tool_call_id,
           child_loop_id: child_loop.id,
           child_status: child_result.status,
           child_step_count: child_result.step_count,
           child_total_tokens: child_result.total_tokens,
           metadata: parent_loop.metadata
         }}
      end
    )
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

  defp execute_loop(loop, [{:execute_tool, tc} | rest], tool_executor, callbacks) do
    callbacks.on_tool_call.(tc)

    result = execute_tool_with_spawn(loop, tc, tool_executor)
    {updated_loop, new_effects} = Loop.handle_tool_result(loop, result)

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

  defp execute_loop(loop, [{:emit_event, _event} | rest], tool_executor, callbacks) do
    execute_loop(loop, rest, tool_executor, callbacks)
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

  defp execute_until_yield(loop, [{:emit_event, _event} | rest], callbacks) do
    execute_until_yield(loop, rest, callbacks)
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

          {:error, reason} ->
            {loop, new_effects} = Loop.handle_error(loop, reason)
            {{loop, new_effects}, %{loop_id: loop_id, step: step, metadata: loop.metadata}}
        end
      end
    )
  end

  # =============================================================================
  # Tool Execution with Spawn Support
  # =============================================================================

  defp execute_tool_with_spawn(loop, tc, tool_executor) do
    loop_id = loop.id
    step = loop.current_step
    tool_id = tc.id
    tool_name = tc.name

    Telemetry.tool_span(
      %{
        loop_id: loop_id,
        step: step,
        tool_id: tool_id,
        tool_name: tool_name,
        arguments: tc.arguments,
        metadata: loop.metadata
      },
      fn ->
        result =
          case tool_executor.(tc) do
            {:ok, content} ->
              ToolResult.make(tc.id, content, false)

            {:error, reason} ->
              ToolResult.make(tc.id, to_string(reason), true)

            {:spawn, request} ->
              child_result = run_child(loop, tc.id, request, tool_executor)
              content = child_result.result || "Child failed: #{inspect(child_result.error)}"
              ToolResult.make(tc.id, content, child_result.status == :failed)

            :suspended ->
              ToolResult.suspended(tc.id)
          end

        stop_meta = %{
          loop_id: loop_id,
          tool_id: tool_id,
          tool_name: tool_name,
          is_error: result.is_error,
          output: result.content,
          metadata: loop.metadata
        }

        {result, stop_meta}
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
  defp normalize_messages(%Message{} = msg), do: [msg]
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

  defp sum_tokens(steps) do
    Enum.reduce(steps, 0, fn step, acc ->
      case step.usage do
        %{input_tokens: i, output_tokens: o} -> acc + i + o
        _ -> acc
      end
    end)
  end
end
