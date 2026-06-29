defmodule FrontmanServer.TasksTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Migration.Runner
  alias FrontmanServer.Repo.Migrations.{BackfillInteractionTurnNumbers, BackfillUserMessageModels}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tasks.TaskSchema
  alias ModelContextProtocol, as: MCP

  setup do
    scope = user_scope_fixture()

    %{scope: scope}
  end

  describe "create_task/3" do
    test "creates task with framework", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      framework = "nextjs"
      {:ok, %TaskSchema{id: ^task_id}} = Tasks.create_task(scope, task_id, framework)

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert task.id == task_id
      assert task.framework == :nextjs
    end
  end

  describe "apply_title_suggestion/3" do
    test "sets the default title once", %{scope: scope} do
      task_id = task_fixture(scope).id

      :ok = Tasks.apply_title_suggestion(scope, task_id, "First Title")
      :ok = Tasks.apply_title_suggestion(scope, task_id, "Second Title")

      assert {:ok, %{short_desc: "First Title"}} = Tasks.get_task(scope, task_id)
    end
  end

  describe "get_task/2 authorization" do
    test "returns not_found when accessing task owned by different user", %{scope: scope} do
      task_id = task_fixture(scope).id

      # Create a different user/scope
      other_scope = user_scope_fixture()

      # Returns :not_found to prevent task enumeration attacks
      assert {:error, :not_found} = Tasks.get_task(other_scope, task_id)
    end
  end

  describe "get_active_run_unresolved_tool_calls/2" do
    test "returns unresolved tool calls only for active agent runs", %{scope: scope} do
      task_id = task_fixture(scope).id

      assert {:ok, :no_active_run} = Tasks.get_active_run_unresolved_tool_calls(scope, task_id)

      insert_interaction_row(task_id, Interaction.UserMessage, 1)
      insert_interaction_row(task_id, Interaction.ToolCall, 1, %{"tool_call_id" => "call_1"})

      assert {:ok, 1, [%Interaction.ToolCall{tool_call_id: "call_1"}]} =
               Tasks.get_active_run_unresolved_tool_calls(scope, task_id)

      insert_interaction_row(task_id, Interaction.ToolResult, 1, %{"tool_call_id" => "call_1"})

      assert {:ok, 1, []} = Tasks.get_active_run_unresolved_tool_calls(scope, task_id)
    end

    test "returns an error for turn-scoped rows missing turn numbers", %{scope: scope} do
      task_id = task_fixture(scope).id

      insert_interaction_row(task_id, Interaction.UserMessage, nil)

      assert {:error, {:missing_turn_number, :user_message}} =
               Tasks.get_active_run_unresolved_tool_calls(scope, task_id)
    end

    test "returns an error for task-scoped rows with turn numbers", %{scope: scope} do
      task_id = task_fixture(scope).id

      insert_interaction_row(task_id, Interaction.DiscoveredProjectRule, 1)

      assert {:error, {:unknown_interaction_type, :discovered_project_rule}} =
               Tasks.get_active_run_unresolved_tool_calls(scope, task_id)
    end
  end

  describe "submit_user_message/2" do
    test "returns an error instead of raising when existing rows have invalid turn state", %{
      scope: scope
    } do
      task_id = task_fixture(scope).id

      insert_interaction_row(task_id, Interaction.UserMessage, nil)

      assert {:error, {:missing_turn_number, :user_message}} =
               Tasks.submit_user_message(
                 scope,
                 Map.merge(execution_request_fixture(), %{
                   task_id: task_id,
                   message: user_content("hello")
                 })
               )
    end
  end

  describe "terminated execution recovery" do
    test "interrupts non-question tools but keeps pending questions open", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)

      {:ok, _tool_call} =
        Tasks.request_client_tool(
          scope,
          task_id,
          turn_number,
          named_swarm_tool_call("question_1", "question")
        )

      {:ok, _tool_call} =
        Tasks.request_client_tool(
          scope,
          task_id,
          turn_number,
          named_swarm_tool_call("read_1", "read_file")
        )

      Tasks.handle_swarm_event(scope, task_id, turn_number, {:terminated, :shutdown})

      {:ok, task} = Tasks.get_task(scope, task_id)
      refute Enum.any?(task.interactions, &match?(%Interaction.AgentError{}, &1))

      assert [
               %Interaction.ToolResult{
                 tool_call_id: "read_1",
                 result: result,
                 is_error: true
               }
             ] = Enum.filter(task.interactions, &match?(%Interaction.ToolResult{}, &1))

      assert result == MCP.tool_result_error("Interrupted by restart")

      assert {:ok, ^turn_number, [%Interaction.ToolCall{tool_call_id: "question_1"}]} =
               Tasks.get_active_run_unresolved_tool_calls(scope, task_id)
    end
  end

  describe "swarm event persistence" do
    test "rejects invalid response metadata", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)

      response = %SwarmAi.LLM.Response{content: "hello", metadata: %{response_id: 123}}

      assert {:error, changeset} =
               Tasks.handle_swarm_event(scope, task_id, turn_number, {:response, response})

      assert %{data: ["metadata.response_id must be a string"]} = errors_on(changeset)
    end
  end

  describe "turn-number backfill migration" do
    test "backfills multi-turn history and leaves context rows nil", %{scope: scope} do
      task_id = task_fixture(scope).id

      for {type, data} <- [
            {Interaction.DiscoveredProjectRule, %{}},
            {Interaction.UserMessage, %{}},
            {Interaction.AgentResponse, %{}},
            {Interaction.AgentCompleted, %{}},
            {Interaction.DiscoveredProjectStructure, %{}},
            {Interaction.UserMessage, %{}},
            {Interaction.ToolCall, %{"tool_call_id" => "call_2"}},
            {Interaction.ToolResult, %{"tool_call_id" => "call_2"}}
          ] do
        insert_interaction_row(task_id, type, nil, data)
      end

      run_backfill_migration()

      assert [
               {Interaction.DiscoveredProjectRule, nil},
               {Interaction.UserMessage, 1},
               {Interaction.AgentResponse, 1},
               {Interaction.AgentCompleted, 1},
               {Interaction.DiscoveredProjectStructure, nil},
               {Interaction.UserMessage, 2},
               {Interaction.ToolCall, 2},
               {Interaction.ToolResult, 2}
             ] = db_type_turns(task_id)
    end
  end

  describe "user-message model backfill migration" do
    test "sets the legacy default model on old user messages", %{scope: scope} do
      task_id = task_fixture(scope).id

      insert_interaction_row(task_id, Interaction.UserMessage, 1, %{"messages" => ["hello"]})
      run_user_message_model_backfill_migration()

      assert [%{data: %{"model" => "openrouter:google/gemini-3-flash-preview"}}] =
               InteractionSchema.for_task(task_id)
               |> InteractionSchema.of_type(Interaction.UserMessage)
               |> Repo.all()
    end

    test "leaves explicit models untouched", %{scope: scope} do
      task_id = task_fixture(scope).id

      insert_interaction_row(task_id, Interaction.UserMessage, 1, %{
        "model" => "anthropic:claude-sonnet-4-6"
      })

      run_user_message_model_backfill_migration()

      assert [%{data: %{"model" => "anthropic:claude-sonnet-4-6"}}] =
               InteractionSchema.for_task(task_id)
               |> InteractionSchema.of_type(Interaction.UserMessage)
               |> Repo.all()
    end
  end

  describe "retry_execution/4" do
    test "only retries agent errors", %{scope: scope} do
      task_id = task_fixture(scope).id
      {:ok, user_message} = user_message_fixture(scope, task_id, user_content("not an error"))

      assert {:error, :not_found} =
               Tasks.retry_execution(scope, task_id, user_message.id, execution_request_fixture())
    end

    test "rejects an older error after later interactions in the same turn", %{scope: scope} do
      task_id = task_fixture(scope).id
      insert_interaction_row(task_id, Interaction.UserMessage, 1)
      insert_interaction_row(task_id, Interaction.AgentError, 1, %{"id" => "error-1"})

      insert_interaction_row(task_id, Interaction.AgentRetry, 1, %{
        "retried_error_id" => "error-1"
      })

      insert_interaction_row(task_id, Interaction.AgentCompleted, 1)

      assert {:error, :stale_turn} =
               Tasks.retry_execution(scope, task_id, "error-1", execution_request_fixture())
    end
  end

  describe "handle_swarm_event/4" do
    test "returns persistence errors instead of crashing", %{scope: scope} do
      missing_task_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               Tasks.handle_swarm_event(scope, missing_task_id, 1, :completed)
    end
  end

  describe "resume_execution/3" do
    test "returns not_running when no active agent run exists", %{scope: scope} do
      task_id = task_fixture(scope).id

      assert {:error, :not_running} =
               Tasks.resume_execution(scope, task_id, execution_request_fixture())
    end
  end

  describe "Swarm message conversion" do
    test "full tool_call + tool_result round-trip produces valid Swarm messages", %{scope: scope} do
      task_id = task_fixture(scope).id

      tool_call_id = "toolu_integration_#{System.unique_integer([:positive])}"

      {:ok, _} =
        user_message_fixture(scope, task_id, user_content("What is 2+2?"))

      turn_number = latest_turn_number(task_id)

      {:ok, _} =
        Tasks.agent_replied(scope, task_id, turn_number, "Let me calculate that.", %{
          "tool_calls" => [
            %{
              "id" => tool_call_id,
              "type" => "function",
              "function" => %{
                "name" => "calculator",
                "arguments" => ~s({"expression": "2+2"})
              }
            }
          ]
        })

      tc = %SwarmAi.ToolCall{
        id: tool_call_id,
        name: "calculator",
        arguments: ~s({"expression": "2+2"})
      }

      {:ok, _} = Tasks.request_client_tool(scope, task_id, turn_number, tc)

      {:ok, _, _} =
        resolve_tool(
          scope,
          task_id,
          %{id: tool_call_id, name: "calculator"},
          MCP.tool_result_text("4"),
          false,
          turn_number
        )

      {:ok, _} = Tasks.agent_replied(scope, task_id, turn_number, "The answer is 4.")

      sequences = db_sequences(task_id)

      assert length(sequences) == 5
      assert sequences == Enum.sort(sequences), "sequences should be strictly increasing"
      assert sequences == Enum.uniq(sequences), "sequences should be unique"

      assert [
               {Interaction.UserMessage, ^turn_number},
               {Interaction.AgentResponse, ^turn_number},
               {Interaction.ToolCall, ^turn_number},
               {Interaction.ToolResult, ^turn_number},
               {Interaction.AgentResponse, ^turn_number}
             ] = db_type_turns(task_id)

      {:ok, task} = Tasks.get_task(scope, task_id)
      messages = Tasks.Interaction.to_swarm_messages(task.interactions)

      assert length(messages) == 4,
             "expected 4 Swarm messages, got #{length(messages)}: #{inspect(Enum.map(messages, &SwarmAi.Message.role/1))}"

      [_user_msg, assistant_with_tool, tool_result_msg, final_assistant] = messages

      assert Enum.map(messages, &SwarmAi.Message.role/1) == [:user, :assistant, :tool, :assistant]

      assert [%SwarmAi.ToolCall{} = tc_in_msg] = assistant_with_tool.tool_calls
      assert tc_in_msg.id == tool_call_id
      assert tc_in_msg.name == "calculator"

      assert tool_result_msg.tool_call_id == tool_call_id
      assert [%{type: :text, text: "4"}] = tool_result_msg.content

      assert [%{type: :text, text: "The answer is 4."}] = final_assistant.content
    end
  end

  describe "request_client_tool/3" do
    test "creates tool call interaction", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)

      tool_call = %SwarmAi.ToolCall{
        id: "call_123",
        name: "calculator",
        arguments: ~s({"expression": "1 + 1"})
      }

      {:ok, interaction} = Tasks.request_client_tool(scope, task_id, turn_number, tool_call)

      assert interaction.tool_name == "calculator"
      assert interaction.tool_call_id == "call_123"
      assert interaction.arguments == %{"expression" => "1 + 1"}
    end

    test "stores blank tool call arguments as an empty map", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)

      tool_call = %SwarmAi.ToolCall{
        id: "call_blank",
        name: "calculator",
        arguments: "  \n  "
      }

      assert {:ok, interaction} =
               Tasks.request_client_tool(scope, task_id, turn_number, tool_call)

      assert interaction.arguments == %{}
    end

    test "returns an error for malformed tool call arguments", %{scope: scope} do
      task_id = task_fixture(scope).id

      tool_call = %SwarmAi.ToolCall{
        id: "call_bad_json",
        name: "calculator",
        arguments: ~s({"expression":)
      }

      assert {:error, {:invalid_tool_arguments, reason}} =
               Tasks.request_client_tool(scope, task_id, 1, tool_call)

      assert reason =~ "unexpected end of input"
    end

    test "returns an error for non-object tool call arguments", %{scope: scope} do
      task_id = task_fixture(scope).id

      tool_call = %SwarmAi.ToolCall{
        id: "call_array",
        name: "calculator",
        arguments: ~s(["not", "object"])
      }

      assert {:error, {:invalid_tool_arguments, reason}} =
               Tasks.request_client_tool(scope, task_id, 1, tool_call)

      assert reason =~ "expected JSON object"
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()
      tool_call = %SwarmAi.ToolCall{id: "call_123", name: "test", arguments: "{}"}

      assert {:error, :not_found} =
               Tasks.request_client_tool(scope, nonexistent_id, 1, tool_call)
    end
  end

  describe "resolve_tool_request/5" do
    test "rejects duplicate tool result for the same tool_call_id", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)

      tool_call_data = %{id: "call_dedup", name: "some_tool"}

      {:ok, _first, _status} =
        resolve_tool(
          scope,
          task_id,
          tool_call_data,
          MCP.tool_result_text("result1"),
          false,
          turn_number
        )

      assert {:error, %Ecto.Changeset{}} =
               resolve_tool(
                 scope,
                 task_id,
                 tool_call_data,
                 MCP.tool_result_text("result2"),
                 false,
                 turn_number
               )

      {:ok, task} = Tasks.get_task(scope, task_id)
      tool_results = Enum.filter(task.interactions, &match?(%Tasks.Interaction.ToolResult{}, &1))
      assert [%Tasks.Interaction.ToolResult{result: result}] = tool_results
      assert result == MCP.tool_result_text("result1")
    end
  end

  describe "interaction persistence ordering" do
    test "mixed interaction writes persist strictly ordered unique positive sequences", %{
      scope: scope
    } do
      task_id = task_fixture(scope).id

      {:ok, _} =
        user_message_fixture(scope, task_id, user_content("msg1"))

      turn_number = latest_turn_number(task_id)

      {:ok, _} = Tasks.agent_replied(scope, task_id, turn_number, "response1")

      tool_call_data = %{id: "tc_1", name: "test_tool"}

      {:ok, _, _} =
        resolve_tool(
          scope,
          task_id,
          tool_call_data,
          MCP.tool_result_text("result"),
          false,
          turn_number
        )

      sequences = db_sequences(task_id)

      assert length(sequences) == 3
      assert sequences == Enum.sort(sequences)
      assert sequences == Enum.uniq(sequences)
      assert Enum.all?(sequences, &(&1 > 0))
    end

    test "concurrent inserts produce unique, sortable sequences", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)

      1..20
      |> Task.async_stream(
        fn i ->
          Tasks.agent_replied(scope, task_id, turn_number, "concurrent msg #{i}")
        end,
        max_concurrency: 20,
        timeout: :infinity
      )
      |> Enum.each(fn {:ok, {:ok, _interaction}} -> :ok end)

      results = db_sequences(task_id)

      assert length(results) == 21
      assert results == Enum.uniq(results), "sequences must be unique, got duplicates"
      assert results == Enum.sort(results), "DB ordering must be sorted"
    end

    test "preserves chronological history when legacy rows have nil sequence", %{scope: scope} do
      task_id = task_fixture(scope).id

      {:ok, legacy_message} = user_message_fixture(scope, task_id, user_content("legacy hello"))
      turn_number = latest_turn_number(task_id)

      from(i in InteractionSchema, where: i.id == ^legacy_message.id)
      |> Repo.update_all(set: [sequence: nil])

      {:ok, _new_response} = Tasks.agent_replied(scope, task_id, turn_number, "new response")

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert [
               %Interaction.UserMessage{messages: ["legacy hello"]},
               %Interaction.AgentResponse{content: "new response"}
             ] = task.interactions
    end
  end

  defp db_sequences(task_id) do
    task_id
    |> db_rows()
    |> Enum.map(& &1.sequence)
  end

  defp db_type_turns(task_id) do
    task_id
    |> db_rows()
    |> Enum.map(&{Interaction.module_for(&1.type), &1.turn_number})
  end

  defp db_rows(task_id) do
    InteractionSchema
    |> InteractionSchema.for_task(task_id)
    |> InteractionSchema.ordered()
    |> Repo.all()
  end

  defp insert_interaction_row(task_id, type, turn_number, data \\ %{}) do
    defaults = %{
      "id" => Ecto.UUID.generate(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "tool_name" => "question",
      "arguments" => %{},
      "result" => "ok"
    }

    Repo.insert!(%InteractionSchema{
      task_id: task_id,
      type: Interaction.type_for(type),
      turn_number: turn_number,
      sequence: System.unique_integer([:monotonic, :positive]),
      data: Map.merge(defaults, data)
    })
  end

  defp run_backfill_migration do
    Code.require_file("priv/repo/migrations/20260531130646_backfill_interaction_turn_numbers.exs")

    assert :ok =
             Runner.run(
               Repo,
               Repo.config(),
               0,
               BackfillInteractionTurnNumbers,
               :forward,
               :up,
               :up,
               log: false
             )
  end

  defp run_user_message_model_backfill_migration do
    Code.require_file("priv/repo/migrations/20260618000000_backfill_user_message_models.exs")

    assert :ok =
             Runner.run(
               Repo,
               Repo.config(),
               0,
               BackfillUserMessageModels,
               :forward,
               :up,
               :up,
               log: false
             )
  end

  defp named_swarm_tool_call(id, name, args \\ %{}) do
    %SwarmAi.ToolCall{id: id, name: name, arguments: Jason.encode!(args)}
  end

  describe "add_discovered_project_rule/4" do
    test "adds rule to task", %{scope: scope} do
      task_id = task_fixture(scope).id

      {:ok, rule} =
        Tasks.add_discovered_project_rule(scope, task_id, "/project/AGENTS.md", "# Rules")

      assert rule.path == "/project/AGENTS.md"
      assert rule.content == "# Rules"

      assert Repo.get_by!(InteractionSchema,
               task_id: task_id,
               type: Interaction.type_for(Interaction.DiscoveredProjectRule)
             ).turn_number ==
               nil
    end

    test "deduplicates by path", %{scope: scope} do
      task_id = task_fixture(scope).id

      {:ok, _rule} =
        Tasks.add_discovered_project_rule(scope, task_id, "/project/AGENTS.md", "# Rules v1")

      {:ok, :already_loaded} =
        Tasks.add_discovered_project_rule(scope, task_id, "/project/AGENTS.md", "# Rules v2")

      {:ok, task} = Tasks.get_task(scope, task_id)

      rules =
        Enum.filter(task.interactions, &match?(%Tasks.Interaction.DiscoveredProjectRule{}, &1))

      assert length(rules) == 1
      assert hd(rules).content == "# Rules v1"
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               Tasks.add_discovered_project_rule(scope, nonexistent_id, "/path", "content")
    end

    test "handles content with null bytes without crashing", %{scope: scope} do
      task_id = task_fixture(scope).id

      content_with_null = "# Rules\0with null\0bytes"

      {:ok, _rule} =
        Tasks.add_discovered_project_rule(
          scope,
          task_id,
          "/project/AGENTS.md",
          content_with_null
        )

      {:ok, task} = Tasks.get_task(scope, task_id)

      [db_rule] =
        Enum.filter(task.interactions, &match?(%Tasks.Interaction.DiscoveredProjectRule{}, &1))

      assert db_rule.path == "/project/AGENTS.md"
      refute String.contains?(db_rule.content, <<0>>)
      assert db_rule.content == "# Ruleswith nullbytes"
    end

    test "handles null bytes in rule file path without crashing", %{scope: scope} do
      task_id = task_fixture(scope).id

      path_with_null = "/project/AGENTS\0.md"

      {:ok, _rule} =
        Tasks.add_discovered_project_rule(scope, task_id, path_with_null, "# Clean content")

      {:ok, task} = Tasks.get_task(scope, task_id)

      [db_rule] =
        Enum.filter(task.interactions, &match?(%Tasks.Interaction.DiscoveredProjectRule{}, &1))

      refute String.contains?(db_rule.path, <<0>>)
      assert db_rule.path == "/project/AGENTS.md"
      assert db_rule.content == "# Clean content"
    end
  end

  describe "add_discovered_project_structure/3" do
    test "adds structure to task", %{scope: scope} do
      task_id = task_fixture(scope).id

      summary = "Project type: single project\n\nDirectory layout:\n."

      {:ok, structure} =
        Tasks.add_discovered_project_structure(scope, task_id, summary)

      assert structure.summary == summary

      assert Repo.get_by!(InteractionSchema,
               task_id: task_id,
               type: Interaction.type_for(Interaction.DiscoveredProjectStructure)
             ).turn_number == nil
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               Tasks.add_discovered_project_structure(scope, nonexistent_id, "summary")
    end
  end

  describe "list_todos/2" do
    test "returns empty list for task with no todos", %{scope: scope} do
      task_id = task_fixture(scope).id

      assert {:ok, []} = Tasks.list_todos(scope, task_id)
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()
      assert {:error, :not_found} = Tasks.list_todos(scope, nonexistent_id)
    end

    test "returns todos from task", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)

      write_result = %{
        "todos" => [
          %{
            "id" => Ecto.UUID.generate(),
            "content" => "First",
            "active_form" => "First",
            "status" => "pending",
            "priority" => "medium",
            "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
          },
          %{
            "id" => Ecto.UUID.generate(),
            "content" => "Second",
            "active_form" => "Second",
            "status" => "in_progress",
            "priority" => "medium",
            "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
          }
        ]
      }

      resolve_tool(
        scope,
        task_id,
        %{id: "c1", name: "todo_write"},
        MCP.tool_result_structured(write_result),
        false,
        turn_number
      )

      {:ok, todos} = Tasks.list_todos(scope, task_id)

      assert length(todos) == 2
      contents = Enum.map(todos, & &1.content)
      assert "First" in contents
      assert "Second" in contents
    end

    test "todos are isolated per task", %{scope: scope} do
      task_a = task_fixture(scope).id
      task_b = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_a)

      write_result = %{
        "todos" => [
          %{
            "id" => Ecto.UUID.generate(),
            "content" => "Task A todo",
            "active_form" => "Working",
            "status" => "pending",
            "priority" => "medium",
            "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
          }
        ]
      }

      resolve_tool(
        scope,
        task_a,
        %{id: "c1", name: "todo_write"},
        MCP.tool_result_structured(write_result),
        false,
        turn_number
      )

      {:ok, todos_a} = Tasks.list_todos(scope, task_a)
      {:ok, todos_b} = Tasks.list_todos(scope, task_b)

      assert match?([_], todos_a)
      assert todos_b == []
    end
  end

  describe "record_agent_run_result/4 paused DB round-trip" do
    test "persisted AgentPaused can be loaded back via get_task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, %TaskSchema{id: ^task_id}} = Tasks.create_task(scope, task_id, "nextjs")
      turn_number = start_turn_fixture(scope, task_id)

      {:ok, _interaction} =
        Tasks.record_agent_run_result(
          scope,
          task_id,
          turn_number,
          {:paused_for_tool_timeout, "question", 120_000}
        )

      {:ok, task} = Tasks.get_task(scope, task_id)

      paused = Enum.find(task.interactions, &match?(%Interaction.AgentPaused{}, &1))
      assert paused != nil
      assert paused.tool_name == "question"
      assert paused.timeout_ms == 120_000
    end

    test "to_swarm_messages/1 succeeds when interactions include AgentPaused", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, %TaskSchema{id: ^task_id}} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, _message} =
        user_message_fixture(scope, task_id, [%{"type" => "text", "text" => "Hi"}])

      turn_number = latest_turn_number(task_id)

      {:ok, _} =
        Tasks.record_agent_run_result(
          scope,
          task_id,
          turn_number,
          {:paused_for_tool_timeout, "question", 120_000}
        )

      {:ok, task} = Tasks.get_task(scope, task_id)

      messages = Interaction.to_swarm_messages(task.interactions)

      assert length(messages) == 1
      assert SwarmAi.Message.role(hd(messages)) == :user
    end
  end

  defp resolve_tool(scope, task_id, tool_call_data, result, is_error, turn_number) do
    Tasks.resolve_tool_request(scope, task_id, tool_call_data, result, is_error,
      turn_number: turn_number
    )
  end
end
