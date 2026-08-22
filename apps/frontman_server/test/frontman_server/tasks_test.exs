defmodule FrontmanServer.TasksTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Migration.Runner

  alias FrontmanServer.Repo.Migrations.{
    BackfillInteractionTurnNumbers,
    BackfillToolResultPayloads,
    BackfillUserMessageModels,
    ScrubToolResultMetadata
  }

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

      other_scope = user_scope_fixture()

      assert {:error, :not_found} = Tasks.get_task(other_scope, task_id)
    end
  end

  describe "get_active_run_unresolved_tool_calls/2" do
    test "returns unresolved tool calls only for active agent runs", %{scope: scope} do
      task_id = task_fixture(scope).id

      assert {:ok, :no_active_run} = Tasks.get_active_run_unresolved_tool_calls(scope, task_id)

      insert_started_user_message_row(task_id, 1)
      insert_interaction_row(task_id, Interaction.ToolCall, 1, %{"tool_call_id" => "call_1"})

      assert {:ok, 1, [%Interaction.ToolCall{tool_call_id: "call_1"}]} =
               Tasks.get_active_run_unresolved_tool_calls(scope, task_id)

      insert_interaction_row(task_id, Interaction.ToolResult, 1, %{"tool_call_id" => "call_1"})

      assert {:ok, 1, []} = Tasks.get_active_run_unresolved_tool_calls(scope, task_id)
    end

    test "accepted user messages without turns do not create an active run", %{scope: scope} do
      task = task_fixture(scope)

      insert_accepted_user_message!(task, "queued")

      assert {:ok, :no_active_run} = Tasks.get_active_run_unresolved_tool_calls(scope, task.id)
    end

    test "returns an error for task-scoped rows with turn numbers", %{scope: scope} do
      task_id = task_fixture(scope).id

      insert_legacy_interaction_row(task_id, Interaction.DiscoveredProjectRule, 1, %{})

      assert {:error, {:unknown_interaction_type, :discovered_project_rule}} =
               Tasks.get_active_run_unresolved_tool_calls(scope, task_id)
    end
  end

  describe "submit_user_message/2" do
    test "persists an accepted user message without starting a turn", %{scope: scope} do
      task = task_fixture(scope)

      assert {:ok, %InteractionSchema{data: %Interaction.UserMessage{}}} =
               Tasks.submit_user_message(scope, %{
                 task_id: task.id,
                 message: submitted_message("hello")
               })

      assert [row] = db_rows(task.id)
      assert row.type == :user_message
      assert row.turn_number == nil
      assert row.data.agent_id == "test-frontman"
      assert row.data.id == row.id
    end

    test "persists a caller-supplied user message id", %{scope: scope} do
      task = task_fixture(scope)
      message_id = Ecto.UUID.generate()

      assert {:ok, %InteractionSchema{id: ^message_id}} =
               Tasks.submit_user_message(scope, %{
                 task_id: task.id,
                 message: %{
                   id: message_id,
                   content: user_content("hello"),
                   model: "openrouter:openai/gpt-5.5",
                   agent_id: "test-frontman"
                 }
               })
    end

    test "rejects a duplicate caller-supplied user message id", %{scope: scope} do
      task = task_fixture(scope)
      message_id = Ecto.UUID.generate()

      attrs = %{
        task_id: task.id,
        message: %{
          id: message_id,
          content: user_content("hello"),
          model: "openrouter:openai/gpt-5.5",
          agent_id: "test-frontman"
        }
      }

      assert {:ok, %InteractionSchema{id: ^message_id}} = Tasks.submit_user_message(scope, attrs)
      assert {:error, %Ecto.Changeset{}} = Tasks.submit_user_message(scope, attrs)
    end

    test "requires agent id", %{scope: scope} do
      task = task_fixture(scope)

      assert Tasks.submit_user_message(scope, %{
               task_id: task.id,
               message: Map.delete(submitted_message("hello"), :agent_id)
             }) == {:error, :missing_agent}
    end

    test "accepts another user message while a turn is running", %{scope: scope} do
      task = task_fixture(scope)
      start_turn_fixture(scope, task.id, user_content("first"))

      assert {:ok, %InteractionSchema{data: %Interaction.UserMessage{}}} =
               Tasks.submit_user_message(scope, %{
                 task_id: task.id,
                 message: submitted_message("second")
               })

      assert [:user_message, :turn_started, :user_message] =
               task.id
               |> db_rows()
               |> Enum.map(& &1.type)
    end
  end

  describe "run_next_turn/3 agent identity" do
    test "persists configured agent identity", %{scope: scope} do
      task = task_fixture(scope)

      assert {:ok, %InteractionSchema{data: %Interaction.UserMessage{}}} =
               Tasks.submit_user_message(scope, %{
                 task_id: task.id,
                 message: submitted_message("hello")
               })

      assert :ok =
               Tasks.run_next_turn(
                 scope,
                 task.id,
                 execution_request_fixture(model: "missing:test")
               )

      assert {:ok, loaded_task} = Tasks.get_task(scope, task.id)

      assert %Interaction.TurnStarted{agent_id: "test-frontman"} =
               Enum.find(
                 Tasks.interactions(loaded_task),
                 &match?(%Interaction.TurnStarted{}, &1)
               )
    end

    test "rejects unknown agents before persisting TurnStarted", %{scope: scope} do
      task = task_fixture(scope)

      assert {:ok, %InteractionSchema{data: %Interaction.UserMessage{}}} =
               Tasks.submit_user_message(scope, %{
                 task_id: task.id,
                 message: submitted_message("hello", agent_id: "unknown-agent")
               })

      assert {:error, :unknown_agent} =
               Tasks.run_next_turn(scope, task.id, execution_request_fixture())

      refute Enum.any?(db_rows(task.id), &(&1.type == :turn_started))
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
      refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.AgentError{}, &1))

      assert [
               %Interaction.ToolResult{
                 tool_call_id: "read_1",
                 result: result,
                 is_error: true
               }
             ] = Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))

      assert result == %{
               "content" => [%{"type" => "text", "text" => "Interrupted by restart"}],
               "isError" => true,
               "_meta" => %{}
             }

      assert {:ok, ^turn_number, [%Interaction.ToolCall{tool_call_id: "question_1"}]} =
               Tasks.get_active_run_unresolved_tool_calls(scope, task_id)
    end
  end

  describe "swarm event persistence" do
    test "persists mixed-key provider usage with known fields only", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)

      usage = %{
        "cost" => 0.21366,
        "cost_details" => %{"upstream_inference_cost" => 0.21366},
        "cache_creation_tokens" => 10,
        input_tokens: 100,
        output_tokens: 50,
        reasoning_tokens: 15,
        cached_tokens: 25,
        total_tokens: 175,
        provider_exact_field: "preserved",
        nested_provider_data: %{"anything" => [1, 2, 3]}
      }

      response = %SwarmAi.LLM.Response{content: "hello", usage: usage}

      assert :ok = Tasks.handle_swarm_event(scope, task_id, turn_number, response_event(response))

      assert [
               %Interaction.AgentResponse{
                 metadata: %{},
                 timestamp: ~U[2026-07-14 12:30:01.000000Z],
                 usage: %Interaction.AgentResponse.Usage{} = stored_usage
               }
             ] = agent_responses(task_id)

      usage_attrs = Map.from_struct(stored_usage)

      assert usage_attrs == %{
               input_tokens: 100,
               output_tokens: 50,
               reasoning_tokens: 15,
               cached_tokens: 25,
               total_tokens: 175,
               cache_creation_tokens: 10
             }
    end

    test "omits response usage when usage is absent", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)
      response = %SwarmAi.LLM.Response{content: "hello", usage: nil}

      assert :ok = Tasks.handle_swarm_event(scope, task_id, turn_number, response_event(response))

      assert [%Interaction.AgentResponse{usage: nil}] = agent_responses(task_id)
    end

    test "rejects invalid response metadata", %{scope: scope} do
      task_id = task_fixture(scope).id
      turn_number = start_turn_fixture(scope, task_id)

      response = %SwarmAi.LLM.Response{content: "hello", metadata: %{response_id: 123}}

      assert_raise Ecto.InvalidChangesetError, ~r/response_id/, fn ->
        Tasks.handle_swarm_event(scope, task_id, turn_number, response_event(response))
      end
    end

    test "rejects invalid response usage", %{scope: scope} do
      for usage <- [
            "not a map",
            ["not", "a", "map"],
            %{input_tokens: -1},
            %{output_tokens: "five"}
          ] do
        task_id = task_fixture(scope).id
        turn_number = start_turn_fixture(scope, task_id)
        response = %SwarmAi.LLM.Response{content: "hello", usage: usage}

        assert_raise Ecto.InvalidChangesetError, ~r/usage/, fn ->
          Tasks.handle_swarm_event(scope, task_id, turn_number, response_event(response))
        end
      end
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
        insert_legacy_interaction_row(task_id, type, nil, data)
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

      insert_legacy_interaction_row(task_id, Interaction.UserMessage, 1, %{
        "messages" => ["hello"]
      })

      run_user_message_model_backfill_migration()

      assert [
               %{
                 data: %Interaction.UserMessage{model: "openrouter:google/gemini-3-flash-preview"}
               }
             ] =
               InteractionSchema.for_task(task_id)
               |> InteractionSchema.of_type(:user_message)
               |> Repo.all()
    end

    test "leaves explicit models untouched", %{scope: scope} do
      task_id = task_fixture(scope).id

      insert_legacy_interaction_row(task_id, Interaction.UserMessage, 1, %{
        "model" => "anthropic:claude-sonnet-4-6"
      })

      run_user_message_model_backfill_migration()

      assert [%{data: %Interaction.UserMessage{model: "anthropic:claude-sonnet-4-6"}}] =
               InteractionSchema.for_task(task_id)
               |> InteractionSchema.of_type(:user_message)
               |> Repo.all()
    end
  end

  describe "tool-result payload backfill migration" do
    test "wraps legacy strings as MCP text results and preserves existing MCP maps", %{
      scope: scope
    } do
      task_id = task_fixture(scope).id
      existing_mcp_result = MCP.tool_result_text("already canonical")

      insert_legacy_interaction_row(task_id, Interaction.ToolResult, 1, %{
        "tool_call_id" => "legacy-call",
        "result" => "[{\"name\":\"README.md\"}]",
        "is_error" => true
      })

      insert_legacy_interaction_row(task_id, Interaction.ToolResult, 2, %{
        "tool_call_id" => "canonical-call",
        "result" => existing_mcp_result,
        "is_error" => false
      })

      run_tool_result_payload_backfill_migration()

      assert [legacy, existing] =
               InteractionSchema.for_task(task_id)
               |> InteractionSchema.of_type(:tool_result)
               |> InteractionSchema.ordered()
               |> Repo.all()

      assert legacy.data.result == %{
               "content" => [
                 %{"type" => "text", "text" => "[{\"name\":\"README.md\"}]"}
               ],
               "isError" => true
             }

      assert existing.data.result == existing_mcp_result
    end
  end

  describe "tool-result metadata scrub migration" do
    test "scrubs historical result metadata without changing tool-owned payloads", %{scope: scope} do
      task_id = task_fixture(scope).id
      image_data = Base.encode64(<<0, 1, 2, 254, 255>>)
      structured_content = %{"items" => [%{"name" => "README.md"}], "count" => 1}

      insert_legacy_interaction_row(task_id, Interaction.ToolResult, 1, %{
        "tool_call_id" => "legacy-call",
        "result" => %{
          "content" => [
            %{"type" => "image", "data" => image_data, "mimeType" => "image/png"}
          ],
          "structuredContent" => structured_content,
          "isError" => false,
          "_meta" => %{
            "envApiKey" => "sk-fake-migration-secret",
            "model" => "fake-provider:fake-model",
            "unapproved" => %{"nested" => true}
          },
          "unknown" => "drop me"
        },
        "is_error" => true
      })

      insert_legacy_interaction_row(task_id, Interaction.ToolResult, 2, %{
        "tool_call_id" => "null-structured-content",
        "result" => %{
          "content" => [%{"type" => "text", "text" => "null structured content"}],
          "structuredContent" => nil
        },
        "is_error" => false
      })

      insert_legacy_interaction_row(task_id, Interaction.ToolResult, 3, %{
        "tool_call_id" => "absent-structured-content",
        "result" => %{
          "content" => [%{"type" => "text", "text" => "absent structured content"}]
        },
        "is_error" => false
      })

      insert_legacy_interaction_row(task_id, Interaction.AgentCompleted, 1, %{
        "result" => %{"unknown" => "leave me"}
      })

      run_tool_result_metadata_scrub_migration(:up)

      assert [tool_result, null_structured_content, absent_structured_content] =
               tool_results =
               task_id
               |> raw_interaction_data("tool_result")
               |> Enum.map(& &1["result"])

      assert tool_result == %{
               "content" => [
                 %{"type" => "image", "data" => image_data, "mimeType" => "image/png"}
               ],
               "structuredContent" => structured_content,
               "isError" => false,
               "unknown" => "drop me",
               "_meta" => %{}
             }

      assert null_structured_content == %{
               "content" => [%{"type" => "text", "text" => "null structured content"}],
               "structuredContent" => nil,
               "_meta" => %{}
             }

      assert absent_structured_content == %{
               "content" => [%{"type" => "text", "text" => "absent structured content"}],
               "_meta" => %{}
             }

      assert [%{"result" => %{"unknown" => "leave me"}}] =
               raw_interaction_data(task_id, "agent_completed")

      run_tool_result_metadata_scrub_migration(:down)

      assert tool_results ==
               task_id
               |> raw_interaction_data("tool_result")
               |> Enum.map(& &1["result"])
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
      insert_started_user_message_row(task_id, 1)
      insert_interaction_row(task_id, Interaction.AgentError, 1, %{"id" => "error-1"})

      insert_interaction_row(task_id, Interaction.AgentRetry, 1, %{
        "retried_error_id" => "error-1"
      })

      insert_interaction_row(task_id, Interaction.AgentCompleted, 1)

      assert {:error, :stale_turn} =
               Tasks.retry_execution(scope, task_id, "error-1", execution_request_fixture())
    end

    test "fills missing model from started turn user messages", %{scope: scope} do
      task = task_fixture(scope)
      start_turn_fixture(scope, task.id, user_content("failed"), "missing:test")

      {:ok, error} = Tasks.record_agent_run_result(scope, task.id, 1, {:failed, "boom"})

      assert :ok =
               Tasks.retry_execution(scope, task.id, error.id, %{
                 mcp_tools: [],
                 project_traits: []
               })

      assert [_retry] =
               task.id
               |> db_rows()
               |> Enum.filter(&(&1.type == :agent_retry))
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

    test "fills missing model from started turn user messages", %{scope: scope} do
      task = task_fixture(scope)
      start_turn_fixture(scope, task.id, user_content("running"), "missing:test")

      assert :ok = Tasks.resume_execution(scope, task.id, %{mcp_tools: [], project_traits: []})
    end
  end

  describe "tool result persistence and Swarm message conversion" do
    test "scrubs tool result metadata through its full round-trip", %{scope: scope} do
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

      untrusted_result = %{
        "content" => [
          %{"type" => "text", "text" => "4", "audience" => ["assistant"]}
        ],
        "structuredContent" => %{"answer" => 4},
        "_meta" => %{
          "envApiKey" => "sk-fake-env-key",
          "model" => %{"provider" => "openrouter", "value" => "fake/model"},
          "unapproved" => true
        },
        "unknownTopLevel" => "drop me"
      }

      sanitized_result = %{
        "content" => [%{"type" => "text", "text" => "4", "audience" => ["assistant"]}],
        "structuredContent" => %{"answer" => 4},
        "isError" => false,
        "_meta" => %{}
      }

      {:ok, persisted_result, _} =
        resolve_tool(
          scope,
          task_id,
          %{id: tool_call_id, name: "calculator"},
          untrusted_result,
          turn_number
        )

      assert persisted_result.result == sanitized_result
      assert persisted_result.is_error == false

      {:ok, _} = Tasks.agent_replied(scope, task_id, turn_number, "The answer is 4.")

      sequences = db_sequences(task_id)

      assert length(sequences) == 6
      assert sequences == Enum.sort(sequences), "sequences should be strictly increasing"
      assert sequences == Enum.uniq(sequences), "sequences should be unique"

      assert [
               {Interaction.UserMessage, nil},
               {Interaction.TurnStarted, ^turn_number},
               {Interaction.AgentResponse, ^turn_number},
               {Interaction.ToolCall, ^turn_number},
               {Interaction.ToolResult, ^turn_number},
               {Interaction.AgentResponse, ^turn_number}
             ] = db_type_turns(task_id)

      {:ok, task} = Tasks.get_task(scope, task_id)
      messages = Enum.flat_map(Tasks.interactions(task), &Tasks.Interaction.to_swarm_messages/1)

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
          turn_number
        )

      sequences = db_sequences(task_id)

      assert length(sequences) == 4
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

      assert length(results) == 22
      assert results == Enum.uniq(results), "sequences must be unique, got duplicates"
      assert results == Enum.sort(results), "DB ordering must be sorted"
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
    |> Enum.map(&{&1.data.__struct__, &1.turn_number})
  end

  defp db_rows(task_id) do
    InteractionSchema
    |> InteractionSchema.for_task(task_id)
    |> InteractionSchema.ordered()
    |> Repo.all()
  end

  defp agent_responses(task_id) do
    task_id
    |> db_rows()
    |> Enum.map(& &1.data)
    |> Enum.filter(&match?(%Interaction.AgentResponse{}, &1))
  end

  defp response_event(response) do
    {:response, %{timestamp: ~U[2026-07-14 12:30:01.000000Z]}, response}
  end

  defp interaction_type(module),
    do: PolymorphicEmbed.get_polymorphic_type(InteractionSchema, :data, module)

  defp insert_started_user_message_row(task_id, turn_number) do
    {:ok, attrs} =
      Interaction.UserMessage.attrs(user_content("test turn"), "openrouter:openai/gpt-5.5")

    attrs = Map.put(attrs, :id, Ecto.UUID.generate())

    row =
      InteractionSchema.create_changeset(task_id, :user_message, attrs, nil)
      |> Repo.insert!()

    InteractionSchema.create_changeset(
      task_id,
      :turn_started,
      %{
        id: Ecto.UUID.generate(),
        timestamp: Interaction.now(),
        agent_id: "test-frontman",
        user_message_id: row.id
      },
      turn_number
    )
    |> Repo.insert!()
  end

  defp insert_interaction_row(task_id, type, turn_number, data \\ %{}) do
    {interaction_type, attrs} = test_interaction_attrs(type, data)

    InteractionSchema.create_changeset(task_id, interaction_type, attrs, turn_number)
    |> Repo.insert!()
  end

  defp test_interaction_attrs(Interaction.DiscoveredProjectRule, _data),
    do:
      {:discovered_project_rule,
       %{path: "/project/AGENTS.md", content: "rules", timestamp: Interaction.now()}}

  defp test_interaction_attrs(Interaction.ToolCall, data) do
    {:ok, attrs} =
      Interaction.ToolCall.attrs(%SwarmAi.ToolCall{
        id: Map.get(data, "tool_call_id", Ecto.UUID.generate()),
        name: Map.get(data, "tool_name", "question"),
        arguments: Jason.encode!(Map.get(data, "arguments", %{}))
      })

    {:tool_call, attrs}
  end

  defp test_interaction_attrs(Interaction.ToolResult, data) do
    {:tool_result,
     Interaction.ToolResult.attrs(
       %{id: Map.get(data, "tool_call_id", Ecto.UUID.generate()), name: "question"},
       MCP.tool_result_text("ok")
     )}
  end

  defp test_interaction_attrs(Interaction.AgentError, data),
    do:
      {:agent_error,
       %{
         id: Map.fetch!(data, "id"),
         timestamp: Interaction.now(),
         error: "error",
         kind: "failed",
         retryable: false,
         category: "unknown"
       }}

  defp test_interaction_attrs(Interaction.AgentRetry, data),
    do:
      {:agent_retry,
       %{
         id: Ecto.UUID.generate(),
         timestamp: Interaction.now(),
         retried_error_id: Map.fetch!(data, "retried_error_id")
       }}

  defp test_interaction_attrs(Interaction.AgentCompleted, _data),
    do: {:agent_completed, %{id: Ecto.UUID.generate(), timestamp: Interaction.now(), result: nil}}

  defp insert_legacy_interaction_row(task_id, type, turn_number, data) do
    now = DateTime.utc_now(:second)

    data =
      %{
        "__type__" => interaction_type(type) |> Atom.to_string(),
        "id" => Ecto.UUID.generate(),
        "timestamp" => DateTime.to_iso8601(now),
        "tool_name" => "question",
        "arguments" => %{},
        "result" => %{}
      }
      |> Map.merge(data)

    Repo.query!(
      """
      INSERT INTO interactions (id, task_id, type, data, turn_number, sequence, inserted_at)
      VALUES ($1, $2, $3, $4::text::jsonb, $5, $6, $7)
      """,
      [
        Ecto.UUID.dump!(Ecto.UUID.generate()),
        Ecto.UUID.dump!(task_id),
        interaction_type(type) |> Atom.to_string(),
        Jason.encode!(data),
        turn_number,
        System.unique_integer([:monotonic, :positive]),
        now
      ]
    )
  end

  defp insert_accepted_user_message!(
         %TaskSchema{} = task,
         text,
         model \\ "openrouter:openai/gpt-5.5"
       ) do
    {:ok, attrs} = Interaction.UserMessage.attrs(user_content(text), model)
    attrs = Map.put(attrs, :id, Ecto.UUID.generate())

    InteractionSchema.create_changeset(task.id, :user_message, attrs, nil)
    |> Repo.insert!()
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

  defp run_tool_result_payload_backfill_migration do
    Code.require_file("priv/repo/migrations/20260717000000_backfill_tool_result_payloads.exs")

    assert :ok =
             Runner.run(
               Repo,
               Repo.config(),
               0,
               BackfillToolResultPayloads,
               :forward,
               :up,
               :up,
               log: false
             )
  end

  defp run_tool_result_metadata_scrub_migration(direction) do
    Code.require_file("priv/repo/migrations/20260721000000_scrub_tool_result_metadata.exs")

    assert :ok =
             Runner.run(
               Repo,
               Repo.config(),
               0,
               ScrubToolResultMetadata,
               :forward,
               direction,
               direction,
               log: false
             )
  end

  defp raw_interaction_data(task_id, type) do
    %{rows: rows} =
      Repo.query!(
        "SELECT data FROM interactions WHERE task_id = $1 AND type = $2 ORDER BY sequence",
        [Ecto.UUID.dump!(task_id), type]
      )

    Enum.map(rows, fn [data] -> data end)
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
               type: :discovered_project_rule
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
        Enum.filter(
          Tasks.interactions(task),
          &match?(%Tasks.Interaction.DiscoveredProjectRule{}, &1)
        )

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
        Enum.filter(
          Tasks.interactions(task),
          &match?(%Tasks.Interaction.DiscoveredProjectRule{}, &1)
        )

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
        Enum.filter(
          Tasks.interactions(task),
          &match?(%Tasks.Interaction.DiscoveredProjectRule{}, &1)
        )

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
               type: :discovered_project_structure
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
        %{"content" => [], "structuredContent" => write_result},
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
        %{"content" => [], "structuredContent" => write_result},
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

      paused = Enum.find(Tasks.interactions(task), &match?(%Interaction.AgentPaused{}, &1))
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

      messages = Enum.flat_map(Tasks.interactions(task), &Interaction.to_swarm_messages/1)

      assert length(messages) == 1
      assert SwarmAi.Message.role(hd(messages)) == :user
    end
  end

  defp resolve_tool(scope, task_id, tool_call_data, result, turn_number) do
    Tasks.resolve_tool_request(scope, task_id, tool_call_data, result, turn_number: turn_number)
  end

  defp submitted_message(text, overrides \\ []) do
    %{
      id: Ecto.UUID.generate(),
      content: user_content(text),
      model: "openrouter:openai/gpt-5.5",
      agent_id: "test-frontman"
    }
    |> Map.merge(Map.new(overrides))
  end
end
