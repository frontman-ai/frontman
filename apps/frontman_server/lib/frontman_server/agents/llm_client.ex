defmodule FrontmanServer.Agents.LLMClient do
  @moduledoc """
  Swarm.LLM implementation using ReqLLM.

  Stream-first design: returns a lazy stream of chunks that can be
  consumed with callbacks or collected into a Response.
  """

  use TypedStruct

  typedstruct do
    field :model, String.t(), default: "anthropic:claude-sonnet-4-20250514"
    field :tools, [ReqLLM.Tool.t()], default: []
  end

  @doc """
  Creates a new LLMClient.

  ## Options

  - `:model` - Model spec string (default: "anthropic:claude-sonnet-4-20250514")
  - `:tools` - List of ReqLLM.Tool structs
  """
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end
end

defimpl Swarm.LLM, for: FrontmanServer.Agents.LLMClient do
  alias Swarm.LLM.{Chunk, Usage}
  alias Swarm.Message
  alias Swarm.Message.ContentPart
  alias Swarm.ToolCall

  def stream(client, messages, _opts) do
    llm_opts = if client.tools != [], do: [tools: client.tools], else: []
    reqllm_messages = Enum.map(messages, &to_reqllm_message/1)

    case ReqLLM.stream_text(client.model, reqllm_messages, llm_opts) do
      {:ok, response} ->
        swarm_stream =
          response.stream
          |> Stream.map(&to_swarm_chunk/1)
          |> Stream.reject(&is_nil/1)

        {:ok, swarm_stream}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_swarm_chunk(%{type: :content, text: text}) when is_binary(text) do
    Chunk.token(text)
  end

  defp to_swarm_chunk(%{type: :thinking, text: text}) when is_binary(text) do
    Chunk.thinking(text)
  end

  defp to_swarm_chunk(%{type: :tool_call, name: name, arguments: args, metadata: meta}) do
    id = Map.get(meta, :id) || "call_#{:erlang.unique_integer([:positive])}"
    args_json = if is_binary(args), do: args, else: Jason.encode!(args || %{})
    tool_call = %ToolCall{id: id, name: name, arguments: args_json}
    Chunk.tool_call_end(tool_call)
  end

  defp to_swarm_chunk(%{type: :meta, metadata: %{tool_call_args: %{index: _, fragment: _}}}) do
    # Argument fragments require an ID to associate with tool_call_start.
    # ReqLLM sends complete tool_calls, so we skip fragments for now.
    nil
  end

  defp to_swarm_chunk(%{type: :meta, metadata: %{usage: usage}}) when is_map(usage) do
    Chunk.usage(%Usage{
      input_tokens: Map.get(usage, :input_tokens, 0),
      output_tokens: Map.get(usage, :output_tokens, 0)
    })
  end

  defp to_swarm_chunk(%{type: :meta, metadata: %{finish_reason: reason}}) do
    Chunk.done(reason)
  end

  defp to_swarm_chunk(_), do: nil

  # --- Swarm.Message -> ReqLLM.Message conversion ---

  defp to_reqllm_message(%Message{} = msg) do
    %ReqLLM.Message{
      role: msg.role,
      content: Enum.map(msg.content, &to_reqllm_content_part/1),
      tool_calls: to_reqllm_tool_calls(msg.tool_calls),
      tool_call_id: msg.tool_call_id,
      name: msg.name
    }
  end

  defp to_reqllm_content_part(%ContentPart{type: :text, text: text}) do
    ReqLLM.Message.ContentPart.text(text)
  end

  defp to_reqllm_content_part(%ContentPart{type: :image, data: data, media_type: mt}) do
    ReqLLM.Message.ContentPart.image(data, mt)
  end

  defp to_reqllm_content_part(%ContentPart{type: :image_url, url: url}) do
    ReqLLM.Message.ContentPart.image_url(url)
  end

  defp to_reqllm_tool_calls([]), do: nil
  defp to_reqllm_tool_calls(nil), do: nil

  defp to_reqllm_tool_calls(tool_calls) do
    Enum.map(tool_calls, fn tc ->
      ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
    end)
  end
end
