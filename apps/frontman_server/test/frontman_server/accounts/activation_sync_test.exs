defmodule FrontmanServer.Accounts.ActivationSyncTest do
  use FrontmanServer.DataCase
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Workers.EnterActivationCampaign
  alias FrontmanServer.Workers.SyncResendContact
  import FrontmanServer.Test.Fixtures.Accounts

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
