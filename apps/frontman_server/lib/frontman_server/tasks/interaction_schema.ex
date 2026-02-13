defmodule FrontmanServer.Tasks.InteractionSchema do
  @moduledoc """
  Ecto schema for persisted interactions.

  Interactions are stored with a type discriminator and JSONB data field.
  The `type` field indicates which interaction struct to deserialize to.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.TaskSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "interactions" do
    field(:type, :string)
    field(:data, :map)
    # Monotonic sequence for deterministic ordering (avoids DB insert race conditions)
    field(:sequence, :integer)

    belongs_to(:task, TaskSchema)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @type t :: %__MODULE__{}

  @doc """
  Changeset for creating an interaction from a domain struct.
  Extracts type from struct module name and data from struct fields.
  The sequence field is extracted from the interaction struct for deterministic ordering.
  """
  @spec create_changeset(String.t(), struct()) :: Ecto.Changeset.t()
  def create_changeset(task_id, interaction) do
    type = interaction.__struct__ |> Module.split() |> List.last() |> Macro.underscore()

    attrs = %{
      task_id: task_id,
      type: type,
      data: Map.from_struct(interaction),
      sequence: Map.get(interaction, :sequence)
    }

    %__MODULE__{}
    |> cast(attrs, [:task_id, :type, :data, :sequence])
    |> validate_required([:task_id, :type, :data, :sequence])
    |> validate_inclusion(:type, Interaction.known_type_strings())
    |> foreign_key_constraint(:task_id)
  end

  # Query helpers

  @spec for_task(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def for_task(query \\ __MODULE__, task_id) do
    from(i in query, where: i.task_id == ^task_id)
  end

  @doc """
  Orders interactions by sequence number for deterministic ordering.
  Falls back to inserted_at for legacy rows without sequence (during migration period).
  """
  @spec ordered(Ecto.Queryable.t()) :: Ecto.Query.t()
  def ordered(query \\ __MODULE__) do
    from(i in query, order_by: [asc: coalesce(i.sequence, 0), asc: i.inserted_at])
  end

  # Deprecated: Use ordered/1 instead
  @spec ordered_by_inserted(Ecto.Queryable.t()) :: Ecto.Query.t()
  def ordered_by_inserted(query \\ __MODULE__) do
    ordered(query)
  end

  # --- JSONB to Domain Struct Conversion ---

  @doc """
  Converts a persisted InteractionSchema to its domain struct.
  """
  @spec to_struct(t()) :: Interaction.t()
  def to_struct(%__MODULE__{type: "user_message", data: data, sequence: sequence}) do
    %Interaction.UserMessage{
      id: data["id"],
      sequence: sequence || data["sequence"] || 0,
      timestamp: parse_datetime(data["timestamp"]),
      messages: data["messages"] || [],
      annotations: parse_annotations(data["annotations"]),
      selected_figma_node: parse_figma_node(data["selected_figma_node"]),
      images: parse_images(data["images"]),
      current_page: parse_current_page(data["current_page"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_response", data: data, sequence: sequence}) do
    %Interaction.AgentResponse{
      id: data["id"],
      sequence: sequence || data["sequence"] || 0,
      content: data["content"],
      timestamp: parse_datetime(data["timestamp"]),
      metadata: data["metadata"]
    }
  end

  def to_struct(%__MODULE__{type: "tool_call", data: data, sequence: sequence}) do
    %Interaction.ToolCall{
      id: data["id"],
      sequence: sequence || data["sequence"] || 0,
      tool_call_id: data["tool_call_id"],
      tool_name: data["tool_name"],
      arguments: data["arguments"] || %{},
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "tool_result", data: data, sequence: sequence}) do
    %Interaction.ToolResult{
      id: data["id"],
      sequence: sequence || data["sequence"] || 0,
      tool_call_id: data["tool_call_id"],
      tool_name: data["tool_name"],
      result: data["result"],
      is_error: data["is_error"] || false,
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "discovered_project_rule", data: data, sequence: sequence}) do
    %Interaction.DiscoveredProjectRule{
      path: data["path"],
      sequence: sequence || data["sequence"] || 0,
      content: data["content"],
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{
        type: "discovered_project_structure",
        data: data,
        sequence: sequence
      }) do
    %Interaction.DiscoveredProjectStructure{
      summary: data["summary"],
      sequence: sequence || data["sequence"] || 0,
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_spawned", data: data, sequence: sequence}) do
    %Interaction.AgentSpawned{
      id: data["id"],
      sequence: sequence || data["sequence"] || 0,
      config: data["config"] || %{},
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_completed", data: data, sequence: sequence}) do
    %Interaction.AgentCompleted{
      id: data["id"],
      sequence: sequence || data["sequence"] || 0,
      result: data["result"],
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: type}) do
    raise "Unknown interaction type: #{type}"
  end

  @spec parse_datetime(DateTime.t() | String.t() | nil) :: DateTime.t() | nil
  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  # Parse annotations list from stored data
  @spec parse_annotations(list() | nil) :: list(Interaction.Annotation.t())
  defp parse_annotations(nil), do: []

  defp parse_annotations(annotations) when is_list(annotations) do
    Enum.map(annotations, &parse_annotation/1)
  end

  defp parse_annotations(_), do: []

  defp parse_annotation(data) when is_map(data) do
    %Interaction.Annotation{
      annotation_id: get_flex(data, "annotation_id"),
      annotation_index: get_flex(data, "annotation_index"),
      tag_name: get_flex(data, "tag_name") || "unknown",
      comment: get_flex(data, "comment"),
      file: get_flex(data, "file"),
      line: get_flex(data, "line"),
      column: get_flex(data, "column"),
      component_name: get_flex(data, "component_name"),
      component_props: get_flex(data, "component_props"),
      parent: parse_parent_chain(get_flex(data, "parent")),
      css_classes: get_flex(data, "css_classes"),
      nearby_text: get_flex(data, "nearby_text"),
      bounding_box: parse_bounding_box(get_flex(data, "bounding_box")),
      screenshot: parse_annotation_screenshot(get_flex(data, "screenshot"))
    }
  end

  # Get value from map supporting both string and atom keys
  defp get_flex(map, key) when is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end

  defp parse_annotation_screenshot(nil), do: nil

  defp parse_annotation_screenshot(%{"blob" => blob, "mime_type" => mime_type})
       when is_binary(blob) and is_binary(mime_type) do
    %{blob: blob, mime_type: mime_type}
  end

  defp parse_annotation_screenshot(%{blob: blob, mime_type: mime_type})
       when is_binary(blob) and is_binary(mime_type) do
    %{blob: blob, mime_type: mime_type}
  end

  defp parse_annotation_screenshot(_), do: nil

  defp parse_bounding_box(nil), do: nil

  defp parse_bounding_box(%{"x" => x, "y" => y, "width" => w, "height" => h})
       when is_number(x) and is_number(y) and is_number(w) and is_number(h) do
    %{x: x / 1, y: y / 1, width: w / 1, height: h / 1}
  end

  defp parse_bounding_box(%{x: x, y: y, width: w, height: h})
       when is_number(x) and is_number(y) and is_number(w) and is_number(h) do
    %{x: x / 1, y: y / 1, width: w / 1, height: h / 1}
  end

  defp parse_bounding_box(_), do: nil

  @spec parse_parent_chain(map() | nil) :: map() | nil
  defp parse_parent_chain(nil), do: nil

  defp parse_parent_chain(parent) when is_map(parent) do
    file = get_flex(parent, "file")
    line = get_flex(parent, "line")
    column = get_flex(parent, "column")

    if is_binary(file) and is_integer(line) and is_integer(column) do
      %{
        file: file,
        line: line,
        column: column,
        component_name: get_flex(parent, "component_name"),
        component_props: get_flex(parent, "component_props"),
        parent: parse_parent_chain(get_flex(parent, "parent"))
      }
    else
      nil
    end
  end

  defp parse_parent_chain(_), do: nil

  @spec parse_figma_node(map() | nil) :: Interaction.FigmaNode.t() | nil
  defp parse_figma_node(nil), do: nil

  defp parse_figma_node(data) when is_map(data) do
    %Interaction.FigmaNode{
      id: data["id"],
      node: data["node"],
      image: data["image"],
      is_dsl: data["is_dsl"] || true
    }
  end

  # Parse user-uploaded images from stored data
  defp parse_images(nil), do: []

  defp parse_images(images) when is_list(images) do
    Enum.map(images, fn img when is_map(img) ->
      %{
        blob: img["blob"],
        mime_type: img["mime_type"] || "image/png",
        filename: img["filename"] || "attachment",
        uri: img["uri"]
      }
    end)
  end

  defp parse_images(_), do: []

  # Parse current page context from stored data
  @spec parse_current_page(map() | nil) :: Interaction.UserMessage.current_page() | nil
  defp parse_current_page(nil), do: nil

  defp parse_current_page(data) when is_map(data) do
    url = data["url"]

    case url do
      url when is_binary(url) ->
        %{
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

  defp parse_current_page(_), do: nil
end
