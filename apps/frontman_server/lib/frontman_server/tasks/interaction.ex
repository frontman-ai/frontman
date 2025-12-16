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
  defp is_conversation_message(_), do: false

  defp to_llm_message(%UserMessage{content_blocks: content_blocks}) do
    # Filter out ContentBlocks with _meta figma_image: true or figma_node: true
    filtered_blocks = Enum.reject(content_blocks, &has_figma_meta?/1)

    # Convert content blocks to LLM message content format
    llm_content = convert_content_blocks_to_llm_format(filtered_blocks)

    # If content is an array (has images), build Message struct manually
    # Otherwise, use ReqLLM.Context.user which handles strings
    case llm_content do
      content when is_list(content) ->
        # Build Message struct with content parts (text + images)
        %ReqLLM.Message{
          role: :user,
          content:
            Enum.map(content, fn
              %{"type" => "text", "text" => text} ->
                ReqLLM.Message.ContentPart.text(text)

              %{"type" => "image", "data" => base64_data, "mimeType" => mime_type} ->
                # Decode base64 data before passing to ContentPart.image/2
                # ContentPart.image expects binary data and will encode it to base64 during JSON encoding
                # Use safe decode64 to avoid crashing on malformed data
                case Base.decode64(base64_data) do
                  {:ok, decoded_data} ->
                    ReqLLM.Message.ContentPart.image(decoded_data, mime_type)

                  :error ->
                    ReqLLM.Message.ContentPart.text("[Invalid image: malformed base64 data]")
                end

              _other ->
                ReqLLM.Message.ContentPart.text("[Unknown content type]")
            end)
        }

      content when is_binary(content) ->
        ReqLLM.Context.user(content)
    end
  end

  defp to_llm_message(%AgentResponse{content: content, metadata: metadata}) do
    tool_calls = Map.get(metadata || %{}, :tool_calls)
    response_id = Map.get(metadata || %{}, :response_id)

    case tool_calls do
      nil ->
        ReqLLM.Context.assistant(content)

      [] ->
        ReqLLM.Context.assistant(content)

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
    # Check if this tool result contains an image that should be sent as image content
    case extract_image_from_result(name, result) do
      {image_binary, mime_type, text_content} ->
        build_tool_message_with_image(name, id, image_binary, mime_type, text_content)

      nil ->
        json_result = if is_binary(result), do: result, else: Jason.encode!(result)
        ReqLLM.Context.tool_result_message(name, id, json_result)
    end
  end

  # Tools that return images: {image_field, extra_text_fields}
  @image_tool_configs %{
    "take_screenshot" => {:screenshot, []},
    "get_figma_node" => {:image, [:node]}
  }

  defp extract_image_from_result(tool_name, result) when is_map(result) do
    with {image_field, text_fields} <- Map.get(@image_tool_configs, tool_name),
         data_url when is_binary(data_url) <- get_field(result, image_field),
         {:ok, binary, mime} <- decode_data_url(data_url) do
      text_content = build_text_content(result, text_fields)
      {binary, mime, text_content}
    else
      _ -> nil
    end
  end

  defp extract_image_from_result(_, _), do: nil

  defp build_tool_message_with_image(name, id, image_binary, mime_type, text_content) do
    content =
      case text_content do
        "" ->
          [ReqLLM.Message.ContentPart.image(image_binary, mime_type)]

        text ->
          [
            ReqLLM.Message.ContentPart.text(text),
            ReqLLM.Message.ContentPart.image(image_binary, mime_type)
          ]
      end

    %ReqLLM.Message{role: :tool, name: name, tool_call_id: id, content: content}
  end

  defp build_text_content(result, fields) do
    text_parts =
      Enum.flat_map(fields, fn field ->
        case get_field(result, field) do
          nil -> []
          value -> [format_field(field, value)]
        end
      end)

    error = get_field(result, :error)
    text_parts = if error, do: text_parts ++ ["Error: #{error}"], else: text_parts

    Enum.join(text_parts, "\n\n")
  end

  defp format_field(:node, value), do: "Node data:\n#{encode_json(value)}"
  defp format_field(field, value), do: "#{field}: #{encode_json(value)}"

  defp encode_json(value) when is_binary(value), do: value
  defp encode_json(value), do: Jason.encode!(value)

  # Get field from map, supporting both string and atom keys
  defp get_field(map, key) when is_atom(key) do
    Map.get(map, Atom.to_string(key)) || Map.get(map, key)
  end

  defp decode_data_url(data_url) do
    with [_, mime_type, base64] <- Regex.run(~r/^data:([^;]+);base64,(.+)$/s, data_url),
         {:ok, binary} <- Base.decode64(base64) do
      {:ok, binary, mime_type}
    else
      _ -> :error
    end
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

      blocks ->
        # Check if we have any image blocks
        image_blocks = Enum.filter(blocks, fn block -> Map.get(block, "type") == "image" end)
        text_blocks = Enum.filter(blocks, fn block -> Map.get(block, "type") == "text" end)

        # If we have images, return array format with both text and images
        if Enum.any?(image_blocks) do
          # Combine text blocks into a single text content
          text_content =
            text_blocks
            |> Enum.map(fn %{"text" => text} -> text end)
            |> Enum.join("")

          # Build content array with text (if any) and images
          content_parts = []

          content_parts =
            if text_content != "",
              do: [%{"type" => "text", "text" => text_content} | content_parts],
              else: content_parts

          content_parts = Enum.reverse(image_blocks) ++ content_parts
          Enum.reverse(content_parts)
        else
          # All blocks are text blocks - concatenate them into a single string
          text_blocks
          |> Enum.map(fn %{"text" => text} -> text end)
          |> Enum.join("")
        end
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

    %{
      "type" => "text",
      "text" => text,
      "cache_control" => %{
        "type" => "ephemeral"
      }
    }
  end

  # Convert resource (embedded JSON or image) to text description
  # New structure: resource is EmbeddedResource containing EmbeddedResourceResource
  defp content_block_to_llm_format(%{"type" => "resource", "resource" => embedded_resource}) do
    case embedded_resource do
      # EmbeddedResource with BlobResourceContents (image)
      %{"resource" => %{"blob" => base64_data, "mimeType" => mime_type}}
      when mime_type in ["image/png", "image/jpeg", "image/gif"] ->
        # For image resources, include as image content part
        %{
          "type" => "image",
          "data" => base64_data,
          "mimeType" => mime_type,
          "cache_control" => %{
            "type" => "ephemeral"
          }
        }

      # EmbeddedResource with TextResourceContents (text/plain for DSL)
      %{"resource" => %{"uri" => uri, "mimeType" => "text/plain", "text" => text}}
      when is_binary(text) ->
        # For Figma node DSL (text/plain), include the DSL as text
        # Check if it's a Figma node URI (figma://node/...)
        dsl_text =
          if String.starts_with?(uri, "figma://node/") do
            "\n\n## Figma Node Structure (DSL)\n\n```\n#{text}\n```"
          else
            "\n\n[Embedded Resource: #{uri}]\n#{text}"
          end

        %{
          "type" => "text",
          "text" => dsl_text,
          "cache_control" => %{
            "type" => "ephemeral"
          }
        }

      # EmbeddedResource with TextResourceContents (application/json)
      %{"resource" => %{"uri" => uri, "mimeType" => "application/json", "text" => text}} ->
        # For Figma nodes or other JSON resources, include the data as text
        %{
          "type" => "text",
          "text" => "\n\n[Embedded Resource: #{uri}]\n#{text}",
          "cache_control" => %{
            "type" => "ephemeral"
          },
          "annotations" => [
            %{
              "usage" => """
              ## Figma Node DSL Format

              When you receive Figma design context, it will be in a compact DSL format optimized for understanding UI structure.

              ### Syntax

              node-name(v:N) #ID:
                child-name #ID
                icon:type #ID
                +N more item-name

              ### Key elements:

              - **`node-name`** — Normalized component/layer name (lowercase, hyphenated)
              - **`(v:N)`** — Volume indicator (1-10 scale of complexity/token count). Higher = more content
              - **`#ID`** — Figma node ID (e.g., `#0:1927`). Use with `get_figma_node` tool to fetch full details
              - **`:`** after a node — Indicates it has children (indented below)
              - **`icon:type`** — Normalized icon reference (e.g., `icon:check`, `icon:arrow`)
              - **`+N more name`** — N additional items with identical structure (template pattern)
              - **`(N)`** — N homogeneous children collapsed (e.g., `list-item(5)` = 5 identical items)

              ### Volume scale:

              v:1-3 = Small/simple, v:4-6 = Medium complexity, v:7-10 = Large/complex

              ### Reading strategy:

              1. Start with high-level structure (root nodes that are not with large/complex volume)
              2. For large/complex nodes (v:7+), use `breakdown_figma_node` to get a component todo list
              3. Use `get_figma_node` tool on specific node IDs to fetch full Tailwind/styling details
              4. Collapsed nodes (no `:`) contain implementation details you can expand on-demand
              """
            }
          ]
        }

      _ ->
        nil
    end
  end

  # Skip unknown block types
  defp content_block_to_llm_format(_), do: nil

  @doc """
  Checks if any user messages in the interactions contain Figma context.
  Returns true if there's a content block with figma_image or figma_node metadata.
  """
  @spec has_figma_context?(list(t())) :: boolean()
  def has_figma_context?(interactions) do
    interactions
    |> Enum.any?(fn
      %UserMessage{content_blocks: content_blocks} ->
        Enum.any?(content_blocks, &has_figma_meta?/1)

      _ ->
        false
    end)
  end

  # Helper to check if a ContentBlock has _meta with figma_image or figma_node set to true
  defp has_figma_meta?(content_block) do
    # Check _meta on embedded resource if it's a resource block
    # _meta is stored on the embedded_resource, not directly on the ContentBlock
    case Map.get(content_block, "resource") do
      %{"_meta" => meta} when is_map(meta) ->
        Map.get(meta, "figma_image") == true || Map.get(meta, "figma_node") == true

      # Fallback: check URI patterns for backward compatibility
      %{"resource" => %{"uri" => uri}} when is_binary(uri) ->
        String.starts_with?(uri, "figma://node/")

      _ ->
        false
    end
  rescue
    _ -> false
  end
end
