defmodule FrontmanServer.Agents.LLMClient do
  @moduledoc """
  Swarm.LLM implementation using ReqLLM.

  Provides non-streaming LLM calls. For streaming, use the `on_llm_call`
  callback in Swarm.run/4 with custom streaming logic.
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
  alias Swarm.LLM.Response, as: SwarmResponse
  alias Swarm.Message
  alias Swarm.Message.ContentPart

  def call(client, messages, _opts) do
    llm_opts = if client.tools != [], do: [tools: client.tools], else: []

    # Convert Swarm.Message to ReqLLM.Message at the boundary
    reqllm_messages = Enum.map(messages, &to_reqllm_message/1)

    case ReqLLM.generate_text(client.model, reqllm_messages, llm_opts) do
      {:ok, response} ->
        {:ok, to_swarm_response(response)}

      {:error, reason} ->
        {:error, reason}
    end
  end

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

  # --- ReqLLM.Response -> Swarm.LLM.Response conversion ---

  defp to_swarm_response(response) do
    %SwarmResponse{
      content: ReqLLM.Response.text(response) || "",
      tool_calls: Enum.map(ReqLLM.Response.tool_calls(response), &to_swarm_tool_call/1),
      finish_reason: response.finish_reason || :stop,
      usage: response.usage,
      raw: response
    }
  end

  defp to_swarm_tool_call(%ReqLLM.ToolCall{} = tc) do
    %Swarm.ToolCall{
      id: tc.id,
      name: tc.function.name,
      arguments: tc.function.arguments
    }
  end

  # Handle map format that might come from some providers
  defp to_swarm_tool_call(%{name: name, arguments: args} = tc) do
    %Swarm.ToolCall{
      id: Map.get(tc, :id) || "call_#{:erlang.unique_integer([:positive])}",
      name: name,
      arguments: if(is_binary(args), do: args, else: Jason.encode!(args))
    }
  end
end
