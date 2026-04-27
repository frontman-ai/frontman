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
          | __MODULE__.AgentSpawned.t()
          | __MODULE__.AgentCompleted.t()
          | __MODULE__.AgentError.t()
          | __MODULE__.AgentPaused.t()
          | __MODULE__.AgentRetry.t()
          | __MODULE__.ToolCall.t()
          | __MODULE__.ToolResult.t()
          | __MODULE__.DiscoveredProjectRule.t()
          | __MODULE__.DiscoveredProjectStructure.t()

  @interaction_modules [
    __MODULE__.UserMessage,
    __MODULE__.AgentResponse,
    __MODULE__.AgentSpawned,
    __MODULE__.AgentCompleted,
    __MODULE__.AgentError,
    __MODULE__.AgentPaused,
    __MODULE__.AgentRetry,
    __MODULE__.ToolCall,
    __MODULE__.ToolResult,
    __MODULE__.DiscoveredProjectRule,
    __MODULE__.DiscoveredProjectStructure
  ]

  @doc """
  Returns the list of all interaction type modules.
  """
  def interaction_modules, do: @interaction_modules

  alias FrontmanServer.Image
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

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil

    def from_map(data) when is_map(data) do
      %__MODULE__{
        id: data["id"],
        node: data["node"],
        image: data["image"],
        is_dsl: data["is_dsl"] || true
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

    def from_map(%{blob: blob, mime_type: mime_type})
        when is_binary(blob) and is_binary(mime_type),
        do: %__MODULE__{blob: blob, mime_type: mime_type}

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

    def from_map(%{x: x, y: y, width: w, height: h})
        when is_number(x) and is_number(y) and is_number(w) and is_number(h),
        do: %__MODULE__{x: x / 1, y: y / 1, width: w / 1, height: h / 1}

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

    alias FrontmanServer.Tasks.Interaction

    @spec from_map(map() | nil) :: t() | nil
    def from_map(nil), do: nil

    def from_map(data) when is_map(data) do
      file = Interaction.get_flex(data, "file")
      line = Interaction.get_flex(data, "line")
      column = Interaction.get_flex(data, "column")

      if is_binary(file) and is_integer(line) and is_integer(column) do
        %__MODULE__{
          file: file,
          line: line,
          column: column,
          component_name: Interaction.get_flex(data, "component_name"),
          component_props: Interaction.get_flex(data, "component_props"),
          parent: from_map(Interaction.get_flex(data, "parent"))
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
      url = data["url"]

      case url do
        url when is_binary(url) ->
          %__MODULE__{
            url: url,
            viewport_width: data["viewport_width"],
            viewport_height: data["viewport_height"],
            device_pixel_ratio: data["device_pixel_ratio"],
            title: data["title"],
            color_scheme: data["color_scheme"],
            scroll_y: data["scroll_y"]
          }

        _ ->
          nil
      end
    end

    def from_map(_), do: nil
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
      field(:bounding_box, BoundingBox.t() | nil)
      field(:screenshot, Screenshot.t() | nil)
    end

    alias FrontmanServer.Tasks.Interaction

    @doc """
    Builds an Annotation from a map with string or atom keys.

    Used by both DB deserialization (InteractionSchema.to_struct) and
    ACP content block parsing (via from_meta/2).
    """
    @spec from_map(map()) :: t()
    def from_map(data) when is_map(data) do
      %__MODULE__{
        annotation_id: Interaction.get_flex(data, "annotation_id"),
        annotation_index: Interaction.get_flex(data, "annotation_index"),
        tag_name: Interaction.get_flex(data, "tag_name") || "unknown",
        comment: Interaction.get_flex(data, "comment"),
        file: Interaction.get_flex(data, "file"),
        line: Interaction.get_flex(data, "line"),
        column: Interaction.get_flex(data, "column"),
        component_name: Interaction.get_flex(data, "component_name"),
        component_props: Interaction.get_flex(data, "component_props"),
        parent: ParentLocation.from_map(Interaction.get_flex(data, "parent")),
        css_classes: Interaction.get_flex(data, "css_classes"),
        nearby_text: Interaction.get_flex(data, "nearby_text"),
        bounding_box: BoundingBox.from_map(Interaction.get_flex(data, "bounding_box")),
        screenshot: Screenshot.from_map(Interaction.get_flex(data, "screenshot"))
      }
    end

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
      alias FrontmanServer.Tasks.Interaction

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
        %{"type" => "resource", "resource" => %{"_meta" => %{"current_page" => true} = meta}} ->
          CurrentPage.from_map(meta)

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

      annotations =
        Enum.map(value.annotations, fn ann ->
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

          # Strip nil values to keep JSON compact
          base
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()
        end)

      Jason.Encode.map(
        %{
          type: "user_message",
          id: value.id,
          messages: value.messages,
          timestamp: DateTime.to_iso8601(value.timestamp),
          annotations: annotations,
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

  defmodule AgentError do
    @moduledoc """
    Represents an agent execution ending with an error (failed, crashed, or cancelled).

    Persisted so that reconnecting clients see the final state of every agent turn,
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
      alias FrontmanServer.Tasks.Interaction

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

  defimpl Jason.Encoder, for: AgentError do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "agent_error",
          id: value.id,
          timestamp: DateTime.to_iso8601(value.timestamp),
          error: value.error,
          kind: value.kind,
          retryable: value.retryable,
          category: value.category
        },
        opts
      )
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
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        timestamp: Interaction.now(),
        retried_error_id: retried_error_id
      }
    end
  end

  defimpl Jason.Encoder, for: AgentRetry do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "agent_retry",
          id: value.id,
          timestamp: DateTime.to_iso8601(value.timestamp),
          retried_error_id: value.retried_error_id
        },
        opts
      )
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
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        id: Interaction.new_id(),
        timestamp: Interaction.now(),
        reason: "Tool #{tool_name} timed out after #{timeout_ms}ms (on_timeout: :pause_agent)",
        tool_name: tool_name,
        timeout_ms: timeout_ms
      }
    end
  end

  defimpl Jason.Encoder, for: AgentPaused do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "agent_paused",
          id: value.id,
          timestamp: DateTime.to_iso8601(value.timestamp),
          reason: value.reason,
          tool_name: value.tool_name,
          timeout_ms: value.timeout_ms
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
      alias FrontmanServer.Tasks.Interaction

      %__MODULE__{
        summary: summary,
        timestamp: Interaction.now()
      }
    end
  end

  defimpl Jason.Encoder, for: DiscoveredProjectStructure do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "discovered_project_structure",
          summary: value.summary,
          timestamp: DateTime.to_iso8601(value.timestamp)
        },
        opts
      )
    end
  end

  @doc """
  Retrieves a value from a map supporting both string and atom keys.

  Useful at persistence boundaries where DB JSON comes with string keys
  but in-memory structs use atoms.
  """
  @spec get_flex(map(), String.t()) :: term()
  def get_flex(map, key) when is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
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
  Checks whether all tool_calls from the last AgentResponse have matching
  ToolResult interactions.

  Returns `true` when there is no pending AgentResponse, or when every
  tool_call in the last AgentResponse has a corresponding later ToolResult.

  Used to gate re-execution after a late-arriving interactive tool result:
  we only restart the agent loop when ALL tool results are present so the
  conversation is valid for the LLM.
  """
  @spec all_pending_tools_resolved?(list(t())) :: boolean()
  def all_pending_tools_resolved?(interactions) do
    case last_agent_response_with_following_interactions(interactions) do
      {tool_calls, following_interactions} ->
        expected_ids = MapSet.new(tool_calls, &get_field(&1, "id"))

        result_ids =
          following_interactions
          |> Enum.filter(&match?(%ToolResult{}, &1))
          |> MapSet.new(& &1.tool_call_id)

        MapSet.subset?(expected_ids, result_ids)

      nil ->
        true
    end
  end

  defp last_agent_response_with_following_interactions(interactions) do
    interactions
    |> Enum.with_index()
    |> Enum.filter(&match?({%AgentResponse{}, _index}, &1))
    |> List.last()
    |> case do
      {%AgentResponse{metadata: meta}, index} ->
        case get_field(meta || %{}, "tool_calls") do
          tool_calls when is_list(tool_calls) and tool_calls != [] ->
            {tool_calls, Enum.drop(interactions, index + 1)}

          _ ->
            nil
        end

      nil ->
        nil
    end
  end

  @doc """
  Converts interactions to LLM message format.

  This is the boundary translation from Tasks domain (Interactions)
  to Agents domain (LLM messages). Conversation messages include
  UserMessage, AgentResponse, and ToolResult.
  ToolCall interactions are excluded as they're embedded in AgentResponse metadata.

  Interactions are expected to be ordered by the persisted sequence column,
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
  # Explicit false for every non-conversation type — no catch-all, so adding
  # a new Interaction type without a clause here will crash immediately and
  # surface the omission instead of silently falling through.
  defp conversation_message?(%ToolCall{}), do: false
  defp conversation_message?(%AgentSpawned{}), do: false
  defp conversation_message?(%AgentCompleted{}), do: false
  defp conversation_message?(%AgentError{}), do: false
  defp conversation_message?(%AgentPaused{}), do: false
  defp conversation_message?(%AgentRetry{}), do: false
  defp conversation_message?(%DiscoveredProjectRule{}), do: false
  defp conversation_message?(%DiscoveredProjectStructure{}), do: false

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
          [SwarmAi.Message.user(content)]
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
            [SwarmAi.Message.user(result)]
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
      |> append_annotations(msg.annotations)
      |> append_image_attachment_context(msg.images)

    content_parts =
      text_content
      |> build_text_parts()
      |> append_annotation_screenshots(msg.annotations)
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

  # Append annotation location info to user message text
  defp append_annotations(text, []), do: text

  defp append_annotations(text, annotations) when is_list(annotations) do
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

  # Append image attachment URIs so the LLM knows they can be referenced via image_ref.
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
          The following images were attached by the user and can be used via image_ref:
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

  defp build_text_parts(""), do: []
  defp build_text_parts(text), do: [ContentPart.text(text)]

  # Append annotation screenshots as image content parts
  defp append_annotation_screenshots(parts, []), do: parts

  defp append_annotation_screenshots(parts, annotations) when is_list(annotations) do
    screenshot_parts =
      annotations
      |> Enum.filter(&(&1.screenshot != nil))
      |> Enum.flat_map(fn ann ->
        %{blob: base64_data, mime_type: mime_type} = ann.screenshot

        case Base.decode64(base64_data) do
          {:ok, decoded_data} -> [ContentPart.image(decoded_data, mime_type)]
          :error -> []
        end
      end)

    parts ++ screenshot_parts
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

  defp build_assistant_message(content, tool_calls, meta) do
    encrypted_reasoning = filter_encrypted_reasoning(get_flexible(meta, :reasoning_details))
    response_metadata = build_response_metadata_for_message(meta)

    if tool_calls in [nil, []] and response_metadata == %{} and is_nil(encrypted_reasoning) do
      ReqLLM.Context.assistant(content)
    else
      %ReqLLM.Message{
        role: :assistant,
        content: [ContentPart.text(content)],
        tool_calls: tool_calls,
        metadata: response_metadata,
        reasoning_details: encrypted_reasoning
      }
    end
  end

  defp build_response_metadata_for_message(meta) do
    response_id = get_flexible(meta, :response_id)
    phase = get_flexible(meta, :phase)
    phase_items = get_flexible(meta, :phase_items)

    metadata = %{}

    metadata =
      if is_binary(response_id) do
        Map.put(metadata, :response_id, response_id)
      else
        metadata
      end

    metadata =
      if is_binary(phase) do
        Map.put(metadata, :phase, phase)
      else
        metadata
      end

    if is_list(phase_items) and phase_items != [] do
      Map.put(metadata, :phase_items, phase_items)
    else
      metadata
    end
  end

  defp filter_encrypted_reasoning(nil), do: nil
  defp filter_encrypted_reasoning(details) when not is_list(details), do: nil

  defp filter_encrypted_reasoning(details) do
    case Enum.filter(details, &(&1["type"] == "reasoning.encrypted")) do
      [] -> nil
      filtered -> filtered
    end
  end

  defp extract_image_from_result(tool_name, result) when is_map(result) do
    with {image_field, text_fields} <- Image.image_tool_config(tool_name),
         data_url when is_binary(data_url) <- get_field(result, image_field),
         {:ok, binary, mime} <- Image.decode_data_url(data_url) do
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

  @doc """
  Checks if any user messages in the interactions contain annotations.
  """
  @spec has_annotations?(list(t())) :: boolean()
  def has_annotations?(interactions) do
    Enum.any?(interactions, fn
      %UserMessage{annotations: anns} when anns != [] -> true
      _ -> false
    end)
  end
end
