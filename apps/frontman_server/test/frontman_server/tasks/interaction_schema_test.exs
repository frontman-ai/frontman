defmodule FrontmanServer.Tasks.InteractionSchemaTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.InteractionCase.Helpers
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
      changeset = InteractionSchema.create_changeset(task, user_msg("queued"), nil)

      assert changeset.valid?
    end

    test "rejects UserMessage with a turn number", %{task: task} do
      changeset = InteractionSchema.create_changeset(task, user_msg("queued"), 1)

      refute changeset.valid?
      assert %{turn_number: ["must be empty for user_message"]} = errors_on(changeset)
    end

    test "requires positive turn numbers for execution-bound interactions", %{task: task} do
      interactions = [
        Interaction.AgentResponse.build("response"),
        tool_call("call_1", "read_file"),
        tool_result("call_1", "read_file", %{"ok" => true}),
        Interaction.AgentCompleted.build(),
        Interaction.AgentError.build("failed"),
        Interaction.AgentPaused.build("read_file", 1_000),
        Interaction.AgentRetry.build(Interaction.new_id())
      ]

      for interaction <- interactions do
        changeset = InteractionSchema.create_changeset(task, interaction, nil)

        refute changeset.valid?
        assert %{turn_number: ["missing for " <> _type]} = errors_on(changeset)
      end
    end
  end

  describe "TurnStarted" do
    test "requires a positive turn number and non-empty user message ids", %{task: task} do
      user_message_id = Interaction.new_id()
      turn_started = Interaction.TurnStarted.build([user_message_id])

      changeset = InteractionSchema.create_changeset(task, turn_started, 1)

      assert changeset.valid?

      missing_turn_changeset = InteractionSchema.create_changeset(task, turn_started, nil)

      refute missing_turn_changeset.valid?
      assert %{turn_number: ["missing for turn_started"]} = errors_on(missing_turn_changeset)

      empty_ids_changeset =
        InteractionSchema.create_changeset(task, Interaction.TurnStarted.build([]), 1)

      refute empty_ids_changeset.valid?

      assert %Ecto.Changeset{errors: [user_message_ids: {"must be non-empty", []}]} =
               get_change(empty_ids_changeset, :data)
    end
  end
end
