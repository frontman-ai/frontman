defmodule FrontmanServer.ResendContacts do
  @moduledoc """
  Signup contact sync and campaign entry/exit. Workers own retries and failure reporting.
  """

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.{Scope, User}
  alias FrontmanServer.Repo

  def enter_activation_campaign(
        %Scope{} = scope,
        policy,
        clock \\ &DateTime.utc_now/0
      ) do
    with true <- policy[:enabled] == true,
         true <- policy[:contact_sync_enabled] == true,
         %DateTime{time_zone: "Etc/UTC"} = cutoff <- policy[:cutoff],
         lag when is_integer(lag) and lag > 0 <- policy[:max_entry_lag_seconds] do
      with_contact_sync(Scope.user_id(scope), &enter(&1, cutoff, lag, clock))
    else
      _ -> :ok
    end
  end

  def sync_contact(%Scope{} = scope, mode, policy)
      when mode in [:signup, :activation] do
    projection = match?(%DateTime{time_zone: "Etc/UTC"}, policy[:cutoff])

    case {policy[:enabled], mode, projection} do
      {true, :activation, false} -> :ok
      {true, _, _} -> with_contact_sync(Scope.user_id(scope), &sync(&1, mode, projection))
      _ -> :ok
    end
  end

  defp enter(user, cutoff, lag, clock) do
    with true <- eligible?(user, cutoff, lag, clock.()),
         :ok <- update_properties(user, %{frontman_activation_state: "inactive"}),
         true <- eligible?(Accounts.get_user(user.id), cutoff, lag, clock.()) do
      send_activation_entry(user)
    else
      false -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp sync(nil, _mode, _projection), do: :discard
  defp sync(%User{first_message_at: nil}, :activation, _projection), do: :discard

  defp sync(%User{first_message_at: %DateTime{}} = user, :activation, true),
    do: update_properties(user, %{frontman_activation_state: "activated"})

  defp sync(%User{first_message_at: %DateTime{}} = user, :signup, true),
    do: create_contact(user, %{properties: %{frontman_activation_state: "activated"}})

  defp sync(%User{} = user, :signup, _projection), do: create_contact(user)

  defp with_contact_sync(user_id, callback) when is_binary(user_id) do
    Repo.transact(
      fn ->
        Repo.query!("SET LOCAL lock_timeout = '5s'")
        Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [user_id])
        {:ok, callback.(Accounts.get_user(user_id))}
      end,
      timeout: 60_000
    )
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  defp eligible?(%User{confirmed_at: %DateTime{}, first_message_at: nil} = user, cutoff, lag, now) do
    with false <- DateTime.before?(user.inserted_at, cutoff),
         age when age >= 0 <- DateTime.diff(now, user.inserted_at) do
      age <= lag
    else
      _ -> false
    end
  end

  defp eligible?(_user, _cutoff, _lag, _now), do: false

  defp create_contact(%User{} = user, properties \\ %{}) do
    mailer = mailer()

    request(
      :post,
      mailer[:contacts_url],
      %{
        email: user.email,
        first_name: first_name(user.name),
        segments: [%{id: mailer[:segment_id]}]
      }
      |> Map.merge(properties)
    )
    |> contact_result()
  end

  defp update_properties(%User{} = user, properties) do
    case request(:patch, mailer()[:contacts_url] <> "/" <> URI.encode_www_form(user.email), %{
           properties: properties
         }) do
      {:ok, %Req.Response{status: 404}} ->
        create_contact(user, %{properties: properties})

      response ->
        contact_result(response)
    end
  end

  defp send_activation_entry(%User{} = user) do
    case request(:post, "https://api.resend.com/events/send", %{
           event: "frontman.activation.entered",
           email: user.email
         }) do
      {:ok, %Req.Response{status: 202}} -> :ok
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, _reason} -> {:error, :transport_uncertain}
    end
  end

  defp request(method, url, payload) do
    options = Application.get_env(:frontman_server, __MODULE__, [])[:req_options] || []

    Req.request(
      Keyword.merge(options,
        method: method,
        url: url,
        json: payload,
        headers: [{"authorization", "Bearer #{mailer()[:api_key]}"}],
        retry: false,
        redirect: false,
        receive_timeout: 15_000,
        connect_options: [timeout: 5_000]
      )
    )
  end

  defp contact_result({:ok, %Req.Response{status: status}}) when status in 200..299,
    do: :ok

  defp contact_result({:ok, %Req.Response{status: status}}), do: {:error, {:http_status, status}}
  defp contact_result({:error, reason}), do: {:error, reason}

  defp mailer, do: Application.fetch_env!(:frontman_server, FrontmanServer.Mailer)
  defp first_name(nil), do: nil
  defp first_name(name), do: name |> String.split(" ", parts: 2) |> List.first()
end
