# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Workers.GenerateTitle do
  @moduledoc """
  Oban worker that generates a short task title from the first user prompt.

  Resolves the API key through the standard priority chain (OAuth > user key >
  server key), bypassing quota checks since title generation is a cheap
  internal operation (~30 tokens).
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [
      keys: [:task_id],
      period: :infinity,
      states: [:available, :scheduled, :executing, :retryable]
    ]

  require Logger

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.ResolvedKey
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.StreamCleanup
  alias FrontmanServer.Vault
  alias ReqLLM.Message.ContentPart

  @system_prompt """
  Generate a concise 3-6 word title for this chat based on the user's message.
  Return only the title text, nothing else. No quotes, no punctuation at the end.
  """

  @typedoc "Arguments for enqueuing a title generation job."
  @type job_args :: %{
          user_id: String.t(),
          task_id: String.t(),
          user_prompt_text: String.t(),
          model: String.t() | nil,
          encrypted_env_api_key: String.t()
        }

  @doc """
  Builds an Oban job changeset for title generation.
  """
  @spec new_job(Scope.t(), String.t(), String.t(), String.t() | nil) :: Oban.Job.changeset()
  def new_job(%Scope{user: user} = scope, task_id, user_prompt_text, model) do
    new(%{
      user_id: user.id,
      task_id: task_id,
      user_prompt_text: user_prompt_text,
      model: model,
      encrypted_env_api_key: encrypt_env_api_key(scope.env_api_keys)
    })
  end

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
    env_api_keys = args |> Map.get("encrypted_env_api_key") |> decrypt_env_api_key()
    scope = user |> Scope.for_user() |> Scope.with_env_api_keys(env_api_keys)
    model = Map.get(args, "model")

    with {:ok, resolved_key} <-
           Providers.prepare_api_key(scope, model, skip_quota: true),
         {:ok, raw_title} <- call_llm(resolved_key, user_prompt_text),
         title = String.trim(raw_title),
         false <- title == "",
         :ok <- Tasks.set_generated_title(scope, task_id, title) do
      :ok
    else
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

  defp call_llm(%ResolvedKey{} = resolved_key, user_prompt_text) do
    messages = [
      ReqLLM.Context.system([ContentPart.text(@system_prompt)]),
      ReqLLM.Context.user(user_prompt_text)
    ]

    {model_spec, llm_opts} = ResolvedKey.to_llm_args(resolved_key, max_tokens: 30)

    case ReqLLM.stream_text(model_spec, messages, llm_opts) do
      {:ok, response} ->
        title =
          response.stream
          |> Stream.filter(fn chunk -> chunk.type == :content end)
          |> Stream.map(fn chunk -> chunk.text || "" end)
          |> StreamCleanup.wrap_stream(response.cancel)
          |> Enum.join("")

        {:ok, title}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp encrypt_env_api_key(env_api_key) when env_api_key == %{}, do: nil

  defp encrypt_env_api_key(env_api_key) do
    env_api_key |> Jason.encode!() |> Vault.encrypt!() |> Base.encode64()
  end

  defp decrypt_env_api_key(nil), do: %{}

  defp decrypt_env_api_key(encrypted) do
    encrypted |> Base.decode64!() |> Vault.decrypt!() |> Jason.decode!()
  end
end
