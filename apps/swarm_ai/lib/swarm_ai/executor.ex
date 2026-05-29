defmodule SwarmAi.Executor do
  @moduledoc false

  alias SwarmAi.LLM.Response
  alias SwarmAi.{Loop, Message, Telemetry}

  import SwarmAi.Message, only: [is_message: 1]

  @type tool_executor ::
          ([SwarmAi.ToolCall.t()] ->
             [SwarmAi.ToolResult.t()] | {:halt, SwarmAi.ParallelExecutor.halt_reason()})

  @type opts :: [
          {:tool_executor, tool_executor()}
          | {:on_chunk, (ReqLLM.StreamChunk.t() -> any())}
          | {:on_response, (Response.t() -> any())}
          | {:on_tool_call, (SwarmAi.ToolCall.t() -> any())}
        ]

  @spec run(SwarmAi.Agent.t(), opts()) ::
          {:ok, String.t(), SwarmAi.Id.t()}
          | {:error, term(), SwarmAi.Id.t()}
          | {:paused, SwarmAi.ParallelExecutor.halt_reason()}
  def run(agent, opts) when is_list(opts) do
    tool_executor = Keyword.fetch!(opts, :tool_executor)
    callbacks = build_callbacks(opts)

    config = %Loop.Config{}
    messages = agent |> SwarmAi.Agent.messages() |> normalize_messages()
    loop = Loop.make(agent, config)

    Telemetry.run_span(
      %{
        loop_id: loop.id,
        agent_id: SwarmAi.Agent.id(agent),
        execution_module: agent.__struct__,
        metadata: loop.metadata,
        input_messages: messages
      },
      fn ->
        {loop, effects} = Loop.execute(loop, messages)

        {result, final_status, step_count, output} =
          case execute_loop(loop, effects, tool_executor, callbacks) do
            {:halt, halt_reason, halted_loop} ->
              {{:paused, halt_reason}, :paused, length(halted_loop.steps), nil}

            %Loop{} = final_loop ->
              execution_result(final_loop, loop.id)
          end

        {result,
         %{
           loop_id: loop.id,
           agent_id: SwarmAi.Agent.id(agent),
           status: final_status,
           step_count: step_count,
           metadata: loop.metadata,
           output: output
         }}
      end
    )
  end

  defp execution_result(%Loop{} = final_loop, loop_id) do
    result =
      case final_loop.status do
        :completed -> {:ok, final_loop.result, loop_id}
        :failed -> {:error, final_loop.error, loop_id}
        other -> {:error, {:unexpected_status, other}, loop_id}
      end

    {result, final_loop.status, length(final_loop.steps), final_loop.result}
  end

  defp execute_loop(loop, effects, tool_executor, callbacks) do
    execute_loop(loop, effects, tool_executor, callbacks, loop.config.max_steps)
  end

  defp execute_loop(loop, [], _tool_executor, _callbacks, _steps_left), do: loop

  defp execute_loop(loop, [{:call_llm, _llm, _messages} | _], _tool_executor, _callbacks, 0) do
    Loop.fail(loop, :max_steps)
  end

  defp execute_loop(
         loop,
         [{:call_llm, llm, messages} | rest],
         tool_executor,
         callbacks,
         steps_left
       )
       when steps_left > 0 do
    {updated_loop, new_effects} = execute_llm_call(loop, llm, messages, callbacks)
    execute_loop(updated_loop, new_effects ++ rest, tool_executor, callbacks, steps_left - 1)
  end

  defp execute_loop(
         loop,
         [{:execute_tool, _} | _] = effects,
         tool_executor,
         callbacks,
         steps_left
       ) do
    {tool_effects, rest} = split_tool_effects(effects)
    tool_calls = Enum.map(tool_effects, fn {:execute_tool, tc} -> tc end)

    Enum.each(tool_calls, callbacks.on_tool_call)

    loop_id = loop.id
    step = loop.current_step
    metadata = loop.metadata

    Enum.each(tool_calls, &emit_tool_start(loop_id, step, &1, metadata))

    executor_result =
      try do
        tool_executor.(tool_calls)
      rescue
        e ->
          Enum.each(tool_calls, &emit_tool_exception(loop_id, step, &1, e, metadata))
          reraise e, __STACKTRACE__
      end

    case executor_result do
      {:halt, halt_reason} ->
        Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
        {:halt, halt_reason, loop}

      results when is_list(results) ->
        Enum.zip(tool_calls, results)
        |> Enum.each(fn {tc, result} -> emit_tool_stop(loop_id, step, tc, result, metadata) end)

        {new_effects, updated_loop} =
          Enum.flat_map_reduce(results, loop, fn result, loop_acc ->
            {l, e} = Loop.handle_tool_result(loop_acc, result)
            {e, l}
          end)

        execute_loop(updated_loop, new_effects ++ rest, tool_executor, callbacks, steps_left)
    end
  end

  defp execute_loop(loop, [{:step_ended, step} | rest], tool_executor, callbacks, steps_left) do
    Telemetry.step_stop(loop.id, step, loop.metadata)
    execute_loop(loop, rest, tool_executor, callbacks, steps_left)
  end

  defp execute_loop(loop, [{:complete, _result} | _rest], _tool_executor, _callbacks, _steps_left) do
    Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
    loop
  end

  defp execute_loop(loop, [{:fail, _error} | _rest], _tool_executor, _callbacks, _steps_left) do
    Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
    loop
  end

  defp execute_llm_call(loop, llm, messages, callbacks) do
    loop_id = loop.id
    step = loop.current_step

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
        case SwarmAi.LLM.stream(llm, messages, timeout_ms: loop.config.step_timeout_ms) do
          {:ok, stream} ->
            try do
              stream_with_callbacks = Stream.each(stream, callbacks.on_chunk)

              response = Response.from_stream(stream_with_callbacks)
              callbacks.on_response.(response)

              {loop, new_effects} = Loop.handle_response(loop, response)
              usage = response.usage || %{}

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

  defp classify_exit_reason({:timeout, {GenServer, :call, _}}), do: :genserver_call_timeout
  defp classify_exit_reason(:timeout), do: :stream_timeout
  defp classify_exit_reason(reason), do: {:exit, reason}

  defp split_tool_effects(effects) do
    Enum.split_while(effects, &match?({:execute_tool, _}, &1))
  end

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
      %{system_time: System.system_time()},
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
      %{system_time: System.system_time()},
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
