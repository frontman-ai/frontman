# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

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
  Persists ordering in the DB `sequence` column; domain interactions do not carry it.
  """
  @spec create_changeset(TaskSchema.t(), struct()) :: Ecto.Changeset.t()
  def create_changeset(%TaskSchema{} = task, interaction) do
    type = interaction.__struct__ |> Module.split() |> List.last() |> Macro.underscore()

    task
    |> Ecto.build_assoc(:interactions)
    |> change(type: type, data: Map.from_struct(interaction), sequence: generate_sequence())
    |> validate_required([:task_id, :type, :data, :sequence])
    |> strip_null_bytes(:data)
    |> validate_json_encodable(:data)
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
  Orders interactions by sequence number for deterministic ordering.
  Falls back to inserted_at for legacy rows without sequence.
  """
  @spec ordered(Ecto.Queryable.t()) :: Ecto.Query.t()
  def ordered(query \\ __MODULE__) do
    from(i in query, order_by: [asc: coalesce(i.sequence, 0), asc: i.inserted_at])
  end

  # --- JSONB to Domain Struct Conversion ---

  @doc """
  Converts a persisted InteractionSchema to its domain struct.
  """
  @spec to_struct(t()) :: Interaction.t()
  def to_struct(%__MODULE__{type: "user_message", data: data}) do
    %Interaction.UserMessage{
      id: data["id"],
      timestamp: parse_datetime(data["timestamp"]),
      messages: data["messages"] || [],
      annotations: parse_annotations(data["annotations"]),
      selected_figma_node: Interaction.FigmaNode.from_map(data["selected_figma_node"]),
      images: parse_images(data["images"]),
      current_page: Interaction.CurrentPage.from_map(data["current_page"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_response", data: data}) do
    %Interaction.AgentResponse{
      id: data["id"],
      content: data["content"],
      timestamp: parse_datetime(data["timestamp"]),
      metadata: data["metadata"]
    }
  end

  def to_struct(%__MODULE__{type: "tool_call", data: data}) do
    %Interaction.ToolCall{
      id: data["id"],
      tool_call_id: data["tool_call_id"],
      tool_name: data["tool_name"],
      arguments: data["arguments"] || %{},
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "tool_result", data: data}) do
    %Interaction.ToolResult{
      id: data["id"],
      tool_call_id: data["tool_call_id"],
      tool_name: data["tool_name"],
      result: data["result"],
      is_error: data["is_error"] || false,
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "discovered_project_rule", data: data}) do
    %Interaction.DiscoveredProjectRule{
      path: data["path"],
      content: data["content"],
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{
        type: "discovered_project_structure",
        data: data
      }) do
    %Interaction.DiscoveredProjectStructure{
      summary: data["summary"],
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_spawned", data: data}) do
    %Interaction.AgentSpawned{
      id: data["id"],
      config: data["config"] || %{},
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_completed", data: data}) do
    %Interaction.AgentCompleted{
      id: data["id"],
      result: data["result"],
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_error", data: data}) do
    %Interaction.AgentError{
      id: data["id"],
      error: data["error"],
      kind: data["kind"] || "failed",
      retryable: data["retryable"] || false,
      category: data["category"] || "unknown",
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_retry", data: data}) do
    %Interaction.AgentRetry{
      id: data["id"],
      retried_error_id: data["retried_error_id"],
      timestamp: parse_datetime(data["timestamp"])
    }
  end

  def to_struct(%__MODULE__{type: "agent_paused", data: data}) do
    %Interaction.AgentPaused{
      id: data["id"],
      timestamp: parse_datetime(data["timestamp"]),
      reason: data["reason"],
      tool_name: data["tool_name"],
      timeout_ms: data["timeout_ms"]
    }
  end

  def to_struct(%__MODULE__{type: type}) do
    raise "Unknown interaction type: #{type}"
  end

  @spec parse_datetime(DateTime.t() | String.t() | nil) :: DateTime.t() | nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(str) when is_binary(str) do
    {:ok, dt, _} = DateTime.from_iso8601(str)
    dt
  end

  # Parse annotations list from stored data — delegates to domain Annotation.from_map/1
  defp parse_annotations(nil), do: []

  defp parse_annotations(annotations) when is_list(annotations),
    do: Enum.map(annotations, &Interaction.Annotation.from_map/1)

  # Parse user-uploaded images from stored data — delegates to domain UserImage.from_map/1
  defp parse_images(nil), do: []

  defp parse_images(images) when is_list(images),
    do: Enum.map(images, &Interaction.UserImage.from_map/1)
end
