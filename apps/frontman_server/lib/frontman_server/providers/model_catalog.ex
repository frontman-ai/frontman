# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.ModelCatalog do
  @moduledoc """
  Client-facing model catalog.

  Owns the model lists, display names, defaults, and tier logic.
  Config options are delivered via ACP session responses and channel
  notifications (see `Providers.model_config_data/2`).

  ## Provider tiers

  Some providers have multiple tiers (e.g. OpenRouter has a *full* list
  for users with their own key and a *free* list for server-key fallback).
  Tiers are selected at query time via `models_for_provider/2`.
  """

  alias FrontmanServer.Providers.Registry

  # ── Model lists ────────────────────────────────────────────────────

  @openrouter_models [
    %{displayName: "GPT-5.5", value: "openai/gpt-5.5"},
    %{displayName: "GPT-5.4 Pro", value: "openai/gpt-5.4-pro"},
    %{displayName: "GPT-5.4", value: "openai/gpt-5.4"},
    %{displayName: "GPT-5.3 Codex", value: "openai/gpt-5.3-codex"},
    %{displayName: "GPT-4.1", value: "openai/gpt-4.1"},
    %{displayName: "o3", value: "openai/o3"},
    %{displayName: "o4-mini", value: "openai/o4-mini"},
    %{displayName: "Claude Opus 4.6", value: "anthropic/claude-opus-4.6"},
    %{displayName: "Claude Sonnet 4.5", value: "anthropic/claude-sonnet-4.5"},
    %{displayName: "Claude Opus 4.5", value: "anthropic/claude-opus-4.5"},
    %{displayName: "Claude Haiku 4.5", value: "anthropic/claude-haiku-4.5"},
    %{displayName: "Gemini 3 Pro Preview", value: "google/gemini-3-pro-preview"},
    %{displayName: "Gemini 3 Flash Preview", value: "google/gemini-3-flash-preview"},
    %{displayName: "Gemini 2.5 Pro", value: "google/gemini-2.5-pro"}
  ]

  @openrouter_free_models [
    %{displayName: "Gemini 3 Flash", value: "google/gemini-3-flash-preview"},
    %{displayName: "Claude Haiku 4.5", value: "anthropic/claude-haiku-4.5"},
    %{displayName: "Kimi K2.5", value: "moonshotai/kimi-k2.5"},
    %{displayName: "Minimax M2.5", value: "minimax/minimax-m2.5"}
  ]

  @anthropic_models [
    %{displayName: "Claude Opus 4.6", value: "claude-opus-4-6"},
    %{displayName: "Claude Sonnet 4.5", value: "claude-sonnet-4-5"},
    %{displayName: "Claude Opus 4.5", value: "claude-opus-4-5"},
    %{displayName: "Claude Haiku 4.5", value: "claude-haiku-4-5"},
    %{displayName: "Claude Sonnet 4", value: "claude-sonnet-4-20250514"},
    %{displayName: "Claude Opus 4", value: "claude-opus-4-20250514"}
  ]

  @fireworks_models [
    %{displayName: "Kimi K2.5 Turbo", value: "accounts/fireworks/routers/kimi-k2p5-turbo"}
  ]

  @openai_models [
    %{displayName: "GPT-5.5", value: "gpt-5.5"},
    %{displayName: "GPT-5.4", value: "gpt-5.4"},
    %{displayName: "GPT-5.3 Codex", value: "gpt-5.3-codex"}
  ]

  @models %{
    "openrouter" => %{full: @openrouter_models, free: @openrouter_free_models},
    "anthropic" => %{full: @anthropic_models},
    "fireworks" => %{full: @fireworks_models},
    "openai" => %{full: @openai_models}
  }

  @defaults %{
    "openrouter" => %{provider: "openrouter", value: "google/gemini-3-flash-preview"},
    "anthropic" => %{provider: "anthropic", value: "claude-sonnet-4-5"},
    "fireworks" => %{provider: "fireworks", value: "accounts/fireworks/routers/kimi-k2p5-turbo"},
    "openai" => %{provider: "openai", value: "gpt-5.5"}
  }

  # ── Public API ─────────────────────────────────────────────────────

  @doc """
  Returns the model list for a provider and tier.

  `tier` is `:full` (user has their own key) or `:free` (server-key fallback).
  Falls back to `:full` when the requested tier doesn't exist.
  Returns `[]` for providers without a catalog entry.

  ## Examples

      iex> ModelCatalog.models("openai", :full) |> length()
      4

      iex> ModelCatalog.models("openrouter", :free) |> length()
      4
  """
  @spec models(String.t(), :full | :free) :: [map()]
  def models(provider, tier \\ :full) when is_binary(provider) do
    case Map.get(@models, String.downcase(provider)) do
      %{} = tiers -> Map.get(tiers, tier) || Map.get(tiers, :full, [])
      nil -> []
    end
  end

  @doc """
  Returns the default model map for a provider, or `nil`.

  ## Examples

      iex> ModelCatalog.default_model("openai")
      %{provider: "openai", value: "gpt-5.5"}
  """
  @spec default_model(String.t()) :: map() | nil
  def default_model(provider) when is_binary(provider) do
    Map.get(@defaults, String.downcase(provider))
  end

  @doc """
  Builds a model group for a provider at the given tier.

  A model group is the domain concept for a set of models offered by a
  single provider (e.g. "Anthropic full-tier models").  It's consumed by
  the ACP translation layer to build `SessionConfigOption` payloads.

  ## Examples

      iex> ModelCatalog.model_group("anthropic", :full)
      %{id: "anthropic", name: "Anthropic (Claude Pro/Max)", models: [...]}
  """
  @spec model_group(String.t(), :full | :free) :: map()
  def model_group(provider, tier \\ :full) when is_binary(provider) do
    %{
      id: provider,
      name: Registry.display_name(provider) || provider,
      models: models(provider, tier)
    }
  end

  @doc """
  Returns the list of providers that have catalog entries, sorted by
  Registry priority (lower = first).
  """
  @spec catalog_providers() :: [String.t()]
  def catalog_providers do
    @models
    |> Map.keys()
    |> Enum.sort_by(&(Registry.priority(&1) || 999))
  end

  @doc """
  Picks the best default model from the available providers, ordered by
  Registry priority (lower = preferred).

  Returns the default for the highest-priority provider that appears in
  `available_providers`, or the OpenRouter default as last resort.

  ## Parameters

    * `available_providers` – list of provider id strings the user has access to.
  """
  @spec pick_default([String.t()]) :: map()
  def pick_default(available_providers) when is_list(available_providers) do
    available_providers
    |> Enum.sort_by(&(Registry.priority(&1) || 999))
    |> Enum.find_value(fn provider -> default_model(provider) end) ||
      default_model("openrouter")
  end

  @doc """
  Returns whether a provider has a free tier in the catalog.
  """
  @spec has_free_tier?(String.t()) :: boolean()
  def has_free_tier?(provider) do
    case Map.get(@models, String.downcase(provider)) do
      %{free: _} -> true
      _ -> false
    end
  end
end
