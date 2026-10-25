defmodule FrontmanServer.Accounts.ActivationAudienceTest do
  use FrontmanServer.DataCase
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Workers.EnterActivationCampaign
  alias FrontmanServer.Workers.SyncResendContact
  import FrontmanServer.Test.Fixtures.Accounts

  test "report partitions at the cutoff and as-of boundaries without provider calls" do
    cutoff = ~U[2026-10-10 00:00:00Z]
    as_of = ~U[2026-10-12 00:00:00Z]

    for attrs <- [
          [inserted_at: DateTime.add(cutoff, -1), first_message_at: cutoff],
          [inserted_at: cutoff, confirmed_at: nil],
          [inserted_at: cutoff, confirmed_at: cutoff, first_message_at: as_of],
          [inserted_at: as_of, confirmed_at: as_of],
          [inserted_at: DateTime.add(as_of, 1), confirmed_at: as_of]
        ] do
      unconfirmed_user_fixture()
      |> Ecto.Changeset.change(attrs)
      |> Repo.update!()
    end

    assert Accounts.activation_audience_report(cutoff, as_of) == %{
             historical_unknown: 1,
             unconfirmed: 1,
             activated: 1,
             eligible: 1,
             total: 4,
             eligible_signup_age_days: %{
               under_1: 1,
               from_1_to_3: 0,
               from_3_to_7: 0,
               at_least_7: 0
             }
           }
  end

  test "eligible age bins include each exact lower boundary" do
    as_of = ~U[2026-10-20 00:00:00Z]
    cutoff = DateTime.add(as_of, -8 * 86_400)

    for age_days <- [0, 1, 3, 7] do
      user_fixture()
      |> Ecto.Changeset.change(
        inserted_at: DateTime.add(as_of, -age_days * 86_400),
        confirmed_at: cutoff
      )
      |> Repo.update!()
    end

    assert Accounts.activation_audience_report(cutoff, as_of).eligible_signup_age_days ==
             %{under_1: 1, from_1_to_3: 1, from_3_to_7: 1, at_least_7: 1}
  end

  test "default-off first prompt records activation without creating a sync backlog" do
    user = user_fixture()
    assert :ok = Accounts.record_first_message(Scope.for_user(user))
    assert Repo.reload!(user).first_message_at
    refute_enqueued(worker: SyncResendContact, args: %{user_id: user.id})
  end

  test "paused first transition enqueues once and outer rollback removes milestone and job" do
    original = Application.get_env(:frontman_server, EnterActivationCampaign, [])

    Application.put_env(
      :frontman_server,
      EnterActivationCampaign,
      Keyword.merge(original, enabled: false, cutoff: ~U[2026-01-01 00:00:00Z])
    )

    on_exit(fn -> Application.put_env(:frontman_server, EnterActivationCampaign, original) end)

    user = user_fixture()
    scope = Scope.for_user(user)

    assert {:error, :prompt_failed} =
             Repo.transact(fn ->
               :ok = Accounts.record_first_message(scope)
               {:error, :prompt_failed}
             end)

    assert Repo.reload!(user).first_message_at == nil
    refute_enqueued(worker: SyncResendContact)

    assert :ok = Accounts.record_first_message(scope)
    assert :ok = Accounts.record_first_message(scope)

    assert [%{args: %{"activation" => true, "user_id" => id}}] =
             all_enqueued(worker: SyncResendContact)

    assert id == user.id
    assert Repo.reload!(user).first_message_at
  end
end
