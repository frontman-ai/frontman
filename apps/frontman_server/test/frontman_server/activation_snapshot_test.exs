defmodule FrontmanServer.ActivationSnapshotTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Accounts.Scope

  @sql File.read!(Path.expand("../../priv/scripts/activation_snapshot.sql", __DIR__))

  test "UTC complete cohorts count distinct surviving users and only retained evidence" do
    Repo.query!("SET LOCAL TIME ZONE 'Pacific/Honolulu'")
    [[today]] = Repo.query!("SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date").rows
    week_end = today |> Date.beginning_of_week() |> DateTime.new!(~T[00:00:00])
    week_start = DateTime.add(week_end, -84, :day)
    last_week = DateTime.add(week_end, -7, :day)

    [_, zero, active, message_only, completed_only, _, _] =
      Enum.map(
        [
          DateTime.add(week_start, -1),
          week_start,
          last_week,
          last_week,
          DateTime.add(week_end, -1),
          week_end,
          DateTime.add(week_end, 1)
        ],
        fn timestamp ->
          unconfirmed_user_fixture()
          |> change(inserted_at: timestamp)
          |> Repo.update!()
        end
      )

    for {user, types} <- [
          {active, ["user_message", "agent_completed", "agent_response"]},
          {message_only, ["user_message"]},
          {completed_only, ["agent_completed"]}
        ],
        _duplicate <- 1..2 do
      task = task_fixture(Scope.for_user(user))

      for type <- types do
        Repo.insert_all("interactions", [
          %{
            id: Ecto.UUID.bingenerate(),
            task_id: Ecto.UUID.dump!(task.id),
            type: type,
            data: %{},
            sequence: System.unique_integer([:positive]),
            inserted_at: DateTime.to_naive(last_week)
          }
        ])
      end
    end

    result = Repo.query!(@sql)

    assert result.columns == [
             "signup_week_utc",
             "surviving_signups",
             "retained_user_message_users",
             "retained_agent_completed_users"
           ]

    first = [DateTime.to_date(week_start), 1, 0, 0]
    assert result.rows == [first, [DateTime.to_date(last_week), 3, 2, 2]]

    Repo.query!("DELETE FROM interactions WHERE type = 'user_message'")
    assert Repo.query!(@sql).rows == [first, [DateTime.to_date(last_week), 3, 0, 2]]
    Repo.query!("DELETE FROM tasks")
    assert Repo.query!(@sql).rows == [first, [DateTime.to_date(last_week), 3, 0, 0]]
    Repo.delete!(zero)
    assert Repo.query!(@sql).rows == [[DateTime.to_date(last_week), 3, 0, 0]]
  end
end
