defmodule SwarmAi.Loop.Step do
  use TypedStruct

  @type usage :: %{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          reasoning_tokens: non_neg_integer(),
          cached_tokens: non_neg_integer()
        }

  typedstruct do
    field(:number, pos_integer(), enforce: true)
    field(:input_messages, [SwarmAi.Message.t()], default: [])
    field(:content, String.t())
    field(:reasoning_details, [map()], default: [])
    field(:usage, usage())
    field(:tool_calls, [SwarmAi.ToolCall.t()], default: [])
    field(:response_metadata, map(), default: %{})
    field(:started_at, DateTime.t(), enforce: true)
    field(:completed_at, DateTime.t())
    field(:duration_ms, non_neg_integer())
  end

  @spec new(pos_integer(), [SwarmAi.Message.t()]) :: t()
  def new(number, input_messages) do
    %__MODULE__{
      number: number,
      input_messages: input_messages,
      started_at: DateTime.utc_now()
    }
  end

  @spec record_response(t(), SwarmAi.LLM.Response.t()) :: t()
  def record_response(%__MODULE__{} = step, %SwarmAi.LLM.Response{} = response) do
    now = DateTime.utc_now()

    %{
      step
      | content: response.content,
        reasoning_details: response.reasoning_details,
        usage: response.usage,
        tool_calls: response.tool_calls,
        response_metadata: response.metadata || %{},
        completed_at: now,
        duration_ms: DateTime.diff(now, step.started_at, :millisecond)
    }
  end

  @spec has_pending_tools?(t()) :: boolean()
  def has_pending_tools?(%__MODULE__{tool_calls: calls}) do
    Enum.any?(calls, &(not SwarmAi.ToolCall.completed?(&1)))
  end

  @spec all_tools_complete?(t()) :: boolean()
  def all_tools_complete?(%__MODULE__{tool_calls: []}), do: true

  def all_tools_complete?(%__MODULE__{tool_calls: calls}) do
    Enum.all?(calls, &SwarmAi.ToolCall.completed?/1)
  end

  @spec add_tool_result(t(), SwarmAi.ToolResult.t()) ::
          {:ok, t()} | {:error, :not_found | :already_completed}
  def add_tool_result(%__MODULE__{tool_calls: calls} = step, %SwarmAi.ToolResult{id: id} = result) do
    with {:ok, index} <- find_index(calls, id),
         tc = Enum.at(calls, index),
         false <- SwarmAi.ToolCall.completed?(tc) do
      updated_tc = SwarmAi.ToolCall.with_result(tc, result)
      {:ok, %{step | tool_calls: List.replace_at(calls, index, updated_tc)}}
    else
      :error -> {:error, :not_found}
      true -> {:error, :already_completed}
    end
  end

  defp find_index(calls, id) do
    case Enum.find_index(calls, &(&1.id == id)) do
      nil -> :error
      index -> {:ok, index}
    end
  end
end
