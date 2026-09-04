# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Workers.SendAgentFeedbackToDiscord do
  @moduledoc """
  Oban worker that posts agent feedback to a Discord webhook.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case enabled?() do
      true -> post_to_discord(args)
      false -> Logger.info("[Discord] Agent feedback worker disabled, skipping notification")
    end
  end

  defp enabled? do
    config()[:enabled] == true
  end

  defp post_to_discord(args) when is_map(args) do
    with {:ok, webhook_url} <- webhook_url() do
      post_to_discord(webhook_url, args)
    end
  end

  defp post_to_discord(webhook_url, args) when is_binary(webhook_url) and is_map(args) do
    body = %{
      embeds: [
        %{
          title: "Agent Feedback",
          color: color(args["outcome"]),
          fields: fields(args),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]
    }

    case Req.post(webhook_url, [json: body] ++ req_options()) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        Logger.info("[Discord] Posted agent feedback for task #{args["task_id"]}")
        :ok

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        Logger.warning(
          "[Discord] Agent feedback webhook returned #{status}: #{inspect(resp_body)}"
        )

        {:error, "Discord webhook returned #{status}"}

      {:error, reason} ->
        Logger.error("[Discord] Agent feedback webhook request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp webhook_url do
    case config()[:webhook_url] do
      webhook_url when is_binary(webhook_url) -> {:ok, webhook_url}
      _missing -> {:error, "Discord agent feedback webhook URL is not configured"}
    end
  end

  defp req_options do
    config()[:req_options] || []
  end

  defp config do
    Application.get_env(:frontman_server, __MODULE__, [])
  end

  defp fields(args) do
    [
      %{name: "Outcome", value: value(args["outcome"]), inline: true},
      %{name: "Framework", value: value(args["framework"]), inline: true},
      %{name: "Task", value: value(args["task_title"]), inline: false},
      %{name: "Message", value: value(args["message"]), inline: false},
      %{name: "Task ID", value: value(args["task_id"]), inline: false}
    ]
  end

  defp value(nil), do: "—"
  defp value(""), do: "—"
  defp value(value) when is_binary(value), do: String.slice(value, 0, 1000)
  defp value(value), do: value |> inspect() |> String.slice(0, 1000)

  defp color("completed"), do: 0x57F287
  defp color("stuck"), do: 0xFEE75C
  defp color("failed"), do: 0xED4245
  defp color("feature_request"), do: 0x5865F2
  defp color(_outcome), do: 0x99AAB5
end
