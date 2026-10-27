defmodule FrontmanServer.RestartResourcesTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts
  alias FrontmanServer.RestartResources
  alias FrontmanServer.Workers.{GenerateTitle, SyncResendContact}

  test "cleanup deletes every owned job regardless of worker and preserves unrelated jobs" do
    scope = user_scope_fixture()
    task_id = Ecto.UUID.generate()

    jobs =
      for {worker, args} <- [
            {SyncResendContact, %{"user_id" => Accounts.scope_user_id(scope)}},
            {GenerateTitle, %{"task_id" => task_id}},
            {SyncResendContact, %{"user_id" => Ecto.UUID.generate()}}
          ] do
        args |> worker.new() |> Oban.insert!()
      end

    [user_job, task_job, sentinel] = jobs
    assert {2, nil} = RestartResources.delete_jobs(scope, task_id)
    refute Repo.get(Oban.Job, user_job.id)
    refute Repo.get(Oban.Job, task_job.id)
    assert Repo.get!(Oban.Job, sentinel.id).args == sentinel.args
  end

  test "Stripe requests use the running PaperTiger instance" do
    config = Application.fetch_env!(:frontman_server, :stripe)
    assert config[:api_base_url] == PaperTiger.Test.base_url("/v1")
    assert PaperTiger.get_port() > 0

    assert {:ok, %{status: 200}} =
             Req.get(config[:api_base_url] <> "/customers",
               auth: {:bearer, config[:secret_key]},
               retry: false,
               receive_timeout: 5_000
             )
  end
end
