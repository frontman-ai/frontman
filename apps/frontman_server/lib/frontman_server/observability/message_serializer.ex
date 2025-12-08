defmodule FrontmanServer.Observability.MessageSerializer do
  @moduledoc """
  Serializes ReqLLM messages to OpenTelemetry GenAI format.

  Follows OTel GenAI semantic conventions for message structure:
  - Input messages: Array of {role, content} pairs
  - Output messages: Assistant response with tool_calls if present
  """

  alias ReqLLM.ToolCall

  @doc """
  Serializes input messages to OTel GenAI format.

  Returns a list of maps with "role" and "content" keys.
  """
  @spec serialize_input(list()) :: list(map())
  def serialize_input(messages) when is_list(messages) do
    Enum.map(messages, &serialize_message/1)
  end

  @doc """
  Serializes output (assistant response) to OTel GenAI format.

  Includes tool_calls when present.
  """
  @spec serialize_output(String.t(), list()) :: list(map())
  def serialize_output(text, tool_calls) when is_binary(text) and is_list(tool_calls) do
    base = %{"role" => "assistant", "content" => text}

    case tool_calls do
      [] ->
        [base]
      tool_calls ->
        [Map.put(base, "tool_calls", Enum.map(tool_calls, &serialize_tool_call/1))]
    end
  end

  # ReqLLM.ToolCall struct from production LLM responses
  defp serialize_tool_call(%ReqLLM.ToolCall{} = tc) do
    %{
      "id" => tc.id,
      "type" => "function",
      "function" => %{
        "name" => ToolCall.name(tc),
        "arguments" => ToolCall.args_json(tc)
      }
    }
  end

  # Plain map format (for tests or other internal uses)
  defp serialize_tool_call(%{id: id, tool_name: name, arguments: arguments}) do
    %{
      "id" => id,
      "type" => "function",
      "function" => %{
        "name" => name,
        "arguments" => encode_if_needed(arguments)
      }
    }
  end

  # Crashing here is intentional: if arguments can't be JSON-encoded, we have
  # a bug in our tool call construction. Better to fail loudly than emit
  # malformed telemetry that silently corrupts our observability data.
  defp encode_if_needed(arguments) when is_binary(arguments), do: arguments
  defp encode_if_needed(arguments), do: Jason.encode!(arguments)

  # Serialize different message formats

  defp serialize_message(%ReqLLM.Message{role: role, content: content}) do
    %{
      "role" => to_string(role),
      "content" => serialize_content(content)
    }
  end

  defp serialize_message(%{role: role, content: content}) do
    %{
      "role" => to_string(role),
      "content" => serialize_content(content)
    }
  end

  # String-keyed maps (from external JSON sources)
  defp serialize_message(%{"role" => role, "content" => content}) do
    %{
      "role" => to_string(role),
      "content" => serialize_content(content)
    }
  end

  # Serialize content (can be string or list of content parts)

  defp serialize_content(content) when is_binary(content), do: content

  defp serialize_content(content) when is_list(content) do
    content
    |> Enum.map(&serialize_content_part/1)
    |> Enum.join("\n")
  end

  defp serialize_content(nil), do: ""

  defp serialize_content_part(%ReqLLM.Message.ContentPart{type: :text, text: text}), do: text
  defp serialize_content_part(%{type: :text, text: text}), do: text
  defp serialize_content_part(%{"type" => "text", "text" => text}), do: text
  defp serialize_content_part(_), do: "[non-text content]"
end
