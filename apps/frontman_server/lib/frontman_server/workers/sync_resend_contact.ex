# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Workers.SyncResendContact do
  @moduledoc """
  Synchronizes signup contacts and activation exits under the Accounts contact lock.
  Signup jobs are enqueued atomically with user creation; activation jobs with
  the first-message transition. Oban uniqueness does not prevent repeated writes.

  Contact writes omit subscription preferences. Duplicate creation alone does not
  prove that Resend preserves preferences. Activation projection requires an approved
  UTC cutoff and registered `frontman_activation_state` property, and continues while
  enrollment is paused. This worker never writes inactive or emits entry events.
  A provider write can outlive a timeout; this is not cross-system atomicity.
  Backfilled milestones are safe exclusions, not conversion evidence.
  """

  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5,
    unique: [keys: [:user_id, :activation], period: :infinity]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.User
  alias FrontmanServer.ResendClient
  alias FrontmanServer.Workers.EnterActivationCampaign

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}} = job) do
    result =
      if enabled?(job) do
        Accounts.with_contact_sync(user_id, &sync(&1, job))
      else
        :ok
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

  defp enabled?(job) do
    with true <- Application.get_env(:frontman_server, __MODULE__, [])[:enabled] == true do
      case job.args do
        %{"activation" => true} -> EnterActivationCampaign.configured?()
        _ -> true
      end
    end
  end

  defp sync(nil, _job), do: :discard
  defp sync(%User{first_message_at: nil}, %{args: %{"activation" => true}}), do: :discard

  defp sync(%User{} = user, _job) do
    case {user.first_message_at, EnterActivationCampaign.configured?()} do
      {%DateTime{}, true} ->
        ResendClient.update_properties(user, %{frontman_activation_state: "activated"})

      _ ->
        ResendClient.create_contact(user)
    end
  end

  defp report_final_failure(
         %Oban.Job{args: %{"activation" => true}, attempt: attempt, max_attempts: max} = job,
         reason
       )
       when attempt >= max,
       do: ResendClient.report_failure(job, reason, :exit)

  defp report_final_failure(_job, _reason), do: :ok
end
