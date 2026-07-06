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

  describe "create_changeset/3 turn_number validation" do
    test "accepts UserMessage without a turn number", %{task: task} do
      changeset = create_changeset(task, user_msg("queued"), nil)

      assert changeset.valid?
    end

    test "rejects UserMessage with a turn number", %{task: task} do
      changeset = create_changeset(task, user_msg("queued"), 1)

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
        changeset = create_changeset(task, interaction, nil)

        refute changeset.valid?
        assert %{turn_number: ["missing for " <> _type]} = errors_on(changeset)
      end
    end
  end

  describe "TurnStarted" do
    test "requires a positive turn number and non-empty user message ids", %{task: task} do
      user_message_id = Ecto.UUID.generate()
      turn_started = turn_started([user_message_id])

      changeset = create_changeset(task, turn_started, 1)

      assert changeset.valid?

      missing_turn_changeset = create_changeset(task, turn_started, nil)

      refute missing_turn_changeset.valid?
      assert %{turn_number: ["missing for turn_started"]} = errors_on(missing_turn_changeset)

      invalid_changeset = create_changeset(task, turn_started([]), 1)

      refute invalid_changeset.valid?
    end
  end

  describe "JSON encoding" do
    test "encodes persisted interaction type from the row", %{task: task} do
      row =
        task
        |> create_changeset(tool_call("call_1", "read_file"), 1)
        |> Ecto.Changeset.apply_changes()

      decoded = row |> Jason.encode!() |> Jason.decode!()

      assert decoded["type"] == "tool_call"
      assert decoded["tool_call_id"] == "call_1"
      assert decoded["tool_name"] == "read_file"
    end
  end

  defp create_changeset(task, interaction, turn_number) do
    InteractionSchema.create_changeset(
      task.id,
      PolymorphicEmbed.get_polymorphic_type(InteractionSchema, :data, interaction),
      Map.from_struct(interaction),
      turn_number
    )
  end

  defp agent_retry(retried_error_id) do
    %Interaction.AgentRetry{
      id: Ecto.UUID.generate(),
      timestamp: Interaction.now(),
      retried_error_id: retried_error_id
    }
  end
end
