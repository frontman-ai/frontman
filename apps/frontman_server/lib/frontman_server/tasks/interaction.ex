defmodule FrontmanServer.Tasks.Interaction do
  @moduledoc """
  Domain interaction types for the LLM agent system.

  Interactions represent domain events that occur during a task's lifecycle.
  These are stored as the source of truth, while streaming tokens are ephemeral
  transport mechanisms for real-time UX.
  """

  @type t ::
          __MODULE__.UserMessage.t()
          | __MODULE__.AgentResponse.t()
          | __MODULE__.AgentSpawned.t()
          | __MODULE__.AgentCompleted.t()
          | __MODULE__.ToolCall.t()
          | __MODULE__.ToolResult.t()
          | __MODULE__.SubAgentSpawned.t()
          | __MODULE__.SubAgentResult.t()
          | __MODULE__.SubAgentFailed.t()
          | __MODULE__.SubAgentSpawnFailed.t()

  defmodule UserMessage do
    @moduledoc """
    Represents a message sent by the user.

    Uses content blocks as the single source of truth for message content.
    The first ContentBlock is typically type="text" with the user's message.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:timestamp, DateTime.t())
      field(:metadata, map(), enforce: false)
      # Content blocks from the prompt (includes text, resource_link, resource)
      field(:content_blocks, list())
    end

    def new(content_blocks, metadata \\ %{}) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        timestamp: Interaction.now(),
        metadata: metadata,
        content_blocks: content_blocks
      }
    end
  end

  defimpl Jason.Encoder, for: UserMessage do
    def encode(value, opts) do
      # Extract text content from content_blocks for backward compatibility
      content =
        value.content_blocks
        |> Enum.find(fn block -> Map.get(block, "type") == "text" end)
        |> case do
          nil -> ""
          block -> Map.get(block, "text", "")
        end

      Jason.Encode.map(
        %{
          type: "user_message",
          id: value.id,
          content: content,
          timestamp: DateTime.to_iso8601(value.timestamp),
          metadata: value.metadata
        },
        opts
      )
    end
  end

  defmodule AgentResponse do
    @moduledoc """
    Represents a complete response from an agent.

    This is the final, stored interaction after streaming is complete.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:agent_id, String.t())
      field(:content, String.t())
      field(:timestamp, DateTime.t())
      field(:metadata, map(), enforce: false)
    end

    def new(agent_id, content, metadata \\ %{}) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        agent_id: agent_id,
        content: content,
        timestamp: Interaction.now(),
        metadata: metadata
      }
    end
  end

  defimpl Jason.Encoder, for: AgentResponse do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "agent_response",
          id: value.id,
          agent_id: value.agent_id,
          content: value.content,
          timestamp: DateTime.to_iso8601(value.timestamp),
          metadata: value.metadata
        },
        opts
      )
    end
  end

  defmodule AgentSpawned do
    @moduledoc """
    Represents the creation of a new agent (including sub-agents).
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:agent_id, String.t())
      field(:config, map(), enforce: false)
      field(:parent_agent_id, String.t() | nil, enforce: false)
      field(:timestamp, DateTime.t())
    end

    def new(agent_id, config \\ %{}) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        agent_id: agent_id,
        config: config,
        timestamp: Interaction.now()
      }
    end
  end

  defimpl Jason.Encoder, for: AgentSpawned do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "agent_spawned",
          id: value.id,
          agent_id: value.agent_id,
          config: value.config,
          parent_agent_id: value.parent_agent_id,
          timestamp: DateTime.to_iso8601(value.timestamp)
        },
        opts
      )
    end
  end

  defmodule AgentCompleted do
    @moduledoc """
    Represents an agent finishing its work.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:agent_id, String.t())
      field(:timestamp, DateTime.t())
      field(:result, term(), enforce: false)
    end

    def new(agent_id, result \\ nil) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        agent_id: agent_id,
        timestamp: Interaction.now(),
        result: result
      }
    end
  end

  defimpl Jason.Encoder, for: AgentCompleted do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "agent_completed",
          id: value.id,
          agent_id: value.agent_id,
          timestamp: DateTime.to_iso8601(value.timestamp),
          result: value.result
        },
        opts
      )
    end
  end

  defmodule ToolCall do
    @moduledoc """
    Represents an LLM requesting a tool execution.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:agent_id, String.t())
      field(:tool_call_id, String.t())
      field(:tool_name, String.t())
      field(:arguments, map())
      field(:timestamp, DateTime.t())
    end

    def new(agent_id, %ReqLLM.ToolCall{} = tc) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        agent_id: agent_id,
        tool_call_id: tc.id,
        tool_name: ReqLLM.ToolCall.name(tc),
        arguments: ReqLLM.ToolCall.args_map(tc) || %{},
        timestamp: Interaction.now()
      }
    end
  end

  defimpl Jason.Encoder, for: ToolCall do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "tool_call",
          id: value.id,
          agent_id: value.agent_id,
          tool_call_id: value.tool_call_id,
          tool_name: value.tool_name,
          arguments: value.arguments,
          timestamp: DateTime.to_iso8601(value.timestamp)
        },
        opts
      )
    end
  end

  defmodule ToolResult do
    @moduledoc """
    Represents the result of a tool execution.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:agent_id, String.t())
      field(:tool_call_id, String.t())
      field(:tool_name, String.t())
      field(:result, term())
      field(:is_error, boolean(), default: false)
      field(:timestamp, DateTime.t())
    end

    def new(agent_id, tool_call_data, result, is_error \\ false) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        agent_id: agent_id,
        tool_call_id: tool_call_data.id,
        tool_name: tool_call_data.name,
        result: result,
        is_error: is_error,
        timestamp: Interaction.now()
      }
    end
  end

  defimpl Jason.Encoder, for: ToolResult do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "tool_result",
          id: value.id,
          agent_id: value.agent_id,
          tool_call_id: value.tool_call_id,
          tool_name: value.tool_name,
          result: value.result,
          is_error: value.is_error,
          timestamp: DateTime.to_iso8601(value.timestamp)
        },
        opts
      )
    end
  end

  defmodule SubAgentSpawned do
    @moduledoc "Interaction recording when a sub-agent is spawned"
    use TypedStruct

    @derive Jason.Encoder
    typedstruct enforce: true do
      field(:id, String.t())
      field(:agent_id, String.t())
      field(:sub_agent_id, String.t())
      field(:agent_key, atom())
      field(:message, String.t())
      field(:timestamp, DateTime.t())
    end

    def new(agent_id, sub_agent_id, agent_key, message) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        agent_id: agent_id,
        sub_agent_id: sub_agent_id,
        agent_key: agent_key,
        message: message,
        timestamp: Interaction.now()
      }
    end
  end

  defimpl Jason.Encoder, for: SubAgentSpawned do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "sub_agent_spawned",
          id: value.id,
          agent_id: value.agent_id,
          sub_agent_id: value.sub_agent_id,
          agent_key: value.agent_key,
          message: value.message,
          timestamp: DateTime.to_iso8601(value.timestamp)
        },
        opts
      )
    end
  end

  defmodule SubAgentResult do
    @moduledoc "Interaction recording a sub-agent's successful result"
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:agent_id, String.t())
      field(:sub_agent_id, String.t())
      field(:tool_call_id, String.t())
      field(:agent_key, atom())
      field(:message, String.t())
      field(:result, String.t())
      field(:partial, boolean(), default: false)
      field(:iterations, integer())
      field(:duration_ms, integer())
      field(:timestamp, DateTime.t())
    end

    def new(
          agent_id,
          sub_agent_id,
          tool_call_id,
          agent_key,
          message,
          result,
          iterations,
          duration_ms,
          partial \\ false
        ) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        agent_id: agent_id,
        sub_agent_id: sub_agent_id,
        tool_call_id: tool_call_id,
        agent_key: agent_key,
        message: message,
        result: result,
        partial: partial,
        iterations: iterations,
        duration_ms: duration_ms,
        timestamp: Interaction.now()
      }
    end
  end

  defimpl Jason.Encoder, for: SubAgentResult do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "sub_agent_result",
          id: value.id,
          agent_id: value.agent_id,
          sub_agent_id: value.sub_agent_id,
          tool_call_id: value.tool_call_id,
          agent_key: value.agent_key,
          message: value.message,
          result: value.result,
          partial: value.partial,
          iterations: value.iterations,
          duration_ms: value.duration_ms,
          timestamp: DateTime.to_iso8601(value.timestamp)
        },
        opts
      )
    end
  end

  defmodule SubAgentFailed do
    @moduledoc "Interaction recording a sub-agent's failure"
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:agent_id, String.t())
      field(:sub_agent_id, String.t())
      field(:agent_key, atom())
      field(:message, String.t())
      field(:error, String.t())
      field(:partial_result, String.t() | nil, enforce: false)
      field(:iterations, integer())
      field(:duration_ms, integer())
      field(:timestamp, DateTime.t())
    end

    def new(
          agent_id,
          sub_agent_id,
          agent_key,
          message,
          error,
          iterations,
          duration_ms,
          partial_result \\ nil
        ) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        agent_id: agent_id,
        sub_agent_id: sub_agent_id,
        agent_key: agent_key,
        message: message,
        error: error,
        partial_result: partial_result,
        iterations: iterations,
        duration_ms: duration_ms,
        timestamp: Interaction.now()
      }
    end
  end

  defimpl Jason.Encoder, for: SubAgentFailed do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "sub_agent_failed",
          id: value.id,
          agent_id: value.agent_id,
          sub_agent_id: value.sub_agent_id,
          agent_key: value.agent_key,
          message: value.message,
          error: value.error,
          partial_result: value.partial_result,
          iterations: value.iterations,
          duration_ms: value.duration_ms,
          timestamp: DateTime.to_iso8601(value.timestamp)
        },
        opts
      )
    end
  end

  defmodule SubAgentSpawnFailed do
    @moduledoc "Interaction recording when a sub-agent fails to spawn"
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:agent_id, String.t())
      field(:tool_call_id, String.t())
      field(:agent_key, atom())
      field(:message, String.t())
      field(:error, String.t())
      field(:timestamp, DateTime.t())
    end

    def new(agent_id, tool_call_id, agent_key, message, error) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        agent_id: agent_id,
        tool_call_id: tool_call_id,
        agent_key: agent_key,
        message: message,
        error: error,
        timestamp: Interaction.now()
      }
    end
  end

  defimpl Jason.Encoder, for: SubAgentSpawnFailed do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "sub_agent_spawn_failed",
          id: value.id,
          agent_id: value.agent_id,
          tool_call_id: value.tool_call_id,
          agent_key: value.agent_key,
          message: value.message,
          error: value.error,
          timestamp: DateTime.to_iso8601(value.timestamp)
        },
        opts
      )
    end
  end

  @doc """
  Generates a new interaction ID (UUID v4).
  """
  def new_id do
    Ecto.UUID.generate()
  end

  @doc """
  Returns the current timestamp.
  """
  def now do
    DateTime.utc_now()
  end

  @doc """
  Checks if an interaction is a user message.
  """
  @spec user_message?(t()) :: boolean()
  def user_message?(%UserMessage{}), do: true
  def user_message?(_), do: false

  @doc """
  Converts interactions to LLM message format.

  This is the boundary translation from Tasks domain (Interactions)
  to Agents domain (LLM messages). Conversation messages include
  UserMessage, AgentResponse, and ToolResult.
  ToolCall interactions are excluded as they're embedded in AgentResponse metadata.
  """
  @spec to_llm_messages(list(t())) :: list(map())
  def to_llm_messages(interactions) do
    interactions
    |> Enum.filter(&is_conversation_message/1)
    |> Enum.map(&to_llm_message/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Converts interactions to LLM messages, filtering by agent_id.

  Only includes interactions that belong to the specified agent.
  UserMessage is always included (it has no agent_id).
  """
  @spec to_llm_messages(list(t()), String.t()) :: list(map())
  def to_llm_messages(interactions, agent_id) when is_binary(agent_id) do
    interactions
    |> Enum.filter(&(is_conversation_message(&1) and belongs_to_agent?(&1, agent_id)))
    |> Enum.map(&to_llm_message/1)
    |> Enum.reject(&is_nil/1)
  end

  defp belongs_to_agent?(%UserMessage{}, _agent_id), do: true
  defp belongs_to_agent?(%{agent_id: id}, agent_id), do: id == agent_id
  defp belongs_to_agent?(_, _agent_id), do: false

  defp is_conversation_message(%UserMessage{}), do: true
  defp is_conversation_message(%AgentResponse{}), do: true
  # ToolCall is skipped - it's embedded in AgentResponse metadata
  defp is_conversation_message(%ToolResult{}), do: true
  defp is_conversation_message(%SubAgentResult{}), do: true
  defp is_conversation_message(_), do: false

  defp to_llm_message(%UserMessage{content_blocks: content_blocks}) do
    # Convert content blocks to LLM message content format
    llm_content = convert_content_blocks_to_llm_format(content_blocks)
    ReqLLM.Context.user(llm_content)
  end

  defp to_llm_message(%AgentResponse{content: content, metadata: metadata}) do
    tool_calls = Map.get(metadata || %{}, :tool_calls)
    response_id = Map.get(metadata || %{}, :response_id)

    case tool_calls do
      nil -> ReqLLM.Context.assistant(content)
      [] -> ReqLLM.Context.assistant(content)
      tool_calls ->
        # Build Message struct with metadata for OpenAI Responses API (previous_response_id)
        %ReqLLM.Message{
          role: :assistant,
          content: [ReqLLM.Message.ContentPart.text(content)],
          tool_calls: tool_calls,
          metadata: if(response_id, do: %{response_id: response_id}, else: %{})
        }
    end
  end

  defp to_llm_message(%ToolCall{}) do
    # Tool calls are embedded in AgentResponse metadata, skip standalone
    nil
  end

  defp to_llm_message(%ToolResult{tool_name: name, tool_call_id: id, result: result}) do
    # Serialize structured data to JSON for LLM projection
    json_result = if is_binary(result), do: result, else: Jason.encode!(result)
    ReqLLM.Context.tool_result_message(name, id, json_result)
  end

  defp to_llm_message(%SubAgentResult{tool_call_id: id, agent_key: role, message: message, result: result}) do
    # Format sub-agent result as tool result for spawn_sub_agent call
    content = """
    Sub-agent (#{role}) completed message: "#{message}"

    Result:
    #{result}
    """

    ReqLLM.Context.tool_result_message("spawn_sub_agent", id, content)
  end

  # Convert content blocks to LLM message content format
  defp convert_content_blocks_to_llm_format(blocks) do
    content =
      blocks
      |> Enum.map(&content_block_to_llm_format/1)
      |> Enum.reject(&is_nil/1)

    case content do
      [] ->
        ""

      text_blocks ->
        # All blocks are now text blocks - concatenate them into a single string
        text_blocks
        |> Enum.map(fn %{"text" => text} -> text end)
        |> Enum.join("")
    end
  end

  # Convert text block
  defp content_block_to_llm_format(%{"type" => "text", "text" => text}) do
    %{"type" => "text", "text" => text}
  end

  # Convert resource_link (file reference) to text description
  defp content_block_to_llm_format(%{"type" => "resource_link", "uri" => uri}) do
    # Extract file path from URI (format: file://path:line:column)
    text =
      case Regex.run(~r/^file:\/\/(.+):(\d+):(\d+)$/, uri) do
        [_, file_path, line, column] ->
          "\n\n[Selected Component Location]\nFile: #{file_path}\nLine: #{line}, Column: #{column}"

        _ ->
          "\n\n[Selected Component]\nURI: #{uri}"
      end

    %{"type" => "text", "text" => text}
  end

  # Convert resource (embedded JSON) to text description
  defp content_block_to_llm_format(%{"type" => "resource", "resource" => resource}) do
    case resource do
      %{"uri" => uri, "mimeType" => _mime_type, "text" => text} ->
        # For Figma nodes or other resources, include the data as text
        %{
          "type" => "text",
          "text" => "\n\n[Embedded Resource: #{uri}]\n#{text}"
        }

      _ ->
        nil
    end
  end

  # Skip unknown block types
  defp content_block_to_llm_format(_), do: nil
end
