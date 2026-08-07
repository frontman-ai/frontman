defmodule FrontmanServer.Workers.SendWelcomeEmail do
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
