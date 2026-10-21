defmodule FrontmanServer.AccountsFirstMessageBackfillTest do
  use FrontmanServer.DataCase

  alias Ecto.Migration.Runner
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo.Migrations.BackfillExistingUsersFirstMessageAt

  import FrontmanServer.Test.Fixtures.Accounts

  test "excludes existing users, preserves recorded prompts and leaves later signups unmarked" do
    confirmed = user_fixture()
    unconfirmed = unconfirmed_user_fixture()
    recorded_at = ~U[2026-06-01 12:00:00Z]

    recorded =
      user_fixture()
      |> Ecto.Changeset.change(first_message_at: recorded_at)
      |> Repo.update!()

    Code.require_file(
      "priv/repo/migrations/20261008000000_backfill_existing_users_first_message_at.exs"
    )

    before_backfill = DateTime.utc_now(:second)
    run_migration(:up)
    after_backfill = DateTime.utc_now(:second)

    for user <- [confirmed, unconfirmed] do
      timestamp = Repo.reload!(user).first_message_at
      assert DateTime.compare(timestamp, before_backfill) in [:eq, :gt]
      assert DateTime.compare(timestamp, after_backfill) in [:eq, :lt]
      refute Accounts.activation_candidate?(Scope.for_user(user), after_backfill)
    end

    assert Repo.reload!(recorded).first_message_at == recorded_at
    backfilled_at = Repo.reload!(confirmed).first_message_at
    run_migration(:up)
    assert Repo.reload!(confirmed).first_message_at == backfilled_at
    run_migration(:down)
    assert Repo.reload!(confirmed).first_message_at == backfilled_at
    assert Repo.reload!(recorded).first_message_at == recorded_at

    new_user = user_fixture()
    assert is_nil(Repo.reload!(new_user).first_message_at)
    assert Accounts.activation_candidate?(Scope.for_user(new_user), DateTime.utc_now(:second))
  end

  defp run_migration(direction) do
    assert :ok =
             Runner.run(
               Repo,
               Repo.config(),
               0,
               BackfillExistingUsersFirstMessageAt,
               :forward,
               direction,
               direction,
               log: false
             )
  end
end
