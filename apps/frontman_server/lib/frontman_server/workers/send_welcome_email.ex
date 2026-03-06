defmodule FrontmanServer.Workers.SendWelcomeEmail do
  @moduledoc """
  Oban worker that sends a welcome email to a newly registered user.

  Enqueued atomically inside the Ecto transaction that creates the user
  (via `Ecto.Multi`), so the job only exists if the user was persisted.

  Idempotency: uses Oban's unique constraint on `user_id` to guarantee
  at-most-once delivery even if the job is retried.
  """

  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5,
    unique: [keys: [:user_id], period: :infinity]

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Accounts.UserNotifier
  alias FrontmanServer.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    case Repo.get(User, user_id) do
      %User{} = user ->
        {:ok, _email} = UserNotifier.deliver_welcome(user)
        :ok

      nil ->
        # User was deleted between enqueue and execution — nothing to do.
        :discard
    end
  end
end
