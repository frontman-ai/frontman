# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

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

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.User

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    if enabled?() do
      case Accounts.get_user(user_id) do
        %User{} = user ->
          {:ok, _email} = Accounts.deliver_welcome_email(user)
          :ok

        nil ->
          # User was deleted between enqueue and execution — nothing to do.
          :discard
      end
    else
      Logger.info("[WelcomeEmail] Worker disabled, skipping email")
      :ok
    end
  end

  defp enabled? do
    Application.get_env(:frontman_server, __MODULE__)[:enabled] == true
  end
end
