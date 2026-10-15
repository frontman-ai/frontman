defmodule FrontmanServer.TasksToolUsageTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.InteractionSchema

  @name "request_customer_feedback"
  @now ~U[2026-10-01 12:00:00Z]
  @cutoff DateTime.add(@now, -30, :day)

  setup do
    scope = user_scope_fixture()
    task = task_fixture(scope)
    turn = start_turn_fixture(scope, task.id)
    call = %SwarmAi.ToolCall{id: "feedback", name: @name, arguments: "{}"}
    %{scope: scope, task: task, turn: turn, call: call}
  end

  test "no request, another tool, and another user do not block eligibility", context do
    refute Tasks.tool_used_since?(context.scope, @name, @cutoff)
    request(context, @now)
    refute Tasks.tool_used_since?(user_scope_fixture(), @name, @cutoff)
    refute Tasks.tool_used_since?(context.scope, "question", @cutoff)
    assert Tasks.tool_used_since?(context.scope, @name, @cutoff)
  end

  test "requests at or before the cutoff expire", context do
    request(context, @cutoff)
    refute Tasks.tool_used_since?(context.scope, @name, @cutoff)
  end

  test "a recent result still counts when its request has expired", context do
    request(context, DateTime.add(@cutoff, -1, :day))
    refute Tasks.tool_used_since?(context.scope, @name, @cutoff)

    {:ok, _, _} =
      Tasks.resolve_tool_request(context.scope, context.task.id, context.call, %{
        "structuredContent" => %{"outcome" => "answered", "score" => 0}
      })

    InteractionSchema.for_task(context.task.id)
    |> InteractionSchema.of_type(:tool_result)
    |> Repo.update_all(set: [inserted_at: @now])

    assert Tasks.tool_used_since?(context.scope, @name, @cutoff)
  end

  defp request(context, timestamp) do
    {:ok, _} =
      Tasks.request_client_tool(
        context.scope,
        context.task.id,
        context.turn,
        context.call,
        :interactive
      )

    InteractionSchema.for_task(context.task.id)
    |> InteractionSchema.of_type(:tool_call)
    |> Repo.update_all(set: [inserted_at: timestamp])
  end
end
