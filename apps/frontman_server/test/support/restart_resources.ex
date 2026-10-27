defmodule FrontmanServer.RestartResources do
  @moduledoc false

  import Ecto.Query

  alias FrontmanServer.Accounts
  alias FrontmanServer.Repo

  def delete_jobs(scope, task_id) do
    user_id = Accounts.scope_user_id(scope)

    from(job in Oban.Job,
      where: job.args["user_id"] == ^user_id or job.args["task_id"] == ^task_id
    )
    |> Repo.delete_all()
  end
end
