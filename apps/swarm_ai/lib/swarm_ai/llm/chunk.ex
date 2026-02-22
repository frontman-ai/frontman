defmodule SwarmAi.LLM.Chunk do
  @moduledoc """
  Stream chunk from an LLM response.

  Inspired by ReqLLM.StreamChunk but adapted for Swarm's semantic needs.
  This is the primitive type for streaming - Response.t() is built by
  collecting chunks, not the other way around.
  """
  use TypedStruct

  alias SwarmAi.LLM.Usage
  alias SwarmAi.ToolCall

  @type chunk_type ::
          :token
          | :thinking
          | :tool_call_start
          | :tool_call_args
          | :tool_call_end
          | :usage
          | :done

  typedstruct do
    field(:type, chunk_type(), enforce: true)
    field(:text, String.t())
    # For complete tool calls (non-streaming or accumulated externally)
    field(:tool_call, ToolCall.t())
    # For streaming tool calls - id and name arrive first
    field(:tool_call_id, String.t())
    field(:tool_call_name, String.t())
    # For streaming tool calls - argument fragments arrive separately
    field(:tool_call_args_fragment, String.t())
    field(:tool_call_index, integer())
    field(:usage, Usage.t())
    field(:finish_reason, atom())
    field(:metadata, map(), default: %{})
  end

  @doc "Creates a text token chunk from LLM output."
  @spec token(String.t(), map()) :: t()
  def token(text, metadata \\ %{}) when is_binary(text) do
    %__MODULE__{type: :token, text: text, metadata: metadata}
  end

  @doc "Creates a thinking/reasoning chunk (e.g., from chain-of-thought models)."
  @spec thinking(String.t(), map()) :: t()
  def thinking(text, metadata \\ %{}) when is_binary(text) do
    %__MODULE__{type: :thinking, text: text, metadata: metadata}
  end

  @doc """
  Creates a tool_call_start chunk when a tool call name is received (streaming).

  This signals the beginning of a tool call. Arguments may arrive in subsequent
  `:tool_call_args` chunks that need to be accumulated.
  """
  @spec tool_call_start(String.t(), String.t(), integer(), map()) :: t()
  def tool_call_start(id, name, index \\ 0, metadata \\ %{})
      when is_binary(id) and is_binary(name) do
    %__MODULE__{
      type: :tool_call_start,
      tool_call_id: id,
      tool_call_name: name,
      tool_call_index: index,
      metadata: metadata
    }
  end

  @doc """
  Creates a tool_call_args chunk for argument fragments (streaming).

  These fragments need to be accumulated and parsed as JSON when the
  tool call is complete.
  """
  @spec tool_call_args(integer(), String.t(), map()) :: t()
  def tool_call_args(index, fragment, metadata \\ %{})
      when is_integer(index) and is_binary(fragment) do
    %__MODULE__{
      type: :tool_call_args,
      tool_call_index: index,
      tool_call_args_fragment: fragment,
      metadata: metadata
    }
  end

  @doc """
  Creates a tool_call_end chunk with a complete tool call.

  Used when the tool call arrives complete (non-streaming) or after
  external accumulation.
  """
  @spec tool_call_end(ToolCall.t(), map()) :: t()
  def tool_call_end(%ToolCall{} = tool_call, metadata \\ %{}) do
    %__MODULE__{type: :tool_call_end, tool_call: tool_call, metadata: metadata}
  end

  @doc "Creates a token usage chunk with input/output token counts."
  @spec usage(Usage.t(), map()) :: t()
  def usage(%Usage{} = usage, metadata \\ %{}) do
    %__MODULE__{type: :usage, usage: usage, metadata: metadata}
  end

  @doc "Creates a done chunk signaling the end of the stream."
  @spec done(atom(), map()) :: t()
  def done(finish_reason, metadata \\ %{}) when is_atom(finish_reason) do
    %__MODULE__{type: :done, finish_reason: finish_reason, metadata: metadata}
  end
end
