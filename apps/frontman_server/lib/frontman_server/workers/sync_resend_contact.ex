# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Workers.SyncResendContact do
  @moduledoc """
  Oban worker that adds a newly registered user to the Resend Contacts list.

  Enqueued atomically inside the Ecto transaction that creates the user
  (via `Ecto.Multi`), so the job only exists if the user was persisted.

  Oban uniqueness limits duplicate jobs, not repeated provider requests.
  Contact creation omits subscription preferences; this alone does not prove
  that Resend preserves preferences on duplicate creation.

  Activation-only jobs are separately keyed from signup jobs. Activation
  synchronization continues whenever the campaign has a valid UTC cutoff, even
  while enrollment is paused. Before configuring it,
  register the string `frontman_activation_state` property and approve provider
  writes. This worker never writes inactive or emits entry events.
  All contact writers share a database advisory lock and read after acquisition.
  A provider write can outlive a timeout; this is not cross-system atomicity.
  Existing backfilled milestones are safe exclusions, not conversion evidence.
  """

  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5,
    unique: [keys: [:user_id, :activation], period: :infinity]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Workers.EnterActivationCampaign

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "activation" => true}} = job) do
    result =
      case {enabled?(), EnterActivationCampaign.configured?()} do
        {true, true} ->
          Accounts.with_contact_sync(user_id, fn
            nil -> :discard
            %User{first_message_at: nil} -> :discard
            %User{} = user -> post_contact(user)
          end)

        _ ->
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

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    if enabled?() do
      Accounts.with_contact_sync(user_id, fn
        nil ->
          :discard

        %User{} = user ->
          post_contact(user)
      end)
    else
      Logger.info("[ResendContact] Worker disabled, skipping sync")
      :ok
    end
  end

  defp enabled? do
    config()[:enabled] == true
  end

  @doc false
  def initialize_activation(%User{} = user) do
    update_properties(user, %{frontman_activation_state: "inactive"})
  end

  defp post_contact(%User{} = user) do
    case activation_properties(user) do
      %{properties: properties} -> update_properties(user, properties)
      %{} -> create_contact(user, Application.fetch_env!(:frontman_server, FrontmanServer.Mailer))
    end
  end

  defp update_properties(%User{email: email} = user, properties) do
    mailer_config = Application.fetch_env!(:frontman_server, FrontmanServer.Mailer)

    case Req.patch(
           mailer_config[:contacts_url] <> "/" <> URI.encode_www_form(email),
           [
             json: %{properties: properties},
             headers: [{"authorization", "Bearer #{mailer_config[:api_key]}"}]
           ] ++ req_options()
         ) do
      {:ok, %Req.Response{status: 404}} ->
        create_contact(user, mailer_config, %{properties: properties})

      response ->
        contact_result(response)
    end
  end

  defp create_contact(user, mailer_config),
    do: create_contact(user, mailer_config, activation_properties(user))

  defp create_contact(%User{email: email, name: name}, mailer_config, properties) do
    Req.post(
      mailer_config[:contacts_url],
      [
        json:
          Map.merge(
            %{
              email: email,
              first_name: first_name(name),
              segments: [%{id: mailer_config[:segment_id]}]
            },
            properties
          ),
        headers: [{"authorization", "Bearer #{mailer_config[:api_key]}"}]
      ] ++ req_options()
    )
    |> contact_result()
  end

  defp contact_result(response) do
    case response do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp activation_properties(%User{first_message_at: nil}), do: %{}

  defp activation_properties(%User{}) do
    case EnterActivationCampaign.configured?() do
      true -> %{properties: %{frontman_activation_state: "activated"}}
      _ -> %{}
    end
  end

  defp report_final_failure(%Oban.Job{attempt: attempt, max_attempts: max} = job, reason)
       when attempt >= max do
    {category, status} =
      case reason do
        {:http_status, status} when is_integer(status) -> {"http_error", status}
        %Req.TransportError{} -> {"transport_uncertain", nil}
        :exception -> {"exception", nil}
        _ -> {"contact_sync_failed", nil}
      end

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

  defp req_options do
    Keyword.merge(config()[:req_options] || [],
      retry: false,
      redirect: false,
      receive_timeout: 15_000,
      connect_options: [timeout: 5_000]
    )
  end

  defp config do
    Application.get_env(:frontman_server, __MODULE__, [])
  end

  defp first_name(nil), do: nil

  defp first_name(name) do
    name
    |> String.split(" ", parts: 2)
    |> List.first()
  end
end
