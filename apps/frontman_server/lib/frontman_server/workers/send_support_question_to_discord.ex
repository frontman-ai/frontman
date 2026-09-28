# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Workers.SendSupportQuestionToDiscord do
  @moduledoc "Delivers a website question without exposing its content in errors."

  use Oban.Worker,
    queue: :support,
    max_attempts: 3,
    unique: [fields: [:worker, :args], keys: [:slot], states: :incomplete, period: :infinity]

  alias FrontmanServer.Support

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"question" => question, "submission_id" => submission_id}}) do
    with {:ok, question} <- Support.validate_question(%{"question" => question}),
         {:ok, options} <- Support.delivery_options() do
      body = %{
        allowed_mentions: %{parse: []},
        embeds: [
          %{
            title: "Website support question (untrusted external input)",
            description: question,
            footer: %{text: "Submission #{submission_id}"}
          }
        ]
      }

      options |> Keyword.put(:json, body) |> Req.post() |> delivery_result()
    else
      {:error, reason} -> {:cancel, reason}
    end
  end

  defp delivery_result({:ok, %Req.Response{status: status}}) when status in 200..299, do: :ok

  defp delivery_result({:ok, %Req.Response{status: 429, body: %{"retry_after" => seconds}}})
       when is_number(seconds) and seconds > 0 do
    {:error, {:discord_rate_limited, seconds |> ceil() |> min(3600)}}
  end

  defp delivery_result({:ok, %Req.Response{status: status}}),
    do: {:error, {:discord_status, status}}

  defp delivery_result({:error, _reason}), do: {:error, :discord_request_failed}

  @impl Oban.Worker
  def backoff(%Oban.Job{
        unsaved_error: %{
          reason: %Oban.PerformError{reason: {:error, {:discord_rate_limited, seconds}}}
        }
      }),
      do: seconds

  def backoff(job), do: Oban.Worker.backoff(job)
end
