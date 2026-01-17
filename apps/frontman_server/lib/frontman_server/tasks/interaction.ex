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

  alias ReqLLM.Message.ContentPart

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
    - Used by `implement_component`, `visual_compare_component_to_figma`, etc. for detailed implementation
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
            column: integer(),
            source_snippet: String.t() | nil,
            source_type: String.t() | nil
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
            %{
              file: file,
              line: line,
              column: column,
              source_snippet: Map.get(meta, "source_snippet"),
              source_type: Map.get(meta, "source_type")
            }
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
      field(:content, String.t())
      field(:timestamp, DateTime.t())
      field(:metadata, map(), enforce: false)
    end

    def new(content, metadata \\ %{}) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
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
    Represents the creation of a new agent run.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:config, map(), enforce: false)
      field(:timestamp, DateTime.t())
    end

    def new(config \\ %{}) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
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
          config: value.config,
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
      field(:timestamp, DateTime.t())
      field(:result, term(), enforce: false)
    end

    def new(result \\ nil) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
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
      field(:tool_call_id, String.t())
      field(:tool_name, String.t())
      field(:arguments, map())
      field(:timestamp, DateTime.t())
    end

    def new(%ReqLLM.ToolCall{} = tc) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
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
      field(:tool_call_id, String.t())
      field(:tool_name, String.t())
      field(:result, term())
      field(:is_error, boolean(), default: false)
      field(:timestamp, DateTime.t())
    end

    def new(tool_call_data, result, is_error \\ false) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
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
    |> Enum.filter(&conversation_message?/1)
    |> Enum.map(&to_llm_message/1)
    |> Enum.reject(&is_nil/1)
  end

  defp conversation_message?(%UserMessage{}), do: true
  defp conversation_message?(%AgentResponse{}), do: true
  defp conversation_message?(%ToolResult{}), do: true
  defp conversation_message?(%DiscoveredProjectRule{}), do: false
  defp conversation_message?(_), do: false

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
          [Swarm.Message.user(content)]
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
            [Swarm.Message.user(result)]
        end

      _ ->
        []
    end
  end

  defp to_llm_message(%UserMessage{} = msg) do
    text_content =
      msg.messages
      |> Enum.join("\n\n")
      |> append_component_location(msg.selected_component)

    content_parts =
      text_content
      |> build_text_parts()
      |> append_screenshot(msg.selected_component_screenshot)

    build_user_message(content_parts)
  end

  defp to_llm_message(%AgentResponse{content: content, metadata: metadata}) do
    meta = metadata || %{}
    tool_calls = Map.get(meta, :tool_calls)

    build_assistant_message(content, tool_calls, meta)
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

  # Helper functions for to_llm_message(%UserMessage{})

  defp append_component_location(text, %{file: file, line: line, column: column} = sc) do
    source_context = build_source_context(sc)

    location_info = """

    [Selected Component Location]
    File: #{file}
    Line: #{line}
    Column: #{column}#{source_context}

    IMPORTANT: The user has selected a specific component at this location.
    Start by reading this exact file and making changes at or near the specified line.
    Do NOT explore or search for files - go directly to the selected file.
    """

    text <> location_info
  end

  defp append_component_location(text, _), do: text

  defp build_source_context(sc) do
    case {Map.get(sc, :source_snippet), Map.get(sc, :source_type)} do
      {nil, nil} ->
        ""

      {snippet, nil} when is_binary(snippet) ->
        """

        Source Context:
        ```
        #{snippet}
        ```
        """

      {nil, source_type} when is_binary(source_type) ->
        """

        Source Type: #{source_type}
        """

      {snippet, source_type} when is_binary(snippet) and is_binary(source_type) ->
        """

        Source Type: #{source_type}
        Source Context:
        ```
        #{snippet}
        ```
        """

      _ ->
        ""
    end
  end

  defp build_text_parts(""), do: []
  defp build_text_parts(text), do: [ContentPart.text(text)]

  defp append_screenshot(parts, nil), do: parts

  defp append_screenshot(parts, base64_data) do
    case Base.decode64(base64_data) do
      {:ok, decoded_data} -> parts ++ [ContentPart.image(decoded_data, "image/png")]
      :error -> parts
    end
  end

  defp build_user_message([]), do: ReqLLM.Context.user("")
  defp build_user_message([%{type: :text, text: text}]), do: ReqLLM.Context.user(text)
  defp build_user_message(parts), do: %ReqLLM.Message{role: :user, content: parts}

  # Helper functions for to_llm_message(%AgentResponse{})

  defp build_assistant_message(content, nil, _meta), do: ReqLLM.Context.assistant(content)
  defp build_assistant_message(content, [], _meta), do: ReqLLM.Context.assistant(content)

  defp build_assistant_message(content, tool_calls, meta) do
    response_id = Map.get(meta, :response_id)
    encrypted_reasoning = filter_encrypted_reasoning(Map.get(meta, :reasoning_details))

    %ReqLLM.Message{
      role: :assistant,
      content: [ContentPart.text(content)],
      tool_calls: tool_calls,
      metadata: if(response_id, do: %{response_id: response_id}, else: %{}),
      reasoning_details: encrypted_reasoning
    }
  end

  defp filter_encrypted_reasoning(nil), do: nil
  defp filter_encrypted_reasoning(details) when not is_list(details), do: nil

  defp filter_encrypted_reasoning(details) do
    case Enum.filter(details, &(&1["type"] == "reasoning.encrypted")) do
      [] -> nil
      filtered -> filtered
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
          [ContentPart.image(image_binary, mime_type)]

        text ->
          [
            ContentPart.text(text),
            ContentPart.image(image_binary, mime_type)
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

  @doc """
  Prepends discovered project rules to the first user message in LLM messages.

  Project rules are formatted as a system reminder and injected into the first
  user message's content to provide context to the LLM.
  """
  @spec prepend_project_rules(list(map()), list(DiscoveredProjectRule.t())) :: list(map())
  def prepend_project_rules(messages, []), do: messages

  def prepend_project_rules(messages, rules) do
    reminder = build_rules_reminder(rules)
    do_prepend_to_first_user_message(messages, reminder)
  end

  defp do_prepend_to_first_user_message([], _reminder), do: []

  defp do_prepend_to_first_user_message([%{role: :user} = msg | rest], reminder) do
    content_parts =
      case msg.content do
        content when is_binary(content) -> [ContentPart.text(content)]
        content when is_list(content) -> content
      end

    updated_content = [ContentPart.text(reminder) | content_parts]
    [%{msg | content: updated_content} | rest]
  end

  defp do_prepend_to_first_user_message([msg | rest], reminder) do
    [msg | do_prepend_to_first_user_message(rest, reminder)]
  end

  defp build_rules_reminder(rules) do
    sections =
      rules
      |> Enum.sort_by(& &1.timestamp)
      |> Enum.map(fn rule -> "Contents of #{rule.path}:\n\n#{rule.content}" end)

    """
    <system-reminder>
    As you answer the user's questions, you can use the following context:
    # Project Rules

    #{Enum.join(sections, "\n\n---\n\n")}

    IMPORTANT: this context may or may not be relevant to your tasks.
    </system-reminder>
    """
  end
end
