# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Workers.SyncResendContact do
  @moduledoc """
  Synchronizes signup contacts and activation exits under the integration contact lock.
  Jobs commit with signup or first-message transitions; uniqueness cannot prevent repeated writes.
  Writes omit preferences, but duplicate-create preservation remains provider-unverified.
  Projection requires a UTC cutoff and registered state property, including while entry is paused.
  Never writes inactive or emits entry. Provider writes may outlive timeouts.
  Backfilled milestones exclude users; they are not conversion evidence.
  """

  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5,
    unique: [keys: [:user_id, :activation], period: :infinity]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.ResendContacts
  alias FrontmanServer.Workers.EnterActivationCampaign

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}} = job) do
    result =
      case Accounts.get_user(user_id) do
        %Accounts.User{} = user ->
          mode = if job.args["activation"] == true, do: :activation, else: :signup

          policy = [
            enabled: Application.get_env(:frontman_server, __MODULE__, [])[:enabled],
            cutoff: Application.get_env(:frontman_server, EnterActivationCampaign, [])[:cutoff]
          ]

          ResendContacts.sync_contact(Scope.for_user(user), mode, policy)

        nil ->
          :discard
      end

    case result do
      {:error, reason} -> report_final_failure(job, reason)
      _ -> :ok
    end

    result
  rescue
    exception ->
      report_final_failure(job, :exception)
      reraise exception, __STACKTRACE__
  end

  defp report_final_failure(
         %Oban.Job{args: %{"activation" => true}, attempt: attempt, max_attempts: max} = job,
         reason
       )
       when attempt >= max do
    {category, status} = failure(reason)
    Sentry.Context.clear_all()

    Sentry.capture_message("Activation exit failed",
      level: :error,
      tags: %{error_type: "activation_exit"},
      extra: %{
        failure_category: category,
        status: status,
        user_id: job.args["user_id"],
        job_id: job.id
      }
    )
  end

  defp report_final_failure(_job, _reason), do: :ok

  defp failure({:http_status, status}) when is_integer(status), do: {"http_error", status}
  defp failure(%Req.TransportError{}), do: {"transport_uncertain", nil}

  defp failure(:exception), do: {"exception", nil}

  defp failure(_reason), do: {"contact_sync_failed", nil}
end
