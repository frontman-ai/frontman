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
  @task_scoped_types Interaction.task_scoped_types()
  @tiebreaker_range 1_000_000

  schema "interactions" do
    field(:type, Ecto.Enum, values: Interaction.type_values())
    field(:data, :map)
    # Monotonic sequence avoids DB insert race conditions.
    field(:sequence, :integer)
    field(:turn_number, :integer)

    belongs_to(:task, TaskSchema)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating an interaction from a domain struct.
  Persists row metadata in DB columns; domain interactions do not carry it.
  """
  def create_changeset(%TaskSchema{} = task, interaction, turn_number)
      when is_struct(interaction) and (is_integer(turn_number) or is_nil(turn_number)) do
    type = Interaction.type_for(interaction)

    task
    |> Ecto.build_assoc(:interaction_rows)
    |> change(
      type: type,
      data: Interaction.to_data_map(interaction),
      sequence: generate_sequence(),
      turn_number: turn_number
    )
    |> validate_required([:task_id, :type, :data, :sequence])
    |> strip_null_bytes(:data)
    |> validate_json_encodable(:data)
    |> validate_agent_response_metadata()
    |> validate_turn_number()
    |> foreign_key_constraint(:task_id)
    |> unique_constraint([:task_id, :data],
      name: :interactions_tool_result_turn_uniqueness,
      message: "duplicate tool result for this tool_call_id"
    )
  end

  def for_task(query \\ __MODULE__, task_id) when is_binary(task_id) do
    from(i in query, where: i.task_id == ^task_id)
  end

  def for_turn(query \\ __MODULE__, turn_number) do
    from(i in query, where: i.turn_number == ^turn_number)
  end

  @doc """
  Filters interactions to those at or before the given turn number.
  """
  def up_to_turn(query \\ __MODULE__, turn_number)
      when is_integer(turn_number) and turn_number > 0 do
    from(i in query, where: i.turn_number <= ^turn_number)
  end

  def ordered(query \\ __MODULE__) do
    # FIXME(Danni) - create a data migration to make everything have sequence so we can order just by sequence
    from(i in query, order_by: [asc: coalesce(i.sequence, 0), asc: i.inserted_at, asc: i.id])
  end

  def of_type(query \\ __MODULE__, type) do
    type = Interaction.type_for(type)
    from(i in query, where: i.type == ^type)
  end

  def data_equals(query \\ __MODULE__, field, value) do
    from(i in query, where: fragment("?->>?", i.data, ^field) == ^value)
  end

  def unresolved_tool_calls(query \\ __MODULE__) do
    tool_call = Interaction.type_for(Interaction.ToolCall)
    tool_result = Interaction.type_for(Interaction.ToolResult)

    from(i in query,
      left_join: r in __MODULE__,
      on:
        r.task_id == i.task_id and r.turn_number == i.turn_number and r.type == ^tool_result and
          fragment("?->>'tool_call_id'", r.data) == fragment("?->>'tool_call_id'", i.data),
      where: i.type == ^tool_call and is_nil(r.id)
    )
  end

  @doc """
  Converts a persisted InteractionSchema to its domain struct.
  """
  def to_struct(%__MODULE__{type: type, data: data}) when is_atom(type) and is_map(data) do
    module = Interaction.module_for(type)
    Ecto.embedded_load(module, data, :json)
  end

  defp generate_sequence do
    unix_s = DateTime.utc_now() |> DateTime.to_unix(:second)
    tiebreaker = System.unique_integer([:monotonic, :positive])
    unix_s * @tiebreaker_range + rem(tiebreaker, @tiebreaker_range)
  end

  defp validate_turn_number(changeset) do
    case {get_field(changeset, :type), get_field(changeset, :turn_number)} do
      {type, nil} when type in @task_scoped_types ->
        changeset

      {type, turn_number}
      when type not in @task_scoped_types and is_integer(turn_number) and turn_number > 0 ->
        changeset

      {type, _turn_number} when type in @task_scoped_types ->
        add_error(changeset, :turn_number, "must be empty for #{type}")

      {type, nil} ->
        add_error(changeset, :turn_number, "missing for #{type}")

      {_type, _turn_number} ->
        add_error(changeset, :turn_number, "must be positive")
    end
  end

  defp validate_agent_response_metadata(changeset) do
    case {get_field(changeset, :type), get_field(changeset, :data)} do
      {:agent_response, data} when is_map(data) ->
        metadata = Map.get(data, :metadata)

        validate_agent_response_metadata(changeset, metadata)

      _other ->
        changeset
    end
  end

  defp validate_agent_response_metadata(changeset, metadata) when is_map(metadata) do
    changeset
    |> validate_metadata_string(metadata, "response_id")
    |> validate_metadata_string(metadata, "phase")
  end

  defp validate_agent_response_metadata(changeset, nil),
    do: add_error(changeset, :data, "metadata must be a map")

  defp validate_agent_response_metadata(changeset, _metadata),
    do: add_error(changeset, :data, "metadata must be a map")

  defp validate_metadata_string(changeset, metadata, field) do
    case Map.fetch(metadata, field) do
      {:ok, value} when is_binary(value) ->
        changeset

      {:ok, _value} ->
        add_error(changeset, :data, "metadata.#{field} must be a string")

      :error ->
        changeset
    end
  end
end
