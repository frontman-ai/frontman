defmodule SwarmAi.Executor do
  @moduledoc false

  alias SwarmAi.LLM.Response
  alias SwarmAi.{Loop, Telemetry}

  def run(%Loop{} = loop, task_supervisor) do
    Telemetry.run_span(
      %{
        loop_id: loop.id,
        task_id: loop.task_id,
        turn_number: loop.turn_number
      },
      fn ->
        # QUESTION(Danni) - why do we need both loop.execute which does almost
        # nothing compared to make, then we've run_effects
        {loop, effects} = Loop.execute(loop)
        final_loop = run_effects(loop, effects, task_supervisor)

        {final_loop,
         %{
           loop_id: final_loop.id,
           task_id: final_loop.task_id,
           turn_number: final_loop.turn_number,
           status: final_loop.status,
           step_count: length(final_loop.steps),
           output: final_loop.result
         }}
      end
    )
  end

  defp run_effects(loop, effects, task_supervisor) do
    run_effects(loop, effects, task_supervisor, loop.config.max_steps)
  end

  defp run_effects(loop, effects, task_supervisor, steps_left) do
    case effects do
      [] ->
        loop

      [{:call_llm, _llm, _messages} | _] when steps_left == 0 ->
        Loop.fail(loop, :max_steps)

      [{:call_llm, llm, messages} | rest] when steps_left > 0 ->
        {updated_loop, new_effects} = execute_llm_call(loop, llm, messages)
        run_effects(updated_loop, new_effects ++ rest, task_supervisor, steps_left - 1)

      [{:execute_tool, _} | _] ->
        execute_tool_effects(loop, effects, task_supervisor, steps_left)

      [{:step_ended, step} | rest] ->
        Telemetry.step_stop(loop.id, step)
        run_effects(loop, rest, task_supervisor, steps_left)

      [{:complete, _result} | _rest] ->
        Telemetry.step_stop(loop.id, loop.current_step)
        loop

      [{:fail, _error} | _rest] ->
        Telemetry.step_stop(loop.id, loop.current_step)
        loop
    end
  end

  defp execute_tool_effects(loop, effects, task_supervisor, steps_left) do
    {tool_effects, rest} = split_tool_effects(effects)
    tool_calls = Enum.map(tool_effects, fn {:execute_tool, tc} -> tc end)

    Enum.each(tool_calls, fn tool_call -> loop.dispatch_event.({:tool_call, tool_call}) end)

    loop_id = loop.id
    step = loop.current_step

    Enum.each(tool_calls, &emit_tool_start(loop_id, step, &1))

    executor_result =
      try do
        loop.execute_tools.(tool_calls, task_supervisor)
      rescue
        e ->
          Enum.each(tool_calls, &emit_tool_exception(loop_id, step, &1, e))
          reraise e, __STACKTRACE__
      end

    case executor_result do
      {:halt, halt_reason} ->
        Telemetry.step_stop(loop.id, loop.current_step)
        Loop.pause(loop, halt_reason)

      {:ok, results} ->
        Enum.zip(tool_calls, results)
        |> Enum.each(fn {tc, result} -> emit_tool_stop(loop_id, step, tc, result) end)

        {new_effects, updated_loop} =
          Enum.flat_map_reduce(results, loop, fn result, loop_acc ->
            {l, e} = Loop.handle_tool_result(loop_acc, result)
            {e, l}
          end)

        run_effects(
          updated_loop,
          new_effects ++ rest,
          task_supervisor,
          steps_left
        )
    end
  end

  defp execute_llm_call(loop, llm, messages) do
    loop_id = loop.id
    current_step = loop.current_step

    Telemetry.step_start(loop_id, current_step)

    Telemetry.llm_span(
      %{
        loop_id: loop_id,
        step: current_step,
        model: llm.model,
        messages: messages
      },
      fn ->
        case SwarmAi.LLM.stream(llm, messages, timeout_ms: loop.config.step_timeout_ms) do
          {:ok, stream} ->
            try do
              stream_with_events =
                Stream.each(stream, fn chunk -> loop.dispatch_event.({:chunk, chunk}) end)

              response = Response.from_stream(stream_with_events)
              :ok = loop.dispatch_event.({:response, response})

              {loop, new_effects} = Loop.handle_response(loop, response)
              usage = response.usage || %{}

              {{loop, new_effects},
               %{
                 loop_id: loop_id,
                 step: current_step,
                 response: response.content,
                 reasoning_details: response.reasoning_details,
                 tool_calls: response.tool_calls,
                 usage: usage,
                 input_tokens: Map.get(usage, :input_tokens, 0),
                 output_tokens: Map.get(usage, :output_tokens, 0),
                 reasoning_tokens: Map.get(usage, :reasoning_tokens, 0),
                 cached_tokens: Map.get(usage, :cached_tokens, 0),
                 tool_call_count: length(response.tool_calls)
               }}
            rescue
              e ->
                {loop, new_effects} = Loop.handle_error(loop, {:exception, e})
                {{loop, new_effects}, %{loop_id: loop_id, step: current_step}}
            catch
              :exit, exit_reason ->
                reason = classify_exit_reason(exit_reason)
                {loop, new_effects} = Loop.handle_error(loop, reason)
                {{loop, new_effects}, %{loop_id: loop_id, step: current_step}}
            end

          {:error, reason} ->
            {loop, new_effects} = Loop.handle_error(loop, {:llm_error, reason})
            {{loop, new_effects}, %{loop_id: loop_id, step: current_step}}
        end
      end
    )
  end

  defp classify_exit_reason({:timeout, {GenServer, :call, _}}), do: :genserver_call_timeout
  defp classify_exit_reason(:timeout), do: :stream_timeout
  defp classify_exit_reason(reason), do: {:exit, reason}

  defp split_tool_effects(effects) do
    Enum.split_while(effects, &match?({:execute_tool, _}, &1))
  end

  defp emit_tool_start(loop_id, step, tc) do
    :telemetry.execute(
      [:swarm_ai, :tool, :execute, :start],
      %{system_time: System.system_time()},
      %{
        loop_id: loop_id,
        step: step,
        tool_id: tc.id,
        tool_name: tc.name,
        arguments: tc.arguments
      }
    )
  end

  defp emit_tool_exception(loop_id, step, tc, exception) do
    :telemetry.execute(
      [:swarm_ai, :tool, :execute, :exception],
      %{system_time: System.system_time()},
      %{
        loop_id: loop_id,
        step: step,
        tool_id: tc.id,
        tool_name: tc.name,
        reason: exception
      }
    )
  end

  defp emit_tool_stop(loop_id, step, tc, result) do
    :telemetry.execute(
      [:swarm_ai, :tool, :execute, :stop],
      %{system_time: System.system_time()},
      %{
        loop_id: loop_id,
        step: step,
        tool_id: tc.id,
        tool_name: tc.name,
        is_error: result.is_error,
        output: result.content
      }
    )
  end
end
