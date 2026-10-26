defmodule FrontmanServer.Workers.EnterActivationCampaign do
  @moduledoc """
  One-shot signup entry. Never retry this job manually after an uncertain result.
  Requires an approved UTC deployment cutoff, entry lag bound, registered contact
  state property, and contact sync enabled. Enrollment defaults off.

  Contact initialization and entry have no automatic retries. A timeout can
  outlive the local contact lock. No event follows uncertain initialization.
  Accounts atomically enqueues exit synchronization on activation; it cannot
  retract an email past its provider condition. Sentry reports require operator
  review, not automatic replay. No local enrollment or delivery ledger is kept.
  """
  use Oban.Worker, queue: :mailers, max_attempts: 1

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.User
  alias FrontmanServer.ResendClient
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
      {:discard, :entry_uncertain}
  end

  defp enter(user, job) do
    with :ok <- ResendClient.update_properties(user, %{frontman_activation_state: "inactive"}),
         true <- eligible?(Accounts.get_user(user.id)),
         :ok <- ResendClient.send_activation_entry(user) do
      :ok
    else
      false ->
        :ok

      {:error, reason} ->
        report(job, reason)
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

  defp report(job, reason), do: ResendClient.report_failure(job, reason, :entry)

  defp config, do: Application.get_env(:frontman_server, __MODULE__, [])
end
