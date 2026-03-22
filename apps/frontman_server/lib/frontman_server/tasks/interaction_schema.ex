defmodule FrontmanServer.Tasks.InteractionSchema do
  @moduledoc """
  Ecto schema for persisted interactions.

  Interactions are stored with a type discriminator and JSONB data field.
  The `type` field indicates which interaction struct to deserialize to.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  import FrontmanServer.ChangesetSanitizer

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
  Sequence is computed via `generate_sequence/0` (timestamp + monotonic tiebreaker).
  """
  @spec create_changeset(String.t(), struct()) :: Ecto.Changeset.t()
  def create_changeset(task_id, interaction) do
    type = interaction.__struct__ |> Module.split() |> List.last() |> Macro.underscore()

    attrs = %{
      task_id: task_id,
      type: type,
      data: Map.from_struct(interaction),
      sequence: generate_sequence()
    }

    %__MODULE__{}
    |> cast(attrs, [:task_id, :type, :data, :sequence])
    |> validate_required([:task_id, :type, :data, :sequence])
    |> strip_null_bytes(:data)
    |> validate_inclusion(:type, Interaction.known_type_strings())
    |> foreign_key_constraint(:task_id)
    |> unique_constraint([:task_id, :data],
      name: :interactions_tool_result_uniqueness,
      message: "duplicate tool result for this tool_call_id"
    )
  end

  # Reserve 6 decimal digits for the tiebreaker (0–999_999).
  # This allows up to 1 million sequence calls per second before
  # wrapping, which is far beyond any realistic throughput.
  @tiebreaker_range 1_000_000

  @doc """
  Generates a monotonic sequence number from wall-clock time + a BEAM-unique tiebreaker.

  The value is `unix_seconds * 1_000_000 + (monotonic_counter mod 1_000_000)`.

  - **Cross-restart monotonicity** — the timestamp component always moves forward.
  - **Within-BEAM uniqueness** — `System.unique_integer([:monotonic, :positive])` never
    repeats within a single BEAM instance, breaking ties when two calls land in the
    same second.
  - **No DB round-trip** — purely in-memory, no TOCTOU race.

  At the current epoch the result is ~1.7 × 10¹², fitting comfortably in a
  Postgres `bigint` (max ~9.2 × 10¹⁸).
  """
  @spec generate_sequence() :: integer()
  def generate_sequence do
    unix_s = DateTime.utc_now() |> DateTime.to_unix(:second)
    tiebreaker = System.unique_integer([:monotonic, :positive])
    unix_s * @tiebreaker_range + rem(tiebreaker, @tiebreaker_range)
  end

  # Query helpers

  @spec for_task(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def for_task(query \\ __MODULE__, task_id) do
    from(i in query, where: i.task_id == ^task_id)
  end

  @doc """
  Filters interactions by their type discriminator (e.g. "tool_call", "tool_result").
  """
  @spec by_type(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def by_type(query \\ __MODULE__, type) do
    from(i in query, where: i.type == ^type)
  end

  @doc """
  Filters interactions by a JSONB data field value (e.g. `tool_call_id`, `tool_name`).
  """
  @spec by_data_field(Ecto.Queryable.t(), String.t(), String.t()) :: Ecto.Query.t()
  def by_data_field(query \\ __MODULE__, field, value) do
    from(i in query, where: fragment("?->>? = ?", i.data, ^field, ^value))
  end

  @spec limited(Ecto.Queryable.t(), pos_integer()) :: Ecto.Query.t()
  def limited(query \\ __MODULE__, count) do
    from(i in query, limit: ^count)
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
      selected_figma_node: Interaction.FigmaNode.from_map(data["selected_figma_node"]),
      images: parse_images(data["images"]),
      current_page: Interaction.CurrentPage.from_map(data["current_page"])
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

  def to_struct(%__MODULE__{type: "agent_error", data: data, sequence: sequence}) do
    %Interaction.AgentError{
      id: data["id"],
      sequence: sequence || data["sequence"] || 0,
      error: data["error"],
      kind: data["kind"] || "failed",
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

  # Parse annotations list from stored data — delegates to domain Annotation.from_map/1
  defp parse_annotations(nil), do: []

  defp parse_annotations(annotations) when is_list(annotations),
    do: Enum.map(annotations, &Interaction.Annotation.from_map/1)

  defp parse_annotations(_), do: []

  # Parse user-uploaded images from stored data — delegates to domain UserImage.from_map/1
  defp parse_images(nil), do: []

  defp parse_images(images) when is_list(images),
    do: Enum.map(images, &Interaction.UserImage.from_map/1)

  defp parse_images(_), do: []
end
