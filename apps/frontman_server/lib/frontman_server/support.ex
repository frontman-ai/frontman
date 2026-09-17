# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Support do
  @moduledoc "One-way website questions delivered to the support team."

  alias FrontmanServer.Workers.SendSupportQuestionToDiscord

  def submit_question(params) do
    with {:ok, question} <- validate_question(params),
         {:ok, _options} <- delivery_options() do
      submission_id = Ecto.UUID.generate()

      %{question: question, submission_id: submission_id}
      |> SendSupportQuestionToDiscord.new()
      |> Oban.insert(log: false)
      |> case do
        {:ok, _job} -> {:ok, submission_id}
        {:error, _changeset} -> {:error, :enqueue_failed}
      end
    end
  rescue
    _error in [DBConnection.ConnectionError, Postgrex.Error] -> {:error, :enqueue_failed}
  end

  def validate_question(%{"question" => question} = params)
      when map_size(params) == 1 and is_binary(question) do
    cond do
      String.trim(question) == "" -> {:error, :invalid_question}
      utf16_length(question) > 4000 -> {:error, :invalid_question}
      true -> {:ok, question}
    end
  end

  def validate_question(_params), do: {:error, :invalid_question}

  def delivery_options do
    config = Application.fetch_env!(:frontman_server, __MODULE__)

    with true <- config[:enabled],
         url when is_binary(url) and byte_size(url) > 0 <- config[:webhook_url] do
      options = Keyword.get(config, :req_options, [])

      {:ok,
       Keyword.merge(options,
         url: url,
         retry: false,
         redirect: false,
         receive_timeout: 5_000,
         connect_options: [timeout: 5_000]
       )}
    else
      _unavailable -> {:error, :unavailable}
    end
  end

  defp utf16_length(value) do
    value |> :unicode.characters_to_binary(:utf8, :utf16) |> byte_size() |> div(2)
  end
end
