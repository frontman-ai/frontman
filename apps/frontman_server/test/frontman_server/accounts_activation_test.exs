defmodule FrontmanServer.AccountsActivationTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServer.Workers.SyncResendContact

  test "activation persists once with exactly one exit job" do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)

    assert {:ok, :ok} = Accounts.record_activation(scope)
    assert %DateTime{} = first_use = Repo.reload!(user).first_message_at

    assert [%{args: args}] =
             all_enqueued(worker: SyncResendContact, args: %{user_id: user.id})

    assert args == %{"activation" => true, "user_id" => user.id}

    assert {:ok, :ok} = Accounts.record_activation(scope)
    assert Repo.reload!(user).first_message_at == first_use
    assert [_] = all_enqueued(worker: SyncResendContact, args: %{user_id: user.id})
  end

  test "outer transaction rollback removes both activation and exit job" do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)

    assert {:error, :rejected} =
             Repo.transact(fn ->
               assert {:ok, :ok} = Accounts.record_activation(scope)
               {:error, :rejected}
             end)

    assert is_nil(Repo.reload!(user).first_message_at)
    assert all_enqueued(worker: SyncResendContact, args: %{user_id: user.id}) == []
  end
end
