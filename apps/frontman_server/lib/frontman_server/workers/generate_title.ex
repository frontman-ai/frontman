# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Workers.GenerateTitle do
  @moduledoc """
  Oban worker that generates a short task title from the first user prompt.

  Resolves the API key through the standard priority chain (OAuth > user key).
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [
      keys: [:task_id],
      period: :infinity,
      states: [:available, :scheduled, :executing, :retryable, :completed]
    ]

  require Logger

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks
  alias ReqLLM.Message.ContentPart

  @system_prompt """
  Generate a concise 3-6 word title for this chat based on the user's message.
  Return only the title text, nothing else. No quotes, no punctuation at the end.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "user_id" => user_id,
            "task_id" => task_id,
            "user_prompt_text" => user_prompt_text
          } = args
      }) do
    user = Accounts.get_user!(user_id)
    scope = Scope.for_user(user)
    model = Map.get(args, "model")

    with {:ok, {model_spec, llm_opts}} <- Providers.prepare_llm_args(scope, model, max_tokens: 30),
         {:ok, raw_title} <- call_llm(model_spec, llm_opts, user_prompt_text),
         title = String.trim(raw_title),
         false <- title == "",
         :ok <- Tasks.apply_title_suggestion(scope, task_id, title) do
      :ok
    else
      {:error, :missing_model} ->
        Logger.debug("GenerateTitle: Missing model, cancelling")
        {:cancel, :missing_model}

      {:error, :no_api_key} ->
        Logger.debug("GenerateTitle: No API key available, cancelling")
        {:cancel, :no_api_key}

      {:error, :not_found} ->
        Logger.debug("GenerateTitle: Task not found, cancelling")
        {:cancel, :not_found}

      {:error, reason} ->
        {:error, reason}

      true ->
        Logger.debug("GenerateTitle: LLM returned empty title, cancelling")
        {:cancel, :empty_title}
    end
  end

  defp call_llm(model_spec, llm_opts, user_prompt_text) do
    messages = [
      ReqLLM.Context.system([ContentPart.text(@system_prompt)]),
      ReqLLM.Context.user(user_prompt_text)
    ]

    with {:ok, response} <- ReqLLM.generate_text(model_spec, messages, llm_opts) do
      {:ok, ReqLLM.Response.text(response)}
    end
  end
end
