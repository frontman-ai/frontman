defmodule Swarm.LLM.Chunk do
  @moduledoc """
  Stream chunk from an LLM response.

  Inspired by ReqLLM.StreamChunk but adapted for Swarm's semantic needs.
  This is the primitive type for streaming - Response.t() is built by
  collecting chunks, not the other way around.
  """
  use TypedStruct

  alias Swarm.LLM.Usage
  alias Swarm.ToolCall

  @type chunk_type ::
          :token
          | :thinking
          | :tool_call_end
          | :usage
          | :done

  typedstruct do
    field :type, chunk_type(), enforce: true
    field :text, String.t()
    field :tool_call, ToolCall.t()
    field :usage, Usage.t()
    field :finish_reason, atom()
    field :metadata, map(), default: %{}
  end

  @spec token(String.t(), map()) :: t()
  def token(text, metadata \\ %{}) when is_binary(text) do
    %__MODULE__{type: :token, text: text, metadata: metadata}
  end

  @spec thinking(String.t(), map()) :: t()
  def thinking(text, metadata \\ %{}) when is_binary(text) do
    %__MODULE__{type: :thinking, text: text, metadata: metadata}
  end

  @spec tool_call_end(ToolCall.t(), map()) :: t()
  def tool_call_end(%ToolCall{} = tool_call, metadata \\ %{}) do
    %__MODULE__{type: :tool_call_end, tool_call: tool_call, metadata: metadata}
  end

  @spec usage(Usage.t(), map()) :: t()
  def usage(%Usage{} = usage, metadata \\ %{}) do
    %__MODULE__{type: :usage, usage: usage, metadata: metadata}
  end

  @spec done(atom(), map()) :: t()
  def done(finish_reason, metadata \\ %{}) when is_atom(finish_reason) do
    %__MODULE__{type: :done, finish_reason: finish_reason, metadata: metadata}
  end
end
