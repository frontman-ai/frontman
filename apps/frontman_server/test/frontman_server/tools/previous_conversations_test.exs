defmodule FrontmanServer.Tools.PreviousConversationsTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.FindPreviousConversations
  alias FrontmanServer.Tools.ReadPreviousConversation

  test "registers both tools for read-only agents" do
    tools = Tools.resolve(%{access: [:read]}, [])
    assert tools["find_previous_conversations"] == FindPreviousConversations
    assert tools["read_previous_conversation"] == ReadPreviousConversation
  end

  test "find tool runs through the backend executor and persists its result" do
    scope = user_scope_fixture()
    prior = task_fixture(scope)
    start_turn_fixture(scope, prior.id, user_content("Prior plan"))
    current = task_with_active_turn_fixture(scope)
    turn = latest_turn_number(current.id)

    tool_call = %SwarmAi.ToolCall{
      id: "find-prior-1",
      name: "find_previous_conversations",
      arguments: Jason.encode!(%{"query" => "Prior plan"})
    }

    %SwarmAi.ToolResult{} =
      ToolExecutor.run_backend_tool(
        scope,
        FindPreviousConversations,
        current.id,
        turn,
        tool_call
      )

    {:ok, task} = Tasks.get_task_with_history(scope, current.id)

    assert Enum.any?(task.interaction_rows, fn row ->
             row.type == :tool_result and row.data.tool_name == "find_previous_conversations" and
               row.data.is_error == false and
               MCP.extract_content_text(row.data.result) =~ prior.id
           end)
  end

  test "finds a prepared response in a differently titled prior task and pages its text" do
    scope = user_scope_fixture()
    prior = task_fixture(scope)
    turn = start_turn_fixture(scope, prior.id, user_content("Rename artist"))
    text = String.duplicate("Préparation ", 900) <> "28 titres SEO et méta-descriptions"
    {:ok, _response} = Tasks.agent_replied(scope, prior.id, turn, text)
    response_id = response_row_id(scope, prior.id)
    current = task_with_active_turn_fixture(scope)
    context = context(scope, current.id)

    result = find(context, %{"query" => "28 TITRES SEO"})

    assert [%{"task_id" => task_id}] = result["tasks"]
    assert task_id == prior.id
    assert result["next_cursor"] == nil

    first_page = read(context, %{"task_id" => prior.id})
    assert Enum.any?(first_page["interactions"], &(&1["id"] == response_id))
    assert Enum.all?(first_page["interactions"], &(byte_size(&1["preview"]) <= 720))

    first = read(context, %{"task_id" => prior.id, "interaction_id" => response_id})
    assert first["total_bytes"] == byte_size(text)
    assert is_integer(first["next_offset"])

    second =
      read(context, %{
        "task_id" => prior.id,
        "interaction_id" => response_id,
        "offset" => first["next_offset"]
      })

    assert first["text"] <> second["text"] == text
    assert second["next_offset"] == nil
    assert first["note"] =~ "Historical reference"

    assert MCP.error?(
             ReadPreviousConversation.execute(
               %{"task_id" => prior.id, "interaction_id" => response_id, "offset" => 3},
               context
             )
           )
  end

  test "only the owner can find or read a previous conversation" do
    scope = user_scope_fixture()
    other_scope = user_scope_fixture()
    other_task = task_fixture(other_scope)
    start_turn_fixture(other_scope, other_task.id, user_content("Private SEO notes"))
    context = context(scope, task_with_active_turn_fixture(scope).id)

    assert find(context, %{"query" => "Private SEO"})["tasks"] == []

    assert MCP.error?(
             FindPreviousConversations.execute(%{"before_task_id" => other_task.id}, context)
           )

    assert MCP.error?(ReadPreviousConversation.execute(%{"task_id" => other_task.id}, context))

    assert MCP.error?(ReadPreviousConversation.execute(%{"task_id" => context.task.id}, context))

    assert MCP.error?(
             ReadPreviousConversation.execute(
               %{"task_id" => String.upcase(context.task.id)},
               context
             )
           )
  end

  test "list cursor and interaction cursor cannot escape a selected owned task" do
    scope = user_scope_fixture()
    prior = task_fixture(scope)
    first_turn = start_turn_fixture(scope, prior.id, user_content("First note"))
    {:ok, _response} = Tasks.agent_replied(scope, prior.id, first_turn, "First response")
    response_id = response_row_id(scope, prior.id)

    for i <- 1..11 do
      turn = start_turn_fixture(scope, prior.id, user_content("Note #{i}"))
      {:ok, _response} = Tasks.agent_replied(scope, prior.id, turn, "Response #{i}")
    end

    current = task_with_active_turn_fixture(scope)
    context = context(scope, current.id)
    page = read(context, %{"task_id" => prior.id})
    assert length(page["interactions"]) == 20
    assert is_binary(page["next_cursor"])

    next_page =
      read(context, %{"task_id" => prior.id, "after_interaction_id" => page["next_cursor"]})

    refute Enum.any?(next_page["interactions"], &(&1["id"] == response_id))
    assert next_page["next_cursor"] == nil

    {:ok, current_task} = Tasks.get_task_with_history(scope, current.id)
    current_message = Enum.find(current_task.interaction_rows, &(&1.type == :user_message))

    assert MCP.error?(
             ReadPreviousConversation.execute(
               %{"task_id" => prior.id, "interaction_id" => current_message.id},
               context
             )
           )
  end

  test "interaction pagination retains rows tied at a page boundary" do
    scope = user_scope_fixture()
    prior = task_fixture(scope)

    for i <- 1..11 do
      turn = start_turn_fixture(scope, prior.id, user_content("Note #{i}"))
      {:ok, _response} = Tasks.agent_replied(scope, prior.id, turn, "Response #{i}")
    end

    rows =
      prior.id
      |> InteractionSchema.for_task()
      |> InteractionSchema.ordered()
      |> Repo.all()
      |> Enum.filter(&(&1.type in [:user_message, :agent_response]))

    twentieth = Enum.at(rows, 19)
    twenty_first = Enum.at(rows, 20)

    twenty_first
    |> Ecto.Changeset.change(
      sequence: twentieth.sequence,
      inserted_at: twentieth.inserted_at
    )
    |> Repo.update!()

    context = context(scope, task_with_active_turn_fixture(scope).id)
    first = read(context, %{"task_id" => prior.id})

    second =
      read(context, %{"task_id" => prior.id, "after_interaction_id" => first["next_cursor"]})

    all_ids = Enum.map(first["interactions"] ++ second["interactions"], & &1["id"])

    assert length(all_ids) == length(rows)
    assert MapSet.new(all_ids) == MapSet.new(Enum.map(rows, & &1.id))
  end

  test "summarizes tool results but allows a previous question answer to be paged" do
    scope = user_scope_fixture()
    prior = task_with_active_turn_fixture(scope)
    turn = latest_turn_number(prior.id)
    answer = ~s({"answers":[{"answer":["The previous plan has four steps"]}]})

    {:ok, _result, :no_executor} =
      Tasks.resolve_tool_request(
        scope,
        prior.id,
        %{id: "question-1", name: "question"},
        %{"content" => [%{"type" => "text", "text" => answer}], "isError" => false},
        turn_number: turn
      )

    {:ok, _result, :no_executor} =
      Tasks.resolve_tool_request(
        scope,
        prior.id,
        %{id: "secret-1", name: "read_file"},
        %{
          "content" => [%{"type" => "text", "text" => "unrelated tool payload"}],
          "isError" => false
        },
        turn_number: turn
      )

    {:ok, _result, :no_executor} =
      Tasks.resolve_tool_request(
        scope,
        prior.id,
        %{id: "todo-1", name: "todo_write"},
        %{
          "content" => [%{"type" => "text", "text" => "Todo updated"}],
          "structuredContent" => %{
            "todos" => [%{"content" => "Apply prepared SEO", "status" => "pending"}]
          },
          "isError" => false
        },
        turn_number: turn
      )

    current = task_with_active_turn_fixture(scope)
    context = context(scope, current.id)
    rows = read(context, %{"task_id" => prior.id})["interactions"]
    question = Enum.find(rows, &(&1["tool_name"] == "question"))
    other = Enum.find(rows, &(&1["tool_name"] == "read_file"))
    todo = Enum.find(rows, &(&1["tool_name"] == "todo_write"))

    assert question["preview"] =~ "previous plan"
    assert other["preview"] == ""
    assert other["bytes"] == 0

    assert read(context, %{"task_id" => prior.id, "interaction_id" => question["id"]})["text"] ==
             answer

    assert read(context, %{"task_id" => prior.id, "interaction_id" => todo["id"]})["text"] =~
             "Apply prepared SEO"

    assert MCP.error?(
             ReadPreviousConversation.execute(
               %{"task_id" => prior.id, "interaction_id" => other["id"]},
               context
             )
           )
  end

  test "paginates recent tasks even when only an older task matches" do
    scope = user_scope_fixture()
    prior = task_fixture(scope)
    start_turn_fixture(scope, prior.id, user_content("Earlier four-step plan"))

    prior
    |> Ecto.Changeset.change(
      inserted_at:
        DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
    )
    |> Repo.update!()

    current = task_with_active_turn_fixture(scope)

    for _ <- 1..20, do: task_fixture(scope)

    context = context(scope, current.id)
    first = find(context, %{"query" => "four-step"})
    assert first["tasks"] == []
    assert is_binary(first["next_cursor"])

    second = find(context, %{"query" => "four-step", "before_task_id" => first["next_cursor"]})
    assert Enum.map(second["tasks"], & &1["task_id"]) == [prior.id]
    assert second["next_cursor"] == nil
  end

  defp context(scope, task_id) do
    {:ok, task} = Tasks.get_task_with_history(scope, task_id)
    %Context{scope: scope, task: task}
  end

  defp response_row_id(scope, task_id) do
    {:ok, task} = Tasks.get_task_with_history(scope, task_id)
    Enum.find(task.interaction_rows, &(&1.type == :agent_response)).id
  end

  defp find(context, args) do
    result = FindPreviousConversations.execute(args, context)
    refute MCP.error?(result)
    result |> MCP.extract_content_text() |> Jason.decode!()
  end

  defp read(context, args) do
    result = ReadPreviousConversation.execute(args, context)
    refute MCP.error?(result)
    result |> MCP.extract_content_text() |> Jason.decode!()
  end
end
