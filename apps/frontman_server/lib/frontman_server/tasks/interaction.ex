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
          | __MODULE__.DiscoveredProjectRule.t()

  defmodule FigmaNode do
    @moduledoc """
    Represents a selected Figma node with its associated data.

    Contains:
    - `id` - the Figma node ID extracted from the resource URI (e.g., "123:456")
    - `node` - the DSL text representation OR full node JSON data
    - `image` - base64 encoded screenshot of the Figma node
    - `is_dsl` - true if `node` contains DSL text, false if it contains full node JSON data

    When `is_dsl` is true:
    - The `node` field contains a compact DSL text representation for design breakdown
    - Used by `breakdown_figma_design` tool to analyze design structure

    When `is_dsl` is false:
    - The `node` field contains full JSON node data from get_figma_node
    - Used by `implement_component`, `finish_component`, etc. for detailed implementation
    """
    use TypedStruct

    typedstruct enforce: true do
      # The Figma node ID extracted from the resource URI (e.g., "123:456")
      field(:id, String.t())
      # DSL text representation OR full JSON node data (depending on is_dsl)
      field(:node, String.t() | nil, enforce: false)
      # Base64 encoded PNG image of the node
      field(:image, String.t() | nil, enforce: false)
      # True if node contains DSL text, false if it contains full JSON data
      field(:is_dsl, boolean(), default: true)
    end
  end

  defmodule UserMessage do
    @moduledoc """
    Represents a message sent by the user.

    All fields are extracted from content blocks at creation time:
    - `messages` - array of text messages from the user
    - `selected_component` - source location of selected element
    - `selected_component_screenshot` - screenshot of selected element
    - `selected_figma_node` - structured Figma node data (id, node DSL, image)
    """
    use TypedStruct

    alias FrontmanServer.Tasks.Interaction.FigmaNode

    @type selected_component :: %{
            file: String.t(),
            line: integer(),
            column: integer()
          }

    typedstruct enforce: true do
      field(:id, String.t())
      field(:timestamp, DateTime.t())
      # Text messages from the user (extracted from text content blocks)
      field(:messages, list(String.t()), default: [])
      # Extracted source location from resource with _meta.selected_component
      field(:selected_component, selected_component() | nil, enforce: false)

      # Extracted screenshot (base64 PNG data) from resource with _meta.selected_component_screenshot
      field(:selected_component_screenshot, String.t() | nil, enforce: false)
      # Extracted Figma node with id, node data (DSL or full JSON), and image
      field(:selected_figma_node, FigmaNode.t() | nil, enforce: false)
    end

    def new(content_blocks) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        timestamp: Interaction.now(),
        messages: extract_messages(content_blocks),
        selected_component: extract_selected_component(content_blocks),
        selected_component_screenshot: extract_selected_component_screenshot(content_blocks),
        selected_figma_node: extract_selected_figma_node(content_blocks)
      }
    end

    # Extract text messages from content blocks
    defp extract_messages(content_blocks) do
      content_blocks
      |> Enum.filter(&match?(%{"type" => "text"}, &1))
      |> Enum.map(&Map.get(&1, "text", ""))
      |> Enum.reject(&(&1 == ""))
    end

    # Extract selected component from content blocks
    # Looks for _meta.selected_component with structured data
    defp extract_selected_component(content_blocks) do
      Enum.find_value(content_blocks, fn
        %{
          "type" => "resource",
          "resource" => %{"_meta" => %{"selected_component" => true} = meta}
        } ->
          file = Map.get(meta, "file")
          line = Map.get(meta, "line")
          column = Map.get(meta, "column")

          if is_binary(file) and is_integer(line) and is_integer(column) do
            %{file: file, line: line, column: column}
          else
            nil
          end

        _ ->
          nil
      end)
    end

    # Extract selected component screenshot from content blocks
    # Looks for _meta.selected_component_screenshot with blob data
    defp extract_selected_component_screenshot(content_blocks) do
      content_blocks
      |> Enum.find_value(fn
        %{"type" => "resource", "resource" => resource} ->
          case resource do
            %{
              "_meta" => %{"selected_component_screenshot" => true},
              "resource" => %{"blob" => blob}
            }
            when is_binary(blob) ->
              blob

            _ ->
              nil
          end

        _ ->
          nil
      end)
    end

    # Extract Figma node data from content blocks
    # Combines figma_node (DSL text or full JSON) and figma_image (blob) into FigmaNode
    # The node_id and is_dsl flag are extracted from _meta
    defp extract_selected_figma_node(content_blocks) do
      Enum.find_value(content_blocks, fn
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"figma_node" => true, "node_id" => node_id} = meta,
            "resource" => %{"text" => text}
          }
        }
        when is_binary(text) and is_binary(node_id) ->
          is_dsl = Map.get(meta, "is_dsl", true)

          %FigmaNode{
            id: node_id,
            node: text,
            image: extract_figma_image_blob(content_blocks),
            is_dsl: is_dsl
          }

        _ ->
          nil
      end)
    end

    # Extract Figma image blob from content blocks
    defp extract_figma_image_blob(content_blocks) do
      Enum.find_value(content_blocks, fn
        %{"type" => "resource", "resource" => resource} ->
          case resource do
            %{"_meta" => %{"figma_image" => true}, "resource" => %{"blob" => blob}}
            when is_binary(blob) ->
              blob

            _ ->
              nil
          end

        _ ->
          nil
      end)
    end
  end

  defimpl Jason.Encoder, for: UserMessage do
    def encode(value, opts) do
      selected_figma_node =
        case value.selected_figma_node do
          nil ->
            nil

          %{id: id, node: node, image: image, is_dsl: is_dsl} ->
            %{
              id: id,
              has_node: node != nil,
              has_image: image != nil,
              is_dsl: is_dsl
            }
        end

      Jason.Encode.map(
        %{
          type: "user_message",
          id: value.id,
          messages: value.messages,
          timestamp: DateTime.to_iso8601(value.timestamp),
          selected_component: value.selected_component,
          selected_component_screenshot: value.selected_component_screenshot != nil,
          selected_figma_node: selected_figma_node
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

  defmodule DiscoveredProjectRule do
    @moduledoc """
    Represents a discovered project rule file (e.g., AGENTS.md, CLAUDE.md).

    These are task-scoped (not agent-scoped) and accumulate as the agent
    explores the codebase. They are injected into LLM messages as context.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:path, String.t())
      field(:content, String.t())
      field(:timestamp, DateTime.t())
    end

    def new(path, content) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        path: path,
        content: content,
        timestamp: Interaction.now()
      }
    end
  end

  defimpl Jason.Encoder, for: DiscoveredProjectRule do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "discovered_project_rule",
          path: value.path,
          content: value.content,
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
  # DiscoveredProjectRule is context, not conversation - injected separately
  defp is_conversation_message(%DiscoveredProjectRule{}), do: false
  defp is_conversation_message(_), do: false

  @doc """
  Extracts markdown file contents from read_file ToolResult interactions
  and converts them to user messages.

  Only includes ToolResults where:
  - tool_name is "read_file"
  - The filename/path (from the matching ToolCall arguments) ends with .md
  - The result is not an error
  """
  @spec extract_markdown_messages(list(t())) :: list(map())
  def extract_markdown_messages(interactions) do
    # Build a map of tool_call_id -> ToolCall for quick lookup
    tool_calls_map = build_tool_calls_map(interactions)

    interactions
    |> Enum.filter(fn
      %ToolResult{tool_name: "read_file", is_error: false} -> true
      _ -> false
    end)
    |> Enum.flat_map(&extract_markdown_from_tool_result(&1, tool_calls_map))
  end

  defp build_tool_calls_map(interactions) do
    interactions
    |> Enum.filter(fn
      %ToolCall{} -> true
      _ -> false
    end)
    |> Enum.reduce(%{}, fn %ToolCall{tool_call_id: id} = tc, acc ->
      Map.put(acc, id, tc)
    end)
  end

  defp extract_markdown_from_tool_result(
         %ToolResult{tool_call_id: tool_call_id, result: result},
         tool_calls_map
       ) do
    # Get the path from the matching ToolCall arguments
    case Map.get(tool_calls_map, tool_call_id) do
      %ToolCall{arguments: args} ->
        path = get_field(args, :path)

        if path && String.ends_with?(path, ".md") do
          extract_content_from_result(result)
        else
          []
        end

      nil ->
        []
    end
  end

  defp extract_content_from_result(result) do
    case result do
      # Result is a map - check for text/content field
      result when is_map(result) ->
        content = get_field(result, :text) || get_field(result, :content)

        if content && is_binary(content) do
          [ReqLLM.Context.user(content)]
        else
          []
        end

      # Result is a string - this is the file content directly
      result when is_binary(result) ->
        # Try to decode as JSON first in case it's structured
        case Jason.decode(result) do
          {:ok, decoded} when is_map(decoded) ->
            extract_content_from_result(decoded)

          _ ->
            # Plain text content - use as is
            [ReqLLM.Context.user(result)]
        end

      _ ->
        []
    end
  end

  defp to_llm_message(%UserMessage{} = msg) do
    # Build text content from messages array
    text_content = Enum.join(msg.messages, "\n\n")

    # Build content parts - start with text
    content_parts =
      if text_content != "" do
        [ReqLLM.Message.ContentPart.text(text_content)]
      else
        []
      end

    # Add selected component screenshot if present
    content_parts =
      case msg.selected_component_screenshot do
        nil ->
          content_parts

        base64_data ->
          case Base.decode64(base64_data) do
            {:ok, decoded_data} ->
              content_parts ++ [ReqLLM.Message.ContentPart.image(decoded_data, "image/png")]

            :error ->
              content_parts
          end
      end

    # Note: selected_figma_node is NOT included here
    # It is handled separately by backend tools (breakdown_figma_design, etc.)

    case content_parts do
      [] ->
        # Empty message - return minimal user message
        ReqLLM.Context.user("")

      [%{type: :text, text: text}] ->
        # Single text content - use simple format
        ReqLLM.Context.user(text)

      parts ->
        # Multiple parts (text + images) - use Message struct
        %ReqLLM.Message{role: :user, content: parts}
    end
  end

  defp to_llm_message(%AgentResponse{content: content, metadata: metadata}) do
    tool_calls = Map.get(metadata || %{}, :tool_calls)
    response_id = Map.get(metadata || %{}, :response_id)
    # Extract reasoning_details for Gemini models (required for tool call round-trips)
    # Filter to only keep "reasoning.encrypted" entries - the encrypted signature is what
    # Gemini needs for tool call continuations, not the plain text reasoning
    all_reasoning_details = Map.get(metadata || %{}, :reasoning_details)

    encrypted_reasoning_details =
      case all_reasoning_details do
        nil ->
          nil

        details when is_list(details) ->
          filtered = Enum.filter(details, &(&1["type"] == "reasoning.encrypted"))
          if filtered == [], do: nil, else: filtered

        _ ->
          nil
      end

    case tool_calls do
      nil ->
        ReqLLM.Context.assistant(content)

      [] ->
        ReqLLM.Context.assistant(content)

      tool_calls ->
        # Build Message struct with metadata for OpenAI Responses API (previous_response_id)
        # and reasoning_details for Gemini models (encrypted signatures only)
        %ReqLLM.Message{
          role: :assistant,
          content: [ReqLLM.Message.ContentPart.text(content)],
          tool_calls: tool_calls,
          metadata: if(response_id, do: %{response_id: response_id}, else: %{}),
          reasoning_details: encrypted_reasoning_details
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

  defp get_field(map, key) when is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_atom(key))
  end

  defp decode_data_url(data_url) do
    with [_, mime_type, base64] <- Regex.run(~r/^data:([^;]+);base64,(.+)$/s, data_url),
         {:ok, binary} <- Base.decode64(base64) do
      {:ok, binary, mime_type}
    else
      _ -> :error
    end
  end

  @doc """
  Checks if any user messages in the interactions contain Figma context.
  Uses the pre-extracted `selected_figma_node` field on UserMessage for efficiency.
  """
  @spec has_figma_context?(list(t())) :: boolean()
  def has_figma_context?(interactions) do
    Enum.any?(interactions, fn
      %UserMessage{selected_figma_node: figma_node} when not is_nil(figma_node) ->
        true

      _ ->
        false
    end)
  end

  @doc """
  Gets the selected Figma node from the most recent user message that has one.
  Returns nil if no Figma context is found.
  """
  @spec get_selected_figma_node(list(t())) :: FigmaNode.t() | nil
  def get_selected_figma_node(interactions) do
    interactions
    |> Enum.reverse()
    |> Enum.find_value(fn
      %UserMessage{selected_figma_node: figma_node} when not is_nil(figma_node) ->
        figma_node

      _ ->
        nil
    end)
  end

  @doc """
  Checks if any user messages in the interactions contain a selected component.
  Uses the pre-extracted `selected_component` field on UserMessage for efficiency.
  """
  @spec has_selected_component?(list(t())) :: boolean()
  def has_selected_component?(interactions) do
    Enum.any?(interactions, fn
      %UserMessage{selected_component: sc} when not is_nil(sc) -> true
      _ -> false
    end)
  end
end
