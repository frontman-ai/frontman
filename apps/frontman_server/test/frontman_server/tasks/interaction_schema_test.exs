defmodule FrontmanServer.Tasks.InteractionSchemaTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.InteractionCase.Helpers,
    only: [
      agent_completed: 0,
      agent_error: 1,
      agent_paused: 2,
      tool_call: 2,
      tool_result: 3,
      turn_started: 1,
      user_msg: 1
    ]

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  setup do
    scope = user_scope_fixture()
    task = task_fixture(scope)

    %{task: task}
  end

  describe "changeset/2 turn_number validation" do
    test "accepts UserMessage without a turn number", %{task: task} do
      changeset = interaction_changeset(task, user_msg("queued"), nil)

      assert changeset.valid?
    end

    test "rejects UserMessage with a turn number", %{task: task} do
      changeset = interaction_changeset(task, user_msg("queued"), 1)

      refute changeset.valid?
      assert %{turn_number: ["must be empty for user_message"]} = errors_on(changeset)
    end

    test "requires positive turn numbers for execution-bound interactions", %{task: task} do
      interactions = [
        struct!(Interaction.AgentResponse, Interaction.AgentResponse.attrs("response")),
        tool_call("call_1", "read_file"),
        tool_result("call_1", "read_file", %{"ok" => true}),
        agent_completed(),
        agent_error("failed"),
        agent_paused("read_file", 1_000),
        agent_retry(Ecto.UUID.generate())
      ]

      for interaction <- interactions do
        changeset = interaction_changeset(task, interaction, nil)

        refute changeset.valid?
        assert %{turn_number: ["missing for " <> _type]} = errors_on(changeset)
      end
    end
  end

  describe "TurnStarted" do
    test "requires a positive turn number and non-empty user message ids", %{task: task} do
      user_message_id = Ecto.UUID.generate()
      turn_started = turn_started([user_message_id])

      changeset = interaction_changeset(task, turn_started, 1)

      assert changeset.valid?

      missing_turn_changeset = interaction_changeset(task, turn_started, nil)

      refute missing_turn_changeset.valid?
      assert %{turn_number: ["missing for turn_started"]} = errors_on(missing_turn_changeset)

      invalid_changeset = interaction_changeset(task, turn_started([]), 1)

      refute invalid_changeset.valid?
    end

    test "requires an agent id", %{task: task} do
      attrs = valid_turn_started_attrs()

      assert changeset(task, :turn_started, attrs, 1).valid?

      changeset = changeset(task, :turn_started, Map.delete(attrs, :agent_id), 1)

      refute changeset.valid?
    end
  end

  describe "changeset/2" do
    test "casts an explicit row id", %{task: task} do
      id = Ecto.UUID.generate()
      data = user_msg("queued") |> Map.from_struct()
      changeset = changeset(task, :user_message, data, nil, %{id: id})

      assert Ecto.Changeset.get_change(changeset, :id) == id
    end

    test "rejects a nonbinary row id", %{task: task} do
      data = user_msg("queued") |> Map.from_struct()
      changeset = changeset(task, :user_message, data, nil, %{id: 123})

      refute changeset.valid?
      assert %{id: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "JSON encoding" do
    test "encodes persisted interaction type from the row", %{task: task} do
      row =
        task
        |> interaction_changeset(tool_call("call_1", "read_file"), 1)
        |> Ecto.Changeset.apply_changes()

      decoded = row |> Jason.encode!() |> Jason.decode!()

      assert decoded["type"] == "tool_call"
      assert decoded["tool_call_id"] == "call_1"
      assert decoded["tool_name"] == "read_file"
    end
  end

  defp interaction_changeset(task, interaction, turn_number) do
    changeset(
      task,
      PolymorphicEmbed.get_polymorphic_type(InteractionSchema, :data, interaction),
      Map.from_struct(interaction),
      turn_number
    )
  end

  defp changeset(task, type, data, turn_number, attrs \\ %{}) do
    task
    |> Ecto.build_assoc(:interaction_rows, type: type, turn_number: turn_number)
    |> InteractionSchema.changeset(Map.merge(attrs, %{data: data}))
  end

  defp agent_retry(retried_error_id) do
    %Interaction.AgentRetry{
      id: Ecto.UUID.generate(),
      timestamp: Interaction.now(),
      retried_error_id: retried_error_id
    }
  end

  defp valid_turn_started_attrs do
    %{
      id: Ecto.UUID.generate(),
      timestamp: Interaction.now(),
      agent_id: "test-frontman",
      user_message_ids: [Ecto.UUID.generate()]
    }
  end
end
