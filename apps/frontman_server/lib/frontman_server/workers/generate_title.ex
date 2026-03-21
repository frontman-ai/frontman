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
  alias ReqLLM.Message.ContentPart

  @fallback_model "openrouter:google/gemini-2.0-flash-001"

  @system_prompt """
  Generate a concise 3-6 word title for this chat based on the user's message.
  Return only the title text, nothing else. No quotes, no punctuation at the end.
  """

  @typedoc "Arguments for enqueuing a title generation job."
  @type job_args :: %{
          user_id: String.t(),
          task_id: String.t(),
          user_prompt_text: String.t()
        }

  @doc """
  Builds an Oban job changeset for title generation.
  """
  @spec new_job(String.t(), String.t(), String.t()) :: Oban.Job.changeset()
  def new_job(user_id, task_id, user_prompt_text) do
    new(%{
      user_id: user_id,
      task_id: task_id,
      user_prompt_text: user_prompt_text
    })
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "user_id" => user_id,
          "task_id" => task_id,
          "user_prompt_text" => user_prompt_text
        }
      }) do
    user = Accounts.get_user!(user_id)
    scope = Scope.for_user(user)
    with {:ok, resolved_key} <-
           Providers.prepare_api_key(scope, @fallback_model, %{}, skip_quota: true),
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
end
