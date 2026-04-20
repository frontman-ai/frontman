# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Workers.NotifyDiscordNewUser do
  @moduledoc """
  Oban worker that posts a new-user signup alert to a Discord webhook.

  Enqueued inside the Ecto.Multi that creates the user, so the job only
  exists if the user was persisted. Replaces the old PG NOTIFY → GenServer
  pipeline.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [keys: [:user_id], period: :infinity]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.User

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id} = args}) do
    if enabled?() do
      case Accounts.get_user(user_id) do
        %User{} = user ->
          post_to_discord(user, args["framework"])

        nil ->
          :discard
      end
    else
      Logger.info("[Discord] Worker disabled, skipping notification")
      :ok
    end
  end

  defp enabled? do
    Application.get_env(:frontman_server, __MODULE__)[:enabled] == true
  end

  defp post_to_discord(user, framework) do
    webhook_url = Application.fetch_env!(:frontman_server, :discord_new_users_webhook_url)

    body = %{
      embeds: [
        %{
          title: "New User Signed Up",
          color: 0x57F287,
          fields: [
            %{name: "Name", value: user.name || "—", inline: true},
            %{name: "Email", value: user.email || "—", inline: true},
            %{name: "Framework", value: framework_display_name(framework), inline: true}
          ],
          timestamp: DateTime.to_iso8601(user.inserted_at)
        }
      ]
    }

    case Req.post(webhook_url, [json: body] ++ req_options()) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        Logger.info("[Discord] Posted new-user alert for #{user.email}")
        :ok

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        Logger.warning("[Discord] Webhook returned #{status}: #{inspect(resp_body)}")
        {:error, "Discord webhook returned #{status}"}

      {:error, reason} ->
        Logger.error("[Discord] Webhook request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp req_options do
    Application.get_env(:frontman_server, :notify_discord_req_options, [])
  end

  defp framework_display_name("nextjs"), do: "Next.js"
  defp framework_display_name("vite"), do: "Vite"
  defp framework_display_name("astro"), do: "Astro"
  defp framework_display_name("wordpress"), do: "WordPress"
  defp framework_display_name(nil), do: "—"
  defp framework_display_name(""), do: "—"
  defp framework_display_name(framework) when is_binary(framework), do: framework
  defp framework_display_name(_), do: "—"
end
