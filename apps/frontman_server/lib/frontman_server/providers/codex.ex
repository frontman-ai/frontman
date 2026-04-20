# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.Codex do
  @moduledoc """
  ChatGPT Codex endpoint wiring.

  When a user authenticates via ChatGPT OAuth, the resolved key carries a
  `codex_endpoint` URL (e.g. `"https://chatgpt.com/backend-api/codex/responses"`).
  Requests to this endpoint require:

    * The `/responses` suffix stripped to get the `base_url`
    * Optional `chatgpt_account_id` passed to ReqLLM
    * `max_tokens` removed (Codex ignores it)
    * Model alias normalisation (`codex-5.3` → `gpt-5.3-codex`)
    * Provider namespace normalisation (`openai:*` → `openai_codex:*`)
    * Model synthesis for entries not yet in LLMDB

  Used by `ResolvedKey.to_llm_args/2` to transform connection config when
  the resolved key carries a Codex endpoint.
  """

  require Logger

  # ── Model helpers ──────────────────────────────────────────────────

  @doc """
  Normalises the ChatGPT Codex model alias.

  The ChatGPT UI sends `"openai:codex-5.3"` but the actual LLMDB / API
  model id is `"openai_codex:gpt-5.3-codex"`.

  ## Examples

      iex> Codex.normalize_model("openai:codex-5.3")
      "openai_codex:gpt-5.3-codex"

      iex> Codex.normalize_model("openai:gpt-5.2-codex")
      "openai_codex:gpt-5.2-codex"
  """
  @spec normalize_model(String.t()) :: String.t()
  def normalize_model("openai:codex-5.3") do
    Logger.debug("Normalizing openai:codex-5.3 → openai_codex:gpt-5.3-codex")
    "openai_codex:gpt-5.3-codex"
  end

  def normalize_model("openai:" <> model_id), do: "openai_codex:" <> model_id

  def normalize_model(model) when is_binary(model), do: model

  @doc """
  Builds an explicit model spec for an OpenAI Codex model string that
  is not yet catalogued in LLMDB.
  """
  @spec synthesize_model(String.t()) :: map() | String.t()
  def synthesize_model("openai_codex:" <> model_id) do
    %{
      provider: :openai_codex,
      id: model_id,
      model: model_id,
      provider_model_id: model_id,
      extra: %{wire: %{protocol: "openai_codex_responses"}}
    }
  end

  def synthesize_model(model_string) when is_binary(model_string), do: model_string

  @doc """
  Resolves an OpenAI Codex model string to an LLMDB struct, synthesising
  a spec when the model isn't catalogued.

  This is the high-level entry point — call it instead of chaining
  `ReqLLM.model` + `synthesize_model` manually.

  ## Examples

      iex> Codex.resolve_model("openai_codex:gpt-5.2-codex")
      # => %LLMDB.Model{provider: :openai_codex, ...}
  """
  @spec resolve_model(String.t()) :: map() | String.t()
  def resolve_model(model_string) when is_binary(model_string) do
    case ReqLLM.model(model_string) do
      {:ok, model} -> model
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
  Patches a keyword list of ReqLLM options for the Codex endpoint.

  Applies:
    * `base_url` derived from `endpoint`
    * Optional `chatgpt_account_id`
    * Removes `max_tokens`
  """
  @spec patch_llm_opts(keyword(), String.t(), String.t() | nil) :: keyword()
  def patch_llm_opts(opts, endpoint, account_id) when is_binary(endpoint) do
    opts
    |> Keyword.put(:base_url, base_url(endpoint))
    |> Keyword.delete(:max_tokens)
    |> maybe_put_chatgpt_account_id(account_id)
  end

  defp maybe_put_chatgpt_account_id(opts, account_id)
       when is_binary(account_id) and account_id != "" do
    Keyword.put(opts, :chatgpt_account_id, account_id)
  end

  defp maybe_put_chatgpt_account_id(opts, _), do: opts
end
