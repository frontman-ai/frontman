defmodule FrontmanServer.Tasks.TitleGenerator do
  @moduledoc """
  Generates short task titles from user prompts using the user's selected model.

  Runs asynchronously after the first user message to avoid blocking the prompt flow.
  Uses the standard `Providers.prepare_api_key` resolution (with quota bypass) so the
  user's selected provider/model is respected. Falls back to a cheap default model
  if no model is selected.

  Updates the task's short_desc in the database and broadcasts the new title
  to the client via PubSub.
  """

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.{Model, ResolvedKey}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.StreamCleanup
  alias ReqLLM.Message.ContentPart

  @fallback_model "openrouter:google/gemini-2.0-flash-001"
  @title_pubsub_topic "title_updates"
  # Timeout for the entire title generation task (LLM call + DB update + broadcast).
  # Prevents hung LLM streams from leaking processes indefinitely.
  @task_timeout_ms :timer.seconds(30)

  @system_prompt """
  Generate a concise 3-6 word title for this chat based on the user's message.
  Return only the title text, nothing else. No quotes, no punctuation at the end.
  """

  @doc """
  Generates a title for a task from the user's prompt text.

  Runs asynchronously under a Task.Supervisor. Uses the user's selected model
  when available, falling back to a cheap default. Resolves the API key through
  the standard priority chain (OAuth > user key > env key > server key), bypassing
  quota checks since title generation is a cheap internal operation (~30 tokens).

  Fails silently if no API key is available or the LLM call fails.
  """
  @spec generate(Scope.t(), String.t(), String.t(), map() | nil, map()) :: :ok
  def generate(
        %Scope{} = scope,
        task_id,
        user_prompt_text,
        model \\ nil,
        env_api_key \\ %{}
      ) do
    Task.Supervisor.start_child(
      FrontmanServer.TaskSupervisor,
      fn ->
        task =
          Task.async(fn -> do_generate(scope, task_id, user_prompt_text, model, env_api_key) end)

        case Task.yield(task, @task_timeout_ms) || Task.shutdown(task) do
          {:ok, _result} ->
            :ok

          {:exit, reason} ->
            Logger.warning("TitleGenerator: Task crashed for #{task_id}: #{inspect(reason)}")

          nil ->
            Logger.warning(
              "TitleGenerator: Timed out after #{@task_timeout_ms}ms for task #{task_id}"
            )
        end
      end
    )

    :ok
  end

  @doc """
  Returns the PubSub topic for title updates for a given user.
  """
  @spec pubsub_topic(String.t()) :: String.t()
  def pubsub_topic(user_id) do
    "#{@title_pubsub_topic}:#{user_id}"
  end

  defp do_generate(scope, task_id, user_prompt_text, model, env_api_key) do
    model_string = Model.resolve_string(model) || @fallback_model

    with {:ok, resolved_key} <-
           Providers.prepare_api_key(scope, model_string, env_api_key, skip_quota: true),
         {:ok, raw_title} <- call_llm(resolved_key, user_prompt_text),
         title = String.trim(raw_title),
         false <- title == "" do
      save_and_broadcast(scope, task_id, title)
    else
      {:error, :no_api_key} ->
        Logger.debug("TitleGenerator: No API key available (#{model_string})")

      {:error, reason} ->
        Logger.warning("TitleGenerator: Failed (#{model_string}): #{inspect(reason)}")

      true ->
        Logger.debug("TitleGenerator: LLM returned empty title, skipping")
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

  defp save_and_broadcast(scope, task_id, title) do
    case Tasks.update_short_desc(scope, task_id, title) do
      {:ok, _updated} ->
        broadcast_title_update(scope, task_id, title)

      {:error, reason} ->
        Logger.warning(
          "TitleGenerator: Failed to update title for task #{task_id}: #{inspect(reason)}"
        )
    end
  end

  defp broadcast_title_update(scope, task_id, title) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      pubsub_topic(scope.user.id),
      {:title_updated, task_id, title}
    )
  end
end
