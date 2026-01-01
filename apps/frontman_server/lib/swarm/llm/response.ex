defmodule Swarm.LLM.Response do
  @moduledoc """
  Normalized response from an LLM call.

  Adapters convert provider-specific responses to this canonical format.
  """
  use TypedStruct

  alias Swarm.LLM.Usage

  @type finish_reason :: :stop | :tool_calls | :length | :error | nil

  typedstruct do
    field :content, String.t()
    field :finish_reason, finish_reason(), default: :stop
    field :tool_calls, [Swarm.ToolCall.t()], default: []
    field :usage, Usage.t()
    field :raw, term()
  end

  @doc """
  Returns true if the response contains tool calls.
  """
  @spec has_tool_calls?(t()) :: boolean()
  def has_tool_calls?(%__MODULE__{tool_calls: []}), do: false
  def has_tool_calls?(%__MODULE__{tool_calls: _}), do: true
end
