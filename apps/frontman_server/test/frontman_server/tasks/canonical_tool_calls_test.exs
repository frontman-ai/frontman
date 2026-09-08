defmodule FrontmanServer.Tasks.CanonicalToolCallsTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias AgentClientProtocol.History, as: ACPHistory
  alias Ecto.Migration.Runner
  alias FrontmanServer.Agents
  alias FrontmanServer.Repo
  alias FrontmanServer.Repo.Migrations.CanonicalizeToolCalls
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.{History, Interaction, InteractionSchema}
  alias FrontmanServer.Tools

  setup do
    scope = user_scope_fixture()
    task_id = task_fixture(scope).id
    turn_number = start_turn_fixture(scope, task_id)
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))
    %{scope: scope, task_id: task_id, turn_number: turn_number}
  end

  test "response persistence creates every call and normalizes arguments once", context do
    calls = [
      call("valid", "todo_write", ~s({"todos":[],"optional":null,"nested":{"optional":null}})),
      call("blank", "question", " \n "),
      call("invalid", "question", "{invalid"),
      call("array", "question", "[]")
    ]

    response = %SwarmAi.LLM.Response{content: "Working", tool_calls: calls}
    timestamp = ~U[2026-09-01 12:00:00.000000Z]

    assert :ok =
             Tasks.handle_swarm_event(
               context.scope,
               context.task_id,
               context.turn_number,
               {:response, %{timestamp: timestamp}, response}
             )

    [response_row | call_rows] = execution_rows(context.task_id)
    assert response_row.type == :agent_response
    assert response_row.data.timestamp == timestamp
    assert Enum.map(call_rows, & &1.data.tool_call_id) == Enum.map(calls, & &1.id)

    assert Enum.map(call_rows, & &1.data.arguments) == [
             %{"todos" => [], "nested" => %{}},
             %{},
             nil,
             nil
           ]

    assert Enum.all?(call_rows, &is_nil(&1.data.execution_target))

    assert Enum.map(response_row.data.metadata["tool_calls"], & &1["arguments"]) ==
             Enum.map(calls, & &1.arguments)

    refute_receive {:tool_call_started, _, _}

    assert {:ok, history} = History.new(all_rows(context.task_id))

    assert {:ok, replay} =
             ACPHistory.build(history, context.task_id, Agents.list_agents(context.scope))

    creates =
      Enum.filter(
        replay.notifications,
        &(get_in(&1, ["params", "update", "sessionUpdate"]) == "tool_call")
      )

    assert length(creates) == 4
    refute Map.has_key?(get_in(List.last(creates), ["params", "update"]), "rawInput")
  end

  test "duplicate declarations roll back the response and every call without broadcasting",
       context do
    declaration = call("duplicate", "todo_write", "{}")

    assert {:error, %Ecto.Changeset{}} =
             declare_tool_calls_fixture(context.scope, context.task_id, context.turn_number, [
               declaration,
               declaration
             ])

    assert execution_rows(context.task_id) == []
    refute_receive {:interaction, _}
  end

  test "call IDs are unique within a turn, not across turns", context do
    declaration = call("reused", "todo_write", "{}")
    assert {:ok, _} = declare_tool_calls_fixture(context.scope, context.task_id, 1, [declaration])

    assert {:error, %Ecto.Changeset{}} =
             declare_tool_calls_fixture(context.scope, context.task_id, 1, [declaration])

    assert {:ok, _} =
             Tasks.record_execution_outcome(context.scope, context.task_id, 1, :completed)

    assert 2 = start_turn_fixture(context.scope, context.task_id)
    assert {:ok, _} = declare_tool_calls_fixture(context.scope, context.task_id, 2, [declaration])

    assert [1, 2] =
             all_rows(context.task_id)
             |> Enum.filter(&(&1.type == :tool_call))
             |> Enum.map(& &1.turn_number)
  end

  @tag :capture_log
  test "malformed backend and client calls both persist a call followed by its error", context do
    backend = call("backend", "todo_write", "{invalid")
    client = call("client", "question", "[]")
    calls = [backend, client]
    assert {:ok, _} = declare_tool_calls_fixture(context.scope, context.task_id, 1, calls)

    assert {:ok, results} =
             ToolExecutor.execute(context.scope, %{
               task_id: context.task_id,
               turn_number: 1,
               tool_calls: calls,
               task_supervisor: SwarmAi.Runtime.task_supervisor_name(FrontmanServer.AgentRuntime),
               backend_tool_modules: [Tools.TodoWrite],
               mcp_tool_defs: [
                 %Tools.MCP{
                   name: "question",
                   description: "Question",
                   input_schema: %{},
                   timeout_ms: 1_000,
                   on_timeout: :error
                 }
               ],
               execution_mode: :serial
             })

    assert Enum.all?(results, & &1.is_error)

    assert [:agent_response, :tool_call, :tool_call, :tool_result, :tool_result] =
             Enum.map(execution_rows(context.task_id), & &1.type)

    for result <- results do
      assert [%{text: "Failed to parse arguments for tool"}] = result.content
    end

    refute_receive {:tool_call_started, _, _}
  end

  test "restart closes declared but undispatched questions as well as backend calls", context do
    declarations = [call("backend", "todo_write", "{}"), call("question", "question", "{}")]
    assert {:ok, _} = declare_tool_calls_fixture(context.scope, context.task_id, 1, declarations)

    assert :ok =
             Tasks.handle_swarm_event(context.scope, context.task_id, 1, {:terminated, :shutdown})

    assert {:ok, :no_active_turn} =
             Tasks.get_active_turn_unresolved_tool_calls(context.scope, context.task_id)

    assert [:agent_response, :tool_call, :tool_call, :tool_result, :tool_result, :agent_error] =
             Enum.map(execution_rows(context.task_id), & &1.type)
  end

  test "resolved calls cannot start again", context do
    declaration = call("resolved", "todo_write", "{}")
    assert {:ok, _} = declare_tool_calls_fixture(context.scope, context.task_id, 1, [declaration])

    assert {:ok, _, _} =
             Tasks.resolve_tool_request(
               context.scope,
               context.task_id,
               declaration,
               ModelContextProtocol.tool_result_text("done"),
               turn_number: 1
             )

    assert {:error, :not_pending} =
             Tasks.start_tool_call(context.scope, context.task_id, 1, declaration.id, :backend)

    refute_receive {:tool_call_started, _, _}
  end

  test "results cannot be recorded without a canonical call", context do
    assert_raise Ecto.NoResultsError, fn ->
      Tasks.resolve_tool_request(
        context.scope,
        context.task_id,
        %{id: "missing", name: "todo_write"},
        ModelContextProtocol.tool_result_text("done"),
        turn_number: 1
      )
    end

    assert execution_rows(context.task_id) == []
  end

  test "backfill preserves standalone calls and inserts missing calls in declaration order",
       context do
    calls = [
      call("existing", "question", "{}"),
      call("valid", "todo_write", ~s({"todos":[],"drop":null})),
      call("invalid", "question", "{invalid")
    ]

    assert {:ok, _} = declare_tool_calls_fixture(context.scope, context.task_id, 1, calls)
    assert {:ok, _} = Tasks.start_tool_call(context.scope, context.task_id, 1, "existing", :mcp)

    for call <- calls do
      assert {:ok, _, _} =
               Tasks.resolve_tool_request(
                 context.scope,
                 context.task_id,
                 call,
                 ModelContextProtocol.tool_result_text("done"),
                 turn_number: 1
               )
    end

    assert {:ok, _} =
             Tasks.record_execution_outcome(context.scope, context.task_id, 1, :completed)

    original_rows = all_rows(context.task_id)

    existing =
      Enum.find(
        original_rows,
        &match?(%InteractionSchema{data: %Interaction.ToolCall{tool_call_id: "existing"}}, &1)
      )

    task_id = Ecto.UUID.dump!(context.task_id)

    Repo.query!(
      "DELETE FROM interactions WHERE task_id = $1 AND type = 'tool_call' AND data->>'tool_call_id' <> 'existing'",
      [task_id]
    )

    Repo.query!("UPDATE interactions SET data = data - 'execution_target' WHERE id = $1", [
      Ecto.UUID.dump!(existing.id)
    ])

    retained_ids = Enum.map(all_rows(context.task_id), & &1.id)
    run_migration(:down)
    run_migration(:up)

    rows = all_rows(context.task_id)
    assert {:ok, _} = History.new(rows)
    assert (Enum.map(rows, & &1.id) -- Enum.map(original_rows, & &1.id)) |> length() == 2
    assert Enum.find(rows, &(&1.id == existing.id)).data.execution_target == :mcp

    assert ["valid", "invalid", "existing"] =
             rows |> Enum.filter(&(&1.type == :tool_call)) |> Enum.map(& &1.data.tool_call_id)

    assert [
             %Interaction.ToolCall{arguments: %{"todos" => []}, execution_target: nil},
             %Interaction.ToolCall{arguments: nil, execution_target: nil}
           ] =
             rows
             |> Enum.filter(&(&1.type == :tool_call and &1.id != existing.id))
             |> Enum.map(& &1.data)

    assert Enum.filter(Enum.map(rows, & &1.id), &(&1 in retained_ids)) == retained_ids
  end

  test "backfill scopes IDs by turn and accepts legacy argument formats", context do
    assert {:ok, _} =
             declare_tool_calls_fixture(context.scope, context.task_id, 1, [
               call("shared", "question", "{}")
             ])

    assert {:ok, _} =
             Tasks.record_execution_outcome(context.scope, context.task_id, 1, :completed)

    assert 2 = start_turn_fixture(context.scope, context.task_id)
    arguments = %{"drop" => nil, "nested" => %{"drop" => nil}, "array" => [%{"keep" => nil}]}

    assert {:ok, _} =
             Tasks.agent_replied(context.scope, context.task_id, 2, nil, %{
               "tool_calls" => [
                 %{
                   "id" => "shared",
                   "function" => %{"name" => "question", "arguments" => " \n "}
                 },
                 %{
                   "id" => "nested",
                   "function" => %{"name" => "question", "arguments" => arguments}
                 },
                 %{"id" => "array", "name" => "question", "arguments" => "[]"}
               ]
             })

    Repo.query!(
      "DELETE FROM interactions WHERE task_id = $1 AND turn_number = 2 AND type = 'tool_call'",
      [Ecto.UUID.dump!(context.task_id)]
    )

    run_migration(:down)
    run_migration(:up)
    rows = all_rows(context.task_id)
    assert {:ok, _} = History.new(rows)
    calls = Enum.filter(rows, &(&1.type == :tool_call))

    assert Enum.map(calls, &{&1.turn_number, &1.data.tool_call_id}) == [
             {1, "shared"},
             {2, "shared"},
             {2, "nested"},
             {2, "array"}
           ]

    assert Enum.map(calls, & &1.data.arguments) == [
             %{},
             %{},
             %{"nested" => %{}, "array" => [%{"keep" => nil}]},
             nil
           ]
  end

  test "backfill gives legacy result-only records a call before the result", context do
    declaration = call("orphan", "todo_write", "{}")
    assert {:ok, _} = declare_tool_calls_fixture(context.scope, context.task_id, 1, [declaration])

    assert {:ok, result, _} =
             Tasks.resolve_tool_request(
               context.scope,
               context.task_id,
               declaration,
               ModelContextProtocol.tool_result_text("done"),
               turn_number: 1
             )

    Repo.query!(
      "DELETE FROM interactions WHERE task_id = $1 AND type IN ('agent_response', 'tool_call')",
      [Ecto.UUID.dump!(context.task_id)]
    )

    run_migration(:down)
    run_migration(:up)

    assert [
             %InteractionSchema{
               data: %Interaction.ToolCall{
                 tool_call_id: "orphan",
                 arguments: nil,
                 execution_target: nil
               }
             },
             %InteractionSchema{data: ^result}
           ] = execution_rows(context.task_id)
  end

  defp run_migration(direction) do
    Code.require_file("priv/repo/migrations/20260907000000_canonicalize_tool_calls.exs")

    assert :ok =
             Runner.run(
               Repo,
               Repo.config(),
               0,
               CanonicalizeToolCalls,
               :forward,
               direction,
               direction,
               log: false
             )
  end

  defp call(id, name, arguments), do: %SwarmAi.ToolCall{id: id, name: name, arguments: arguments}

  defp all_rows(task_id),
    do: task_id |> InteractionSchema.for_task() |> InteractionSchema.ordered() |> Repo.all()

  defp execution_rows(task_id),
    do: Enum.reject(all_rows(task_id), &(&1.type in [:user_message, :turn_started]))
end
