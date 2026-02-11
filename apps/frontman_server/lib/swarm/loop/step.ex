defmodule Swarm.Loop.Step do
  @moduledoc """
  Represents a single step in the agentic loop.

  Each step tracks one LLM iteration:
  - `input_messages` - Messages sent TO the LLM (system, user, assistant messages)
  - `content` - Text response received FROM the LLM
  - `usage` - Token usage stats: %{input_tokens: int, output_tokens: int, reasoning_tokens: int, cached_tokens: int}
  - `started_at` - When the LLM call was initiated
  - `completed_at` - When the LLM response was received
  - `duration_ms` - How long the LLM call took

  Steps are created when an iteration starts and completed when the LLM responds.
  """

  use TypedStruct

  @type usage :: %{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          reasoning_tokens: non_neg_integer(),
          cached_tokens: non_neg_integer()
        }

  typedstruct do
    field(:number, pos_integer(), enforce: true)
    field(:input_messages, [Swarm.Message.t()], default: [])
    field(:content, String.t())
    field(:reasoning_details, [map()], default: [])
    field(:usage, usage())
    field(:tool_calls, [Swarm.ToolCall.t()], default: [])
    field(:response_metadata, map(), default: %{})
    field(:started_at, DateTime.t(), enforce: true)
    field(:completed_at, DateTime.t())
    field(:duration_ms, non_neg_integer())
  end

  @doc """
  Creates a new step for an LLM iteration.

  ## Example

      step = Step.new(1, [
        Swarm.Message.system("You are helpful"),
        Swarm.Message.user("Hello")
      ])
  """
  @spec new(pos_integer(), [Swarm.Message.t()]) :: t()
  def new(number, input_messages) do
    %__MODULE__{
      number: number,
      input_messages: input_messages,
      started_at: DateTime.utc_now()
    }
  end

  @doc "Records the LLM response on this step, including any tool calls."
  @spec record_response(t(), Swarm.LLM.Response.t()) :: t()
  def record_response(%__MODULE__{} = step, %Swarm.LLM.Response{} = response) do
    %{
      step
      | content: response.content,
        reasoning_details: response.reasoning_details,
        usage: response.usage,
        tool_calls: response.tool_calls,
        response_metadata: response.metadata || %{}
    }
  end

  @doc "Returns true if any tool calls are pending (no result yet)."
  @spec has_pending_tools?(t()) :: boolean()
  def has_pending_tools?(%__MODULE__{tool_calls: calls}) do
    Enum.any?(calls, &(not Swarm.ToolCall.completed?(&1)))
  end

  @doc "Returns true if there are tool calls and all have results."
  @spec all_tools_complete?(t()) :: boolean()
  def all_tools_complete?(%__MODULE__{tool_calls: []}), do: true

  def all_tools_complete?(%__MODULE__{tool_calls: calls}) do
    Enum.all?(calls, &Swarm.ToolCall.completed?/1)
  end

  @doc "Adds a result to the tool call with matching ID."
  @spec add_tool_result(t(), Swarm.ToolResult.t()) ::
          {:ok, t()} | {:error, :not_found | :already_completed}
  def add_tool_result(%__MODULE__{tool_calls: calls} = step, %Swarm.ToolResult{id: id} = result) do
    with {:ok, index} <- find_index(calls, id),
         tc = Enum.at(calls, index),
         false <- Swarm.ToolCall.completed?(tc) do
      updated_tc = Swarm.ToolCall.with_result(tc, result)
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
