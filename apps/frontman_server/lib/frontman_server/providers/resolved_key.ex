# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.ResolvedKey do
  @moduledoc """
  Resolved provider request data.
  """

  use TypedStruct

  typedstruct do
    field(:provider, String.t(), enforce: true)
    field(:model, String.t() | map(), enforce: true)
    field(:llm_opts, keyword(), enforce: true)
  end

  @spec to_llm_args(t(), keyword()) :: {String.t() | map(), keyword()}
  def to_llm_args(key, extra_opts \\ [])

  def to_llm_args(
        %__MODULE__{model: %{provider: :openai_codex} = model, llm_opts: opts},
        extra_opts
      ) do
    llm_opts =
      opts
      |> Keyword.merge(extra_opts)
      |> Keyword.delete(:max_tokens)

    {model, llm_opts}
  end

  def to_llm_args(%__MODULE__{model: model, llm_opts: opts}, extra_opts) do
    {model, Keyword.merge(opts, extra_opts)}
  end
end
