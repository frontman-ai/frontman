defmodule FrontmanServer.Tasks.TitleGenerator do
  @moduledoc """
  Generates short task titles from user prompts using the user's selected model.

  Runs asynchronously after the first user message to avoid blocking the prompt flow.
  Uses the same model and API key resolution as the main agent so the user's
  selected provider/model is respected. Falls back to a cheap default model
  if no model is selected.

  Updates the task's short_desc in the database and broadcasts the new title
  to the client via PubSub.
  """

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks
  alias ReqLLM.Message.ContentPart

  @fallback_model "openrouter:google/gemini-2.0-flash-lite"
  @title_pubsub_topic "title_updates"
  # Timeout for the entire title generation task (LLM call + DB update + broadcast).
  # Prevents hung LLM streams from leaking processes indefinitely.
  @task_timeout_ms :timer.seconds(30)

  @system_prompt """
  Generate a concise 3-6 word title for this chat based on the user's message.
  Return only the title text, nothing else. No quotes, no punctuation at the end.
  """

  @doc """
  Asynchronously generates a title for a task from the user's prompt text.

  Uses the user's selected model when available, falling back to a cheap default.
  Resolves the API key through the standard priority chain (OAuth → user key → env key → server key).

  Fails silently if no API key is available or the LLM call fails.
  """
  @spec generate_async(Scope.t(), String.t(), String.t(), map() | nil, map()) :: :ok
  def generate_async(
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
          Task.async(fn -> generate(scope, task_id, user_prompt_text, model, env_api_key) end)

        case Task.yield(task, @task_timeout_ms) || Task.shutdown(task) do
          {:ok, _result} ->
            :ok

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

  defp generate(scope, task_id, user_prompt_text, model, env_api_key) do
    # Build the model string from user selection or fall back to default
    model_string = model_to_string(model)

    with {:ok, resolved_key} <- Providers.prepare_api_key(scope, model_string, env_api_key),
         {:ok, title} <- call_llm(resolved_key.api_key, model_string, user_prompt_text),
         title = String.trim(title),
         false <- title == "" do
      Logger.debug(
        "TitleGenerator: Generated title for task #{task_id} using #{model_string}: #{title}"
      )

      save_and_broadcast(scope, task_id, title)
    else
      true ->
        Logger.debug("TitleGenerator: LLM returned empty title, skipping")

      {:error, reason} when reason in [:no_api_key, :usage_limit_exceeded] ->
        Logger.debug("TitleGenerator: No API key available (#{model_string}): #{inspect(reason)}")

      {:error, reason} ->
        Logger.warning("TitleGenerator: LLM call failed (#{model_string}): #{inspect(reason)}")
    end
  end

  # Convert the model selection map to a "provider:value" string
  defp model_to_string(%{provider: provider, value: value})
       when is_binary(provider) and is_binary(value) and provider != "" and value != "" do
    "#{provider}:#{value}"
  end

  defp model_to_string(_), do: @fallback_model

  defp save_and_broadcast(scope, task_id, title) do
    case Tasks.update_short_desc(scope, task_id, title) do
      {:ok, _} ->
        broadcast_title_update(scope, task_id, title)

      {:error, reason} ->
        Logger.warning(
          "TitleGenerator: Failed to update title for task #{task_id}: #{inspect(reason)}"
        )
    end
  end

  defp call_llm(api_key, model, user_prompt_text) do
    messages = [
      ReqLLM.Context.system([ContentPart.text(@system_prompt)]),
      ReqLLM.Context.user(user_prompt_text)
    ]

    opts = [api_key: api_key, max_tokens: 30]

    case ReqLLM.stream_text(model, messages, opts) do
      {:ok, response} ->
        title =
          response.stream
          |> Stream.filter(fn chunk -> chunk.type == :content end)
          |> Stream.map(fn chunk -> chunk.text || "" end)
          |> Enum.join("")

        {:ok, title}

      {:error, reason} ->
        {:error, reason}
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
