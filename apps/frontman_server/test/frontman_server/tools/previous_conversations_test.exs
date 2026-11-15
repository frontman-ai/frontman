defmodule FrontmanServer.Tools.PreviousConversationsTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Todos
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.PreviousConversations

  test "finds prior prepared text across task titles and pages its UTF-8 content" do
    scope = user_scope_fixture()
    prior = task_fixture(scope)

    turn =
      start_turn_fixture(scope, prior.id, [
        %{"type" => "text", "text" => "Rename artist"},
        %{"type" => "text", "text" => "Unique second-block phrase"}
      ])

    text = String.duplicate("Préparation ", 900) <> "28 titres SEO"
    {:ok, _} = Tasks.agent_replied(scope, prior.id, turn, text)
    {:ok, _} = Tasks.record_execution_outcome(scope, prior.id, turn, :completed)
    context = context(scope)

    assert Tools.resolve(%{access: [:read]}, [])["previous_conversations"] ==
             PreviousConversations

    [%{"task_id" => task_id, "match" => %{"interaction_id" => id}}] =
      call(context, %{"query" => "28 TITRES SEO"})["tasks"]

    assert task_id == prior.id

    assert [%{"match" => %{"excerpt" => excerpt}}] =
             call(context, %{"query" => "second-block"})["tasks"]

    assert excerpt =~ "Unique second-block phrase"
    first = call(context, %{"task_id" => prior.id, "interaction_id" => id})

    second =
      call(context, %{
        "task_id" => prior.id,
        "interaction_id" => id,
        "offset" => first["next_offset"]
      })

    assert first["text"] <> second["text"] == text
    assert second["next_offset"] == nil
  end

  test "rejects other users' conversations and the current task" do
    scope = user_scope_fixture()
    other_scope = user_scope_fixture()
    other = task_fixture(other_scope)
    start_turn_fixture(other_scope, other.id, user_content("Private SEO notes"))
    context = context(scope)

    assert call(context, %{"query" => "Private SEO"})["tasks"] == []
    assert MCP.error?(PreviousConversations.execute(%{"before_task_id" => other.id}, context))
    assert MCP.error?(PreviousConversations.execute(%{"task_id" => other.id}, context))
    own_id = String.upcase(context.task.id)
    assert MCP.error?(PreviousConversations.execute(%{"task_id" => own_id}, context))
  end

  test "pages completed turns and projects answers and validated todos, not other results" do
    scope = user_scope_fixture()
    prior = task_fixture(scope)

    for i <- 1..11 do
      turn = start_turn_fixture(scope, prior.id, user_content("Step #{i}"))
      {:ok, _} = Tasks.agent_replied(scope, prior.id, turn, "Answer #{i}")
      {:ok, _} = Tasks.record_execution_outcome(scope, prior.id, turn, :completed)
    end

    context = context(scope)
    first = call(context, %{"task_id" => prior.id})
    second = call(context, %{"task_id" => prior.id, "page" => first["next_page"]})
    assert length(first["interactions"]) == 20
    assert length(second["interactions"]) == 2
    assert second["next_page"] == nil

    turn = start_turn_fixture(scope, prior.id, user_content("Continue plan"))
    {:ok, todo} = Todos.Todo.make("Apply SEO", "Applying SEO", "pending", "high")
    todo = todo |> Jason.encode!() |> Jason.decode!()

    for {id, name, result} <- [
          {"answer", "question",
           %{"content" => [%{"type" => "text", "text" => "Original plan"}]}},
          {"todo", "todo_write", %{"content" => [], "structuredContent" => %{"todos" => [todo]}}},
          {"other", "read_file",
           %{"content" => [%{"type" => "text", "text" => "private payload"}]}}
        ] do
      {:ok, _, :no_executor} =
        Tasks.resolve_tool_request(scope, prior.id, %{id: id, name: name}, result,
          turn_number: turn
        )
    end

    rows = call(context, %{"task_id" => prior.id, "page" => 1})["interactions"]
    question = Enum.find(rows, &(&1["tool_name"] == "question"))
    todo_row = Enum.find(rows, &(&1["tool_name"] == "todo_write"))
    other = Enum.find(rows, &(&1["tool_name"] == "read_file"))

    assert call(context, %{"task_id" => prior.id, "interaction_id" => question["id"]})["text"] ==
             "Original plan"

    assert call(context, %{"task_id" => prior.id, "interaction_id" => todo_row["id"]})["text"] =~
             "Apply SEO"

    refute Map.has_key?(other, "preview")

    assert MCP.error?(
             PreviousConversations.execute(
               %{"task_id" => prior.id, "interaction_id" => other["id"]},
               context
             )
           )
  end

  defp context(scope) do
    {:ok, task} = Tasks.get_task_with_history(scope, task_with_active_turn_fixture(scope).id)
    %Context{scope: scope, task: task}
  end

  defp call(context, args) do
    result = PreviousConversations.execute(args, context)
    refute MCP.error?(result)
    result |> MCP.extract_content_text() |> Jason.decode!()
  end
end
