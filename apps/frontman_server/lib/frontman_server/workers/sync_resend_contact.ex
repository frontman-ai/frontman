defmodule FrontmanServer.Workers.SyncResendContact do
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
        nil ->
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

  defp req_options do
    Application.get_env(:frontman_server, :sync_resend_contact_req_options, [])
  end

  defp first_name(nil), do: nil

  defp first_name(name) do
    name
    |> String.split(" ", parts: 2)
    |> List.first()
  end
end
