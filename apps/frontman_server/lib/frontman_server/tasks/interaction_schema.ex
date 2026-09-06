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
  import PolymorphicEmbed

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.TaskSchema

  @types [
    user_message: Interaction.UserMessage,
    turn_started: Interaction.TurnStarted,
    agent_response: Interaction.AgentResponse,
    agent_completed: Interaction.AgentCompleted,
    agent_error: Interaction.AgentError,
    agent_paused: Interaction.AgentPaused,
    agent_retry: Interaction.AgentRetry,
    skill_used: Interaction.SkillUsed,
    tool_call: Interaction.ToolCall,
    tool_result: Interaction.ToolResult,
    discovered_project_rule: Interaction.DiscoveredProjectRule,
    discovered_project_structure: Interaction.DiscoveredProjectStructure
  ]

  @tool_result_unique_constraint :interactions_tool_result_turn_uniqueness

  @type_values Keyword.keys(@types)
  @task_scoped_types [:discovered_project_rule, :discovered_project_structure]

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  @foreign_key_type :binary_id
  @accepted_message_types [:user_message]
  @tiebreaker_range 1_000_000
  schema "interactions" do
    field(:type, Ecto.Enum, values: @type_values)

    polymorphic_embeds_one(:data,
      types: @types,
      use_parent_field_for_type: :type,
      on_type_not_found: :raise,
      on_replace: :update
    )

    field(:sequence, :integer)
    field(:turn_number, :integer)

    belongs_to(:task, TaskSchema)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def types, do: @types
  def task_scoped_types, do: @task_scoped_types

  def changeset(%__MODULE__{} = interaction, attrs) when is_map(attrs) do
    interaction
    |> cast(attrs, [:id, :type, :turn_number])
    |> put_change(:sequence, generate_sequence())
    |> cast_polymorphic_embed(:data, required: true, with: polymorphic_changesets())
    |> validate_create()
  end

  def for_task(query \\ __MODULE__, task_id) when is_binary(task_id) do
    from(i in query, where: i.task_id == ^task_id)
  end

  def for_turn(query \\ __MODULE__, turn_number) do
    from(i in query, where: i.turn_number == ^turn_number)
  end

  def ordered(query \\ __MODULE__) do
    from(i in query, order_by: [asc: i.sequence, asc: i.inserted_at, asc: i.id])
  end

  def of_type(query \\ __MODULE__, type) when is_atom(type) do
    from(i in query, where: i.type == ^type)
  end

  def data_equals(query \\ __MODULE__, field, value) do
    from(i in query, where: fragment("?->>?", i.data, ^field) == ^value)
  end

  def limited_data_values(query, field, limit) do
    from(i in query, select: fragment("?->>?", i.data, ^field), limit: ^limit)
  end

  def unresolved_tool_calls(query \\ __MODULE__) do
    from(i in query,
      left_join: r in __MODULE__,
      on:
        r.task_id == i.task_id and r.turn_number == i.turn_number and r.type == :tool_result and
          fragment("?->>'tool_call_id'", r.data) == fragment("?->>'tool_call_id'", i.data),
      where: i.type == :tool_call and is_nil(r.id)
    )
  end

  def to_json_map(%__MODULE__{type: type, data: data}) when is_struct(data) do
    data
    |> Interaction.to_json_map()
    |> Map.put(:type, type)
  end

  defp polymorphic_changesets do
    Keyword.new(@types, fn {type, module} ->
      {type, fn struct, attrs -> module.changeset(struct, attrs) end}
    end)
  end

  defp validate_create(changeset) do
    changeset
    |> validate_required([:id, :task_id, :type, :data, :sequence])
    |> validate_turn_number()
    |> foreign_key_constraint(:task_id)
    |> unique_constraint(:id, name: :interactions_pkey)
    |> unique_constraint([:task_id, :data],
      name: @tool_result_unique_constraint,
      message: "duplicate tool result for this tool_call_id"
    )
  end

  defp generate_sequence do
    unix_s = DateTime.utc_now() |> DateTime.to_unix(:second)
    tiebreaker = System.unique_integer([:monotonic, :positive])
    unix_s * @tiebreaker_range + rem(tiebreaker, @tiebreaker_range)
  end

  defp validate_turn_number(changeset) do
    type = get_field(changeset, :type)
    turn_number = get_field(changeset, :turn_number)

    cond do
      empty_turn_number_type?(type) and is_nil(turn_number) ->
        changeset

      execution_turn_number?(type, turn_number) ->
        changeset

      empty_turn_number_type?(type) ->
        add_error(changeset, :turn_number, "must be empty for #{type}")

      is_nil(turn_number) ->
        add_error(changeset, :turn_number, "missing for #{type}")

      true ->
        add_error(changeset, :turn_number, "must be positive")
    end
  end

  defp empty_turn_number_type?(type),
    do: type in @accepted_message_types or type in @task_scoped_types

  defp execution_turn_number?(type, turn_number) do
    !empty_turn_number_type?(type) and is_integer(turn_number) and turn_number > 0
  end
end

defimpl Jason.Encoder, for: FrontmanServer.Tasks.InteractionSchema do
  alias FrontmanServer.Tasks.InteractionSchema

  def encode(value, opts) do
    value
    |> InteractionSchema.to_json_map()
    |> Jason.Encode.map(opts)
  end
end
