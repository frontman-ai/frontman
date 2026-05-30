defmodule SwarmAi.Executor do
  @moduledoc false

  alias SwarmAi.LLM.Response
  alias SwarmAi.{Loop, Message, Telemetry}

  import SwarmAi.Message, only: [is_message: 1]

  @type dispatch_event :: ({atom(), term()} -> any())

  @spec run(atom(), SwarmAi.Agent.t(), dispatch_event()) ::
          {:completed | :failed | :paused, term()}
  def run(runtime, agent, dispatch_event)
      when is_atom(runtime) and is_function(dispatch_event, 1) do
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

        {event, final_status, step_count, output} =
          case execute_loop(loop, effects, runtime, dispatch_event) do
            {:halt, halt_reason, halted_loop} ->
              {{:paused, halt_reason}, :paused, length(halted_loop.steps), nil}

            %Loop{} = final_loop ->
              execution_event(final_loop, loop.id)
          end

        {event,
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

  defp execution_event(%Loop{status: :completed} = loop, _loop_id),
    do: {{:completed, nil}, :completed, length(loop.steps), loop.result}

  defp execution_event(%Loop{status: :failed} = loop, loop_id),
    do: failed_event(loop, loop.error, loop_id, :failed)

  defp execution_event(%Loop{} = loop, loop_id),
    do: failed_event(loop, {:unexpected_status, loop.status}, loop_id, loop.status)

  defp failed_event(loop, reason, loop_id, status),
    do: {{:failed, %{reason: reason, loop_id: loop_id}}, status, length(loop.steps), loop.result}

  defp execute_loop(loop, effects, runtime, dispatch_event) do
    execute_loop(loop, effects, runtime, dispatch_event, loop.config.max_steps)
  end

  defp execute_loop(loop, effects, runtime, dispatch_event, steps_left) do
    case effects do
      [] ->
        loop

      [{:call_llm, _llm, _messages} | _] when steps_left == 0 ->
        Loop.fail(loop, :max_steps)

      [{:call_llm, llm, messages} | rest] ->
        {updated_loop, new_effects} = execute_llm_call(loop, llm, messages, dispatch_event)
        execute_loop(updated_loop, new_effects ++ rest, runtime, dispatch_event, steps_left - 1)

      [{:execute_tool, _} | _] ->
        execute_tool_effects(loop, effects, runtime, dispatch_event, steps_left)

      [{:step_ended, step} | rest] ->
        Telemetry.step_stop(loop.id, step, loop.metadata)
        execute_loop(loop, rest, runtime, dispatch_event, steps_left)

      [{:complete, _result} | _rest] ->
        Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
        loop

      [{:fail, _error} | _rest] ->
        Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
        loop
    end
  end

  defp execute_tool_effects(loop, effects, runtime, dispatch_event, steps_left) do
    {tool_effects, rest} = split_tool_effects(effects)
    tool_calls = Enum.map(tool_effects, fn {:execute_tool, tc} -> tc end)

    Enum.each(tool_calls, fn tool_call -> dispatch_event.({:tool_call, tool_call}) end)

    loop_id = loop.id
    step = loop.current_step
    metadata = loop.metadata

    Enum.each(tool_calls, &emit_tool_start(loop_id, step, &1, metadata))

    executor_result =
      try do
        run_tools(loop.agent, tool_calls, runtime)
      rescue
        e ->
          Enum.each(tool_calls, &emit_tool_exception(loop_id, step, &1, e, metadata))
          reraise e, __STACKTRACE__
      end

    case executor_result do
      {:halt, halt_reason} ->
        Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
        {:halt, halt_reason, loop}

      {:ok, results} ->
        Enum.zip(tool_calls, results)
        |> Enum.each(fn {tc, result} -> emit_tool_stop(loop_id, step, tc, result, metadata) end)

        {new_effects, updated_loop} =
          Enum.flat_map_reduce(results, loop, fn result, loop_acc ->
            {l, e} = Loop.handle_tool_result(loop_acc, result)
            {e, l}
          end)

        execute_loop(
          updated_loop,
          new_effects ++ rest,
          runtime,
          dispatch_event,
          steps_left
        )
    end
  end

  defp run_tools(agent, tool_calls, runtime) do
    task_supervisor = SwarmAi.task_supervisor_name(runtime)
    tool_executor = SwarmAi.Agent.tool_executor(agent)
    build = Map.fetch!(tool_executor, :build)
    execution_mode = Map.fetch!(tool_executor, :execution_mode)
    executions = build.(tool_calls)

    case execution_mode do
      :serial -> SwarmAi.ParallelExecutor.run_serial(executions, task_supervisor)
      :parallel -> SwarmAi.ParallelExecutor.run(executions, task_supervisor)
    end
  end

  defp execute_llm_call(loop, llm, messages, dispatch_event) do
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
              stream_with_events =
                Stream.each(stream, fn chunk -> dispatch_event.({:chunk, chunk}) end)

              response = Response.from_stream(stream_with_events)
              dispatch_event.({:response, response})

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
