defmodule FrontmanServer.Workers.EnterActivationCampaign do
  @moduledoc """
  One-shot signup entry. Never retry this job manually after an uncertain result.
  Requires a UTC cutoff, lag bound, registered state property, and contact sync; defaults off.
  Initialization and entry never retry. Timeouts may outlive locks; uncertain init prevents entry.
  Prompt acceptance atomically enqueues exit but cannot retract mail past provider conditions.
  Sentry requires operator review, not replay. No enrollment or delivery ledger is kept.
  """
  use Oban.Worker, queue: :mailers, max_attempts: 1

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.ResendContacts
  alias FrontmanServer.Workers.SyncResendContact

  @impl Oban.Worker
  def perform(%Oban.Job{attempt: attempt} = job) when attempt > 1 do
    report(job, :replay_refused)
    {:discard, :entry_replay_refused}
  end

  def perform(%Oban.Job{args: %{"user_id" => user_id}} = job) do
    contact_sync = Application.get_env(:frontman_server, SyncResendContact, [])[:enabled]
    policy = Keyword.put(config(), :contact_sync_enabled, contact_sync)

    case Accounts.get_user(user_id) do
      %Accounts.User{} = user ->
        case ResendContacts.enter_activation_campaign(Scope.for_user(user), policy) do
          {:error, reason} ->
            report(job, reason)
            {:discard, :entry_failed_or_uncertain}

          result ->
            result
        end

      nil ->
        :ok
    end
  rescue
    _exception ->
      report(job, :exception)
      {:discard, :entry_uncertain}
  end

  defp report(job, reason) do
    {category, status} = failure(reason)
    Sentry.Context.clear_all()

    Sentry.capture_message("Activation entry failed or uncertain",
      level: :error,
      tags: %{error_type: "activation_entry"},
      extra: %{
        failure_category: category,
        status: status,
        user_id: job.args["user_id"],
        job_id: job.id
      }
    )
  end

  defp failure({:http_status, status}) when is_integer(status), do: {"http_error", status}
  defp failure(%Req.TransportError{}), do: {"transport_uncertain", nil}

  defp failure(reason)
       when reason in [:transport_uncertain, :exception, :replay_refused, :coordination_failed],
       do: {Atom.to_string(reason), nil}

  defp failure(_reason), do: {"contact_sync_failed", nil}

  defp config, do: Application.get_env(:frontman_server, __MODULE__, [])
end
