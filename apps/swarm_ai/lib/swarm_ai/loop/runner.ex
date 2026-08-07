defmodule SwarmAi.Loop.Runner do
  alias SwarmAi.{Effect, LLM, Loop, Message}

  def handle_llm_response(%Loop{status: :running} = loop, %LLM.Response{} = response) do
    cond do
      truncated_tool_calls?(response) ->
        handle_truncation_error(loop)

      LLM.Response.has_tool_calls?(response) ->
        handle_tool_calls(loop, response)

      true ->
        handle_completion(loop, response)
    end
  end

  defp truncated_tool_calls?(%LLM.Response{finish_reason: :length} = response) do
    LLM.Response.has_tool_calls?(response)
  end

  defp truncated_tool_calls?(%LLM.Response{}), do: false

  defp handle_completion(loop, response) do
    loop = Loop.complete(loop, response)

    effects = [Effect.complete(response.content)]

    {loop, effects}
  end

  defp handle_tool_calls(loop, response) do
    loop = Loop.wait_for_tools(loop, response)
    tool_effects = Enum.map(response.tool_calls, &Effect.execute_tool/1)

    {loop, tool_effects}
  end

  defp handle_truncation_error(loop) do
    loop = Loop.fail(loop, :output_truncated)
    {loop, [Effect.fail(:output_truncated)]}
  end

  @spec continue(Loop.t()) :: {Loop.t(), [Effect.t()]}
  def continue(%Loop{status: :waiting_for_tools} = loop) do
    step = Loop.current_step(loop)

    if Loop.Step.all_tools_complete?(step) do
      continue_after_tools(loop, step)
    else
      {loop, []}
    end
  end

  @spec handle_tool_result(Loop.t(), SwarmAi.ToolResult.t()) :: {Loop.t(), [Effect.t()]}
  def handle_tool_result(
        %Loop{status: :waiting_for_tools, steps: [_ | _]} = loop,
        %SwarmAi.ToolResult{} = result
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
        {loop, [Effect.fail({:tool_result_error, reason})]}
    end
  end

  defp continue_after_tools(
         %Loop{llm: llm, steps: steps} = loop,
         %Loop.Step{
           input_messages: input_msgs,
           tool_calls: tool_calls,
           content: content,
           reasoning_details: reasoning_details,
           response_metadata: response_metadata
         }
       ) do
    completed_step = loop.current_step

    assistant_msg = Message.assistant(content, tool_calls, response_metadata, reasoning_details)
    tool_msgs = Enum.map(tool_calls, &format_tool_result/1)
    messages = input_msgs ++ [assistant_msg | tool_msgs]

    new_step = Loop.Step.new(length(steps) + 1, messages)
    loop = %{loop | status: :running, steps: steps ++ [new_step], current_step: new_step.number}

    {loop, [Effect.step_ended(completed_step), Effect.call_llm(llm, messages)]}
  end

  defp format_tool_result(%SwarmAi.ToolCall{
         id: id,
         name: name,
         result: %SwarmAi.ToolResult{
           content: content,
           is_error: is_error
         }
       }) do
    metadata = if is_error, do: %{is_error: true}, else: %{}
    Message.tool_result(name, id, content, metadata)
  end

  @spec handle_llm_error(Loop.t(), term()) :: {Loop.t(), [Effect.t()]}
  def handle_llm_error(%Loop{} = loop, error) do
    loop = Loop.fail(loop, error)

    effects = [Effect.fail(error)]

    {loop, effects}
  end
end
