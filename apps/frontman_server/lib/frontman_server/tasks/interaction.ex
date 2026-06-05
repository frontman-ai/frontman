# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

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
          | __MODULE__.AgentCompleted.t()
          | __MODULE__.AgentError.t()
          | __MODULE__.AgentPaused.t()
          | __MODULE__.AgentRetry.t()
          | __MODULE__.ToolCall.t()
          | __MODULE__.ToolResult.t()
          | __MODULE__.DiscoveredProjectRule.t()
          | __MODULE__.DiscoveredProjectStructure.t()

  @types [
    user_message: __MODULE__.UserMessage,
    agent_response: __MODULE__.AgentResponse,
    agent_completed: __MODULE__.AgentCompleted,
    agent_error: __MODULE__.AgentError,
    agent_paused: __MODULE__.AgentPaused,
    agent_retry: __MODULE__.AgentRetry,
    tool_call: __MODULE__.ToolCall,
    tool_result: __MODULE__.ToolResult,
    discovered_project_rule: __MODULE__.DiscoveredProjectRule,
    discovered_project_structure: __MODULE__.DiscoveredProjectStructure
  ]

  @type_values Keyword.keys(@types)
  @interaction_modules Keyword.values(@types)
  @type_to_module Map.new(@types)
  @module_to_type Map.new(@types, fn {type, module} -> {module, type} end)

  @task_scoped_types [:discovered_project_rule, :discovered_project_structure]

  @doc """
  Returns the list of all interaction type modules.
  """
  def interaction_modules, do: @interaction_modules
  def type_values, do: @type_values
  def task_scoped_types, do: @task_scoped_types

  def type_for(%{__struct__: module}), do: type_for(module)

  def type_for(module) when is_atom(module) do
    case Map.fetch(@module_to_type, module) do
      {:ok, type} ->
        type

      :error ->
        if Map.has_key?(@type_to_module, module),
          do: module,
          else: raise("Unknown interaction type: #{inspect(module)}")
    end
  end

  def module_for(type) when is_atom(type), do: Map.fetch!(@type_to_module, type)

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Tasks.Interaction
  alias SwarmAi.Message, as: SwarmMessage
  alias SwarmAi.Message.ContentPart, as: SwarmContentPart
  alias SwarmAi.ToolCall, as: SwarmToolCall

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

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil

    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: data["id"],
        node: data["node"],
        image: data["image"],
        is_dsl: Map.get(data, "is_dsl", true)
      }
    end
  end

  defmodule Screenshot do
    @moduledoc """
    Base64-encoded screenshot with MIME type.
    """
    use TypedStruct

    @derive Jason.Encoder
    typedstruct enforce: true do
      field(:blob, String.t())
      field(:mime_type, String.t())
    end

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil

    def from_map(%{"blob" => blob, "mime_type" => mime_type})
        when is_binary(blob) and is_binary(mime_type),
        do: %__MODULE__{blob: blob, mime_type: mime_type}

    def from_map(_), do: nil
  end

  defmodule BoundingBox do
    @moduledoc """
    Bounding box of an element in viewport coordinates.
    """
    use TypedStruct

    @derive Jason.Encoder
    typedstruct enforce: true do
      field(:x, float())
      field(:y, float())
      field(:width, float())
      field(:height, float())
    end

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil

    def from_map(%{"x" => x, "y" => y, "width" => w, "height" => h})
        when is_number(x) and is_number(y) and is_number(w) and is_number(h),
        do: %__MODULE__{x: x / 1, y: y / 1, width: w / 1, height: h / 1}

    def from_map(_), do: nil
  end

  defmodule ParentLocation do
    @moduledoc """
    Source location of a parent component in the React tree.

    Forms a recursive chain via the `parent` field.
    """
    use TypedStruct

    @derive Jason.Encoder
    typedstruct enforce: true do
      field(:file, String.t())
      field(:line, integer())
      field(:column, integer())
      field(:component_name, String.t() | nil, enforce: false)
      field(:component_props, map() | nil, enforce: false)
      field(:parent, t() | nil, enforce: false)
    end

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil

    def from_map(data) when is_map(data) do
      file = data["file"]
      line = data["line"]
      column = data["column"]

      if is_binary(file) and is_integer(line) and is_integer(column) do
        %__MODULE__{
          file: file,
          line: line,
          column: column,
          component_name: data["component_name"],
          component_props: data["component_props"],
          parent: from_map(data["parent"])
        }
      else
        nil
      end
    end

    def from_map(_), do: nil
  end

  defmodule UserImage do
    @moduledoc """
    A user-uploaded image or PDF attachment.
    """
    use TypedStruct

    @derive Jason.Encoder
    typedstruct enforce: true do
      field(:blob, String.t())
      field(:mime_type, String.t())
      field(:filename, String.t())
      field(:uri, String.t() | nil, enforce: false)
    end

    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        blob: data["blob"],
        mime_type: data["mime_type"] || "image/png",
        filename: data["filename"] || "attachment",
        uri: data["uri"]
      }
    end
  end

  defmodule CurrentPage do
    @moduledoc """
    Page context from the client: URL, viewport, DPR, title, color scheme, scroll position.
    """
    use TypedStruct

    alias FrontmanServer.CurrentPageContext

    @derive Jason.Encoder
    typedstruct enforce: true do
      field(:url, String.t())
      field(:viewport_width, integer() | nil, enforce: false)
      field(:viewport_height, integer() | nil, enforce: false)
      field(:device_pixel_ratio, float() | nil, enforce: false)
      field(:title, String.t() | nil, enforce: false)
      field(:color_scheme, String.t() | nil, enforce: false)
      field(:scroll_y, integer() | nil, enforce: false)
    end

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil

    def from_map(data) when is_map(data) do
      case CurrentPageContext.fields_from_meta(data) do
        %{url: url} = fields ->
          %__MODULE__{
            url: url,
            viewport_width: fields.viewport_width,
            viewport_height: fields.viewport_height,
            device_pixel_ratio: fields.device_pixel_ratio,
            title: fields.title,
            color_scheme: fields.color_scheme,
            scroll_y: fields.scroll_y
          }

        nil ->
          nil
      end
    end

    def from_map(_), do: nil

    @spec from_acp_meta(map() | nil) :: t() | nil
    def from_acp_meta(nil), do: nil

    def from_acp_meta(meta) when is_map(meta) do
      if CurrentPageContext.current_page_in_meta?(meta), do: from_map(meta), else: nil
    end

    def from_acp_meta(_), do: nil
  end

  defmodule Annotation do
    @moduledoc """
    Represents a single annotated element from the client.

    Contains source location, screenshot, and enrichment data.
    """
    use TypedStruct

    @derive Jason.Encoder
    typedstruct do
      field(:annotation_id, String.t())
      field(:annotation_index, integer())
      field(:tag_name, String.t())
      field(:comment, String.t() | nil)
      field(:file, String.t() | nil)
      field(:line, integer() | nil)
      field(:column, integer() | nil)
      field(:component_name, String.t() | nil)
      field(:component_props, map() | nil)
      field(:parent, ParentLocation.t() | nil)
      field(:css_classes, String.t() | nil)
      field(:nearby_text, String.t() | nil)
      field(:metadata, map(), default: %{})
      field(:bounding_box, BoundingBox.t() | nil)
      field(:screenshot, Screenshot.t() | nil)
    end

    @known_meta_keys ~w(
      annotation
      annotation_id
      annotation_index
      annotation_screenshot
      bounding_box
      column
      comment
      component_name
      component_props
      css_classes
      file
      line
      metadata
      nearby_text
      parent
      screenshot
      tag_name
    )

    @doc """
    Builds an Annotation from a string-key ACP/DB map.

    Used by both DB deserialization (InteractionSchema.to_struct) and
    ACP content block parsing (via from_meta/2).
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        annotation_id: data["annotation_id"],
        annotation_index: data["annotation_index"],
        tag_name: data["tag_name"] || "unknown",
        comment: data["comment"],
        file: data["file"],
        line: data["line"],
        column: data["column"],
        component_name: data["component_name"],
        component_props: data["component_props"],
        parent: ParentLocation.from_map(data["parent"]),
        css_classes: data["css_classes"],
        nearby_text: data["nearby_text"],
        metadata: metadata_from_map(data),
        bounding_box: BoundingBox.from_map(data["bounding_box"]),
        screenshot: Screenshot.from_map(data["screenshot"])
      }
    end

    defp metadata_from_map(data) do
      inline_metadata = drop_known_metadata(data)
      explicit_metadata = data |> Map.get("metadata") |> drop_known_metadata()

      Map.merge(inline_metadata, explicit_metadata)
    end

    defp drop_known_metadata(metadata) when is_map(metadata),
      do:
        metadata
        |> Map.drop(@known_meta_keys)
        |> Map.reject(fn {_key, value} -> is_nil(value) end)

    defp drop_known_metadata(_), do: %{}

    @doc """
    Builds an Annotation from an ACP `_meta` block, pairing with a separate
    screenshot map keyed by annotation_id.

    The _meta block contains all annotation fields inline. Screenshots are
    sent as separate content blocks and collected into `screenshot_map` by
    the caller.
    """
    @spec from_meta(map(), %{optional(String.t()) => Screenshot.t()}) :: t()
    def from_meta(meta, screenshot_map \\ %{}) when is_map(meta) do
      ann = from_map(meta)
      %{ann | screenshot: Map.get(screenshot_map, ann.annotation_id)}
    end
  end

  defmodule UserMessage do
    @moduledoc """
    Represents a message sent by the user.

    All fields are extracted from content blocks at creation time:
    - `messages` - array of text messages from the user
    - `annotations` - list of annotated elements (replaces selected_component)
    - `current_page` - page context (URL, viewport, DPR, title, color scheme, scroll)
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:timestamp, DateTime.t())
      # Text messages from the user (extracted from text content blocks)
      field(:messages, list(String.t()), default: [])

      # Annotated elements extracted from resource blocks with _meta.annotation: true
      # Each annotation contains source location, screenshot, and enrichment data
      field(:annotations, list(Annotation.t()), default: [])

      # Extracted Figma node with id, node data (DSL or full JSON), and image
      field(:selected_figma_node, FigmaNode.t() | nil, enforce: false)

      # User-uploaded image/PDF attachments
      field(:images, list(UserImage.t()), default: [])

      # Extracted current page context from resource with _meta.current_page
      field(:current_page, CurrentPage.t() | nil, enforce: false)
    end

    def new(content_blocks) do
      %__MODULE__{
        id: Interaction.new_id(),
        timestamp: Interaction.now(),
        messages: extract_messages(content_blocks),
        annotations: extract_annotations(content_blocks),
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

    # Extract annotations from content blocks.
    # Annotations are resource blocks with _meta.annotation: true.
    # Screenshots are paired by annotation_id via _meta.annotation_screenshot: true.
    defp extract_annotations(content_blocks) do
      screenshot_map = extract_screenshot_map(content_blocks)

      content_blocks
      |> Enum.filter(&annotation_block?/1)
      |> Enum.map(fn %{"type" => "resource", "resource" => %{"_meta" => meta}} ->
        Annotation.from_meta(meta, screenshot_map)
      end)
      |> Enum.sort_by(& &1.annotation_index)
    end

    defp annotation_block?(%{
           "type" => "resource",
           "resource" => %{"_meta" => %{"annotation" => true}}
         }),
         do: true

    defp annotation_block?(_), do: false

    # Collect screenshot blobs indexed by annotation_id
    defp extract_screenshot_map(content_blocks) do
      content_blocks
      |> Enum.filter(&annotation_screenshot_block?/1)
      |> Enum.reduce(%{}, fn %{"type" => "resource", "resource" => resource}, acc ->
        annotation_id = get_in(resource, ["_meta", "annotation_id"])
        inner = Map.get(resource, "resource", %{})

        case Screenshot.from_map(%{
               "blob" => inner["blob"],
               "mime_type" => inner["mimeType"] || "image/jpeg"
             }) do
          %Screenshot{} = screenshot when is_binary(annotation_id) ->
            Map.put(acc, annotation_id, screenshot)

          _ ->
            acc
        end
      end)
    end

    defp annotation_screenshot_block?(%{
           "type" => "resource",
           "resource" => %{"_meta" => %{"annotation_screenshot" => true}}
         }),
         do: true

    defp annotation_screenshot_block?(_), do: false

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

    # Extract current page context from content blocks.
    # Delegates construction to CurrentPage.from_map/1.
    defp extract_current_page(content_blocks) do
      Enum.find_value(content_blocks, fn
        %{"type" => "resource", "resource" => %{"_meta" => meta}} ->
          CurrentPage.from_acp_meta(meta)

        _ ->
          nil
      end)
    end

    # Extract user-uploaded images from content blocks.
    # Merges _meta and inner resource fields, then delegates to UserImage.from_map/1.
    defp extract_user_images(content_blocks) do
      content_blocks
      |> Enum.filter(&user_image_block?/1)
      |> Enum.map(fn %{"type" => "resource", "resource" => resource} ->
        inner = Map.get(resource, "resource", %{})
        meta = Map.get(resource, "_meta", %{})

        # UserImage fields come from both _meta (filename) and inner resource (blob, mimeType, uri).
        # Merge into a flat map with the keys UserImage.from_map expects.
        UserImage.from_map(%{
          "blob" => inner["blob"] || "",
          "mime_type" => inner["mimeType"] || "image/png",
          "filename" => meta["filename"] || "attachment",
          "uri" => inner["uri"]
        })
      end)
    end

    defp user_image_block?(%{
           "type" => "resource",
           "resource" => %{"_meta" => %{"user_image" => true}}
         }),
         do: true

    defp user_image_block?(_), do: false
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
      %__MODULE__{
        id: Interaction.new_id(),
        content: content,
        timestamp: Interaction.now(),
        metadata: metadata
      }
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
      %__MODULE__{
        id: Interaction.new_id(),
        timestamp: Interaction.now(),
        result: result
      }
    end
  end

  defmodule AgentError do
    @moduledoc """
    Represents an agent execution ending with an error (failed, crashed, or cancelled).

    Persisted so that reconnecting clients see the terminal interaction for every agent run,
    even when the channel process was dead when the error occurred.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:timestamp, DateTime.t())
      field(:error, String.t())
      field(:kind, String.t(), default: "failed")
      field(:retryable, boolean(), default: false)
      field(:category, String.t(), default: "unknown")
    end

    @doc """
    Creates a new AgentError interaction.

    `kind` is one of "failed", "crashed", "cancelled", or "terminated".
    `retryable` indicates whether the client should offer a retry action.
    `category` is a machine-readable error category (e.g. "rate_limit", "context_limit").
    """
    def new(error, kind \\ "failed", retryable \\ false, category \\ "unknown") do
      %__MODULE__{
        id: Interaction.new_id(),
        timestamp: Interaction.now(),
        error: error,
        kind: kind,
        retryable: retryable,
        category: category
      }
    end
  end

  defmodule AgentRetry do
    @moduledoc """
    Records a user-initiated retry after an AgentError.
    Persisted for observability — lets you measure retry success rates.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:timestamp, DateTime.t())
      field(:retried_error_id, String.t())
    end

    def new(retried_error_id) do
      %__MODULE__{
        id: Interaction.new_id(),
        timestamp: Interaction.now(),
        retried_error_id: retried_error_id
      }
    end
  end

  defmodule AgentPaused do
    @moduledoc """
    Recorded when the agent loop is paused due to a tool timeout with
    `on_timeout: :pause_agent`. Stored as an interaction so reconnecting
    clients and the debug-task tool can see why the agent stopped.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:id, String.t())
      field(:timestamp, DateTime.t())
      field(:reason, String.t())
      field(:tool_name, String.t())
      field(:timeout_ms, pos_integer())
    end

    def new(tool_name, timeout_ms) do
      %__MODULE__{
        id: Interaction.new_id(),
        timestamp: Interaction.now(),
        reason: "Tool #{tool_name} timed out after #{timeout_ms}ms (on_timeout: :pause_agent)",
        tool_name: tool_name,
        timeout_ms: timeout_ms
      }
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

    def new(%SwarmAi.ToolCall{} = tc) do
      case SwarmAi.ToolCall.parse_arguments(tc) do
        {:ok, arguments} ->
          {:ok,
           %__MODULE__{
             id: Interaction.new_id(),
             tool_call_id: tc.id,
             tool_name: tc.name,
             arguments: SwarmAi.SchemaTransformer.strip_nulls(arguments),
             timestamp: Interaction.now()
           }}

        {:error, message} ->
          {:error, {:invalid_tool_arguments, message}}
      end
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
      %__MODULE__{
        path: path,
        content: content,
        timestamp: Interaction.now()
      }
    end
  end

  defmodule DiscoveredProjectStructure do
    @moduledoc """
    Represents a discovered project structure summary (from list_tree during MCP init).

    Stored once per task during initialization. Injected into the system prompt
    so the agent always has structural awareness of the project.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:summary, String.t())
      field(:timestamp, DateTime.t())
    end

    def new(summary) do
      %__MODULE__{
        summary: summary,
        timestamp: Interaction.now()
      }
    end
  end

  for module <- @interaction_modules do
    defimpl Jason.Encoder, for: module do
      def encode(value, opts) do
        value
        |> Interaction.to_json_map()
        |> Jason.Encode.map(opts)
      end
    end
  end

  def to_json_map(%UserMessage{} = value) do
    %{
      type: type_for(value),
      id: value.id,
      messages: value.messages,
      timestamp: DateTime.to_iso8601(value.timestamp),
      annotations: Enum.map(value.annotations, &annotation_json_map/1),
      selected_figma_node: selected_figma_node_json_map(value.selected_figma_node),
      images: Enum.map(value.images, &user_image_json_map/1)
    }
  end

  def to_json_map(value) when is_struct(value) do
    value
    |> Map.from_struct()
    |> Map.put(:type, type_for(value))
    |> stringify_timestamp()
  end

  defp annotation_json_map(ann) do
    base = %{
      annotation_id: ann.annotation_id,
      annotation_index: ann.annotation_index,
      tag_name: ann.tag_name,
      comment: ann.comment,
      file: ann.file,
      line: ann.line,
      column: ann.column,
      component_name: ann.component_name,
      component_props: ann.component_props,
      parent: ann.parent,
      css_classes: ann.css_classes,
      nearby_text: ann.nearby_text,
      bounding_box: ann.bounding_box,
      screenshot: ann.screenshot
    }

    ann.metadata
    |> Map.merge(base)
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp selected_figma_node_json_map(nil), do: nil

  defp selected_figma_node_json_map(%{id: id, node: node, image: image, is_dsl: is_dsl}) do
    %{id: id, has_node: node != nil, has_image: image != nil, is_dsl: is_dsl}
  end

  defp user_image_json_map(img) do
    %{mime_type: img.mime_type, filename: img.filename, has_blob: img.blob != ""}
  end

  defp stringify_timestamp(%{timestamp: %DateTime{} = timestamp} = data) do
    %{data | timestamp: DateTime.to_iso8601(timestamp)}
  end

  defp stringify_timestamp(data), do: data

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
  Converts interactions to Swarm message format.

  This is the boundary translation from Tasks domain (Interactions)
  to Agents domain (Swarm messages). Conversation messages include
  UserMessage, AgentResponse, and ToolResult.
  ToolCall interactions are excluded as they're embedded in AgentResponse metadata.

  Interactions are expected to be ordered by the persisted sequence column,
  which guarantees correct conversation structure (assistant messages before their
  tool results) regardless of database insertion timing.
  """
  @spec to_swarm_messages(list(t())) :: list(SwarmMessage.t())
  def to_swarm_messages(interactions) when is_list(interactions) do
    Enum.flat_map(interactions, &to_swarm_message/1)
  end

  # Explicit clause for every Interaction type. Adding a new type without a
  # clause crashes immediately instead of silently omitting it from LLM history.
  defp to_swarm_message(%UserMessage{} = msg) do
    prompt_text = build_user_prompt_text(msg)
    content_parts = build_user_content_parts(prompt_text, msg)

    [build_swarm_user_message(content_parts)]
  end

  defp to_swarm_message(%AgentResponse{content: content, metadata: metadata}) do
    meta = metadata || %{}

    [
      %SwarmMessage.Assistant{
        content: [SwarmContentPart.text(content)],
        tool_calls: swarm_tool_calls(meta["tool_calls"]),
        metadata: swarm_metadata(meta),
        reasoning_details: filter_encrypted_reasoning(meta["reasoning_details"])
      }
    ]
  end

  defp to_swarm_message(%ToolResult{tool_name: name, tool_call_id: id, result: result}) do
    json_result = if is_binary(result), do: result, else: Jason.encode!(result)

    [
      %SwarmMessage.Tool{
        content: [SwarmContentPart.text(json_result)],
        tool_call_id: id,
        name: name,
        metadata: %{}
      }
    ]
  end

  defp to_swarm_message(%ToolCall{}), do: []
  defp to_swarm_message(%AgentCompleted{}), do: []
  defp to_swarm_message(%AgentError{}), do: []
  defp to_swarm_message(%AgentPaused{}), do: []
  defp to_swarm_message(%AgentRetry{}), do: []
  defp to_swarm_message(%DiscoveredProjectRule{}), do: []
  defp to_swarm_message(%DiscoveredProjectStructure{}), do: []

  @spec build_user_prompt_text(UserMessage.t()) :: String.t()
  defp build_user_prompt_text(%UserMessage{} = msg) do
    msg.messages
    |> Enum.join("\n\n")
    |> CurrentPageContext.append_prompt_section(msg.current_page)
    |> append_annotation_context(msg.annotations)
    |> append_attachment_context(msg.images)
  end

  @spec build_user_content_parts(String.t(), UserMessage.t()) :: list(SwarmContentPart.t())
  defp build_user_content_parts(prompt_text, %UserMessage{} = msg) do
    prompt_text
    |> text_parts()
    |> append_annotation_screenshot_parts(msg.annotations)
    |> append_user_attachment_parts(msg.images)
  end

  defp text_parts(""), do: []
  defp text_parts(text), do: [SwarmContentPart.text(text)]

  defp append_annotation_screenshot_parts(parts, []), do: parts

  defp append_annotation_screenshot_parts(parts, annotations) when is_list(annotations) do
    screenshot_parts =
      annotations
      |> Enum.filter(&(&1.screenshot != nil))
      |> Enum.flat_map(fn ann ->
        %{blob: base64_data, mime_type: mime_type} = ann.screenshot

        case Base.decode64(base64_data) do
          {:ok, decoded_data} -> [SwarmContentPart.image(decoded_data, mime_type)]
          :error -> []
        end
      end)

    parts ++ screenshot_parts
  end

  defp append_user_attachment_parts(parts, []), do: parts

  defp append_user_attachment_parts(parts, images) when is_list(images) do
    {image_attachments, pdf_attachments} =
      Enum.split_with(images, fn %{mime_type: mime_type} ->
        String.starts_with?(mime_type, "image/")
      end)

    image_parts =
      image_attachments
      |> Enum.map(fn %{blob: base64_data, mime_type: mime_type} ->
        case Base.decode64(base64_data) do
          {:ok, decoded_data} -> SwarmContentPart.image(decoded_data, mime_type)
          :error -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    pdf_parts =
      Enum.map(pdf_attachments, fn %{filename: filename} ->
        SwarmContentPart.text("[Attached PDF: #{filename}]")
      end)

    parts ++ image_parts ++ pdf_parts
  end

  defp build_swarm_user_message([]), do: SwarmMessage.user("")
  defp build_swarm_user_message(parts), do: %SwarmMessage.User{content: parts}

  defp append_annotation_context(text, []), do: text

  defp append_annotation_context(text, annotations) when is_list(annotations) do
    annotation_sections =
      annotations
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {ann, idx} -> format_annotation(ann, idx) end)

    text <>
      """

      [Annotated Elements]
      #{annotation_sections}
      IMPORTANT: The user has annotated specific element(s) in their application.
      Start by reading the exact file(s) and making changes at or near the specified line(s).
      Do NOT explore or search for files - go directly to the annotated file(s).
      """
  end

  defp format_annotation(ann, idx) do
    location = format_annotation_location(ann)
    optional_parts = format_annotation_optional_parts(ann)

    """
    Annotation #{idx + 1}:
      Tag: <#{ann.tag_name}>
      #{location}#{optional_parts}
    """
  end

  defp format_annotation_location(%{file: file, line: line, column: column})
       when is_binary(file) and is_integer(line) do
    "File: #{file}\n  Line: #{line}\n  Column: #{column || 0}"
  end

  defp format_annotation_location(%{tag_name: tag_name}), do: "Element: <#{tag_name}>"

  defp format_annotation_optional_parts(ann) do
    [
      annotation_string_field(ann.component_name, "Component"),
      annotation_string_field(ann.comment, "Comment"),
      annotation_string_field(ann.css_classes, "CSS Classes"),
      annotation_string_field(ann.nearby_text, "Nearby Text"),
      annotation_bbox_field(ann.bounding_box),
      annotation_props_field(ann.component_props),
      annotation_parent_field(ann.parent)
    ]
    |> Enum.join()
  end

  defp annotation_string_field(value, label) when is_binary(value), do: "\n  #{label}: #{value}"
  defp annotation_string_field(_, _), do: ""

  defp annotation_bbox_field(%{x: x, y: y, width: w, height: h}),
    do: "\n  Bounding Box: {x: #{x}, y: #{y}, width: #{w}, height: #{h}}"

  defp annotation_bbox_field(_), do: ""

  defp annotation_props_field(props) when is_map(props) and map_size(props) > 0,
    do: "\n  Props: #{Jason.encode!(props, pretty: false)}"

  defp annotation_props_field(_), do: ""

  defp annotation_parent_field(nil), do: ""
  defp annotation_parent_field(parent), do: "\n  Parent: #{format_parent_chain(parent, 1)}"

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

  defp append_attachment_context(text, images) when is_list(images) and images != [] do
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
          The following images were attached by the user and can be used via image_ref:
          #{uri_list}
          """
    end
  end

  defp append_attachment_context(text, _), do: text

  defp swarm_tool_calls(nil), do: []
  defp swarm_tool_calls([]), do: []

  defp swarm_tool_calls(tool_calls) when is_list(tool_calls) do
    Enum.map(tool_calls, &swarm_tool_call/1)
  end

  defp swarm_tool_call(%{
         "id" => id,
         "function" => %{"name" => name, "arguments" => arguments}
       }) do
    %SwarmToolCall{id: id, name: name, arguments: tool_arguments_json(arguments)}
  end

  defp swarm_tool_call(%{"id" => id, "name" => name, "arguments" => arguments}) do
    %SwarmToolCall{id: id, name: name, arguments: tool_arguments_json(arguments)}
  end

  defp tool_arguments_json(arguments) when is_binary(arguments), do: arguments
  defp tool_arguments_json(arguments), do: Jason.encode!(arguments)

  defp swarm_metadata(meta) do
    %{
      response_id: meta["response_id"],
      phase: meta["phase"],
      phase_items: meta["phase_items"]
    }
    |> Map.reject(fn {_key, value} -> value in [nil, []] end)
  end

  defp filter_encrypted_reasoning(nil), do: nil
  defp filter_encrypted_reasoning(details) when not is_list(details), do: nil

  defp filter_encrypted_reasoning(details) do
    case Enum.filter(details, &(&1["type"] == "reasoning.encrypted")) do
      [] -> nil
      filtered -> filtered
    end
  end
end
