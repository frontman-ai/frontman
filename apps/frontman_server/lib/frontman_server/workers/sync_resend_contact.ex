defmodule FrontmanServer.Workers.SyncResendContact do
  @moduledoc """
  Oban worker that adds a newly registered user to the Resend Contacts list.

  Enqueued atomically inside the Ecto transaction that creates the user
  (via `Ecto.Multi`), so the job only exists if the user was persisted.

  Idempotency: uses Oban's unique constraint on `user_id` to guarantee
  at-most-once sync even if the job is retried. The Resend Contacts API
  is itself idempotent on email — re-adding an existing contact just
  updates their info.
  """

  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5,
    unique: [keys: [:user_id], period: :infinity]

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    if enabled?() do
      case Repo.get(User, user_id) do
        nil ->
          # User was deleted between enqueue and execution — nothing to do.
          :discard

        %User{} = user ->
          post_contact(user)
      end
    else
      Logger.info("[ResendContact] Worker disabled, skipping sync")
      :ok
    end
  end

  defp enabled? do
    Application.get_env(:frontman_server, __MODULE__)[:enabled] == true
  end

  defp post_contact(%User{email: email, name: name}) do
    mailer_config = Application.fetch_env!(:frontman_server, FrontmanServer.Mailer)

    case Req.post(
           mailer_config[:contacts_url],
           [
             json: %{
               email: email,
               first_name: first_name(name),
               unsubscribed: false,
               segments: [%{id: mailer_config[:segment_id]}]
             },
             headers: [{"authorization", "Bearer #{mailer_config[:api_key]}"}]
           ] ++ req_options()
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Resend API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Extra Req options — overridden in tests to inject Req.Test as the adapter.
  defp req_options do
    Application.get_env(:frontman_server, :sync_resend_contact_req_options, [])
  end

  # Extract the first word of the full name as first_name, falling back to the
  # full string if there's no space (or nil if name is nil).
  defp first_name(nil), do: nil

  defp first_name(name) do
    name
    |> String.split(" ", parts: 2)
    |> List.first()
  end
end
