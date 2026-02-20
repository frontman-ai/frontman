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
    - `current_page` - page context (URL, viewport, DPR, title, color scheme, scroll)
    """
    use TypedStruct

    @type selected_component :: %{
            file: String.t(),
            line: integer(),
            column: integer(),
            source_snippet: String.t() | nil,
            source_type: String.t() | nil,
            component_name: String.t() | nil,
            component_props: map() | nil,
            parent: selected_component() | nil
          }

    @type current_page :: %{
            url: String.t(),
            viewport_width: integer() | nil,
            viewport_height: integer() | nil,
            device_pixel_ratio: float() | nil,
            title: String.t() | nil,
            color_scheme: String.t() | nil,
            scroll_y: integer() | nil
          }

    typedstruct enforce: true do
      field(:id, String.t())
      field(:sequence, integer())
      field(:timestamp, DateTime.t())
      # Text messages from the user (extracted from text content blocks)
      field(:messages, list(String.t()), default: [])
      # Extracted source location from resource with _meta.selected_component
      field(:selected_component, selected_component() | nil, enforce: false)

      # Extracted screenshot from resource with _meta.selected_component_screenshot
      # Contains %{blob: base64_data, mime_type: "image/jpeg" | "image/png"}
      field(:selected_component_screenshot, %{blob: String.t(), mime_type: String.t()} | nil,
        enforce: false
      )

      # Extracted Figma node with id, node data (DSL or full JSON), and image
      field(:selected_figma_node, FigmaNode.t() | nil, enforce: false)

      # User-uploaded image/PDF attachments
      # Each entry: %{blob: base64_data, mime_type: "image/png", filename: "image.png"}
      field(:images, list(map()), default: [])

      # Extracted current page context from resource with _meta.current_page
      field(:current_page, current_page() | nil, enforce: false)
    end

    def new(content_blocks) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        timestamp: Interaction.now(),
        messages: extract_messages(content_blocks),
        selected_component: extract_selected_component(content_blocks),
        selected_component_screenshot: extract_selected_component_screenshot(content_blocks),
        selected_figma_node: extract_selected_figma_node(content_blocks),
        images: extract_user_images(content_blocks),
        current_page: extract_current_page(content_blocks)
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
              source_type: Map.get(meta, "source_type"),
              component_name: Map.get(meta, "component_name"),
              component_props: Map.get(meta, "component_props"),
              parent: parse_parent_chain(Map.get(meta, "parent"))
            }
          else
            nil
          end

        _ ->
          nil
      end)
    end

    # Recursively parse parent chain from _meta
    defp parse_parent_chain(nil), do: nil

    defp parse_parent_chain(parent) when is_map(parent) do
      file = Map.get(parent, "file")
      line = Map.get(parent, "line")
      column = Map.get(parent, "column")

      if is_binary(file) and is_integer(line) and is_integer(column) do
        %{
          file: file,
          line: line,
          column: column,
          source_snippet: nil,
          source_type: nil,
          component_name: Map.get(parent, "component_name"),
          component_props: Map.get(parent, "component_props"),
          parent: parse_parent_chain(Map.get(parent, "parent"))
        }
      else
        nil
      end
    end

    defp parse_parent_chain(_), do: nil

    # Extract selected component screenshot from content blocks
    # Looks for _meta.selected_component_screenshot with blob data and mimeType
    defp extract_selected_component_screenshot(content_blocks) do
      content_blocks
      |> Enum.find_value(fn
        %{"type" => "resource", "resource" => resource} ->
          case resource do
            %{
              "_meta" => %{"selected_component_screenshot" => true},
              "resource" => %{"blob" => blob, "mimeType" => mime_type}
            }
            when is_binary(blob) and is_binary(mime_type) ->
              %{blob: blob, mime_type: mime_type}

            # Fallback for legacy data without mimeType - default to image/jpeg
            %{
              "_meta" => %{"selected_component_screenshot" => true},
              "resource" => %{"blob" => blob}
            }
            when is_binary(blob) ->
              %{blob: blob, mime_type: "image/jpeg"}

            _ ->
              nil
          end

        _ ->
          nil
      end)
    end

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

    # Extract current page context from content blocks
    # Looks for _meta.current_page with page metadata
    defp extract_current_page(content_blocks) do
      Enum.find_value(content_blocks, fn
        %{
          "type" => "resource",
          "resource" => %{"_meta" => %{"current_page" => true} = meta}
        } ->
          url = Map.get(meta, "url")

          case url do
            url when is_binary(url) ->
              %{
                url: url,
                viewport_width: Map.get(meta, "viewport_width"),
                viewport_height: Map.get(meta, "viewport_height"),
                device_pixel_ratio: Map.get(meta, "device_pixel_ratio"),
                title: Map.get(meta, "title"),
                color_scheme: Map.get(meta, "color_scheme"),
                scroll_y: Map.get(meta, "scroll_y")
              }

            _ ->
              nil
          end

        _ ->
          nil
      end)
    end

    # Extract user-uploaded images from content blocks
    # Looks for resource blocks with _meta.user_image: true
    defp extract_user_images(content_blocks) do
      content_blocks
      |> Enum.filter(fn
        %{"type" => "resource", "resource" => %{"_meta" => %{"user_image" => true}}} -> true
        _ -> false
      end)
      |> Enum.map(fn %{"type" => "resource", "resource" => resource} ->
        inner = Map.get(resource, "resource", %{})
        meta = Map.get(resource, "_meta", %{})

        %{
          blob: Map.get(inner, "blob", ""),
          mime_type: Map.get(inner, "mimeType", "image/png"),
          filename: Map.get(meta, "filename", "attachment"),
          uri: Map.get(inner, "uri")
        }
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
          selected_figma_node: selected_figma_node,
          images:
            Enum.map(value.images, fn img ->
              %{mime_type: img.mime_type, filename: img.filename, has_blob: img.blob != ""}
            end)
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
      field(:sequence, integer())
      field(:content, String.t())
      field(:timestamp, DateTime.t())
      field(:metadata, map(), enforce: false)
    end

    def new(content, metadata \\ %{}) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
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
      field(:sequence, integer())
      field(:config, map(), enforce: false)
      field(:timestamp, DateTime.t())
    end

    def new(config \\ %{}) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
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
      field(:sequence, integer())
      field(:timestamp, DateTime.t())
      field(:result, term(), enforce: false)
    end

    def new(result \\ nil) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
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
      field(:sequence, integer())
      field(:tool_call_id, String.t())
      field(:tool_name, String.t())
      field(:arguments, map())
      field(:timestamp, DateTime.t())
    end

    def new(%ReqLLM.ToolCall{} = tc) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
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
      field(:sequence, integer())
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
        sequence: Interaction.new_sequence(),
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
      field(:sequence, integer())
      field(:content, String.t())
      field(:timestamp, DateTime.t())
    end

    def new(path, content) do
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        path: path,
        sequence: Interaction.new_sequence(),
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
  Generates a monotonic sequence number for deterministic ordering.

  Uses System.unique_integer([:monotonic, :positive]) which is guaranteed to be
  strictly increasing within a single VM instance. This ensures that
  interactions created in sequence (e.g., AgentResponse followed by ToolResult)
  will always be ordered correctly regardless of DB insert timing.
  """
  def new_sequence do
    System.unique_integer([:monotonic, :positive])
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

  Interactions are expected to be ordered by sequence number (set at creation time),
  which guarantees correct conversation structure (assistant messages before their
  tool results) regardless of database insertion timing.
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
      |> append_current_page_context(msg.current_page)
      |> append_component_location(msg.selected_component)
      |> append_image_attachment_context(msg.images)

    content_parts =
      text_content
      |> build_text_parts()
      |> append_screenshot(msg.selected_component_screenshot)
      |> append_user_images(msg.images)

    build_user_message(content_parts)
  end

  defp to_llm_message(%AgentResponse{content: content, metadata: metadata}) do
    meta = metadata || %{}
    # Handle both atom and string keys (DB stores string keys, but in-memory uses atoms)
    raw_tool_calls = get_flexible(meta, :tool_calls)
    # Convert stored tool_calls (maps with string keys) to ReqLLM.ToolCall structs
    tool_calls = normalize_tool_calls(raw_tool_calls)

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
    component_name_context = build_component_name_context(sc)
    props_context = build_props_context(sc)
    parent_context = build_parent_context(sc)

    location_info = """

    [Selected Component Location]
    File: #{file}
    Line: #{line}
    Column: #{column}#{component_name_context}#{source_context}#{props_context}#{parent_context}

    IMPORTANT: The user has selected a specific component at this location.
    Start by reading this exact file and making changes at or near the specified line.
    Do NOT explore or search for files - go directly to the selected file.
    """

    text <> location_info
  end

  defp append_component_location(text, _), do: text

  # Append current page context to user message text
  defp append_current_page_context(text, %{url: url} = page) do
    viewport_context = build_viewport_context(page)
    dpr_context = build_dpr_context(page)
    title_context = build_title_context(page)
    color_scheme_context = build_color_scheme_context(page)
    scroll_context = build_scroll_context(page)

    page_info = """

    [Current Page Context]
    URL: #{url}#{viewport_context}#{dpr_context}#{title_context}#{color_scheme_context}#{scroll_context}
    """

    text <> page_info
  end

  defp append_current_page_context(text, _), do: text

  # Append image attachment URIs so the LLM knows it can save them via write_file's image_ref
  defp append_image_attachment_context(text, images) when is_list(images) and images != [] do
    uris =
      images
      |> Enum.filter(fn img -> is_binary(Map.get(img, :uri)) end)
      |> Enum.map(fn img -> "- #{img.uri} (#{img.filename}, #{img.mime_type})" end)

    case uris do
      [] ->
        text

      _ ->
        uri_list = Enum.join(uris, "\n")

        text <>
          """

          [Available Image Attachments]
          The following images were attached by the user and can be saved to disk using the write_file tool with the image_ref parameter:
          #{uri_list}
          """
    end
  end

  defp append_image_attachment_context(text, _), do: text

  defp build_viewport_context(%{viewport_width: w, viewport_height: h})
       when is_integer(w) and is_integer(h) do
    "\nViewport: #{w}x#{h}"
  end

  defp build_viewport_context(_), do: ""

  defp build_dpr_context(%{device_pixel_ratio: dpr})
       when is_number(dpr) do
    "\nDevice Pixel Ratio: #{dpr}"
  end

  defp build_dpr_context(_), do: ""

  defp build_title_context(%{title: title}) when is_binary(title) do
    "\nPage Title: #{title}"
  end

  defp build_title_context(_), do: ""

  defp build_color_scheme_context(%{color_scheme: scheme}) when is_binary(scheme) do
    "\nColor Scheme: #{scheme}"
  end

  defp build_color_scheme_context(_), do: ""

  defp build_scroll_context(%{scroll_y: scroll_y}) when is_integer(scroll_y) do
    "\nScroll Position: #{scroll_y}px"
  end

  defp build_scroll_context(_), do: ""

  defp build_component_name_context(%{component_name: name}) when is_binary(name) do
    "\nComponent: #{name}"
  end

  defp build_component_name_context(_), do: ""

  defp build_props_context(%{component_props: props})
       when is_map(props) and map_size(props) > 0 do
    props_json = Jason.encode!(props, pretty: true)

    """

    Component Props:
    ```json
    #{props_json}
    ```
    """
  end

  defp build_props_context(_), do: ""

  defp build_parent_context(%{parent: parent}) when not is_nil(parent) do
    parent_chain = format_parent_chain(parent, 1)

    """

    Parent Component Hierarchy:
    #{parent_chain}
    """
  end

  defp build_parent_context(_), do: ""

  defp format_parent_chain(nil, _depth), do: ""

  defp format_parent_chain(%{file: file, line: line, column: column} = parent, depth) do
    component_name = Map.get(parent, :component_name)
    props = Map.get(parent, :component_props)
    nested_parent = Map.get(parent, :parent)

    indent = String.duplicate("  ", depth - 1)
    name_part = if component_name, do: " (#{component_name})", else: ""
    location = "#{indent}#{depth}. #{file}:#{line}:#{column}#{name_part}"

    props_part =
      if is_map(props) and map_size(props) > 0 do
        props_json = Jason.encode!(props, pretty: false)
        "\n#{indent}   Props: #{props_json}"
      else
        ""
      end

    nested_part = format_parent_chain(nested_parent, depth + 1)
    nested_separator = if nested_part != "", do: "\n", else: ""

    location <> props_part <> nested_separator <> nested_part
  end

  defp format_parent_chain(_, _depth), do: ""

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

  defp append_screenshot(parts, %{blob: base64_data, mime_type: mime_type}) do
    case Base.decode64(base64_data) do
      {:ok, decoded_data} -> parts ++ [ContentPart.image(decoded_data, mime_type)]
      :error -> parts
    end
  end

  # Fallback for legacy string format (before mime_type was tracked)
  defp append_screenshot(parts, base64_data) when is_binary(base64_data) do
    case Base.decode64(base64_data) do
      {:ok, decoded_data} -> parts ++ [ContentPart.image(decoded_data, "image/jpeg")]
      :error -> parts
    end
  end

  # Append user-uploaded images to content parts
  # PDFs are converted to text mentions since LLM APIs only support image/* content types
  defp append_user_images(parts, []), do: parts

  defp append_user_images(parts, images) when is_list(images) do
    {image_attachments, pdf_attachments} =
      Enum.split_with(images, fn %{mime_type: mime_type} ->
        String.starts_with?(mime_type, "image/")
      end)

    image_parts =
      image_attachments
      |> Enum.map(fn %{blob: base64_data, mime_type: mime_type} ->
        case Base.decode64(base64_data) do
          {:ok, decoded_data} -> ContentPart.image(decoded_data, mime_type)
          :error -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    pdf_parts =
      Enum.map(pdf_attachments, fn %{filename: filename} ->
        ContentPart.text("[Attached PDF: #{filename}]")
      end)

    parts ++ image_parts ++ pdf_parts
  end

  defp build_user_message([]), do: ReqLLM.Context.user("")
  defp build_user_message([%{type: :text, text: text}]), do: ReqLLM.Context.user(text)
  defp build_user_message(parts), do: %ReqLLM.Message{role: :user, content: parts}

  # Helper functions for to_llm_message(%AgentResponse{})

  defp build_assistant_message(content, nil, _meta), do: ReqLLM.Context.assistant(content)
  defp build_assistant_message(content, [], _meta), do: ReqLLM.Context.assistant(content)

  defp build_assistant_message(content, tool_calls, meta) do
    # Handle both atom and string keys (DB stores string keys, but in-memory uses atoms)
    response_id = get_flexible(meta, :response_id)
    encrypted_reasoning = filter_encrypted_reasoning(get_flexible(meta, :reasoning_details))

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
    "take_screenshot" => {:screenshot, []}
  }

  defp extract_image_from_result(tool_name, result) when is_map(result) do
    canonical_name = String.replace_prefix(tool_name, "mcp_", "")
    config = Map.get(@image_tool_configs, canonical_name)

    with {image_field, text_fields} <- config,
         data_url when is_binary(data_url) <- get_field(result, image_field),
         {:ok, binary, mime} <- decode_data_url(data_url) do
      text_content = build_text_content(result, text_fields)
      {binary, mime, text_content}
    else
      _ -> nil
    end
  end

  defp extract_image_from_result(_tool_name, _result), do: nil

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

  # Get field from map, supporting both string and atom keys.
  # This is needed because metadata from DB has string keys, but in-memory uses atoms.
  defp get_field(map, key) when is_atom(key) do
    Map.get(map, Atom.to_string(key)) || Map.get(map, key)
  end

  defp get_field(map, key) when is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_atom(key))
  end

  # Alias for get_field, used for metadata access to make intent clear
  defp get_flexible(map, key), do: get_field(map, key)

  # Convert stored tool_calls (maps with string keys in OpenAI wire format) to ReqLLM.ToolCall structs
  defp normalize_tool_calls(nil), do: nil
  defp normalize_tool_calls([]), do: []

  defp normalize_tool_calls(tool_calls) when is_list(tool_calls) do
    Enum.map(tool_calls, &normalize_tool_call/1)
  end

  # Already a struct, pass through
  defp normalize_tool_call(%ReqLLM.ToolCall{} = tc), do: tc

  # OpenAI wire format with string keys (from DB JSON)
  defp normalize_tool_call(%{"id" => id, "function" => %{"name" => name, "arguments" => args}}) do
    ReqLLM.ToolCall.new(id, name, args)
  end

  # OpenAI wire format with atom keys (fresh from response)
  defp normalize_tool_call(%{id: id, function: %{name: name, arguments: args}}) do
    ReqLLM.ToolCall.new(id, name, args)
  end

  # Flat format with string keys
  defp normalize_tool_call(%{"id" => id, "name" => name, "arguments" => args}) do
    ReqLLM.ToolCall.new(id, name, args)
  end

  # Flat format with atom keys
  defp normalize_tool_call(%{id: id, name: name, arguments: args}) do
    ReqLLM.ToolCall.new(id, name, args)
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
  Checks if any user messages in the interactions contain current page context.
  Uses the pre-extracted `current_page` field on UserMessage for efficiency.
  """
  @spec has_current_page?(list(t())) :: boolean()
  def has_current_page?(interactions) do
    Enum.any?(interactions, fn
      %UserMessage{current_page: cp} when not is_nil(cp) -> true
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
