defmodule FrontmanServer.TaskSummariesTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.BillingFixtures
  import FrontmanServer.InteractionCase.Helpers

  alias FrontmanNotifier.State
  alias FrontmanNotifier.TaskSummaries
  alias FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.Test.Fixtures.Tasks

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    state = String.to_atom("task_summary_#{System.unique_integer([:positive])}")
    start_supervised!({State, name: state, table: state, state_dir: tmp_dir})
    scope = Accounts.user_scope_fixture()
    task = Tasks.task_fixture(scope)
    task = task |> Ecto.Changeset.change(short_desc: "Fix the hero button") |> Repo.update!()
    %{scope: scope, task: task, state: state}
  end

  test "loads subscribed users with accurate stats, intent, tools, and issue details", %{
    scope: scope,
    task: task,
    state: state
  } do
    subscription_for_scope_fixture(scope, %{status: "active", interval: :monthly})

    persist(task, :user_message, user_msg("Make the hero button more prominent"))

    persist(
      task,
      :agent_error,
      agent_error("Could not apply patch", "failed", true, "tool_failure")
    )

    call = %{tool_call("call_1", "edit_file") | execution_mode: :synchronous}
    persist(task, :tool_call, call)

    result = %{
      "content" => [%{"type" => "text", "text" => "Patch failed"}],
      "isError" => true
    }

    persist(
      task,
      :tool_result,
      tool_result("call_1", "edit_file", result, is_error: true)
    )

    embed = summary(task, state)

    assert embed.title == "Task summary: Fix the hero button"
    assert embed.description =~ "Make the hero button more prominent"
    assert embed.color == 0xED4245
    assert field_value(embed, "User") =~ scope.user.email
    assert field_value(embed, "Framework") == "nextjs"
    assert field_value(embed, "Billing") == "active · monthly"
    assert field_value(embed, "Stats") =~ "4 interactions"
    assert field_value(embed, "Issues") == "1 agent errors · 1 tool errors · 0 pauses"
    assert field_value(embed, "Issue details") =~ "Could not apply patch"
    assert field_value(embed, "Issue details") =~ "Patch failed"
    assert field_value(embed, "Tools") == "edit_file"
  end

  test "keeps users without billing records and reports five free messages", %{
    task: task,
    state: state
  } do
    persist(task, :agent_completed, agent_completed())
    embed = summary(task, state)

    assert field_value(embed, "Billing") == "Free · 5 of 5 messages left"
    assert field_value(embed, "Stats") =~ "1 interactions"
    assert embed.color == 0x57F287
  end

  test "keeps billing customers without subscriptions or allowance records", %{
    scope: scope,
    task: task,
    state: state
  } do
    customer_for_scope_fixture(scope)
    persist(task, :agent_completed, agent_completed())

    assert field_value(summary(task, state), "Billing") == "Free · 5 of 5 messages left"
  end

  test "loads partial and exhausted lifetime allowances without subscriptions", %{state: state} do
    for {used, remaining} <- [{2, 3}, {5, 0}] do
      scope = Accounts.user_scope_fixture()
      task = Tasks.task_fixture(scope)
      run_allowance_fixture(scope, used)
      persist(task, :agent_completed, agent_completed())

      embed = summary(task, state)
      assert field_value(embed, "Billing") == "Free · #{remaining} of 5 messages left"
      assert field_value(embed, "Stats") =~ "1 interactions"
    end
  end

  test "preserves stored subscription statuses and optional intervals", %{state: state} do
    for {status, interval, expected} <- [
          {"trialing", :yearly, "trialing · yearly"},
          {"past_due", :yearly, "past_due · yearly"},
          {"canceled", nil, "canceled"},
          {"unpaid", :monthly, "unpaid · monthly"},
          {"incomplete", :monthly, "incomplete · monthly"}
        ] do
      scope = Accounts.user_scope_fixture()
      task = Tasks.task_fixture(scope)
      subscription_for_scope_fixture(scope, %{status: status, interval: interval})
      persist(task, :agent_completed, agent_completed())

      assert field_value(summary(task, state), "Billing") == expected
    end
  end

  test "excludes tasks with recent interactions", %{task: task, state: state} do
    persist(task, :agent_completed, agent_completed(), DateTime.utc_now(:second))

    refute Enum.any?(TaskSummaries.load_summaries(Repo, 100, state), fn {id, _embed} ->
             id == task.id
           end)
  end

  test "excludes notified tasks before applying the batch limit", %{
    scope: scope,
    task: seen,
    state: state
  } do
    pending = Tasks.task_fixture(scope)
    persist(seen, :agent_completed, agent_completed())
    persist(pending, :agent_completed, agent_completed())
    :ok = State.mark_seen(:task_summary, seen.id, state)

    pending_id = pending.id
    assert [{^pending_id, _embed}] = TaskSummaries.load_summaries(Repo, 1, state)
    refute State.seen?(:task_summary, pending_id, state)
  end

  defp persist(task, type, data, inserted_at \\ DateTime.add(DateTime.utc_now(:second), -7_200)) do
    Tasks.interaction_changeset(task.id, %{
      id: data.id,
      type: type,
      data: Map.from_struct(data),
      turn_number: if(type == :user_message, do: nil, else: 1)
    })
    |> Ecto.Changeset.put_change(:inserted_at, inserted_at)
    |> Repo.insert!()
  end

  defp summary(task, state) do
    summaries = TaskSummaries.load_summaries(Repo, 100, state)
    task_id = task.id
    assert [{^task_id, embed}] = Enum.filter(summaries, fn {id, _embed} -> id == task_id end)
    embed
  end

  defp field_value(embed, name) do
    embed.fields
    |> Enum.find(&(&1.name == name))
    |> Map.fetch!(:value)
  end
end
