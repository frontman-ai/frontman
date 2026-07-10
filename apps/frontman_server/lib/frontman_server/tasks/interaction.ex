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

  @interaction_modules [
    __MODULE__.UserMessage,
    __MODULE__.TurnStarted,
    __MODULE__.AgentResponse,
    __MODULE__.AgentCompleted,
    __MODULE__.AgentError,
    __MODULE__.AgentPaused,
    __MODULE__.AgentRetry,
    __MODULE__.ToolCall,
    __MODULE__.ToolResult,
    __MODULE__.DiscoveredProjectRule,
    __MODULE__.DiscoveredProjectStructure
  ]

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Tasks.Interaction
  alias SwarmAi.Message, as: SwarmMessage
  alias SwarmAi.Message.ContentPart, as: SwarmContentPart
  alias SwarmAi.ToolCall, as: SwarmToolCall

  defp put_timestamp(changeset) do
    case Ecto.Changeset.get_field(changeset, :timestamp) do
      nil -> Ecto.Changeset.put_change(changeset, :timestamp, now())
      _timestamp -> changeset
    end
  end

  def cast_timestamped(schema, attrs, fields) do
    schema
    |> Ecto.Changeset.cast(attrs, fields)
    |> put_timestamp()
  end

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

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :id, :string
      field :node, :string
      field :image, :string
      field :is_dsl, :boolean, default: true
    end

    def changeset(%__MODULE__{} = figma_node, attrs) do
      cast(figma_node, attrs, [:id, :node, :image, :is_dsl])
    end
  end

  defmodule Screenshot do
    @moduledoc """
    Base64-encoded screenshot with MIME type.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @derive Jason.Encoder
    @primary_key false
    embedded_schema do
      field :blob, :string
      field :mime_type, :string
    end

    def changeset(%__MODULE__{} = screenshot, attrs) do
      cast(screenshot, attrs, [:blob, :mime_type])
    end
  end

  defmodule BoundingBox do
    @moduledoc """
    Bounding box of an element in viewport coordinates.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @derive Jason.Encoder
    @primary_key false
    embedded_schema do
      field :x, :float
      field :y, :float
      field :width, :float
      field :height, :float
    end

    def changeset(%__MODULE__{} = bounding_box, attrs) do
      cast(bounding_box, attrs, [:x, :y, :width, :height])
    end
  end

  defmodule ParentLocation do
    @moduledoc """
    Source location of a parent component in the React tree.

    Forms a recursive chain via the `parent` field.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @derive Jason.Encoder
    @primary_key false
    embedded_schema do
      field :file, :string
      field :line, :integer
      field :column, :integer
      field :component_name, :string
      field :component_props, :map
      embeds_one :parent, __MODULE__
    end

    def changeset(%__MODULE__{} = parent_location, attrs) do
      parent_location
      |> cast(attrs, [:file, :line, :column, :component_name, :component_props])
      |> cast_embed(:parent, with: &__MODULE__.changeset/2)
    end
  end

  defmodule UserImage do
    @moduledoc """
    A user-uploaded image or PDF attachment.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @derive Jason.Encoder
    @primary_key false
    embedded_schema do
      field :blob, :string
      field :mime_type, :string
      field :filename, :string
      field :uri, :string
    end

    def changeset(%__MODULE__{} = user_image, attrs) do
      cast(user_image, attrs, [:blob, :mime_type, :filename, :uri])
    end
  end

  defmodule CurrentPage do
    @moduledoc """
    Page context from the client: URL, viewport, DPR, title, color scheme, scroll position.
    """

    alias FrontmanServer.CurrentPageContext

    use Ecto.Schema
    import Ecto.Changeset

    @derive Jason.Encoder
    @primary_key false
    embedded_schema do
      field :url, :string
      field :viewport_width, :integer
      field :viewport_height, :integer
      field :device_pixel_ratio, :float
      field :title, :string
      field :color_scheme, :string
      field :scroll_y, :integer
    end

    def changeset(%__MODULE__{} = current_page, attrs) do
      cast(current_page, attrs, [
        :url,
        :viewport_width,
        :viewport_height,
        :device_pixel_ratio,
        :title,
        :color_scheme,
        :scroll_y
      ])
    end

    def attrs_from_acp_meta(meta) when is_map(meta) do
      case CurrentPageContext.fields_from_current_page_meta(meta) do
        %{url: url} = fields ->
          %{
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

    def attrs_from_acp_meta(_), do: nil
  end

  defmodule Annotation do
    @moduledoc """
    Represents a single annotated element from the client.

    Contains source location, screenshot, and enrichment data.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @derive Jason.Encoder
    @primary_key false
    embedded_schema do
      field :annotation_id, :string
      field :annotation_index, :integer
      field :tag_name, :string
      field :selector, :string
      field :comment, :string
      field :file, :string
      field :line, :integer
      field :column, :integer
      field :component_name, :string
      field :component_props, :map
      embeds_one :parent, ParentLocation
      field :css_classes, :string
      field :nearby_text, :string
      field :metadata, :map, default: %{}
      embeds_one :bounding_box, BoundingBox
      embeds_one :screenshot, Screenshot
    end

    def changeset(%__MODULE__{} = annotation, attrs) do
      annotation
      |> cast(attrs, [
        :annotation_id,
        :annotation_index,
        :tag_name,
        :selector,
        :comment,
        :file,
        :line,
        :column,
        :component_name,
        :component_props,
        :css_classes,
        :nearby_text,
        :metadata
      ])
      |> cast_embed(:parent, with: &ParentLocation.changeset/2)
      |> cast_embed(:bounding_box, with: &BoundingBox.changeset/2)
      |> cast_embed(:screenshot, with: &Screenshot.changeset/2)
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
      selector
      tag_name
    )

    def attrs_from_acp_meta(data) when is_map(data) do
      %{
        annotation_id: data["annotation_id"],
        annotation_index: data["annotation_index"],
        tag_name: data["tag_name"] || "unknown",
        selector: data["selector"],
        comment: data["comment"],
        file: data["file"],
        line: data["line"],
        column: data["column"],
        component_name: data["component_name"],
        component_props: data["component_props"],
        parent: data["parent"],
        css_classes: data["css_classes"],
        nearby_text: data["nearby_text"],
        metadata: metadata_from_map(data),
        bounding_box: data["bounding_box"],
        screenshot: data["screenshot"]
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
    def from_meta(meta, screenshot_map \\ %{}) when is_map(meta) do
      attrs = attrs_from_acp_meta(meta)
      %{attrs | screenshot: Map.get(screenshot_map, attrs.annotation_id)}
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

    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :model, :string
      field :messages, {:array, :string}, default: []
      embeds_many :annotations, Annotation
      embeds_one :selected_figma_node, FigmaNode
      embeds_many :images, UserImage
      embeds_one :current_page, CurrentPage
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = user_message, attrs) do
      user_message
      |> Interaction.cast_timestamped(attrs, [:id, :timestamp, :model, :messages])
      |> cast_embed(:annotations, with: &Annotation.changeset/2)
      |> cast_embed(:selected_figma_node, with: &FigmaNode.changeset/2)
      |> cast_embed(:images, with: &UserImage.changeset/2)
      |> cast_embed(:current_page, with: &CurrentPage.changeset/2)
    end

    def attrs(content_blocks, model \\ nil) do
      with {:ok, messages} <- extract_messages(content_blocks) do
        {:ok,
         %{
           model: model,
           messages: messages,
           annotations: extract_annotations(content_blocks),
           selected_figma_node: extract_selected_figma_node(content_blocks),
           images: extract_user_images(content_blocks),
           current_page: extract_current_page(content_blocks)
         }}
      end
    end

    # Extract text messages from content blocks
    defp extract_messages(content_blocks) do
      content_blocks
      |> Enum.reduce_while({:ok, []}, fn
        %{"type" => "text", "text" => text}, {:ok, messages}
        when is_binary(text) and text != "" ->
          {:cont, {:ok, [text | messages]}}

        %{"type" => "text"}, {:ok, _messages} ->
          {:halt,
           {:error,
            {:invalid_content_block, "text content block must include non-empty string text"}}}

        _block, {:ok, messages} ->
          {:cont, {:ok, messages}}
      end)
      |> case do
        {:ok, messages} -> {:ok, Enum.reverse(messages)}
        {:error, reason} -> {:error, reason}
      end
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

        case {annotation_id, inner["blob"]} do
          {annotation_id, blob} when is_binary(annotation_id) and is_binary(blob) ->
            Map.put(acc, annotation_id, %{
              "blob" => blob,
              "mime_type" => inner["mimeType"] || "image/jpeg"
            })

          {_annotation_id, _blob} ->
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

    defp extract_current_page(content_blocks) do
      Enum.find_value(content_blocks, fn
        %{"type" => "resource", "resource" => %{"_meta" => meta}} ->
          CurrentPage.attrs_from_acp_meta(meta)

        _ ->
          nil
      end)
    end

    defp extract_user_images(content_blocks) do
      content_blocks
      |> Enum.filter(&user_image_block?/1)
      |> Enum.map(fn %{"type" => "resource", "resource" => resource} ->
        inner = Map.get(resource, "resource", %{})
        meta = Map.get(resource, "_meta", %{})

        # UserImage fields come from both _meta (filename) and inner resource (blob, mimeType, uri).
        # Merge into the embedded schema attrs.
        %{
          "blob" => inner["blob"] || "",
          "mime_type" => inner["mimeType"] || "image/png",
          "filename" => meta["filename"] || "attachment",
          "uri" => inner["uri"]
        }
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

    use Ecto.Schema
    import Ecto.Changeset

    @fields [:id, :content, :timestamp, :metadata, :response_id, :phase, :phase_items]
    @usage_fields [
      :input_tokens,
      :output_tokens,
      :reasoning_tokens,
      :cached_tokens,
      :cache_creation_tokens,
      :total_tokens
    ]

    embedded_schema do
      field :content, :string
      field :metadata, :map, default: %{}
      field :response_id, :string
      field :phase, :string
      field :phase_items, {:array, :map}

      embeds_one :usage, Usage, primary_key: false do
        field :input_tokens, :integer
        field :output_tokens, :integer
        field :reasoning_tokens, :integer
        field :cached_tokens, :integer
        field :cache_creation_tokens, :integer
        field :total_tokens, :integer
      end

      field :timestamp, :utc_datetime_usec
    end

    def attrs(content, metadata \\ %{}, usage \\ nil) do
      {response_fields, metadata} = split_response_metadata(metadata)

      attrs = %{
        content: content,
        metadata: metadata,
        response_id: response_fields.response_id,
        phase: response_fields.phase,
        phase_items: response_fields.phase_items
      }

      case usage do
        nil -> attrs
        usage -> Map.put(attrs, :usage, usage_params(usage))
      end
    end

    def attrs_from_llm_response(%SwarmAi.LLM.Response{} = response) do
      attrs = attrs(response.content, llm_response_metadata(response), response.usage)

      %__MODULE__{}
      |> changeset(attrs)
      |> apply_action!(:insert)

      attrs
    end

    def changeset(%__MODULE__{} = agent_response, attrs) do
      agent_response
      |> Interaction.cast_timestamped(attrs, @fields)
      |> cast_embed(:usage, with: &usage_changeset/2, invalid_message: "must be a map")
      |> validate_metadata_string(attrs, :response_id)
      |> validate_metadata_string(attrs, :phase)
    end

    defp validate_metadata_string(changeset, attrs, field) do
      case Map.fetch(attrs, field) do
        {:ok, nil} ->
          changeset

        {:ok, value} when is_binary(value) ->
          changeset

        {:ok, _value} ->
          add_error(changeset, field, "must be a string")

        :error ->
          changeset
      end
    end

    defp usage_changeset(%__MODULE__.Usage{} = usage, attrs) do
      changeset = cast(usage, attrs, @usage_fields)

      Enum.reduce(@usage_fields, changeset, fn field, acc ->
        validate_number(acc, field, greater_than_or_equal_to: 0)
      end)
    end

    defp split_response_metadata(metadata) when is_map(metadata) do
      response_fields = %{
        response_id: metadata_value(metadata, :response_id),
        phase: metadata_value(metadata, :phase),
        phase_items: metadata_value(metadata, :phase_items)
      }

      metadata =
        Map.drop(metadata, [
          :response_id,
          "response_id",
          :phase,
          "phase",
          :phase_items,
          "phase_items"
        ])

      {response_fields, metadata}
    end

    defp metadata_value(metadata, key) do
      case Map.fetch(metadata, key) do
        {:ok, value} -> value
        :error -> Map.get(metadata, Atom.to_string(key))
      end
    end

    defp usage_params(%__MODULE__.Usage{} = usage), do: Map.from_struct(usage)
    defp usage_params(usage) when is_map(usage), do: usage
    defp usage_params(usage), do: usage

    defp llm_response_metadata(response) do
      meta = response.metadata || %{}

      %{
        "tool_calls" => stored_tool_calls(response.tool_calls),
        "reasoning_details" => non_empty(response.reasoning_details),
        "response_id" => metadata_value(meta, :response_id),
        "phase" => metadata_value(meta, :phase),
        "phase_items" => non_empty(metadata_value(meta, :phase_items))
      }
      |> Map.reject(fn {_key, value} -> is_nil(value) end)
    end

    defp stored_tool_calls(tool_calls) when is_list(tool_calls) and tool_calls != [] do
      Enum.map(tool_calls, fn %SwarmAi.ToolCall{id: id, name: name, arguments: arguments} ->
        %{"id" => id, "name" => name, "arguments" => arguments}
      end)
    end

    defp stored_tool_calls(_tool_calls), do: nil

    defp non_empty(list) when is_list(list) and list != [], do: list
    defp non_empty(_list), do: nil
  end

  defmodule TurnStarted do
    @moduledoc """
    Represents a normal agent turn starting from accepted user messages.

    The persisted row turn_number identifies the execution turn; user_message_ids
    records the accepted messages included in that turn in order.
    """

    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :user_message_ids, {:array, :string}
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = turn_started, attrs) do
      turn_started
      |> Interaction.cast_timestamped(attrs, [:id, :timestamp, :user_message_ids])
      |> validate_required([:user_message_ids])
      |> validate_length(:user_message_ids, min: 1)
    end
  end

  defmodule AgentCompleted do
    @moduledoc """
    Represents an agent finishing its work.
    """

    use Ecto.Schema

    embedded_schema do
      field :result, :map
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = agent_completed, attrs) do
      Interaction.cast_timestamped(agent_completed, attrs, [:id, :timestamp, :result])
    end
  end

  defmodule AgentError do
    @moduledoc """
    Represents an agent execution ending with an error (failed, crashed, or cancelled).

    Persisted so that reconnecting clients see the terminal interaction for every agent run,
    even when the channel process was dead when the error occurred.
    """

    use Ecto.Schema

    embedded_schema do
      field :error, :string
      field :kind, :string, default: "failed"
      field :retryable, :boolean, default: false
      field :category, :string, default: "unknown"
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = agent_error, attrs) do
      Interaction.cast_timestamped(agent_error, attrs, [
        :id,
        :timestamp,
        :error,
        :kind,
        :retryable,
        :category
      ])
    end
  end

  defmodule AgentRetry do
    @moduledoc """
    Records a user-initiated retry after an AgentError.
    Persisted for observability — lets you measure retry success rates.
    """

    use Ecto.Schema

    embedded_schema do
      field :retried_error_id, :string
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = agent_retry, attrs) do
      Interaction.cast_timestamped(agent_retry, attrs, [:id, :timestamp, :retried_error_id])
    end
  end

  defmodule AgentPaused do
    @moduledoc """
    Recorded when the agent loop is paused due to a tool timeout with
    `on_timeout: :pause_agent`. Stored as an interaction so reconnecting
    clients and the debug-task tool can see why the agent stopped.
    """

    use Ecto.Schema

    embedded_schema do
      field :reason, :string
      field :tool_name, :string
      field :timeout_ms, :integer
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = agent_paused, attrs) do
      Interaction.cast_timestamped(agent_paused, attrs, [
        :id,
        :timestamp,
        :reason,
        :tool_name,
        :timeout_ms
      ])
    end
  end

  defmodule ToolCall do
    @moduledoc """
    Represents an LLM requesting a tool execution.
    """

    use Ecto.Schema

    embedded_schema do
      field :tool_call_id, :string
      field :tool_name, :string
      field :arguments, :map
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = tool_call, attrs) do
      Interaction.cast_timestamped(tool_call, attrs, [
        :id,
        :tool_call_id,
        :tool_name,
        :arguments,
        :timestamp
      ])
    end

    def attrs(%SwarmAi.ToolCall{} = tc) do
      case SwarmAi.ToolCall.parse_arguments(tc) do
        {:ok, arguments} ->
          {:ok,
           %{
             tool_call_id: tc.id,
             tool_name: tc.name,
             arguments: SwarmAi.SchemaTransformer.strip_nulls(arguments)
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

    use Ecto.Schema

    embedded_schema do
      field :tool_call_id, :string
      field :tool_name, :string
      field :result, :map
      field :is_error, :boolean, default: false
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = tool_result, attrs) do
      Interaction.cast_timestamped(tool_result, attrs, [
        :id,
        :tool_call_id,
        :tool_name,
        :result,
        :is_error,
        :timestamp
      ])
    end

    def attrs(tool_call_data, result, is_error \\ false) do
      %{
        tool_call_id: tool_call_data.id,
        tool_name: tool_call_data.name,
        result: result,
        is_error: is_error
      }
    end
  end

  defmodule DiscoveredProjectRule do
    @moduledoc """
    Represents a discovered project rule file (e.g., AGENTS.md, CLAUDE.md).

    These are task-scoped (not agent-scoped) and accumulate as the agent
    explores the codebase. They are injected into LLM messages as context.
    """

    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :path, :string
      field :content, :string
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = discovered_project_rule, attrs) do
      Interaction.cast_timestamped(discovered_project_rule, attrs, [:path, :content, :timestamp])
    end
  end

  defmodule DiscoveredProjectStructure do
    @moduledoc """
    Represents a discovered project structure summary (from list_tree during MCP init).

    Stored once per task during initialization. Injected into the system prompt
    so the agent always has structural awareness of the project.
    """

    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :summary, :string
      field :timestamp, :utc_datetime_usec
    end

    def changeset(%__MODULE__{} = discovered_project_structure, attrs) do
      Interaction.cast_timestamped(discovered_project_structure, attrs, [:summary, :timestamp])
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

  def to_json_map(%AgentResponse{} = value) do
    value
    |> Map.from_struct()
    |> Map.update!(:usage, &usage_json_map/1)
    |> stringify_timestamp()
  end

  def to_json_map(%UserMessage{} = value) do
    %{
      id: value.id,
      model: value.model,
      messages: value.messages,
      timestamp: timestamp_json(value.timestamp),
      annotations: Enum.map(value.annotations, &annotation_json_map/1),
      selected_figma_node: selected_figma_node_json_map(value.selected_figma_node),
      images: Enum.map(value.images, &user_image_json_map/1)
    }
  end

  def to_json_map(value) when is_struct(value) do
    value
    |> Map.from_struct()
    |> stringify_timestamp()
  end

  defp annotation_json_map(ann) do
    base = %{
      annotation_id: ann.annotation_id,
      annotation_index: ann.annotation_index,
      tag_name: ann.tag_name,
      selector: ann.selector,
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

  defp usage_json_map(nil), do: nil

  defp usage_json_map(%AgentResponse.Usage{} = usage) do
    usage
    |> Map.from_struct()
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp usage_json_map(usage) when is_map(usage) do
    Map.reject(usage, fn {_key, value} -> is_nil(value) end)
  end

  defp timestamp_json(%DateTime{} = timestamp), do: DateTime.to_iso8601(timestamp)
  defp timestamp_json(timestamp), do: timestamp

  defp stringify_timestamp(%{timestamp: %DateTime{} = timestamp} = data) do
    %{data | timestamp: DateTime.to_iso8601(timestamp)}
  end

  defp stringify_timestamp(data), do: data

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
  def to_swarm_messages(interactions) when is_list(interactions) do
    Enum.flat_map(interactions, &to_swarm_message/1)
  end

  defp to_swarm_message(%UserMessage{} = msg) do
    prompt_text = user_prompt_text(msg)
    content_parts = build_user_content_parts(prompt_text, msg)

    [build_swarm_user_message(content_parts)]
  end

  defp to_swarm_message(
         %AgentResponse{content: nil, metadata: %{"tool_calls" => [_ | _]} = meta} = msg
       ) do
    [
      %SwarmMessage.Assistant{
        content: [],
        tool_calls: swarm_tool_calls(meta["tool_calls"]),
        metadata: swarm_metadata(msg),
        reasoning_details: filter_encrypted_reasoning(meta["reasoning_details"])
      }
    ]
  end

  defp to_swarm_message(%AgentResponse{content: content, metadata: metadata} = msg)
       when is_binary(content) do
    meta = metadata || %{}

    [
      %SwarmMessage.Assistant{
        content: [SwarmContentPart.text(content)],
        tool_calls: swarm_tool_calls(meta["tool_calls"]),
        metadata: swarm_metadata(msg),
        reasoning_details: filter_encrypted_reasoning(meta["reasoning_details"])
      }
    ]
  end

  defp to_swarm_message(%ToolResult{result: %{"content" => [_ | _] = content}} = result) do
    [
      %SwarmMessage.Tool{
        content: Enum.map(content, &tool_result_content_part/1),
        tool_call_id: result.tool_call_id,
        name: result.tool_name
      }
    ]
  end

  defp to_swarm_message(%ToolCall{}), do: []
  defp to_swarm_message(%TurnStarted{}), do: []
  defp to_swarm_message(%AgentCompleted{}), do: []
  defp to_swarm_message(%AgentError{}), do: []
  defp to_swarm_message(%AgentPaused{}), do: []
  defp to_swarm_message(%AgentRetry{}), do: []
  defp to_swarm_message(%DiscoveredProjectRule{}), do: []
  defp to_swarm_message(%DiscoveredProjectStructure{}), do: []

  def user_prompt_text(%UserMessage{} = msg) do
    msg.messages
    |> Enum.join("\n\n")
    |> CurrentPageContext.append_prompt_section(msg.current_page)
    |> append_annotation_context(msg.annotations)
    |> append_attachment_context(msg.images)
  end

  defp build_user_content_parts(prompt_text, %UserMessage{} = msg) do
    prompt_text
    |> text_parts()
    |> append_annotation_screenshot_parts(msg.annotations)
    |> append_user_attachment_parts(msg.images)
  end

  defp text_parts(""), do: []
  defp text_parts(text), do: [SwarmContentPart.text(text)]

  defp tool_result_content_part(%{"type" => "text", "text" => text}),
    do: SwarmContentPart.text(text)

  defp tool_result_content_part(%{"type" => "image", "data" => data, "mimeType" => mime_type}),
    do: SwarmContentPart.image(Base.decode64!(data), mime_type)

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
      annotation_string_field(ann.selector, "CSS Selector"),
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

  defp swarm_metadata(%AgentResponse{} = msg) do
    %{
      response_id: msg.response_id,
      phase: msg.phase,
      phase_items: msg.phase_items
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
