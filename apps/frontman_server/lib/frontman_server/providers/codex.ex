defmodule FrontmanServer.Providers.Codex do
  @moduledoc """
  ChatGPT Codex endpoint wiring.

  When a user authenticates via ChatGPT OAuth, the resolved key carries a
  `codex_endpoint` URL (e.g. `"https://chatgpt.com/backend-api/codex/responses"`).
  Requests to this endpoint require:

    * The `/responses` suffix stripped to get the `base_url`
    * An optional `ChatGPT-Account-Id` header
    * `max_tokens` removed (Codex ignores it)
    * `provider_options: [store: false]`
    * The wire protocol forced to `"openai_responses"`
    * Model alias normalisation (`codex-5.3` → `gpt-5.3-codex`)
    * Model synthesis for entries not yet in LLMDB

  Used by `ResolvedKey.to_llm_args/2` to transform connection config when
  the resolved key carries a Codex endpoint.
  """

  require Logger

  # ── Model helpers ──────────────────────────────────────────────────

  @doc """
  Normalises the ChatGPT Codex model alias.

  The ChatGPT UI sends `"openai:codex-5.3"` but the actual LLMDB / API
  model id is `"openai:gpt-5.3-codex"`.

  ## Examples

      iex> Codex.normalize_model("openai:codex-5.3")
      "openai:gpt-5.3-codex"

      iex> Codex.normalize_model("openai:gpt-5.2-codex")
      "openai:gpt-5.2-codex"
  """
  @spec normalize_model(String.t()) :: String.t()
  def normalize_model("openai:codex-5.3") do
    Logger.debug("Normalizing openai:codex-5.3 → openai:gpt-5.3-codex for Codex endpoint")
    "openai:gpt-5.3-codex"
  end

  def normalize_model(model) when is_binary(model), do: model

  @doc """
  Forces the wire protocol to `"openai_responses"` on an LLMDB model struct.

  The Codex endpoint only speaks the OpenAI Responses API, so we patch
  `model.extra.wire.protocol` regardless of what LLMDB declares.
  """
  @spec force_responses_protocol(map()) :: map()
  def force_responses_protocol(model) do
    extra = model.extra || %{}
    wire = Map.get(extra, :wire, %{})
    patched_extra = Map.put(extra, :wire, Map.put(wire, :protocol, "openai_responses"))
    %{model | extra: patched_extra}
  end

  @doc """
  Builds an LLMDB-compatible model spec for a Codex model string that
  isn't catalogued in LLMDB yet.

  Clones `gpt-5.2-codex` (which *is* catalogued) and swaps the model id.
  Falls back to the raw model string when even the base entry is missing.
  """
  @spec synthesize_model(String.t()) :: map() | String.t()
  def synthesize_model("openai:gpt-5.3-codex") do
    case ReqLLM.model("openai:gpt-5.2-codex") do
      {:ok, base} ->
        %{force_responses_protocol(base) | id: "gpt-5.3-codex", model: "gpt-5.3-codex"}

      {:error, _} ->
        "openai:gpt-5.3-codex"
    end
  end

  def synthesize_model(model_string) when is_binary(model_string), do: model_string

  @doc """
  Resolves a Codex model string to an LLMDB struct with the Responses
  protocol forced, synthesising a spec when the model isn't catalogued.

  This is the high-level entry point — call it instead of chaining
  `ReqLLM.model` + `force_responses_protocol` + `synthesize_model` manually.

  ## Examples

      iex> Codex.resolve_model("openai:gpt-5.2-codex")
      # => %LLMDB.Model{..., extra: %{wire: %{protocol: "openai_responses"}}}
  """
  @spec resolve_model(String.t()) :: map() | String.t()
  def resolve_model(model_string) when is_binary(model_string) do
    case ReqLLM.model(model_string) do
      {:ok, model} -> force_responses_protocol(model)
      {:error, _} -> synthesize_model(model_string)
    end
  end

  # ── LLM opts helpers ───────────────────────────────────────────────

  @doc """
  Derives the ReqLLM `base_url` from a Codex endpoint URL by stripping
  the `/responses` suffix.

  ## Examples

      iex> Codex.base_url("https://chatgpt.com/backend-api/codex/responses")
      "https://chatgpt.com/backend-api/codex"
  """
  @spec base_url(String.t()) :: String.t()
  def base_url(endpoint) when is_binary(endpoint) do
    String.replace_suffix(endpoint, "/responses", "")
  end

  @doc """
  Builds the extra headers list for a Codex request.

  Returns `[{"ChatGPT-Account-Id", id}]` when the account id is a
  non-empty binary, `[]` otherwise.
  """
  @spec extra_headers(String.t() | nil) :: [{String.t(), String.t()}]
  def extra_headers(account_id) when is_binary(account_id) and account_id != "" do
    [{"ChatGPT-Account-Id", account_id}]
  end

  def extra_headers(_), do: []

  @doc """
  Patches a keyword list of ReqLLM options for the Codex endpoint.

  Applies:
    * `base_url` derived from `endpoint`
    * `extra_headers` with optional account id
    * Removes `max_tokens`
    * Adds `provider_options: [store: false]`
  """
  @spec patch_llm_opts(keyword(), String.t(), String.t() | nil) :: keyword()
  def patch_llm_opts(opts, endpoint, account_id) when is_binary(endpoint) do
    opts
    |> Keyword.put(:base_url, base_url(endpoint))
    |> Keyword.put(:extra_headers, extra_headers(account_id))
    |> Keyword.delete(:max_tokens)
    |> Keyword.update(:provider_options, [store: false], &Keyword.put(&1, :store, false))
  end
end
