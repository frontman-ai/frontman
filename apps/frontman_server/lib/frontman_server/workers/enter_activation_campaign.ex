defmodule FrontmanServer.Workers.EnterActivationCampaign do
  @moduledoc """
  One-shot signup entry. Never retry this job manually after an uncertain result.
  Requires an approved UTC deployment cutoff, entry lag bound, registered contact
  state property, and contact sync enabled. Enrollment defaults off.

  Contact initialization and entry have no automatic retries. A timeout can
  outlive the local contact lock. No event follows uncertain initialization.
  Activated-only reconciliation repairs observed activation; it cannot retract
  an email already past its provider condition. Sentry reports require operator
  review, not automatic replay. No local enrollment or delivery ledger is kept.
  """
  use Oban.Worker, queue: :mailers, max_attempts: 1

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Workers.SyncResendContact

  def configured? do
    match?(%DateTime{time_zone: "Etc/UTC"}, config()[:cutoff])
  end

  def enqueue_signup(%User{} = user) do
    if eligible?(user) do
      %{user_id: user.id} |> new() |> Oban.insert()
    else
      {:ok, :excluded}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{attempt: attempt} = job) when attempt > 1 do
    report(job, :replay_refused)
    {:discard, :entry_replay_refused}
  end

  def perform(%Oban.Job{args: %{"user_id" => user_id}} = job) do
    Accounts.with_contact_sync(user_id, fn user ->
      if eligible?(user), do: enter(user, job), else: :ok
    end)
    |> case do
      {:error, _reason} ->
        report(job, :coordination_failed)
        {:discard, :entry_failed_or_uncertain}

      result ->
        result
    end
  rescue
    _exception ->
      report(job, :exception)
      reconcile(user_id)
      {:discard, :entry_uncertain}
  end

  defp enter(user, job) do
    with :ok <- SyncResendContact.initialize_activation(user),
         true <- eligible?(Accounts.get_user(user.id)),
         :ok <- send_event(user) do
      :ok
    else
      false ->
        reconcile(user.id)
        :ok

      {:error, reason} ->
        report(job, reason)
        reconcile(user.id)
        {:discard, :entry_failed_or_uncertain}
    end
  end

  defp eligible?(%User{confirmed_at: %DateTime{}, first_message_at: nil} = user) do
    with true <- config()[:enabled] == true,
         true <- Application.get_env(:frontman_server, SyncResendContact, [])[:enabled] == true,
         %DateTime{time_zone: "Etc/UTC"} = cutoff <- config()[:cutoff],
         lag when is_integer(lag) and lag > 0 <- config()[:max_entry_lag_seconds],
         false <- DateTime.before?(user.inserted_at, cutoff),
         age when age >= 0 <- DateTime.diff(DateTime.utc_now(), user.inserted_at) do
      age <= lag
    else
      _ -> false
    end
  end

  defp eligible?(_user), do: false

  defp send_event(user) do
    mailer = Application.fetch_env!(:frontman_server, FrontmanServer.Mailer)

    options =
      Keyword.merge(config()[:req_options] || [],
        json: %{event: "frontman.activation.entered", email: user.email},
        headers: [{"authorization", "Bearer #{mailer[:api_key]}"}],
        retry: false,
        redirect: false,
        receive_timeout: 15_000,
        connect_options: [timeout: 5_000]
      )

    case Req.post("https://api.resend.com/events/send", options) do
      {:ok, %Req.Response{status: 202}} -> :ok
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, _reason} -> {:error, :transport_uncertain}
    end
  end

  defp reconcile(user_id) do
    case Accounts.get_user(user_id) do
      %User{first_message_at: %DateTime{}} ->
        %{user_id: user_id, activation: true} |> SyncResendContact.new() |> Oban.insert!()

      _ ->
        :ok
    end
  end

  defp report(job, reason) do
    status =
      case reason do
        {:http_status, status} -> status
        _ -> nil
      end

    Sentry.Context.clear_all()

    Sentry.capture_message("Activation entry failed or uncertain",
      level: :error,
      tags: %{error_type: "activation_entry"},
      extra: %{
        user_id: job.args["user_id"],
        job_id: job.id,
        status: status,
        failure_category: failure_category(reason)
      }
    )
  end

  defp failure_category({:http_status, _}), do: "http_error"
  defp failure_category(%Req.TransportError{}), do: "transport_uncertain"

  defp failure_category(reason)
       when reason in [:transport_uncertain, :exception, :replay_refused, :coordination_failed],
       do: Atom.to_string(reason)

  defp failure_category(_reason), do: "contact_sync_failed"

  defp config, do: Application.get_env(:frontman_server, __MODULE__, [])
end
