defmodule FrontmanServer.TasksTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.InteractionCase.Helpers
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.Framework
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  setup do
    scope = user_scope_fixture()
    %{scope: scope}
  end

  describe "topic/1" do
    test "returns topic string for task_id" do
      assert Tasks.topic("abc123") == "task:abc123"
    end
  end

  describe "create_task/3" do
    test "creates task with framework", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      framework = "nextjs"
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, framework)

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert task.task_id == task_id
      assert task.framework == Framework.from_string(framework)
    end
  end

  describe "get_short_desc/2" do
    test "returns title for existing task", %{scope: scope} do
      task_id = task_fixture(scope)

      assert {:ok, "New Task"} = Tasks.get_short_desc(scope, task_id)
    end

    test "returns updated title after set_generated_title", %{scope: scope} do
      task_id = task_fixture(scope)

      :ok = Tasks.set_generated_title(scope, task_id, "My Custom Title")
      assert {:ok, "My Custom Title"} = Tasks.get_short_desc(scope, task_id)
    end

    test "returns not_found for non-existent task", %{scope: scope} do
      assert {:error, :not_found} = Tasks.get_short_desc(scope, Ecto.UUID.generate())
    end

    test "returns not_found for task owned by different user", %{scope: scope} do
      task_id = task_fixture(scope)

      other_scope = user_scope_fixture()
      assert {:error, :not_found} = Tasks.get_short_desc(other_scope, task_id)
    end
  end

  describe "get_task/2 authorization" do
    test "returns not_found when accessing task owned by different user", %{scope: scope} do
      task_id = task_fixture(scope)

      # Create a different user/scope
      other_scope = user_scope_fixture()

      # Returns :not_found to prevent task enumeration attacks
      assert {:error, :not_found} = Tasks.get_task(other_scope, task_id)
    end
  end

  describe "LLM message conversion" do
    test "returns all messages for task", %{scope: scope} do
      task_id = task_fixture(scope)

      # Add a user message
      Tasks.add_user_message(scope, task_id, user_content("Hello"))

      # Add responses
      Tasks.add_agent_response(scope, task_id, "Response from agent", %{})
      Tasks.add_agent_response(scope, task_id, "Another response", %{})

      {:ok, task} = Tasks.get_task(scope, task_id)
      messages = Tasks.Interaction.to_llm_messages(task.interactions)

      # Should have: UserMessage + 2 responses = 3 messages
      assert length(messages) == 3

      # Should have assistant messages
      assistant_messages = Enum.filter(messages, &(&1.role == :assistant))
      assert length(assistant_messages) == 2
    end

    test "full tool_call + tool_result round-trip produces valid LLM messages", %{scope: scope} do
      task_id = task_fixture(scope)

      tool_call_id = "toolu_integration_#{System.unique_integer([:positive])}"

      {:ok, _} =
        Tasks.add_user_message(scope, task_id, user_content("What is 2+2?"))

      {:ok, _} =
        Tasks.add_agent_response(scope, task_id, "Let me calculate that.", %{
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

      tc = ReqLLM.ToolCall.new(tool_call_id, "calculator", ~s({"expression": "2+2"}))
      {:ok, _} = Tasks.add_tool_call(scope, task_id, tc)

      {:ok, _, _} =
        Tasks.add_tool_result(scope, task_id, %{id: tool_call_id, name: "calculator"}, "4", false)

      {:ok, _} = Tasks.add_agent_response(scope, task_id, "The answer is 4.")

      sequences = db_sequences(task_id)

      assert length(sequences) == 5
      assert sequences == Enum.sort(sequences), "sequences should be strictly increasing"
      assert sequences == Enum.uniq(sequences), "sequences should be unique"

      {:ok, task} = Tasks.get_task(scope, task_id)
      messages = Tasks.Interaction.to_llm_messages(task.interactions)

      assert length(messages) == 4,
             "expected 4 LLM messages, got #{length(messages)}: #{inspect(Enum.map(messages, & &1.role))}"

      [_user_msg, assistant_with_tool, tool_result_msg, final_assistant] = messages

      assert Enum.map(messages, & &1.role) == [:user, :assistant, :tool, :assistant]

      assert [%ReqLLM.ToolCall{} = tc_in_msg] = assistant_with_tool.tool_calls
      assert tc_in_msg.id == tool_call_id
      assert tc_in_msg.function.name == "calculator"

      assert tool_result_msg.tool_call_id == tool_call_id
      assert [%{type: :text, text: "4"}] = tool_result_msg.content

      assert [%{type: :text, text: "The answer is 4."}] = final_assistant.content
    end
  end

  describe "add_tool_call/3" do
    test "creates tool call interaction", %{scope: scope} do
      task_id = task_fixture(scope)

      tool_call = ReqLLM.ToolCall.new("call_123", "calculator", ~s({"expression": "1 + 1"}))

      {:ok, interaction} = Tasks.add_tool_call(scope, task_id, tool_call)

      assert interaction.tool_name == "calculator"
      assert interaction.tool_call_id == "call_123"
      assert interaction.arguments == %{"expression" => "1 + 1"}
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()
      tool_call = ReqLLM.ToolCall.new("call_123", "test", "{}")

      assert {:error, :not_found} =
               Tasks.add_tool_call(scope, nonexistent_id, tool_call)
    end
  end

  describe "add_tool_result/5" do
    test "creates tool result interaction", %{scope: scope} do
      task_id = task_fixture(scope)

      tool_call_data = %{id: "call_123", name: "calculator"}

      {:ok, interaction, _status} =
        Tasks.add_tool_result(scope, task_id, tool_call_data, 2, false)

      assert interaction.result == 2
      assert interaction.is_error == false
      assert interaction.tool_call_id == "call_123"
    end

    test "creates error tool result", %{scope: scope} do
      task_id = task_fixture(scope)

      tool_call_data = %{id: "call_456", name: "failing_tool"}

      {:ok, interaction, _status} =
        Tasks.add_tool_result(scope, task_id, tool_call_data, "error message", true)

      assert interaction.is_error == true
      assert interaction.result == "error message"
    end

    test "rejects duplicate tool result for the same tool_call_id", %{scope: scope} do
      task_id = task_fixture(scope)

      tool_call_data = %{id: "call_dedup", name: "some_tool"}

      {:ok, _first, _status} =
        Tasks.add_tool_result(scope, task_id, tool_call_data, "result1", false)

      assert {:error, %Ecto.Changeset{}} =
               Tasks.add_tool_result(scope, task_id, tool_call_data, "result2", false)

      {:ok, task} = Tasks.get_task(scope, task_id)
      tool_results = Enum.filter(task.interactions, &match?(%Tasks.Interaction.ToolResult{}, &1))
      assert [%Tasks.Interaction.ToolResult{result: "result1"}] = tool_results
    end
  end

  describe "interaction persistence ordering" do
    test "mixed interaction writes persist strictly ordered unique positive sequences", %{
      scope: scope
    } do
      task_id = task_fixture(scope)

      {:ok, _} =
        Tasks.add_user_message(scope, task_id, user_content("msg1"))

      {:ok, _} = Tasks.add_agent_response(scope, task_id, "response1")

      tool_call_data = %{id: "tc_1", name: "test_tool"}
      {:ok, _, _} = Tasks.add_tool_result(scope, task_id, tool_call_data, "result", false)

      sequences = db_sequences(task_id)

      assert length(sequences) == 3
      assert sequences == Enum.sort(sequences)
      assert sequences == Enum.uniq(sequences)
      assert Enum.all?(sequences, &(&1 > 0))
    end

    test "concurrent inserts produce unique, sortable sequences", %{scope: scope} do
      task_id = task_fixture(scope)

      1..20
      |> Task.async_stream(
        fn i ->
          Tasks.add_agent_response(scope, task_id, "concurrent msg #{i}")
        end,
        max_concurrency: 20,
        timeout: :infinity
      )
      |> Enum.each(fn {:ok, {:ok, _interaction}} -> :ok end)

      results = db_sequences(task_id)

      assert length(results) == 20
      assert results == Enum.uniq(results), "sequences must be unique, got duplicates"
      assert results == Enum.sort(results), "DB ordering must be sorted"
    end

    test "preserves chronological history when legacy rows have nil sequence", %{scope: scope} do
      task_id = task_fixture(scope)

      {:ok, legacy_message} = Tasks.add_user_message(scope, task_id, user_content("legacy hello"))

      from(i in InteractionSchema, where: i.id == ^legacy_message.id)
      |> Repo.update_all(set: [sequence: nil])

      {:ok, _new_response} = Tasks.add_agent_response(scope, task_id, "new response")

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert [
               %Interaction.UserMessage{messages: ["legacy hello"]},
               %Interaction.AgentResponse{content: "new response"}
             ] = task.interactions
    end
  end

  defp db_sequences(task_id) do
    InteractionSchema
    |> InteractionSchema.for_task(task_id)
    |> InteractionSchema.ordered()
    |> Repo.all()
    |> Enum.map(& &1.sequence)
  end

  describe "add_discovered_project_rule/4" do
    test "adds rule to task", %{scope: scope} do
      task_id = task_fixture(scope)

      {:ok, rule} =
        Tasks.add_discovered_project_rule(scope, task_id, "/project/AGENTS.md", "# Rules")

      assert rule.path == "/project/AGENTS.md"
      assert rule.content == "# Rules"
    end

    test "deduplicates by path", %{scope: scope} do
      task_id = task_fixture(scope)

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
      task_id = task_fixture(scope)

      # Simulate a project rule file containing null bytes (e.g., from a
      # Windows UTF-16 file, binary artifact, or corrupted file).
      # PostgreSQL rejects \0 in text/jsonb columns with:
      #   Postgrex.Error: ERROR 22P05 (untranslatable_character)
      content_with_null = "# Rules\0with null\0bytes"

      {:ok, _rule} =
        Tasks.add_discovered_project_rule(
          scope,
          task_id,
          "/project/AGENTS.md",
          content_with_null
        )

      # Verify it round-trips through the database with null bytes stripped
      {:ok, task} = Tasks.get_task(scope, task_id)

      [db_rule] =
        Enum.filter(task.interactions, &match?(%Tasks.Interaction.DiscoveredProjectRule{}, &1))

      assert db_rule.path == "/project/AGENTS.md"
      refute String.contains?(db_rule.content, <<0>>)
      assert db_rule.content == "# Ruleswith nullbytes"
    end

    test "handles null bytes in rule file path without crashing", %{scope: scope} do
      task_id = task_fixture(scope)

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
      task_id = task_fixture(scope)

      summary = "Project type: single project\n\nDirectory layout:\n."

      {:ok, structure} =
        Tasks.add_discovered_project_structure(scope, task_id, summary)

      assert structure.summary == summary
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               Tasks.add_discovered_project_structure(scope, nonexistent_id, "summary")
    end
  end

  describe "LLM message conversion excludes non-conversational interactions" do
    test "structure is excluded from LLM messages", %{scope: scope} do
      task_id = task_fixture(scope)

      Tasks.add_discovered_project_structure(scope, task_id, "Project layout...")

      Tasks.add_user_message(scope, task_id, user_content("Hello"))

      {:ok, task} = Tasks.get_task(scope, task_id)
      messages = Tasks.Interaction.to_llm_messages(task.interactions)

      # Only the user message should be present — structure goes in system prompt
      assert length(messages) == 1
      [msg] = messages
      assert msg.role == :user
    end

    test "rules are excluded from LLM messages", %{scope: scope} do
      task_id = task_fixture(scope)

      Tasks.add_discovered_project_rule(scope, task_id, "/project/AGENTS.md", "# Project Rules")

      Tasks.add_user_message(scope, task_id, user_content("Hello"))

      {:ok, task} = Tasks.get_task(scope, task_id)
      messages = Tasks.Interaction.to_llm_messages(task.interactions)

      assert length(messages) == 1
      [msg] = messages
      assert msg.role == :user

      content_text = extract_content_text(msg.content)
      refute content_text =~ "# Project Rules"
      assert content_text =~ "Hello"
    end
  end

  describe "annotation round-trip through JSONB" do
    test "annotation survives DB round-trip and appears in LLM messages", %{
      scope: scope
    } do
      task_id = task_fixture(scope)

      content_blocks = [
        text_block("Fix the button"),
        annotation_block("ann-test-1", "button", "src/components/Button.tsx", 42, 5),
        screenshot_block("ann-test-1", "iVBORw0KGgoAAAANSUhEUg==")
      ]

      {:ok, _interaction} =
        Tasks.add_user_message(scope, task_id, content_blocks)

      # Retrieve via LLM conversion (exercises the full JSONB round-trip)
      {:ok, task} = Tasks.get_task(scope, task_id)
      messages = Tasks.Interaction.to_llm_messages(task.interactions)

      assert length(messages) == 1
      [msg] = messages
      assert msg.role == :user

      # Extract text from content parts
      content_text = extract_content_text(msg.content)

      # The annotation location should have been appended by append_annotations/2
      assert content_text =~ "[Annotated Elements]"
      assert content_text =~ "src/components/Button.tsx"
      assert content_text =~ "42"

      # Screenshot should be present as an image content part
      image_parts =
        case msg.content do
          parts when is_list(parts) ->
            Enum.filter(parts, fn
              %{type: :image} -> true
              _ -> false
            end)

          _ ->
            []
        end

      assert [_ | _] = image_parts
    end
  end

  describe "list_todos/2" do
    test "returns empty list for task with no todos", %{scope: scope} do
      task_id = task_fixture(scope)

      assert {:ok, []} = Tasks.list_todos(scope, task_id)
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()
      assert {:error, :not_found} = Tasks.list_todos(scope, nonexistent_id)
    end

    test "returns todos from task", %{scope: scope} do
      task_id = task_fixture(scope)

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

      Tasks.add_tool_result(scope, task_id, %{id: "c1", name: "todo_write"}, write_result, false)

      {:ok, todos} = Tasks.list_todos(scope, task_id)

      assert length(todos) == 2
      contents = Enum.map(todos, & &1.content)
      assert "First" in contents
      assert "Second" in contents
    end

    test "todos are isolated per task", %{scope: scope} do
      task_a = task_fixture(scope)
      task_b = task_fixture(scope)

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

      Tasks.add_tool_result(scope, task_a, %{id: "c1", name: "todo_write"}, write_result, false)

      {:ok, todos_a} = Tasks.list_todos(scope, task_a)
      {:ok, todos_b} = Tasks.list_todos(scope, task_b)

      assert match?([_], todos_a)
      assert todos_b == []
    end
  end

  # ---------------------------------------------------------------------------
  # AgentPaused DB round-trip (regression tests for bugs 5 & 6)
  # ---------------------------------------------------------------------------

  describe "add_agent_paused/4 DB round-trip" do
    test "persisted AgentPaused can be loaded back via get_task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, _interaction} = Tasks.add_agent_paused(scope, task_id, "question", 120_000)

      # Bug 6: to_struct/1 had no "agent_paused" clause — get_task crashes
      {:ok, task} = Tasks.get_task(scope, task_id)

      paused = Enum.find(task.interactions, &match?(%Interaction.AgentPaused{}, &1))
      assert paused != nil
      assert paused.tool_name == "question"
      assert paused.timeout_ms == 120_000
    end

    test "to_llm_messages/1 succeeds when interactions include AgentPaused", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      Tasks.add_user_message(scope, task_id, [%{"type" => "text", "text" => "Hi"}])

      {:ok, _} = Tasks.add_agent_paused(scope, task_id, "question", 120_000)

      {:ok, task} = Tasks.get_task(scope, task_id)

      # Bug 5: conversation_message?/1 had no AgentPaused clause — FunctionClauseError
      messages = Interaction.to_llm_messages(task.interactions)

      # AgentPaused is not a conversation message — only the UserMessage should appear
      assert length(messages) == 1
      assert hd(messages).role == :user
    end
  end
end
