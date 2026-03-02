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
  alias FrontmanServer.Tasks.StreamCleanup
  alias ReqLLM.Message.ContentPart

  @fallback_model "openrouter:google/gemini-2.0-flash-001"
  # OAuth opts consumed by prepare_model_and_opts but not understood by ReqLLM.
  # Stripped before calling stream_text to avoid leaking provider-internal keys.
  @internal_oauth_keys [
    :codex_endpoint,
    :chatgpt_account_id,
    :requires_mcp_prefix,
    :identity_override
  ]
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

  defp generate(scope, task_id, user_prompt_text, model, env_api_key) do
    model_string = model_to_string(model)

    with {:ok, api_key, key_opts} <- resolve_api_key(scope, model_string, env_api_key),
         {:ok, title} <- call_llm(api_key, model_string, user_prompt_text, key_opts) do
      title = String.trim(title)

      if title == "" do
        Logger.debug("TitleGenerator: LLM returned empty title, skipping")
      else
        save_and_broadcast(scope, task_id, title)
      end
    else
      {:error, :no_key, reason} ->
        Logger.debug("TitleGenerator: No API key available (#{model_string}): #{inspect(reason)}")

      {:error, reason} ->
        Logger.warning("TitleGenerator: LLM call failed (#{model_string}): #{inspect(reason)}")
    end
  end

  # Resolve API key for title generation, bypassing usage quota checks.
  #
  # Title generation is a cheap internal operation (~30 tokens) that should
  # always work regardless of the user's free-tier server-key usage.
  # We use Providers.resolve_api_key (which finds the best key without quota
  # checks) instead of Providers.prepare_api_key (which rejects server keys
  # when the user's quota is exhausted).
  defp resolve_api_key(scope, model_string, env_api_key) do
    provider = Providers.provider_from_model(model_string)

    case Providers.resolve_api_key(scope, provider, env_api_key) do
      {:oauth_token, access_token, oauth_opts} -> {:ok, access_token, oauth_opts}
      {:user_key, key} -> {:ok, key, []}
      {:env_key, key} -> {:ok, key, []}
      {:server_key, key} when is_binary(key) and key != "" -> {:ok, key, []}
      {:server_key, _} -> {:error, :no_key, :no_api_key}
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
      {:ok, _updated} ->
        broadcast_title_update(scope, task_id, title)

      {:error, reason} ->
        Logger.warning(
          "TitleGenerator: Failed to update title for task #{task_id}: #{inspect(reason)}"
        )
    end
  end

  defp call_llm(api_key, model, user_prompt_text, key_opts) do
    messages = [
      ReqLLM.Context.system([ContentPart.text(@system_prompt)]),
      ReqLLM.Context.user(user_prompt_text)
    ]

    {model_spec, opts} = prepare_model_and_opts(model, api_key, key_opts)

    case ReqLLM.stream_text(model_spec, messages, opts) do
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

  # ChatGPT OAuth Codex endpoint needs Responses API config and specific model wiring.
  # Consumes codex_endpoint/chatgpt_account_id from key_opts, then strips all
  # internal OAuth keys so only ReqLLM-compatible options reach stream_text.
  defp prepare_model_and_opts(model_string, api_key, key_opts) do
    base_opts =
      [api_key: api_key, max_tokens: 30]
      |> Keyword.merge(key_opts)
      |> Keyword.drop(@internal_oauth_keys)

    case Keyword.get(key_opts, :codex_endpoint) do
      endpoint when is_binary(endpoint) ->
        normalized_model = normalize_chatgpt_codex_model(model_string)
        base_url = String.replace_suffix(endpoint, "/responses", "")

        extra_headers =
          case Keyword.get(key_opts, :chatgpt_account_id) do
            account_id when is_binary(account_id) and account_id != "" ->
              [{"ChatGPT-Account-Id", account_id}]

            _ ->
              []
          end

        opts =
          base_opts
          |> Keyword.put(:base_url, base_url)
          |> Keyword.put(:extra_headers, extra_headers)
          |> Keyword.delete(:max_tokens)
          |> Keyword.update(:provider_options, [store: false], &Keyword.put(&1, :store, false))

        model_spec = resolve_or_synthesize_codex_model(normalized_model)
        {model_spec, opts}

      _ ->
        {model_string, base_opts}
    end
  end

  defp normalize_chatgpt_codex_model("openai:codex-5.3"), do: "openai:gpt-5.3-codex"
  defp normalize_chatgpt_codex_model(model), do: model

  # Resolve a model from LLMDB and force wire.protocol to openai_responses,
  # or synthesize a spec from gpt-5.2-codex when the model isn't cataloged yet.
  defp resolve_or_synthesize_codex_model(model_string) do
    case ReqLLM.model(model_string) do
      {:ok, model} -> force_responses_protocol(model)
      {:error, _} -> synthesize_codex_model(model_string)
    end
  end

  defp force_responses_protocol(model) do
    extra = model.extra || %{}
    wire = Map.get(extra, :wire, %{})
    patched_extra = Map.put(extra, :wire, Map.put(wire, :protocol, "openai_responses"))
    %{model | extra: patched_extra}
  end

  # Build a temporary model spec for ChatGPT Codex models not yet in LLMDB.
  # Clones gpt-5.2-codex and swaps the wire model id.
  defp synthesize_codex_model("openai:gpt-5.3-codex") do
    case ReqLLM.model("openai:gpt-5.2-codex") do
      {:ok, base} ->
        %{force_responses_protocol(base) | id: "gpt-5.3-codex", model: "gpt-5.3-codex"}

      {:error, _} ->
        "openai:gpt-5.3-codex"
    end
  end

  defp synthesize_codex_model(model_string), do: model_string

  defp broadcast_title_update(scope, task_id, title) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      pubsub_topic(scope.user.id),
      {:title_updated, task_id, title}
    )
  end
end
