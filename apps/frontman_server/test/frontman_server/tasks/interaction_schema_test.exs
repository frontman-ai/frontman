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

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tasks.ToolCallClaimToken
  alias FrontmanServer.Tasks.ToolCallExecutionClaim

  setup do
    scope = user_scope_fixture()
    task = task_fixture(scope)

    %{scope: scope, task: task}
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
        tool_result("call_1", "read_file", ModelContextProtocol.tool_result_text("ok")),
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

      assert changeset(task, interaction_attrs(:turn_started, attrs, 1)).valid?

      changeset =
        changeset(task, interaction_attrs(:turn_started, Map.delete(attrs, :agent_id), 1))

      refute changeset.valid?
    end
  end

  describe "changeset/2" do
    test "uses Ecto.UUID as the row id type" do
      assert InteractionSchema.__schema__(:type, :id) == Ecto.UUID
    end

    test "requires an explicit row id", %{task: task} do
      data = user_msg("queued") |> Map.from_struct()

      changeset =
        task
        |> Ecto.build_assoc(:interaction_rows)
        |> InteractionSchema.changeset(%{type: :user_message, data: data, turn_number: nil})

      refute changeset.valid?
      assert %{id: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts a valid explicit row id", %{task: task} do
      id = Ecto.UUID.generate()
      data = user_msg("queued") |> Map.from_struct()
      changeset = changeset(task, %{id: id, type: :user_message, data: data, turn_number: nil})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :id) == id
    end

    test "rejects a malformed row id", %{task: task} do
      data = user_msg("queued") |> Map.from_struct()

      changeset =
        changeset(task, %{
          id: "not-a-uuid",
          type: :user_message,
          data: data,
          turn_number: nil
        })

      refute changeset.valid?
      assert %{id: ["is invalid"]} = errors_on(changeset)
    end

    test "rejects a nonbinary row id", %{task: task} do
      data = user_msg("queued") |> Map.from_struct()
      changeset = changeset(task, %{id: 123, type: :user_message, data: data, turn_number: nil})

      refute changeset.valid?
      assert %{id: ["is invalid"]} = errors_on(changeset)
    end

    test "returns duplicate row ids as primary-key changeset errors", %{task: task} do
      id = Ecto.UUID.generate()
      data = user_msg("queued") |> Map.from_struct()
      attrs = %{id: id, type: :user_message, data: data, turn_number: nil}

      assert {:ok, %InteractionSchema{id: ^id}} = task |> changeset(attrs) |> Repo.insert()
      assert {:error, duplicate_changeset} = task |> changeset(attrs) |> Repo.insert()
      assert %{id: ["has already been taken"]} = errors_on(duplicate_changeset)
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

    test "round-trips every typed tool-call and claim field without exposing claims publicly", %{
      scope: scope,
      task: task
    } do
      lease_expires_at = DateTime.add(Interaction.now(), 30, :second)
      started_at = Interaction.now()
      deadline_at = DateTime.add(started_at, 600, :second)

      row =
        InteractionSchema.create_changeset(
          task.id,
          :tool_call,
          %{
            tool_call_id: "claimed-call",
            tool_name: "read_file",
            arguments: %{"path" => "README.md"},
            execution_claim: %{
              owner_connection_id: "connection-1",
              generation: 2,
              started_at: started_at,
              deadline_at: deadline_at,
              lease_expires_at: lease_expires_at,
              dispatch_state: :started,
              resolution_state: :unresolved,
              replay_policy: :verified_idempotent,
              recovery_state: :none
            }
          },
          1
        )
        |> Repo.insert!()

      reference = %Tasks.ToolCallExecutionReference{
        interaction_id: row.id,
        task_id: task.id,
        turn_number: 1,
        tool_call_id: "claimed-call",
        tool_name: "read_file"
      }

      token = %ToolCallClaimToken{
        reference: reference,
        owner_connection_id: "connection-1",
        generation: 2,
        started_at: started_at,
        deadline_at: deadline_at,
        lease_expires_at: lease_expires_at
      }

      assert {:ok, %ToolCallClaimToken{generation: 2}} =
               Tasks.mark_tool_call_dispatch_started(scope, token)

      loaded = Repo.get!(InteractionSchema, row.id)

      assert {:ok, dumped} =
               Ecto.Type.dump(InteractionSchema.__schema__(:type, :data), loaded.data)

      assert {:ok, typed} =
               Ecto.Type.load(InteractionSchema.__schema__(:type, :data), dumped)

      reloaded = Repo.get!(InteractionSchema, row.id)

      for tool_call <- [loaded.data, typed, reloaded.data] do
        assert %Interaction.ToolCall{
                 id: _id,
                 tool_call_id: "claimed-call",
                 tool_name: "read_file",
                 arguments: %{"path" => "README.md"},
                 timestamp: %DateTime{},
                 execution_claim: %ToolCallExecutionClaim{
                   owner_connection_id: "connection-1",
                   generation: 2,
                   started_at: ^started_at,
                   deadline_at: ^deadline_at,
                   lease_expires_at: ^lease_expires_at,
                   dispatch_state: :started,
                   resolution_state: :unresolved,
                   replay_policy: :verified_idempotent,
                   recovery_state: :none
                 }
               } = tool_call
      end

      assert %ToolCallExecutionClaim{
               owner_connection_id: "connection-1",
               generation: 2,
               dispatch_state: :started,
               resolution_state: :unresolved,
               replay_policy: :verified_idempotent,
               recovery_state: :none
             } = reloaded.data.execution_claim

      public = reloaded |> Jason.encode!() |> Jason.decode!()
      refute Map.has_key?(public, "execution_claim")
      assert public["tool_call_id"] == "claimed-call"
      assert public["tool_name"] == "read_file"
      assert public["arguments"] == %{"path" => "README.md"}
    end
  end

  defp interaction_changeset(task, interaction, turn_number) do
    type = PolymorphicEmbed.get_polymorphic_type(InteractionSchema, :data, interaction)
    changeset(task, interaction_attrs(type, Map.from_struct(interaction), turn_number))
  end

  defp changeset(task, attrs) do
    task
    |> Ecto.build_assoc(:interaction_rows)
    |> InteractionSchema.changeset(attrs)
  end

  defp interaction_attrs(type, data, turn_number) do
    %{id: Ecto.UUID.generate(), type: type, data: data, turn_number: turn_number}
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
